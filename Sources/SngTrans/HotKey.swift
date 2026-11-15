import Carbon

/// Phím tắt toàn hệ thống (không cần quyền đặc biệt).
final class HotKey {
    private var ref: EventHotKeyRef?
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var installed = false

    init(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        HotKey.installHandlerOnce()
        let id = HotKey.nextID; HotKey.nextID += 1
        HotKey.handlers[id] = handler
        RegisterEventHotKey(keyCode, modifiers,
                            EventHotKeyID(signature: OSType(0x534E4754), id: id),
                            GetApplicationEventTarget(), 0, &ref)
    }

    deinit { if let r = ref { UnregisterEventHotKey(r) } }

    private static func installHandlerOnce() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hk)
            HotKey.handlers[hk.id]?()
            return noErr
        }, 1, &spec, nil, nil)
    }
}
