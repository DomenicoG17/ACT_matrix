import SwiftUI
import UIKit

struct BulletedEditor: UIViewRepresentable {
    @Binding var lines: [String]
    let focusToken: Int
    let currentQuadrant: Int
    let onNavigate: (Int) -> Void
    let onNew: () -> Void

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
        textView.text = Self.displayText(lines)
        textView.delegate = context.coordinator

        let accessory = MatrixKeyboardBar(currentQuadrant: currentQuadrant)
        accessory.onNavigate = { [weak coordinator = context.coordinator] destination in
            coordinator?.parent.onNavigate(destination)
        }
        accessory.onNew = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onNew()
        }
        textView.inputAccessoryView = accessory
        context.coordinator.accessory = accessory
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.accessory?.selectQuadrant(currentQuadrant)

        let display = Self.displayText(lines)
        if textView.text != display {
            let oldSelection = textView.selectedRange
            textView.text = display
            let end = (display as NSString).length
            textView.selectedRange = NSRange(location: min(oldSelection.location, end), length: 0)
        }

        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async { [weak textView] in
                guard let textView = textView, textView.window != nil else { return }
                textView.becomeFirstResponder()
                let end = (textView.text as NSString).length
                textView.selectedRange = NSRange(location: end, length: 0)
                textView.scrollRangeToVisible(textView.selectedRange)
            }
        }
    }

    static func displayText(_ lines: [String]) -> String {
        (lines.isEmpty ? [""] : lines).map { "• " + $0 }.joined(separator: "\n")
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: BulletedEditor
        weak var accessory: MatrixKeyboardBar?
        var lastFocusToken: Int?

        init(parent: BulletedEditor) { self.parent = parent }

        func textView(_ textView: UITextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {
            // The Return key creates a new bullet and leaves the cursor ready to type.
            if text == "\n" {
                let insertion = "\n• "
                let newText = (textView.text as NSString)
                    .replacingCharacters(in: range, with: insertion)
                textView.text = newText
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

        func textViewDidChange(_ textView: UITextView) {
            let normalized = textView.text.components(separatedBy: "\n").map { line -> String in
                if line.hasPrefix("• ") { return String(line.dropFirst(2)) }
                if line.hasPrefix("•") { return String(line.dropFirst(1)) }
                return line
            }
            if normalized != parent.lines {
                parent.lines = normalized
            }
        }
    }
}
