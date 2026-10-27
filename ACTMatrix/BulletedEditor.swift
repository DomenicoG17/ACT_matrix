import SwiftUI
import UIKit

/// Allows a side rail of small, independently tappable counter controls on top
/// of the native multiline UITextView. Controls use TextKit's actual line geometry,
/// so a wrapped entry is counted once and keeps its button next to its first line.
private final class RecurrenceTextView: UITextView {
    var onLayout: (() -> Void)?
    private var isNotifyingLayout = false

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !isNotifyingLayout else { return }
        isNotifyingLayout = true
        onLayout?()
        isNotifyingLayout = false
    }
}

private final class RecurrenceRowControls: UIView {
    var onIncrease: (() -> Void)?
    var onDecrease: (() -> Void)?

    private let increase = UIButton(type: .system)
    private let decrease = UIButton(type: .system)
    private let number = UILabel()
    private var count = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isAccessibilityElement = false

        increase.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        increase.tintColor = .systemRed
        increase.accessibilityLabel = "Segna una ricorrenza in più"
        increase.addTarget(self, action: #selector(increaseTapped), for: .touchUpInside)

        decrease.setImage(UIImage(systemName: "minus.circle"), for: .normal)
        decrease.tintColor = .secondaryLabel
        decrease.accessibilityLabel = "Togli una ricorrenza"
        decrease.addTarget(self, action: #selector(decreaseTapped), for: .touchUpInside)

        number.font = .systemFont(ofSize: 12, weight: .bold)
        number.textColor = .systemRed
        number.textAlignment = .center
        number.adjustsFontSizeToFitWidth = true
        number.minimumScaleFactor = 0.6

        for control in [increase, decrease, number] { addSubview(control) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func configure(count: Int, text: String) {
        self.count = max(0, count)
        increase.accessibilityLabel = "Aumenta ricorrenze: \(text)"
        decrease.accessibilityLabel = "Diminuisci ricorrenze: \(text)"
        number.text = "\(self.count)"
        number.accessibilityLabel = "\(self.count) ricorrenze"
        number.isHidden = self.count == 0
        decrease.isHidden = self.count == 0
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        // Larger hit targets than the icons themselves, while remaining compact.
        increase.frame = CGRect(x: width - 29, y: 0, width: 29, height: 32)
        if count > 0 {
            decrease.frame = CGRect(x: 0, y: 0, width: 23, height: 32)
            number.frame = CGRect(x: 22, y: 0, width: width - 52, height: 32)
        }
    }

    @objc private func increaseTapped() { onIncrease?() }
    @objc private func decreaseTapped() { onDecrease?() }
}

struct BulletedEditor: UIViewRepresentable {
    @Binding var entries: [ACTEntry]
    let focusToken: Int
    let currentQuadrant: Int
    let onNavigate: (Int) -> Void
    let onNew: () -> Void
    let onShowAll: () -> Void
    let onAdjustRecurrence: (Int, Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITextView {
        let textView = RecurrenceTextView(frame: .zero)
        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = .label
        textView.tintColor = .systemTeal
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 10, right: 83)
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.autocorrectionType = .yes
        textView.spellCheckingType = .yes
        textView.text = Self.displayText(entries)
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        textView.onLayout = { [weak coordinator = context.coordinator] in
            coordinator?.layoutCounters()
        }

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
        context.coordinator.layoutCounters()
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
        private var rowControls: [Int: RecurrenceRowControls] = [:]
        // A replacement can add/delete physical lines. Preserve counters
        // belonging to all unaffected lines instead of re-parsing them as zero.
        private var pendingEdit: (startLine: Int, removedBreaks: Int, addedBreaks: Int)?
        private var layingOutCounters = false

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
            pendingEdit = nil
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
            let raw = (textView.text ?? "") as NSString
            guard range.location <= raw.length, NSMaxRange(range) <= raw.length else { return false }
            let prior = raw.substring(to: range.location)
            let removed = raw.substring(with: range)
            pendingEdit = (
                startLine: prior.filter { $0 == "\n" }.count,
                removedBreaks: removed.filter { $0 == "\n" }.count,
                addedBreaks: text.filter { $0 == "\n" }.count
            )
            // Return inherits the icon of the preceding line, but NOT its count.
            if text == "\n" {
                let lineRange = raw.lineRange(for: NSRange(location: range.location, length: 0))
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
            let parsed = (textView.text ?? "")
                .components(separatedBy: "\n")
                .map { ACTEntryKind.parse($0) }
            let previous = parent.entries
            let change = pendingEdit
            pendingEdit = nil
            // Special case: pressing Return BEFORE an existing thought inserts
            // an empty line, pushing the entire old thought to the NEXT line.
            // In that situation its count must follow the thought, not the blank.
            let insertedBeforeExisting: Bool
            if let change = change,
               change.addedBreaks == 1, change.removedBreaks == 0,
               previous.indices.contains(change.startLine),
               parsed.indices.contains(change.startLine + 1),
               parsed.count == previous.count + 1 {
                let blank = parsed[change.startLine]
                let moved = parsed[change.startLine + 1]
                let original = previous[change.startLine]
                insertedBeforeExisting = blank.text.isEmpty
                    && moved.text == original.text && moved.kind == original.kind
            } else {
                insertedBeforeExisting = false
            }
            let updated: [ACTEntry] = parsed.enumerated().map { index, newEntry in
                let oldIndex: Int?
                if let change = change {
                    if insertedBeforeExisting && index == change.startLine {
                        oldIndex = nil
                    } else if insertedBeforeExisting && index == change.startLine + 1 {
                        oldIndex = change.startLine
                    } else if index <= change.startLine {
                        oldIndex = index
                    } else if index <= change.startLine + change.addedBreaks {
                        oldIndex = nil // newly created line starts at zero
                    } else {
                        oldIndex = index - change.addedBreaks + change.removedBreaks
                    }
                } else {
                    oldIndex = index // icon replacement or an autocorrect update
                }
                let count: Int
                if let oldIndex = oldIndex, previous.indices.contains(oldIndex) {
                    count = previous[oldIndex].recurrenceCount
                } else {
                    count = 0
                }
                return ACTEntry(text: newEntry.text, kind: newEntry.kind,
                                recurrenceCount: count)
            }
            if updated != previous { parent.entries = updated }
            refreshSelectedKind()
            layoutCounters()
        }

        func layoutCounters() {
            guard !layingOutCounters, let view = textView, view.bounds.width > 100 else { return }
            layingOutCounters = true
            defer { layingOutCounters = false }

            let source = (view.text ?? "") as NSString
            let manager = view.layoutManager
            let container = view.textContainer
            manager.ensureLayout(for: container)
            let entries = parent.entries
            // Remove buttons when lines are removed, to avoid tapping an old index.
            for index in Array(rowControls.keys) where !entries.indices.contains(index) {
                rowControls.removeValue(forKey: index)?.removeFromSuperview()
            }
            var start = 0
            for index in entries.indices {
                guard start <= source.length else { break }
                let line = source.lineRange(for: NSRange(location: start, length: 0))
                let glyphs = manager.glyphRange(
                    forCharacterRange: NSRange(location: start, length: min(1, source.length - start)),
                    actualCharacterRange: nil
                )
                let y: CGFloat
                if glyphs.length > 0 {
                    y = manager.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil).minY
                        + view.textContainerInset.top
                } else {
                    // Empty trailing entry: use the final caret for its placement.
                    let endPosition = view.endOfDocument
                    let caret = view.caretRect(for: endPosition)
                    y = caret.minY + view.contentOffset.y
                }
                // Blank drafts have no recurrence button until they contain text.
                if entries[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    rowControls.removeValue(forKey: index)?.removeFromSuperview()
                    if line.length == 0 { break }
                    start = NSMaxRange(line)
                    continue
                }
                let controls: RecurrenceRowControls
                if let existing = rowControls[index] {
                    controls = existing
                } else {
                    controls = RecurrenceRowControls(frame: .zero)
                    rowControls[index] = controls
                    view.addSubview(controls)
                }
                controls.onIncrease = { [weak self] in
                    self?.parent.onAdjustRecurrence(index, 1)
                }
                controls.onDecrease = { [weak self] in
                    self?.parent.onAdjustRecurrence(index, -1)
                }
                controls.configure(count: entries[index].recurrenceCount,
                                   text: entries[index].text)
                controls.frame = CGRect(x: max(0, view.bounds.width - 77),
                                        y: max(0, y - 3), width: 76, height: 32)
                // Skip this physical line (including its trailing newline).
                if line.length == 0 { break }
                start = NSMaxRange(line)
            }
        }
    }
}
