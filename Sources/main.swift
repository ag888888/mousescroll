import AppKit
import ServiceManagement

private func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

// MARK: - Settings

enum Settings {
    private static let d = UserDefaults.standard

    static var enabled: Bool {
        get { d.object(forKey: "enabled") as? Bool ?? true }
        set { d.set(newValue, forKey: "enabled") }
    }
    static var reverseVertical: Bool {
        get { d.object(forKey: "reverseVertical") as? Bool ?? true }
        set { d.set(newValue, forKey: "reverseVertical") }
    }
    static var reverseHorizontal: Bool {
        get { d.object(forKey: "reverseHorizontal") as? Bool ?? false }
        set { d.set(newValue, forKey: "reverseHorizontal") }
    }
    static var speed: Double {
        get { d.object(forKey: "speed") as? Double ?? 1.0 }
        set { d.set(newValue, forKey: "speed") }
    }
}

// MARK: - Scroll event tap

final class ScrollTap {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isRunning: Bool { tap != nil }

    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let refcon {
                    let me = Unmanaged<ScrollTap>.fromOpaque(refcon).takeUnretainedValue()
                    if let t = me.tap { CGEvent.tapEnable(tap: t, enable: true) }
                }
                return Unmanaged.passUnretained(event)
            }
            guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }
            ScrollTap.process(event)
            return Unmanaged.passUnretained(event)
        }
        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        tap = t
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        source = nil
        tap = nil
    }

    /// Trackpad (and Magic Mouse) events are "continuous"; a classic wheel mouse is not.
    private static func process(_ event: CGEvent) {
        guard Settings.enabled else { return }
        if event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 { return }

        let speed = Settings.speed
        if Settings.reverseVertical {
            transform(event, axis: 1, sign: -1, speed: speed)
        } else if speed != 1 {
            transform(event, axis: 1, sign: 1, speed: speed)
        }
        if Settings.reverseHorizontal {
            transform(event, axis: 2, sign: -1, speed: speed)
        } else if speed != 1 {
            transform(event, axis: 2, sign: 1, speed: speed)
        }
    }

    private static func transform(_ e: CGEvent, axis: Int, sign: Double, speed: Double) {
        let line: CGEventField = axis == 1 ? .scrollWheelEventDeltaAxis1 : .scrollWheelEventDeltaAxis2
        let point: CGEventField = axis == 1 ? .scrollWheelEventPointDeltaAxis1 : .scrollWheelEventPointDeltaAxis2
        let fixed: CGEventField = axis == 1 ? .scrollWheelEventFixedPtDeltaAxis1 : .scrollWheelEventFixedPtDeltaAxis2

        let l = e.getIntegerValueField(line)
        let p = e.getIntegerValueField(point)
        let f = e.getDoubleValueField(fixed)
        if l == 0 && p == 0 && f == 0 { return }

        func scaled(_ v: Int64) -> Int64 {
            if v == 0 { return 0 }
            let r = Int64((Double(v) * sign * speed).rounded())
            return r == 0 ? (v > 0 ? 1 : -1) * Int64(sign) : r  // never swallow a tick
        }
        e.setIntegerValueField(line, value: scaled(l))
        e.setIntegerValueField(point, value: scaled(p))
        e.setDoubleValueField(fixed, value: f * sign * speed)
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let scrollTap = ScrollTap()
    private var permissionTimer: Timer?
    private let speeds: [Double] = [0.5, 0.75, 1, 1.5, 2, 3]

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "MouseScroll")
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        startTapWhenPermitted()
    }

    private func startTapWhenPermitted() {
        if scrollTap.start() { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self else { return }
            if AXIsProcessTrusted(), self.scrollTap.start() {
                t.invalidate()
                self.permissionTimer = nil
            }
        }
    }

    // Rebuild the menu each time it opens so state is always fresh.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if !scrollTap.isRunning {
            let warn = NSMenuItem(title: L("Permission needed: Accessibility…"), action: #selector(openPrivacy), keyEquivalent: "")
            warn.target = self
            menu.addItem(warn)
            menu.addItem(.separator())
        }

        menu.addItem(toggle(L("Enable mouse scroll fix"), Settings.enabled, #selector(toggleEnabled)))
        menu.addItem(.separator())
        menu.addItem(toggle(L("Reverse vertical direction"), Settings.reverseVertical, #selector(toggleVertical)))
        menu.addItem(toggle(L("Reverse horizontal direction"), Settings.reverseHorizontal, #selector(toggleHorizontal)))

        let speedItem = NSMenuItem(title: L("Scroll speed"), action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for s in speeds {
            let item = NSMenuItem(title: "\(s)x", action: #selector(setSpeed(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = s
            item.state = abs(Settings.speed - s) < 0.001 ? .on : .off
            sub.addItem(item)
        }
        speedItem.submenu = sub
        menu.addItem(speedItem)

        menu.addItem(.separator())
        menu.addItem(toggle(L("Launch at login"), SMAppService.mainApp.status == .enabled, #selector(toggleLogin)))
        menu.addItem(.separator())
        let quit = NSMenuItem(title: L("Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func toggle(_ title: String, _ on: Bool, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = on ? .on : .off
        return item
    }

    @objc private func toggleEnabled() { Settings.enabled.toggle() }
    @objc private func toggleVertical() { Settings.reverseVertical.toggle() }
    @objc private func toggleHorizontal() { Settings.reverseHorizontal.toggle() }
    @objc private func setSpeed(_ sender: NSMenuItem) {
        if let s = sender.representedObject as? Double { Settings.speed = s }
    }
    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            let a = NSAlert()
            a.messageText = L("Could not change launch at login")
            a.informativeText = error.localizedDescription
            a.runModal()
        }
    }
    @objc private func openPrivacy() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
