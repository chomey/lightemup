import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var booster: BrightnessBooster!
    private var brightnessSlider: NSSlider!
    private var boostValueLabel: NSTextField!
    private var edrInfoLabel: NSTextField!
    private var lastBoostLevel: Double = 0.5
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var onboarding: OnboardingWindow?
    private var currentHotkey: Hotkey = Hotkey.load()
    private var hotkeyLabel: NSTextField!
    private var hotkeyRecorder: HotkeyRecorderPanel?
    private var statusLabel: NSTextField!

    func applicationDidFinishLaunching(_ notification: Notification) {
        booster = BrightnessBooster()
        registerGlobalHotKey()

        if OnboardingWindow.needsOnboarding() {
            onboarding = OnboardingWindow()
            onboarding?.show()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Light Em Up")
        }

        let menu = NSMenu()

        // Title
        let titleView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 28))
        let titleLabel = NSTextField(labelWithString: "Light Em Up")
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 16, y: 4, width: 220, height: 20)
        titleView.addSubview(titleLabel)
        let titleItem = NSMenuItem()
        titleItem.view = titleView
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // Slider with label
        let sliderContainer = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 50))

        boostValueLabel = NSTextField(labelWithString: "Boost: 1.0x")
        boostValueLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        boostValueLabel.textColor = .labelColor
        boostValueLabel.frame = NSRect(x: 20, y: 26, width: 210, height: 18)
        sliderContainer.addSubview(boostValueLabel)

        brightnessSlider = NSSlider(value: 0.0, minValue: 0.0, maxValue: 1.0, target: self, action: #selector(sliderChanged))
        brightnessSlider.frame = NSRect(x: 20, y: 2, width: 210, height: 24)
        brightnessSlider.isContinuous = true
        sliderContainer.addSubview(brightnessSlider)

        let sliderItem = NSMenuItem()
        sliderItem.view = sliderContainer
        menu.addItem(sliderItem)

        menu.addItem(NSMenuItem.separator())

        // Hotkey display + change button
        let hotkeyView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        hotkeyLabel = NSTextField(labelWithString: "Hotkey: \(currentHotkey.displayString)")
        hotkeyLabel.font = NSFont.systemFont(ofSize: 11)
        hotkeyLabel.textColor = .secondaryLabelColor
        hotkeyLabel.frame = NSRect(x: 16, y: 2, width: 220, height: 18)
        hotkeyView.addSubview(hotkeyLabel)
        let hotkeyInfoItem = NSMenuItem()
        hotkeyInfoItem.view = hotkeyView
        menu.addItem(hotkeyInfoItem)

        let changeHotkeyItem = NSMenuItem(title: "Change Hotkey...", action: #selector(changeHotkey), keyEquivalent: "")
        menu.addItem(changeHotkeyItem)

        menu.addItem(NSMenuItem.separator())

        // Status
        let statusView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        statusLabel = NSTextField(labelWithString: eventTap != nil ? "Status: Inactive (hotkeys ready)" : "Status: Inactive (hotkeys FAILED)")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.frame = NSRect(x: 16, y: 2, width: 220, height: 18)
        statusView.addSubview(statusLabel)
        let statusMenuItem = NSMenuItem()
        statusMenuItem.view = statusView
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // EDR info
        let infoView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        edrInfoLabel = NSTextField(labelWithString: "EDR: checking...")
        edrInfoLabel.font = NSFont.systemFont(ofSize: 11)
        edrInfoLabel.textColor = .secondaryLabelColor
        edrInfoLabel.frame = NSRect(x: 16, y: 2, width: 220, height: 18)
        infoView.addSubview(edrInfoLabel)
        let infoItem = NSMenuItem()
        infoItem.view = infoView
        menu.addItem(infoItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        menu.delegate = self
        statusItem.menu = menu
    }

    func applicationWillTerminate(_ notification: Notification) {
        booster.deactivate()
    }

    @objc private func sliderChanged() {
        let level = brightnessSlider.doubleValue
        let multiplier = 1.0 + level * 1.0
        boostValueLabel.stringValue = String(format: "Boost: %.1fx", multiplier)

        if level > 0.0 {
            lastBoostLevel = level
            if !booster.isActive {
                booster.activate(boostLevel: level)
            } else {
                booster.setBoostLevel(level)
            }
            statusLabel.stringValue = String(format: "Status: Active (%.1fx)", multiplier)
            if let button = statusItem.button {
                button.image = NSImage(systemSymbolName: "sun.max.trianglebadge.exclamationmark.fill", accessibilityDescription: "Light Em Up (Active)")
            }
        } else {
            statusLabel.stringValue = "Status: Inactive"
            booster.deactivate()
            if let button = statusItem.button {
                button.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Light Em Up")
            }
        }
    }

    @objc private func toggleBoost() {
        if booster.isActive {
            lastBoostLevel = brightnessSlider.doubleValue
            brightnessSlider.doubleValue = 0.0
            sliderChanged()
        } else {
            brightnessSlider.doubleValue = lastBoostLevel
            sliderChanged()
        }
    }

    private func adjustBoost(by delta: Double) {
        let newLevel = min(max(brightnessSlider.doubleValue + delta, 0.0), 1.0)
        brightnessSlider.doubleValue = newLevel
        sliderChanged()
    }

    @objc private func changeHotkey() {
        hotkeyRecorder = HotkeyRecorderPanel()
        hotkeyRecorder?.onChange = { [weak self] newHotkey in
            guard let self = self else { return }
            self.currentHotkey = newHotkey
            self.hotkeyLabel.stringValue = "Hotkey: \(newHotkey.displayString)"
            self.unregisterGlobalHotKey()
            self.registerGlobalHotKey()
        }
        hotkeyRecorder?.show()
    }

    private static let relevantCGFlags: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
    private static let allModifierMask: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand, .maskShift]

    private func registerGlobalHotKey() {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = appDelegate.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                let flags = event.flags.intersection(AppDelegate.allModifierMask)

                // Check ⌃⌥⌘↑/↓ for brightness adjust
                if flags == AppDelegate.relevantCGFlags {
                    if keyCode == 126 { // Up arrow
                        DispatchQueue.main.async { appDelegate.adjustBoost(by: 0.1) }
                        return nil
                    } else if keyCode == 125 { // Down arrow
                        DispatchQueue.main.async { appDelegate.adjustBoost(by: -0.1) }
                        return nil
                    }
                }

                // Check user-configured toggle hotkey
                if let nsEvent = NSEvent(cgEvent: event) {
                    if appDelegate.currentHotkey.matches(event: nsEvent) {
                        DispatchQueue.main.async { appDelegate.toggleBoost() }
                        return nil
                    }
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            NSLog("LightEmUp: Failed to create CGEvent tap — check Accessibility permissions")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func unregisterGlobalHotKey() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    @objc private func quit() {
        booster.deactivate()
        NSApplication.shared.terminate(nil)
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Retry event tap if it failed at launch (e.g. accessibility wasn't granted yet)
        if eventTap == nil {
            registerGlobalHotKey()
        }

        if eventTap != nil {
            let boostStatus = booster.isActive ? String(format: "Active (%.1fx)", 1.0 + brightnessSlider.doubleValue) : "Inactive"
            statusLabel.stringValue = "Status: \(boostStatus) — hotkeys ready"
        } else {
            statusLabel.stringValue = "Status: hotkeys FAILED — check Accessibility"
        }

        if let screen = NSScreen.main {
            let maxEDR = screen.maximumExtendedDynamicRangeColorComponentValue
            let potentialEDR = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
            edrInfoLabel.stringValue = String(format: "EDR: current %.1fx / max %.1fx", maxEDR, potentialEDR)
        } else {
            edrInfoLabel.stringValue = "EDR: no display detected"
        }
    }
}
