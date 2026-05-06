import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let text: String
}

@MainActor
final class OpenClawClient: ObservableObject {
    @Published var status = "Disconnected"
    @Published var messages: [ChatMessage] = []
    @Published var latestAssistantText = ""

    private var webSocket: URLSessionWebSocketTask?
    private var continuations: [String: CheckedContinuation<[String: Any], Error>] = [:]
    private var activeRunId: String?
    private var activeReply = ""

    func connect(urlString: String, token: String) async throws {
        guard let url = URL(string: urlString) else { throw ClientError.badURL }
        webSocket?.cancel(with: .goingAway, reason: nil)
        let task = URLSession.shared.webSocketTask(with: url)
        webSocket = task
        task.resume()
        listen()

        let params: [String: Any] = [
            "minProtocol": 3,
            "maxProtocol": 3,
            "client": ["id": "louis-voice-ios", "version": "0.1", "platform": "ios", "mode": "operator"],
            "role": "operator",
            "scopes": ["operator.read", "operator.write"],
            "caps": [],
            "commands": [],
            "permissions": [:],
            "auth": ["token": token],
            "locale": Locale.current.identifier,
            "userAgent": "LouisVoice/0.1"
        ]
        _ = try await request(method: "connect", params: params)
        status = "Connected"
    }

    func sendToLouis(_ text: String, sessionKey: String) async throws {
        messages.append(ChatMessage(role: "You", text: text))
        activeReply = ""
        let idempotencyKey = UUID().uuidString
        let payload = try await request(method: "chat.send", params: [
            "sessionKey": sessionKey,
            "message": text,
            "deliver": false,
            "timeoutMs": 120_000,
            "idempotencyKey": idempotencyKey
        ])
        activeRunId = payload["runId"] as? String
        status = "Louis is thinking…"
    }

    private func request(method: String, params: [String: Any]) async throws -> [String: Any] {
        guard let webSocket else { throw ClientError.notConnected }
        let id = UUID().uuidString
        let frame: [String: Any] = ["type": "req", "id": id, "method": method, "params": params]
        let data = try JSONSerialization.data(withJSONObject: frame)
        let text = String(data: data, encoding: .utf8)!
        return try await withCheckedThrowingContinuation { continuation in
            continuations[id] = continuation
            webSocket.send(.string(text)) { error in
                if let error {
                    Task { @MainActor in
                        self.continuations.removeValue(forKey: id)?.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func listen() {
        webSocket?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                defer { self.listen() }
                do {
                    let text: String
                    switch result {
                    case .success(.string(let s)): text = s
                    case .success(.data(let d)): text = String(decoding: d, as: UTF8.self)
                    case .failure(let error): self.status = "Connection error: \(error.localizedDescription)"; return
                    @unknown default: return
                    }
                    try self.handleFrame(text)
                } catch {
                    self.status = "Parse error: \(error.localizedDescription)"
                }
            }
        }
    }

    private func handleFrame(_ text: String) throws {
        guard let data = text.data(using: .utf8),
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else { return }

        if type == "res", let id = obj["id"] as? String, let cont = continuations.removeValue(forKey: id) {
            if (obj["ok"] as? Bool) == true {
                cont.resume(returning: obj["payload"] as? [String: Any] ?? [:])
            } else {
                cont.resume(throwing: ClientError.gateway(String(describing: obj["error"] ?? "Unknown gateway error")))
            }
            return
        }

        if type == "event", obj["event"] as? String == "chat",
           let payload = obj["payload"] as? [String: Any] {
            handleChatEvent(payload)
        }
    }

    private func handleChatEvent(_ payload: [String: Any]) {
        guard let runId = payload["runId"] as? String, runId == activeRunId else { return }
        let state = payload["state"] as? String ?? ""
        if let message = payload["message"] {
            if let s = message as? String { activeReply += s }
            else if let dict = message as? [String: Any], let text = dict["text"] as? String { activeReply += text }
        }
        if state == "final" || state == "error" || state == "aborted" {
            let finalText = activeReply.trimmingCharacters(in: .whitespacesAndNewlines)
            let visibleText = finalText.isEmpty ? "No visible reply." : finalText
            messages.append(ChatMessage(role: "Louis", text: visibleText))
            latestAssistantText = visibleText
            status = state == "final" ? "Ready" : "Stopped: \(state)"
            activeRunId = nil
        }
    }

    enum ClientError: LocalizedError {
        case badURL, notConnected, gateway(String)
        var errorDescription: String? {
            switch self {
            case .badURL: return "Bad gateway URL"
            case .notConnected: return "Not connected"
            case .gateway(let msg): return msg
            }
        }
    }
}
