import Cocoa

class OnboardingWindow {
    private var window: NSWindow?

    static func needsOnboarding() -> Bool {
        return !AXIsProcessTrusted()
    }

    func show() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.center()
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.backgroundColor = .windowBackgroundColor

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        let w: CGFloat = 440
        var y: CGFloat = 465

        // App icon
        if let icon = NSApp.applicationIconImage {
            let iconView = NSImageView(frame: NSRect(x: (w - 72) / 2, y: y - 72, width: 72, height: 72))
            iconView.image = icon
            iconView.imageScaling = .scaleProportionallyUpOrDown
            contentView.addSubview(iconView)
            y -= 84
        }

        // Title
        let title = NSTextField(labelWithString: "Light Em Up")
        title.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        title.alignment = .center
        title.frame = NSRect(x: 0, y: y - 26, width: w, height: 26)
        contentView.addSubview(title)
        y -= 34

        // Subtitle
        let subtitle = NSTextField(labelWithString: "Boost your MacBook display beyond standard brightness")
        subtitle.font = NSFont.systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center
        subtitle.frame = NSRect(x: 0, y: y - 16, width: w, height: 16)
        contentView.addSubview(subtitle)
        y -= 32

        // Separator
        let sep = NSBox(frame: NSRect(x: 32, y: y, width: w - 64, height: 1))
        sep.boxType = .separator
        contentView.addSubview(sep)
        y -= 24

        // Section header
        let header = NSTextField(labelWithString: "Grant Accessibility Permission")
        header.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        header.frame = NSRect(x: 32, y: y - 18, width: w - 64, height: 18)
        contentView.addSubview(header)
        y -= 28

        // Explanation
        let explanation = NSTextField(wrappingLabelWithString:
            "Required for the global shortcut (\(Hotkey.load().displayString)) to toggle brightness from any app. You can change the shortcut in the menu bar.")
        explanation.font = NSFont.systemFont(ofSize: 11.5)
        explanation.textColor = .secondaryLabelColor
        explanation.frame = NSRect(x: 32, y: y - 32, width: w - 64, height: 32)
        contentView.addSubview(explanation)
        y -= 44

        // Steps
        let steps = [
            "Click \"Open Accessibility Settings\" below",
            "Click the + button",
            "Add Light Em Up from Applications",
            "Toggle it ON",
        ]

        for (i, text) in steps.enumerated() {
            let numLabel = NSTextField(labelWithString: "\(i + 1)")
            numLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
            numLabel.textColor = .white
            numLabel.alignment = .center
            numLabel.backgroundColor = NSColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1.0)
            numLabel.drawsBackground = true
            numLabel.isBezeled = false
            numLabel.frame = NSRect(x: 40, y: y - 18, width: 20, height: 18)
            numLabel.wantsLayer = true
            numLabel.layer?.cornerRadius = 9
            numLabel.layer?.masksToBounds = true
            contentView.addSubview(numLabel)

            let stepLabel = NSTextField(labelWithString: text)
            stepLabel.font = NSFont.systemFont(ofSize: 12)
            stepLabel.frame = NSRect(x: 72, y: y - 18, width: w - 104, height: 18)
            contentView.addSubview(stepLabel)
            y -= 28
        }

        y -= 8

        // Status indicator
        let trusted = AXIsProcessTrusted()

        let statusDot = NSTextField(labelWithString: "●")
        statusDot.font = NSFont.systemFont(ofSize: 10)
        statusDot.textColor = trusted ? .systemGreen : .systemOrange
        statusDot.frame = NSRect(x: 40, y: y - 16, width: 16, height: 16)
        statusDot.tag = 201
        contentView.addSubview(statusDot)

        let statusLabel = NSTextField(labelWithString: trusted
            ? "Permission granted — you're all set!"
            : "Waiting for permission...")
        statusLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        statusLabel.textColor = trusted ? .systemGreen : .systemOrange
        statusLabel.frame = NSRect(x: 58, y: y - 16, width: w - 90, height: 16)
        statusLabel.tag = 200
        contentView.addSubview(statusLabel)
        y -= 36

        // Buttons
        let openSettingsButton = NSButton(title: "Open Accessibility Settings", target: self, action: #selector(openAccessibilitySettings))
        openSettingsButton.bezelStyle = .rounded
        openSettingsButton.controlSize = .large
        openSettingsButton.frame = NSRect(x: 32, y: 20, width: 230, height: 36)
        contentView.addSubview(openSettingsButton)

        let doneButton = NSButton(title: "Done", target: self, action: #selector(closeWindow))
        doneButton.bezelStyle = .rounded
        doneButton.controlSize = .large
        doneButton.keyEquivalent = "\r"
        doneButton.frame = NSRect(x: w - 32 - 90, y: 20, width: 90, height: 36)
        contentView.addSubview(doneButton)

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window

        // Poll for permission changes
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, let window = self.window, window.isVisible else {
                timer.invalidate()
                return
            }
            let trusted = AXIsProcessTrusted()
            if let statusLabel = window.contentView?.viewWithTag(200) as? NSTextField,
               let statusDot = window.contentView?.viewWithTag(201) as? NSTextField {
                statusDot.textColor = trusted ? .systemGreen : .systemOrange
                statusLabel.stringValue = trusted
                    ? "Permission granted — you're all set!"
                    : "Waiting for permission..."
                statusLabel.textColor = trusted ? .systemGreen : .systemOrange
            }
        }
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func closeWindow() {
        window?.close()
        window = nil
    }
}
