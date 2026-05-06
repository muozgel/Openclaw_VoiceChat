import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var gatewayURL: String {
        didSet { UserDefaults.standard.set(gatewayURL, forKey: "gatewayURL") }
    }
    @Published var gatewayToken: String {
        didSet { UserDefaults.standard.set(gatewayToken, forKey: "gatewayToken") }
    }
    @Published var sessionKey: String {
        didSet { UserDefaults.standard.set(sessionKey, forKey: "sessionKey") }
    }
    @Published var speakReplies: Bool {
        didSet { UserDefaults.standard.set(speakReplies, forKey: "speakReplies") }
    }

    init() {
        gatewayURL = UserDefaults.standard.string(forKey: "gatewayURL") ?? "wss://murats-mac-mini.tail60faa0.ts.net"
        gatewayToken = UserDefaults.standard.string(forKey: "gatewayToken") ?? ""
        sessionKey = UserDefaults.standard.string(forKey: "sessionKey") ?? "main"
        speakReplies = UserDefaults.standard.object(forKey: "speakReplies") as? Bool ?? true
    }
}
