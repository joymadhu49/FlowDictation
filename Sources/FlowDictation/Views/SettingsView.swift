import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dictationManager: DictationManager
    @State private var showAPIKey = false
    @State private var testResult: String?
    @State private var isTesting = false
    @State private var isRecordingHotkey = false
    @State private var hotkeyMonitor: Any?

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            apiTab
                .tabItem {
                    Label("API", systemImage: "key.fill")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 350)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section {
                Picker("Hotkey", selection: $dictationManager.selectedHotkey) {
                    ForEach(HotkeyOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                if dictationManager.selectedHotkey == .custom {
                    HStack {
                        Text("Shortcut:")
                        Button(action: { startRecordingHotkey() }) {
                            Text(isRecordingHotkey ? "Press keys..."
                                 : (dictationManager.customHotkey?.displayName ?? "Click to set"))
                                .frame(minWidth: 120)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isRecordingHotkey ? Color.orange.opacity(0.2) : Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if dictationManager.selectedHotkey == .custom {
                    Text("Press a key combination with at least one modifier (Cmd, Option, Shift, or Control) to set your custom hotkey.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Hold the selected key to record, release to transcribe.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Hotkey")
            }

            Section {
                Toggle("Auto-insert text at cursor", isOn: $dictationManager.autoInsertText)
                Text(dictationManager.autoInsertText
                     ? "Transcribed text will be pasted at the current cursor position."
                     : "Transcribed text will be copied to the clipboard.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Text Insertion")
            }

            Section {
                Toggle("Sound feedback", isOn: $dictationManager.soundEnabled)

                if dictationManager.soundEnabled {
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Slider(value: $dictationManager.soundVolume, in: 0.05...1.0, step: 0.05)
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                Toggle("Enable dictation", isOn: $dictationManager.isEnabled)
            } header: {
                Text("Behavior")
            }

            Section {
                Button("Check Accessibility Permission") {
                    _ = GlobalHotkeyManager.checkAccessibilityPermission()
                }
                Text("Accessibility access is required for global hotkeys and text insertion.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Permissions")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - API Tab

    private var apiTab: some View {
        Form {
            Section {
                HStack {
                    if showAPIKey {
                        TextField("Enter Groq API Key", text: $dictationManager.apiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("Enter Groq API Key", text: $dictationManager.apiKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button(action: { showAPIKey.toggle() }) {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }

                Text("Get your API key from [console.groq.com](https://console.groq.com)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Groq API Key")
            }

            Section {
                HStack {
                    Button(action: testAPI) {
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Text("Test Connection")
                        }
                    }
                    .disabled(dictationManager.apiKey.isEmpty || isTesting)

                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.contains("Success") ? .green : .red)
                    }
                }
            } header: {
                Text("Connection Test")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model: whisper-large-v3-turbo")
                    Text("Max file size: 25MB")
                    Text("Supported format: WAV (16kHz mono)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } header: {
                Text("API Details")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("FlowDictation")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("A lightweight voice dictation app powered by Groq's Whisper API.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Text("Hold your hotkey to record, release to transcribe. Text is automatically inserted at your cursor.")
                .font(.caption)
                .foregroundColor(.secondary)
                .opacity(0.6)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Hotkey Recording

    private func startRecordingHotkey() {
        isRecordingHotkey = true
        hotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])
            // Require at least one modifier
            if !modifiers.isEmpty {
                let config = CustomHotkeyConfig(keyCode: event.keyCode, modifierFlags: modifiers.rawValue)
                dictationManager.customHotkey = config
                stopRecordingHotkey()
            }
            return nil  // consume the event
        }
    }

    private func stopRecordingHotkey() {
        isRecordingHotkey = false
        if let monitor = hotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            hotkeyMonitor = nil
        }
    }

    // MARK: - Actions

    private func testAPI() {
        isTesting = true
        testResult = nil

        // Quick validation - just check if the API key format seems right
        if dictationManager.apiKey.isEmpty {
            testResult = "API key is empty"
            isTesting = false
            return
        }

        // Make a simple request to validate the key
        Task {
            do {
                let url = URL(string: "https://api.groq.com/openai/v1/models")!
                var request = URLRequest(url: url)
                request.setValue("Bearer \(dictationManager.apiKey)", forHTTPHeaderField: "Authorization")
                request.timeoutInterval = 10

                let (_, response) = try await URLSession.shared.data(for: request)
                let httpResponse = response as? HTTPURLResponse

                await MainActor.run {
                    if httpResponse?.statusCode == 200 {
                        testResult = "Success! API key is valid."
                    } else if httpResponse?.statusCode == 401 {
                        testResult = "Invalid API key."
                    } else {
                        testResult = "Error: HTTP \(httpResponse?.statusCode ?? 0)"
                    }
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = "Connection error: \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(DictationManager())
    }
}
