import SwiftUI
import UIKit

struct BulletedEditor: UIViewRepresentable {
    @Binding var entries: [ACTEntry]
    let focusToken: Int
    let currentQuadrant: Int
    let onNavigate: (Int) -> Void
    let onNew: () -> Void
    let onShowAll: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(frame: .zero)
        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = .label
        textView.tintColor = .systemTeal
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 10, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.autocorrectionType = .yes
        textView.spellCheckingType = .yes
        textView.text = Self.displayText(entries)
        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        let accessory = MatrixKeyboardBar(currentQuadrant: currentQuadrant)
        accessory.onNavigate = { [weak coordinator = context.coordinator] destination in
            coordinator?.parent.onNavigate(destination)
        }
        accessory.onNew = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onNew()
        }
        accessory.onShowAll = { [weak coordinator = context.coordinator] in
            coordinator?.textView?.resignFirstResponder()
            coordinator?.parent.onShowAll()
        }
        accessory.onChooseKind = { [weak coordinator = context.coordinator] kind in
            coordinator?.setKindOfCurrentEntry(kind)
        }
        textView.inputAccessoryView = accessory
        context.coordinator.accessory = accessory
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.accessory?.selectQuadrant(currentQuadrant)

        let display = Self.displayText(entries)
        if textView.text != display {
            let oldSelection = textView.selectedRange
            textView.text = display
            let end = (display as NSString).length
            textView.selectedRange = NSRange(location: min(oldSelection.location, end), length: 0)
        }
        context.coordinator.refreshSelectedKind()

        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async { [weak textView] in
                guard let textView = textView, textView.window != nil else { return }
                textView.becomeFirstResponder()
                let end = (textView.text as NSString).length
                textView.selectedRange = NSRange(location: end, length: 0)
                textView.scrollRangeToVisible(textView.selectedRange)
                context.coordinator.refreshSelectedKind()
            }
        }
    }

    static func displayText(_ entries: [ACTEntry]) -> String {
        (entries.isEmpty ? [ACTEntry()] : entries)
            .map { $0.kind.prefix + $0.text }
            .joined(separator: "\n")
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: BulletedEditor
        weak var accessory: MatrixKeyboardBar?
        weak var textView: UITextView?
        var lastFocusToken: Int?

        init(parent: BulletedEditor) { self.parent = parent }

        private func currentLine(in view: UITextView) -> (NSRange, String) {
            let text = (view.text ?? "") as NSString
            let position = min(view.selectedRange.location, text.length)
            let lineRange = text.lineRange(for: NSRange(location: position, length: 0))
            let raw = text.substring(with: lineRange)
            let clean = raw.hasSuffix("\n") ? String(raw.dropLast()) : raw
            return (lineRange, clean)
        }

        func refreshSelectedKind() {
            guard let view = textView else { return }
            let (_, line) = currentLine(in: view)
            accessory?.selectKind(ACTEntryKind.parse(line).kind)
        }

        func setKindOfCurrentEntry(_ kind: ACTEntryKind) {
            guard let view = textView else { return }
            let (lineRange, oldLine) = currentLine(in: view)
            let oldEntry = ACTEntryKind.parse(oldLine)
            let newLine = kind.prefix + oldEntry.text
            let endsWithNewline = (view.text as NSString).substring(with: lineRange).hasSuffix("\n")
            let replacement = newLine + (endsWithNewline ? "\n" : "")
            let oldPrefixLength = (oldEntry.kind.prefix as NSString).length
            let newPrefixLength = (kind.prefix as NSString).length
            let oldPosition = view.selectedRange.location - lineRange.location
            let bodyOffset = max(0, oldPosition - oldPrefixLength)
            view.text = (view.text as NSString).replacingCharacters(in: lineRange, with: replacement)
            let position = lineRange.location + newPrefixLength
                + min(bodyOffset, (oldEntry.text as NSString).length)
            view.selectedRange = NSRange(location: position, length: 0)
            textViewDidChange(view)
            accessory?.selectKind(kind)
            view.becomeFirstResponder()
            view.scrollRangeToVisible(view.selectedRange)
        }

        func textView(_ textView: UITextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {
            // Return inherits the icon of the line just edited, including in mid-list.
            if text == "\n" {
                let raw = (textView.text ?? "") as NSString
                let location = min(range.location, raw.length)
                let lineRange = raw.lineRange(for: NSRange(location: location, length: 0))
                let line = raw.substring(with: lineRange)
                let kind = ACTEntryKind.parse(line).kind
                let insertion = "\n" + kind.prefix
                textView.text = raw.replacingCharacters(in: range, with: insertion)
                textView.selectedRange = NSRange(
                    location: range.location + (insertion as NSString).length,
                    length: 0
                )
                textViewDidChange(textView)
                textView.scrollRangeToVisible(textView.selectedRange)
                return false
            }
            return true
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            refreshSelectedKind()
        }

        func textViewDidChange(_ textView: UITextView) {
            let updated = (textView.text ?? "")
                .components(separatedBy: "\n")
                .map { ACTEntryKind.parse($0) }
            if updated != parent.entries {
                parent.entries = updated
            }
            refreshSelectedKind()
        }
    }
}
