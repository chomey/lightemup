import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var booster: BrightnessBooster!
    private var brightnessSlider: NSSlider!
    private var boostValueLabel: NSTextField!
    private var edrInfoLabel: NSTextField!
    private var lastBoostLevel: Double = 0.5
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var onboarding: OnboardingWindow?
    private var currentHotkey: Hotkey = Hotkey.load()
    private var hotkeyLabel: NSTextField!
    private var hotkeyRecorder: HotkeyRecorderPanel?

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
            if let button = statusItem.button {
                button.image = NSImage(systemSymbolName: "sun.max.trianglebadge.exclamationmark.fill", accessibilityDescription: "Light Em Up (Active)")
            }
        } else {
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

    private func registerGlobalHotKey() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            if self.currentHotkey.matches(event: event) {
                self.toggleBoost()
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if self.currentHotkey.matches(event: event) {
                self.toggleBoost()
                return nil
            }
            return event
        }
    }

    private func unregisterGlobalHotKey() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    @objc private func quit() {
        booster.deactivate()
        NSApplication.shared.terminate(nil)
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if let screen = NSScreen.main {
            let maxEDR = screen.maximumExtendedDynamicRangeColorComponentValue
            let potentialEDR = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
            edrInfoLabel.stringValue = String(format: "EDR: current %.1fx / max %.1fx", maxEDR, potentialEDR)
        } else {
            edrInfoLabel.stringValue = "EDR: no display detected"
        }
    }
}
