import Cocoa
import SwiftUI
import Combine
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    let dictationManager = DictationManager()
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - menu bar only app
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        observeDictationState()

        // Request microphone permission early
        AudioRecorder.requestMicrophonePermission { granted in
            if !granted {
                DispatchQueue.main.async {
                    self.showNotification(
                        title: "Microphone Access Required",
                        body: "FlowDictation needs microphone access. Enable it in System Settings > Privacy & Security > Microphone."
                    )
                }
            }
        }

        // Check accessibility permission
        if !GlobalHotkeyManager.checkAccessibilityPermission() {
            showNotification(
                title: "Accessibility Access Required",
                body: "FlowDictation needs Accessibility access for global hotkeys. Enable it in System Settings > Privacy & Security > Accessibility."
            )
        }
    }

    // MARK: - Status Bar Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "FlowDictation")
            button.image?.size = NSSize(width: 18, height: 18)
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 360)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(dictationManager)
        )
    }

    private func setupEventMonitor() {
        // Close popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
    }

    // MARK: - State Observation

    private func observeDictationState() {
        dictationManager.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateStatusBarIcon(for: state)
            }
            .store(in: &cancellables)
    }

    private func updateStatusBarIcon(for state: DictationState) {
        guard let button = statusItem.button else { return }

        switch state {
        case .idle:
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "FlowDictation - Ready")
            button.image?.isTemplate = true

        case .recording:
            button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "FlowDictation - Recording")
            button.image?.isTemplate = false
            // Apply red tint
            button.contentTintColor = .systemRed

        case .transcribing:
            button.image = NSImage(systemSymbolName: "ellipsis.circle.fill", accessibilityDescription: "FlowDictation - Transcribing")
            button.image?.isTemplate = true
            button.contentTintColor = .systemOrange

        case .error:
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "FlowDictation - Error")
            button.image?.isTemplate = false
            button.contentTintColor = .systemYellow
        }

        if state == .idle {
            button.contentTintColor = nil
            button.image?.isTemplate = true
        }

        button.image?.size = NSSize(width: 18, height: 18)
    }

    // MARK: - Actions

    func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // Bring popover to front
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    // MARK: - Notifications

    private func showNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { _, _ in }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func applicationWillTerminate(_ notification: Notification) {
        dictationManager.shutdown()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
