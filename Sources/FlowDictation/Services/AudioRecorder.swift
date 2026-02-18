import AVFoundation
import Foundation

class AudioRecorder: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    @Published var isRecording = false

    // MARK: - Permissions

    static func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                completion(granted)
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    // MARK: - Recording

    func startRecording() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "flowdictation_\(UUID().uuidString).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)

        // WAV format settings: 16kHz mono 16-bit PCM (optimal for Whisper)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true

        guard audioRecorder?.record() == true else {
            throw RecordingError.failedToStart
        }

        recordingURL = fileURL
        isRecording = true

        return fileURL
    }

    func stopRecording() -> URL? {
        guard let recorder = audioRecorder, recorder.isRecording else {
            return nil
        }

        recorder.stop()
        isRecording = false

        return recordingURL
    }

    func cleanup() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
    }

    // MARK: - Audio Level

    func currentAudioLevel() -> Float {
        guard let recorder = audioRecorder, recorder.isRecording else { return 0 }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        // Normalize from -160...0 dB to 0...1
        let level = max(0, min(1, (power + 50) / 50))
        return level
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("FlowDictation: Recording finished unsuccessfully")
        }
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("FlowDictation: Recording encode error: \(error.localizedDescription)")
        }
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
}

// MARK: - Errors

enum RecordingError: LocalizedError {
    case failedToStart
    case noPermission

    var errorDescription: String? {
        switch self {
        case .failedToStart:
            return "Failed to start audio recording."
        case .noPermission:
            return "Microphone permission not granted."
        }
    }
}
