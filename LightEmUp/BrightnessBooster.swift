import CoreGraphics
import Foundation

/// Boosts display brightness by adjusting the display's gamma transfer table
/// to map SDR output into EDR range. Values > 1.0 in the gamma table cause
/// XDR displays to output beyond the standard SDR white point.
class BrightnessBooster {
    private(set) var isActive = false
    private var currentBoost: Double = 1.0
    private var refreshTimer: Timer?

    /// Activate the brightness boost.
    /// - Parameter boostLevel: 0.0 = no boost, 1.0 = maximum boost
    func activate(boostLevel: Double) {
        isActive = true
        setBoostLevel(boostLevel)

        // Periodically re-apply in case ColorSync resets (e.g. wake from sleep)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isActive else { return }
            self.applyGammaTable(boost: self.currentBoost)
        }

        NSLog("LightEmUp: Activated brightness boost (level: %.2f, multiplier: %.2fx)", boostLevel, currentBoost)
    }

    /// Deactivate and restore normal display settings.
    func deactivate() {
        isActive = false
        refreshTimer?.invalidate()
        refreshTimer = nil
        CGDisplayRestoreColorSyncSettings()
        NSLog("LightEmUp: Deactivated, restored display defaults")
    }

    /// Update the boost level while active.
    /// - Parameter level: 0.0 = no boost (1.0x), 1.0 = maximum boost
    func setBoostLevel(_ level: Double) {
        // Map 0.0-1.0 slider to 1.0x-2.0x brightness multiplier
        // We cap at 2.0x to avoid extreme color shifts and keep it usable
        currentBoost = 1.0 + level * 1.0
        if isActive {
            applyGammaTable(boost: currentBoost)
        }
    }

    private func applyGammaTable(boost: Double) {
        let tableSize: UInt32 = 256
        var redTable = [CGGammaValue](repeating: 0, count: Int(tableSize))
        var greenTable = [CGGammaValue](repeating: 0, count: Int(tableSize))
        var blueTable = [CGGammaValue](repeating: 0, count: Int(tableSize))

        for i in 0..<Int(tableSize) {
            let normalizedInput = Float(i) / Float(tableSize - 1)
            // Apply boost: scale the output value beyond 1.0 into EDR range
            let boostedValue = normalizedInput * Float(boost)
            redTable[i] = boostedValue
            greenTable[i] = boostedValue
            blueTable[i] = boostedValue
        }

        // Apply to all online displays
        let maxDisplays: UInt32 = 16
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0
        CGGetOnlineDisplayList(maxDisplays, &displays, &displayCount)

        for d in 0..<Int(displayCount) {
            let result = CGSetDisplayTransferByTable(displays[d], tableSize, &redTable, &greenTable, &blueTable)
            if result != .success {
                NSLog("LightEmUp: Failed to set gamma for display %d: %d", displays[d], result.rawValue)
            }
        }
    }
}
