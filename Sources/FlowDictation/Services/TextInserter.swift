import Cocoa
import Carbon

class TextInserter {

    /// Insert text at the current cursor position using clipboard + Cmd+V
    /// - Parameters:
    ///   - text: The text to insert
    ///   - targetApp: The application that should receive the paste (saved when recording started)
    static func insertText(_ text: String, targetApp: NSRunningApplication? = nil) {
        guard AXIsProcessTrusted() else {
            print("FlowDictation: Accessibility not granted, copying to clipboard only")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            return
        }

        let pasteboard = NSPasteboard.general

        // Save the current clipboard contents
        let previousContents = pasteboard.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
            let newItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            return newItem
        }

        // Set our text on the clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Run osascript as a separate process — fully isolated from our app context
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.15) {
            // Activate the user's target app so paste goes to the right place
            if let app = targetApp {
                app.activate()
                Thread.sleep(forTimeInterval: 0.1)  // Give it time to come to front
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = [
                "-e",
                "tell application \"System Events\" to keystroke \"v\" using command down"
            ]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("FlowDictation: osascript paste failed: \(error)")
            }

            // Restore previous clipboard after paste completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let items = previousContents, !items.isEmpty {
                    pasteboard.clearContents()
                    pasteboard.writeObjects(items)
                }
            }
        }
    }
}
