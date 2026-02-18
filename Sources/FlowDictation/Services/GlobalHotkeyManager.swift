import Cocoa
import Carbon

class GlobalHotkeyManager {
    private var flagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var keyDownMonitor: Any?
    private var localKeyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var localKeyUpMonitor: Any?
    private var isHotkeyDown = false

    var onHotkeyDown: (() -> Void)?
    var onHotkeyUp: (() -> Void)?

    // Current hotkey setting
    var selectedHotkey: HotkeyOption = .option

    // Custom hotkey configuration
    var customHotkey: CustomHotkeyConfig?

    // MARK: - Accessibility Permission

    static func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Start/Stop Monitoring

    func startMonitoring() {
        stopMonitoring()

        if selectedHotkey == .custom && customHotkey != nil {
            startCustomMonitoring()
        } else {
            // Monitor modifier key flags changes globally
            flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.handleFlagsChanged(event)
            }

            // Also monitor local events (when our app is focused)
            localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.handleFlagsChanged(event)
                return event
            }
        }
    }

    func stopMonitoring() {
        for monitor in [flagsMonitor, localFlagsMonitor, keyDownMonitor, localKeyDownMonitor, keyUpMonitor, localKeyUpMonitor] {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
        flagsMonitor = nil
        localFlagsMonitor = nil
        keyDownMonitor = nil
        localKeyDownMonitor = nil
        keyUpMonitor = nil
        localKeyUpMonitor = nil
        isHotkeyDown = false
    }

    // MARK: - Custom Hotkey Monitoring

    private func startCustomMonitoring() {
        guard let config = customHotkey else { return }
        let requiredModifiers = NSEvent.ModifierFlags(rawValue: config.modifierFlags)
            .intersection([.command, .option, .shift, .control])

        // Global key down
        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            if event.keyCode == config.keyCode && !event.isARepeat {
                let eventMods = event.modifierFlags.intersection([.command, .option, .shift, .control])
                if eventMods == requiredModifiers && !self.isHotkeyDown {
                    self.isHotkeyDown = true
                    self.onHotkeyDown?()
                }
            }
        }

        // Local key down
        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if event.keyCode == config.keyCode && !event.isARepeat {
                let eventMods = event.modifierFlags.intersection([.command, .option, .shift, .control])
                if eventMods == requiredModifiers && !self.isHotkeyDown {
                    self.isHotkeyDown = true
                    self.onHotkeyDown?()
                }
            }
            return event
        }

        // Global key up
        keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self = self else { return }
            if event.keyCode == config.keyCode && self.isHotkeyDown {
                self.isHotkeyDown = false
                self.onHotkeyUp?()
            }
        }

        // Local key up
        localKeyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self = self else { return event }
            if event.keyCode == config.keyCode && self.isHotkeyDown {
                self.isHotkeyDown = false
                self.onHotkeyUp?()
            }
            return event
        }
    }

    // MARK: - Event Handling

    private func handleFlagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags

        let isKeyCurrentlyDown: Bool

        switch selectedHotkey {
        case .option:
            // Either option key
            isKeyCurrentlyDown = flags.contains(.option)
        case .rightOption:
            // Right option specifically - key code 61
            if event.keyCode == 61 && flags.contains(.option) {
                isKeyCurrentlyDown = true
            } else if !flags.contains(.option) {
                isKeyCurrentlyDown = false
            } else {
                // Another modifier changed while option is still held - ignore
                return
            }
        case .control:
            isKeyCurrentlyDown = flags.contains(.control)
        case .fn:
            isKeyCurrentlyDown = flags.contains(.function)
        case .custom:
            return  // Custom handled separately
        }

        if isKeyCurrentlyDown && !isHotkeyDown {
            // Key just pressed down
            isHotkeyDown = true
            onHotkeyDown?()
        } else if !isKeyCurrentlyDown && isHotkeyDown {
            // Key just released
            isHotkeyDown = false
            onHotkeyUp?()
        }
    }

    deinit {
        stopMonitoring()
    }
}
