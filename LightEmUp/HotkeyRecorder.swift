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
            // Function keys
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            // Special
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
        let eventMods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return event.keyCode == keyCode && eventMods == modifiers
    }
}

/// A control that records a keyboard shortcut when clicked.
class HotkeyRecorderView: NSView {
    var hotkey: Hotkey {
        didSet { updateLabel(); onChange?(hotkey) }
    }
    var onChange: ((Hotkey) -> Void)?
    private var isRecording = false
    private var label: NSTextField!
    private var recordButton: NSButton!
    private var localMonitor: Any?

    init(frame: NSRect, hotkey: Hotkey) {
        self.hotkey = hotkey
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        label = NSTextField(labelWithString: hotkey.displayString)
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        label.frame = NSRect(x: 0, y: 2, width: 100, height: 20)
        addSubview(label)

        recordButton = NSButton(title: "Record", target: self, action: #selector(startRecording))
        recordButton.bezelStyle = .rounded
        recordButton.controlSize = .small
        recordButton.frame = NSRect(x: 105, y: 0, width: 65, height: 22)
        addSubview(recordButton)
    }

    private func updateLabel() {
        label.stringValue = isRecording ? "Press keys..." : hotkey.displayString
        label.textColor = isRecording ? .systemOrange : .labelColor
    }

    @objc private func startRecording() {
        isRecording = true
        updateLabel()
        recordButton.title = "Cancel"
        recordButton.action = #selector(stopRecording)

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Escape cancels
            if event.keyCode == 53 {
                self.stopRecording()
                return nil
            }

            // Require at least one modifier
            if mods.isEmpty || mods == .shift {
                return nil
            }

            self.hotkey = Hotkey(keyCode: event.keyCode, modifiers: mods)
            self.hotkey.save()
            self.stopRecording()
            return nil
        }
    }

    @objc private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        recordButton.title = "Record"
        recordButton.action = #selector(startRecording)
        updateLabel()
    }
}
