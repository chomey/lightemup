import Cocoa

/// Stores a hotkey as modifier flags + key code, persisted to UserDefaults.
struct Hotkey: Equatable {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags

    static let defaultHotkey = Hotkey(keyCode: 11, modifiers: [.control, .option, .command]) // ⌃⌥⌘B

    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyName)
        return parts.joined()
    }

    private var keyName: String {
        let mapping: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 50: "`",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        ]
        return mapping[keyCode] ?? "Key\(keyCode)"
    }

    func save() {
        UserDefaults.standard.set(Int(keyCode), forKey: "hotkeyKeyCode")
        UserDefaults.standard.set(Int(modifiers.rawValue), forKey: "hotkeyModifiers")
    }

    static func load() -> Hotkey {
        guard UserDefaults.standard.object(forKey: "hotkeyKeyCode") != nil else {
            return defaultHotkey
        }
        let keyCode = UInt16(UserDefaults.standard.integer(forKey: "hotkeyKeyCode"))
        let modRaw = UInt(UserDefaults.standard.integer(forKey: "hotkeyModifiers"))
        return Hotkey(keyCode: keyCode, modifiers: NSEvent.ModifierFlags(rawValue: modRaw))
    }

    func matches(event: NSEvent) -> Bool {
        // Only compare the modifiers we care about (ignore capsLock, function, numericPad)
        let relevant: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        let eventMods = event.modifierFlags.intersection(relevant)
        let savedMods = modifiers.intersection(relevant)
        return event.keyCode == keyCode && eventMods == savedMods
    }
}

/// A floating panel that captures a keyboard shortcut.
class HotkeyRecorderPanel {
    private var panel: NSPanel?
    private var localMonitor: Any?
    var onChange: ((Hotkey) -> Void)?

    func show() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 140),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Record Hotkey"
        panel.level = .floating
        panel.center()
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = false

        let content = NSView(frame: panel.contentView!.bounds)

        let instruction = NSTextField(labelWithString: "Press your desired key combination")
        instruction.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        instruction.alignment = .center
        instruction.frame = NSRect(x: 20, y: 90, width: 280, height: 20)
        content.addSubview(instruction)

        let hint = NSTextField(labelWithString: "Must include ⌘, ⌥, or ⌃. Press Esc to cancel.")
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.alignment = .center
        hint.frame = NSRect(x: 20, y: 68, width: 280, height: 16)
        content.addSubview(hint)

        let keysLabel = NSTextField(labelWithString: "Waiting...")
        keysLabel.font = NSFont.monospacedSystemFont(ofSize: 20, weight: .bold)
        keysLabel.textColor = .systemOrange
        keysLabel.alignment = .center
        keysLabel.frame = NSRect(x: 20, y: 24, width: 280, height: 30)
        keysLabel.tag = 300
        content.addSubview(keysLabel)

        panel.contentView = content
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.panel = panel

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Escape cancels
            if event.keyCode == 53 {
                self.close()
                return nil
            }

            // Require at least one real modifier
            if mods.isEmpty || mods == .shift {
                return nil
            }

            let newHotkey = Hotkey(keyCode: event.keyCode, modifiers: mods)
            newHotkey.save()

            // Show the recorded hotkey briefly
            if let label = self.panel?.contentView?.viewWithTag(300) as? NSTextField {
                label.stringValue = newHotkey.displayString
                label.textColor = .systemGreen
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.onChange?(newHotkey)
                self.close()
            }

            return nil
        }
    }

    private func close() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        panel?.close()
        panel = nil
    }
}
