import AppKit
import SwiftUI
import AVFoundation
import Combine

final class CardModel: ObservableObject {
    @Published var original = ""
    @Published var result: TranslationResult?
    @Published var loading = false
    @Published var error: String?
    @Published var pinned = false
    @Published var noteSaved = false
    @Published var appBlocked = false
    var appID: String?
    var appName: String?
    var onNote: () -> Void = {}
    var onToggleBlock: () -> Void = {}
    var onSpeak: () -> Void = {}
    var onCopy: () -> Void = {}
    var onClose: () -> Void = {}
}

struct CardView: View {
    @ObservedObject var m: CardModel

    private var langLabel: String {
        guard let r = m.result else { return "Đang dịch…" }
        let from = Locale.current.localizedString(forLanguageCode: r.detected) ?? r.detected
        let to = Locale.current.localizedString(forLanguageCode: r.target) ?? r.target
        return "\(from) → \(to)"
    }

    private func icon(_ name: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: name).font(.system(size: 12)) }
            .buttonStyle(.plain)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(langLabel).font(.caption).foregroundStyle(.secondary)
                Spacer()
                icon(m.noteSaved ? "bookmark.fill" : "bookmark") { m.onNote() }
                icon("speaker.wave.2") { m.onSpeak() }
                icon("doc.on.doc") { m.onCopy() }
                icon(m.pinned ? "pin.fill" : "pin") { m.pinned.toggle() }
                icon("xmark") { m.onClose() }
            }
            Text(m.original).font(.system(size: 12)).foregroundStyle(.secondary)
                .lineLimit(3).fixedSize(horizontal: false, vertical: true)
            Divider()
            if m.loading {
                ProgressView().controlSize(.small)
            } else if let e = m.error {
                Text(e).foregroundStyle(.red).font(.system(size: 13))
            } else if let r = m.result {
                Text(r.text).font(.system(size: 15, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(r.meanings.enumerated()), id: \.offset) { _, mn in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(mn.pos).italic().font(.system(size: 11)).foregroundStyle(.secondary)
                        Text(mn.words.joined(separator: ", ")).font(.system(size: 12))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let name = m.appName, m.appID != nil {
                Button(action: { m.onToggleBlock() }) {
                    HStack(spacing: 4) {
                        Image(systemName: m.appBlocked ? "checkmark.square.fill" : "square")
                        Text("Không tự dịch ở \(name)")
                    }
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 340, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.12)))
    }
}

/// Cửa sổ nổi không cướp focus của app đang dùng (để vùng bôi đen không bị mất).
final class NonKeyPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class CardController {
    let model = CardModel()
    private let panel: NonKeyPanel
    private let host: NSHostingView<CardView>
    private var bag = Set<AnyCancellable>()
    private let synth = AVSpeechSynthesizer()
    private var task: Task<Void, Never>?
    private let targetLang: () -> String

    var isPinned: Bool { model.pinned }
    var isVisible: Bool { panel.isVisible }

    init(targetLang: @escaping () -> String) {
        self.targetLang = targetLang
        host = NSHostingView(rootView: CardView(m: model))
        panel = NonKeyPanel(contentRect: NSRect(x: 0, y: 0, width: 340, height: 80),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.contentView = host
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        model.onClose = { [weak self] in self?.hide() }
        model.onCopy = { [weak self] in
            guard let t = self?.model.result?.text else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(t, forType: .string)
        }
        model.onSpeak = { [weak self] in self?.speak() }
        model.onNote = { [weak self] in
            guard let self, let r = self.model.result, !self.model.noteSaved else { return }
            Store.shared.addNote(Note(original: self.model.original, translation: r.text,
                                      from: r.detected, to: r.target))
            self.model.noteSaved = true
        }
        model.onToggleBlock = { [weak self] in
            guard let self, let id = self.model.appID else { return }
            if Store.shared.isBlocked(id) { Store.shared.unblock(id) }
            else { Store.shared.block(id, name: self.model.appName ?? id) }
            self.model.appBlocked = Store.shared.isBlocked(id)
        }
        model.objectWillChange.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fit()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self?.fit() }
            }.store(in: &bag)
    }

    func show(_ sel: Selection) {
        let text = sel.text
        task?.cancel()
        synth.stopSpeaking(at: .immediate)
        model.pinned = false
        model.noteSaved = false
        model.appID = sel.bundleID
        model.appName = sel.appName
        model.appBlocked = Store.shared.isBlocked(sel.bundleID)
        model.original = text
        model.result = nil
        model.error = nil
        model.loading = true

        let mouse = NSEvent.mouseLocation
        let size = host.fittingSize
        panel.setFrame(NSRect(x: mouse.x + 10, y: mouse.y - 24 - size.height, width: 340, height: size.height),
                       display: false)
        clamp(mouse: mouse)
        panel.orderFrontRegardless()

        let tl = targetLang()
        task = Task { [weak self] in
            do {
                let r = try await Translator.shared.translate(text, to: tl)
                if Task.isCancelled { return }
                await MainActor.run {
                    self?.model.result = r
                    self?.model.loading = false
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    self?.model.error = (error as? TranslateError) == .rateLimited
                        ? "Google đang giới hạn tần suất, thử lại sau ít giây."
                        : "Không dịch được. Kiểm tra kết nối mạng."
                    self?.model.loading = false
                }
            }
        }
    }

    func hide() {
        task?.cancel()
        synth.stopSpeaking(at: .immediate)
        panel.orderOut(nil)
        model.pinned = false
    }

    func hideIfNotPinned() { if panel.isVisible && !model.pinned { hide() } }

    /// Đổi kích thước theo nội dung, giữ nguyên góc trên bên trái.
    private func fit() {
        guard panel.isVisible else { return }
        host.layoutSubtreeIfNeeded()
        let h = host.fittingSize.height
        let f = panel.frame
        guard abs(f.height - h) > 0.5 else { return }
        panel.setFrame(NSRect(x: f.minX, y: f.maxY - h, width: 340, height: h), display: true)
        clamp(mouse: nil)
    }

    private func clamp(mouse: NSPoint?) {
        let ref = mouse ?? NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(ref, $0.frame, false) }) ?? NSScreen.main
        else { return }
        let vf = screen.visibleFrame
        var f = panel.frame
        f.origin.x = min(max(f.origin.x, vf.minX + 4), vf.maxX - f.width - 4)
        if f.minY < vf.minY + 4 {
            if let m = mouse { f.origin.y = m.y + 24 }     // không đủ chỗ phía dưới: hiện phía trên con trỏ
            else { f.origin.y = vf.minY + 4 }
        }
        if f.maxY > vf.maxY - 4 { f.origin.y = vf.maxY - 4 - f.height }
        panel.setFrame(f, display: true)
    }

    private func speak() {
        guard let r = model.result else { return }
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: r.text)
        let base = Translator.base(r.target)
        u.voice = AVSpeechSynthesisVoice.speechVoices().first { $0.language.lowercased().hasPrefix(base) }
        synth.speak(u)
    }
}
