import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var dictationManager: DictationManager
    @State private var pulsingOpacity: Double = 1.0

    private var hotkeyDisplayName: String {
        if dictationManager.selectedHotkey == .custom, let config = dictationManager.customHotkey {
            return config.displayName
        }
        return dictationManager.selectedHotkey.displayName
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // Status section
            statusSection

            Divider()

            // API key setup (shown when no key is set)
            if dictationManager.apiKey.isEmpty {
                apiKeySetupSection
                Divider()
            }

            // Last transcription
            transcriptionSection

            Divider()

            // Quick settings
            quickSettingsSection

            Divider()

            // Footer buttons
            footerSection
        }
        .frame(width: 300)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            Text("FlowDictation")
                .font(.headline)
            Spacer()
            statusBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statusBadge: some View {
        Group {
            switch dictationManager.state {
            case .idle:
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            case .recording:
                Label("Recording", systemImage: "record.circle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            case .transcribing:
                Label("Processing", systemImage: "ellipsis.circle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            case .error:
                Label("Error", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(spacing: 8) {
            switch dictationManager.state {
            case .idle:
                HStack {
                    Image(systemName: "keyboard")
                        .foregroundColor(.secondary)
                    Text("Hold \(hotkeyDisplayName) to dictate")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

            case .recording:
                VStack(spacing: 6) {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .opacity(pulsingOpacity)
                        Text("Recording...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Text(String(format: "%.1fs", dictationManager.recordingDuration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

            case .transcribing:
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Transcribing...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

            case .error(let message):
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - API Key Setup (inline in popover)

    private var apiKeySetupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("API Key Required", systemImage: "key.fill")
                .font(.caption)
                .foregroundColor(.orange)

            SecureField("Paste Groq API key here", text: $dictationManager.apiKey)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            Text("Get a free key at console.groq.com")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Transcription

    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Last Transcription")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            if dictationManager.lastTranscription.isEmpty {
                Text("No transcriptions yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(0.6)
                    .italic()
            } else {
                Text(dictationManager.lastTranscription)
                    .font(.system(.caption, design: .rounded))
                    .lineLimit(4)
                    .textSelection(.enabled)

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(dictationManager.lastTranscription, forType: .string)
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.link)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Quick Settings

    private var quickSettingsSection: some View {
        VStack(spacing: 6) {
            Toggle(isOn: $dictationManager.isEnabled) {
                Label("Dictation Enabled", systemImage: "mic.fill")
                    .font(.subheadline)
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Toggle(isOn: $dictationManager.soundEnabled) {
                Label("Sound Feedback", systemImage: "speaker.wave.2.fill")
                    .font(.subheadline)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            settingsButton

            Spacer()

            Button(action: {
                NSApp.terminate(nil)
            }) {
                Label("Quit", systemImage: "power")
                    .font(.subheadline)
            }
            .buttonStyle(.link)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var settingsButton: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                Label("Settings...", systemImage: "gear")
                    .font(.subheadline)
            }
            .buttonStyle(.link)
        } else {
            Button(action: {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }) {
                Label("Settings...", systemImage: "gear")
                    .font(.subheadline)
            }
            .buttonStyle(.link)
        }
    }
}

struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarView()
            .environmentObject(DictationManager())
    }
}
