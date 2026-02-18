import AppKit

class SoundFeedback {
    static let shared = SoundFeedback()

    /// Volume from 0.0 (silent) to 1.0 (full). Default 0.4 for subtle feedback.
    var volume: Float = 0.4

    private init() {}

    func playStartSound() {
        playSound(named: "Tink")
    }

    func playStopSound() {
        playSound(named: "Pop")
    }

    func playErrorSound() {
        playSound(named: "Basso")
    }

    func playSuccessSound() {
        playSound(named: "Purr")
    }

    private func playSound(named name: String) {
        guard let sound = NSSound(named: .init(name)) else {
            print("FlowDictation: Sound '\(name)' not found")
            return
        }
        sound.volume = volume
        sound.play()
    }
}
