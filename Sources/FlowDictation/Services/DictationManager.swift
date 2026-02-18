import Foundation
import Combine
import AppKit

class DictationManager: ObservableObject {
    @Published var state: DictationState = .idle
    @Published var lastTranscription: String = ""
    @Published var isEnabled: Bool = true
    @Published var recordingDuration: TimeInterval = 0

    // Settings (persisted in UserDefaults)
    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "groq_api_key") }
    }
    @Published var selectedHotkey: HotkeyOption {
        didSet {
            UserDefaults.standard.set(selectedHotkey.rawValue, forKey: "selected_hotkey")
            hotkeyManager.selectedHotkey = selectedHotkey
            // Restart monitoring when hotkey type changes
            hotkeyManager.stopMonitoring()
            hotkeyManager.startMonitoring()
        }
    }
    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "sound_enabled") }
    }
    @Published var autoInsertText: Bool {
        didSet { UserDefaults.standard.set(autoInsertText, forKey: "auto_insert_text") }
    }
    @Published var soundVolume: Double {
        didSet {
            UserDefaults.standard.set(soundVolume, forKey: "sound_volume")
            SoundFeedback.shared.volume = Float(soundVolume)
        }
    }
    @Published var customHotkey: CustomHotkeyConfig? {
        didSet {
            if let config = customHotkey, let data = try? JSONEncoder().encode(config) {
                UserDefaults.standard.set(data, forKey: "custom_hotkey")
            } else {
                UserDefaults.standard.removeObject(forKey: "custom_hotkey")
            }
            hotkeyManager.customHotkey = customHotkey
        }
    }

    private let audioRecorder = AudioRecorder()
    private let apiClient = GroqAPIClient()
    private let hotkeyManager = GlobalHotkeyManager()
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private var targetApplication: NSRunningApplication?

    init() {
        // Load persisted settings
        self.apiKey = UserDefaults.standard.string(forKey: "groq_api_key") ?? ""
        let hotkeyRaw = UserDefaults.standard.string(forKey: "selected_hotkey") ?? HotkeyOption.rightOption.rawValue
        self.selectedHotkey = HotkeyOption(rawValue: hotkeyRaw) ?? .rightOption
        self.soundEnabled = UserDefaults.standard.object(forKey: "sound_enabled") as? Bool ?? true
        self.autoInsertText = UserDefaults.standard.object(forKey: "auto_insert_text") as? Bool ?? true
        self.soundVolume = UserDefaults.standard.object(forKey: "sound_volume") as? Double ?? 0.4
        SoundFeedback.shared.volume = Float(self.soundVolume)

        // Load custom hotkey configuration
        if let data = UserDefaults.standard.data(forKey: "custom_hotkey"),
           let config = try? JSONDecoder().decode(CustomHotkeyConfig.self, from: data) {
            self.customHotkey = config
        } else {
            self.customHotkey = nil
        }

        setupHotkey()
    }

    // MARK: - Hotkey Setup

    private func setupHotkey() {
        hotkeyManager.selectedHotkey = selectedHotkey
        hotkeyManager.customHotkey = customHotkey

        hotkeyManager.onHotkeyDown = { [weak self] in
            DispatchQueue.main.async {
                self?.startDictation()
            }
        }

        hotkeyManager.onHotkeyUp = { [weak self] in
            DispatchQueue.main.async {
                self?.stopDictation()
            }
        }

        hotkeyManager.startMonitoring()
    }

    // MARK: - Dictation Control

    func startDictation() {
        guard isEnabled, state == .idle else { return }

        if apiKey.isEmpty {
            state = .error("API key not set. Click the menu bar icon to configure.")
            if soundEnabled { SoundFeedback.shared.playErrorSound() }
            resetErrorAfterDelay()
            return
        }

        // Save the frontmost application so we can paste into it later
        targetApplication = NSWorkspace.shared.frontmostApplication

        do {
            _ = try audioRecorder.startRecording()
            state = .recording
            recordingStartTime = Date()

            if soundEnabled { SoundFeedback.shared.playStartSound() }

            // Start duration timer
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let start = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
            }

        } catch {
            state = .error("Failed to start recording: \(error.localizedDescription)")
            if soundEnabled { SoundFeedback.shared.playErrorSound() }
            resetErrorAfterDelay()
        }
    }

    func stopDictation() {
        guard state == .recording else { return }

        recordingTimer?.invalidate()
        recordingTimer = nil

        guard let audioURL = audioRecorder.stopRecording() else {
            state = .error("No audio recorded.")
            if soundEnabled { SoundFeedback.shared.playErrorSound() }
            resetErrorAfterDelay()
            return
        }

        if soundEnabled { SoundFeedback.shared.playStopSound() }

        // Check minimum recording duration (avoid accidental taps)
        if recordingDuration < 0.3 {
            audioRecorder.cleanup()
            state = .idle
            recordingDuration = 0
            return
        }

        state = .transcribing
        recordingDuration = 0

        // Send to Groq API
        Task {
            do {
                let text = try await apiClient.transcribe(audioFileURL: audioURL, apiKey: apiKey)

                await MainActor.run {
                    self.lastTranscription = text

                    if self.autoInsertText {
                        TextInserter.insertText(text, targetApp: self.targetApplication)
                    } else {
                        // Just copy to clipboard
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }

                    if self.soundEnabled { SoundFeedback.shared.playSuccessSound() }
                    self.state = .idle
                }
            } catch {
                await MainActor.run {
                    self.state = .error(error.localizedDescription)
                    if self.soundEnabled { SoundFeedback.shared.playErrorSound() }
                    self.resetErrorAfterDelay()
                }
            }

            // Clean up the audio file and clear target app reference
            await MainActor.run {
                self.audioRecorder.cleanup()
                self.targetApplication = nil
            }
        }
    }

    // MARK: - Helpers

    private func resetErrorAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.state.isError == true {
                self?.state = .idle
            }
        }
    }

    func shutdown() {
        hotkeyManager.stopMonitoring()
        recordingTimer?.invalidate()
        audioRecorder.cleanup()
    }
}
