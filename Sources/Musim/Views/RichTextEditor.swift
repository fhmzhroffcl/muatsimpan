import SwiftUI
import AppKit

/// A compact rich-text editor with a formatting toolbar (bold / italic /
/// underline / strikethrough / bullet list / numbered list), backed by
/// NSTextView. Used by sticky notes.
struct RichTextEditor: View {
    @Binding var text: NSAttributedString
    @StateObject private var proxy = RichTextProxy()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                tool("bold") { proxy.toggle(.bold) }
                tool("italic") { proxy.toggle(.italic) }
                tool("underline") { proxy.toggle(.underline) }
                tool("strikethrough") { proxy.toggle(.strike) }
                Divider().frame(height: 15).padding(.horizontal, 3)
                tool("list.bullet") { proxy.list(ordered: false) }
                tool("list.number") { proxy.list(ordered: true) }
                Spacer()
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            Divider()
            RichTextViewRep(text: $text, proxy: proxy)
        }
    }

    private func tool(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                .frame(width: 26, height: 24)
                .foregroundStyle(Theme.textPrimary)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surface))
        }.buttonStyle(.plain)
    }
}

/// Bridges SwiftUI toolbar buttons to the live NSTextView.
final class RichTextProxy: ObservableObject {
    weak var textView: NSTextView?
    enum Fmt { case bold, italic, underline, strike }

    func toggle(_ f: Fmt) {
        guard let tv = textView, let storage = tv.textStorage else { return }
        var range = tv.selectedRange()
        if range.length == 0 { range = NSRange(location: 0, length: storage.length) }
        guard range.length > 0 else { return }
        storage.beginEditing()
        switch f {
        case .bold, .italic:
            let trait: NSFontTraitMask = f == .bold ? .boldFontMask : .italicFontMask
            let fm = NSFontManager.shared
            storage.enumerateAttribute(.font, in: range, options: []) { val, r, _ in
                let font = (val as? NSFont) ?? NSFont.systemFont(ofSize: 13)
                let has = fm.traits(of: font).contains(trait)
                let newFont = has ? fm.convert(font, toNotHaveTrait: trait) : fm.convert(font, toHaveTrait: trait)
                storage.addAttribute(.font, value: newFont, range: r)
            }
        case .underline:
            toggleStyle(.underlineStyle, in: range, storage: storage)
        case .strike:
            toggleStyle(.strikethroughStyle, in: range, storage: storage)
        }
        storage.endEditing()
        tv.didChangeText()
    }

    private func toggleStyle(_ key: NSAttributedString.Key, in range: NSRange, storage: NSTextStorage) {
        let current = storage.attribute(key, at: range.location, effectiveRange: nil) as? Int ?? 0
        let newValue = current == 0 ? NSUnderlineStyle.single.rawValue : 0
        storage.addAttribute(key, value: newValue, range: range)
    }

    /// Prefix each selected line with a bullet or a running number.
    func list(ordered: Bool) {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let ns = storage.string as NSString
        var range = tv.selectedRange()
        if range.length == 0 { range = ns.lineRange(for: NSRange(location: range.location, length: 0)) }
        let lineRange = ns.lineRange(for: range)
        let block = ns.substring(with: lineRange)
        var n = 1
        let rebuilt = block.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            let s = String(line)
            if s.trimmingCharacters(in: .whitespaces).isEmpty { return s }
            let prefix = ordered ? "\(n). " : "• "
            n += 1
            return prefix + s
        }.joined(separator: "\n")
        storage.beginEditing()
        storage.replaceCharacters(in: lineRange, with: rebuilt)
        storage.endEditing()
        tv.didChangeText()
    }
}

struct RichTextViewRep: NSViewRepresentable {
    @Binding var text: NSAttributedString
    let proxy: RichTextProxy

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let tv = scroll.documentView as? NSTextView else { return scroll }
        tv.delegate = context.coordinator
        tv.isRichText = true
        tv.allowsUndo = true
        tv.font = NSFont.systemFont(ofSize: 13)
        tv.drawsBackground = false
        tv.textContainerInset = NSSize(width: 6, height: 8)
        tv.textStorage?.setAttributedString(text)
        proxy.textView = tv
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = nsView.documentView as? NSTextView else { return }
        if !context.coordinator.editing, !tv.attributedString().isEqual(to: text) {
            tv.textStorage?.setAttributedString(text)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: RichTextViewRep
        var editing = false
        init(_ parent: RichTextViewRep) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            editing = true
            parent.text = tv.attributedString()
            editing = false
        }
    }
}
