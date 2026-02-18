import Foundation
import AppKit

enum DictationState: Equatable {
    case idle
    case recording
    case transcribing
    case error(String)

    static func == (lhs: DictationState, rhs: DictationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.recording, .recording): return true
        case (.transcribing, .transcribing): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let msg) = self { return msg }
        return nil
    }
}

enum HotkeyOption: String, CaseIterable, Identifiable {
    case option = "Option"
    case rightOption = "Right Option"
    case control = "Control"
    case fn = "Fn"
    case custom = "Custom"

    var id: String { rawValue }

    var displayName: String { rawValue }
}

struct CustomHotkeyConfig: Codable, Equatable {
    var keyCode: UInt16
    var modifierFlags: UInt

    var displayName: String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        if flags.contains(.control) { parts.append("\u{2303}") }
        if flags.contains(.option) { parts.append("\u{2325}") }
        if flags.contains(.shift) { parts.append("\u{21E7}") }
        if flags.contains(.command) { parts.append("\u{2318}") }
        let keyName = Self.stringForKeyCode(keyCode)
        parts.append(keyName)
        return parts.joined(separator: "")
    }

    static func stringForKeyCode(_ keyCode: UInt16) -> String {
        // Common key code mappings
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
            50: "`", 51: "Delete", 53: "Esc",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 103: "F11", 105: "F13", 107: "F14",
            109: "F10", 111: "F12", 113: "F15",
            118: "F4", 119: "F2", 120: "F1", 122: "F16",
            123: "\u{2190}", 124: "\u{2192}", 125: "\u{2193}", 126: "\u{2191}"
        ]
        return keyMap[keyCode] ?? "Key\(keyCode)"
    }
}
