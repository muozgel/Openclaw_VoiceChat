import AVFoundation
import SwiftUI

struct ContentView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var speech = SpeechService()
    @StateObject private var client = OpenClawClient()
    @State private var showSettings = false
    @State private var errorText: String?
    private let speaker = AVSpeechSynthesizer()

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                statusCard
                transcriptCard
                talkButton
                messagesList
            }
            .padding()
            .navigationTitle("Louis")
            .toolbar { Button("Settings") { showSettings = true } }
            .sheet(isPresented: $showSettings) { SettingsView(settings: settings) }
            .alert("Louis", isPresented: .constant(errorText != nil)) {
                Button("OK") { errorText = nil }
            } message: { Text(errorText ?? "") }
            .task { await speech.requestPermissions() }
            .onChange(of: client.latestAssistantText) { _, text in
                guard settings.speakReplies, !text.isEmpty else { return }
                speak(text)
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(client.status).font(.headline)
            Text(speech.status).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcript").font(.caption).foregroundStyle(.secondary)
            Text(speech.transcript.isEmpty ? "Press and hold to speak." : speech.transcript)
                .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var talkButton: some View {
        Button {
            Task { await toggleRecordingOrSend() }
        } label: {
            Text(speech.isRecording ? "Stop & Send" : "Talk to Louis")
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        }
        .buttonStyle(.borderedProminent)
        .tint(speech.isRecording ? .red : .blue)
    }

    private var messagesList: some View {
        List(client.messages) { message in
            VStack(alignment: .leading, spacing: 4) {
                Text(message.role).font(.caption.bold()).foregroundStyle(.secondary)
                Text(message.text)
            }
        }
        .listStyle(.plain)
    }

    private func toggleRecordingOrSend() async {
        do {
            if speech.isRecording {
                speech.stop()
                let text = speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                if client.status != "Connected" {
                    try await client.connect(urlString: settings.gatewayURL, token: settings.gatewayToken)
                }
                try await client.sendToLouis(text, sessionKey: settings.sessionKey)
            } else {
                try speech.start()
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.48
        speaker.speak(utterance)
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Gateway") {
                    TextField("Gateway URL", text: $settings.gatewayURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    SecureField("Gateway token", text: $settings.gatewayToken)
                    TextField("Session key", text: $settings.sessionKey)
                        .textInputAutocapitalization(.never)
                    Toggle("Speak replies", isOn: $settings.speakReplies)
                }
                Section("Privacy") {
                    Text("This MVP sends only the final transcript after you press Stop & Send. It does not do covert background listening.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
