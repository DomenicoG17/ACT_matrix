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

        increase.setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)), for: .normal)
        increase.tintColor = .tertiaryLabel
        increase.accessibilityLabel = "Segna una ricorrenza in più"
        increase.addTarget(self, action: #selector(increaseTapped), for: .touchUpInside)

        decrease.setImage(UIImage(systemName: "minus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)), for: .normal)
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
    let onOpenTodo: (UUID) -> Void

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
        let linkTap = UITapGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.openTodoOnTap(_:)))
        linkTap.delegate = context.coordinator
        linkTap.cancelsTouchesInView = true
        textView.addGestureRecognizer(linkTap)
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
        accessory.onIndent = { [weak coordinator = context.coordinator] delta in
            coordinator?.adjustIndent(delta)
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
        context.coordinator.styleTodoLinks()
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
            .map(\.displayLine)
            .joined(separator: "\n")
    }

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
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

        private func selectedLineIndex(_ view: UITextView) -> Int {
            let raw = (view.text ?? "") as NSString
            let location = min(view.selectedRange.location, raw.length)
            return raw.substring(to: location).filter { $0 == "\n" }.count
        }

        func refreshSelectedKind() {
            guard let view = textView else { return }
            let index = selectedLineIndex(view)
            accessory?.selectKind(parent.entries.indices.contains(index)
                ? parent.entries[index].kind : .bullet)
        }

        func setKindOfCurrentEntry(_ kind: ACTEntryKind) {
            guard let view = textView else { return }
            let index = selectedLineIndex(view)
            guard parent.entries.indices.contains(index) else { return }
            var updated = parent.entries
            let oldPrefix = updated[index].displayPrefix
            updated[index].kind = kind
            let newPrefix = updated[index].displayPrefix
            let (lineRange, _) = currentLine(in: view)
            let relative = max(0, view.selectedRange.location - lineRange.location
                                    - (oldPrefix as NSString).length)
            pendingEdit = nil
            parent.entries = updated
            view.text = BulletedEditor.displayText(updated)
            view.selectedRange = NSRange(location: lineRange.location
                + (newPrefix as NSString).length
                + min(relative, (updated[index].text as NSString).length), length: 0)
            styleTodoLinks()
            refreshSelectedKind()
            layoutCounters()
            view.becomeFirstResponder()
            view.scrollRangeToVisible(view.selectedRange)
        }

        func adjustIndent(_ delta: Int) {
            guard let view = textView else { return }
            let index = selectedLineIndex(view)
            guard parent.entries.indices.contains(index) else { return }
            var updated = parent.entries
            let original = updated[index].indentLevel
            let next = max(0, min(4, original + delta))
            guard original != next else { return }
            let line = currentLine(in: view).0
            let before = (updated[index].displayPrefix as NSString).length
            let relative = max(0, view.selectedRange.location - line.location - before)
            updated[index].indentLevel = next
            pendingEdit = nil
            parent.entries = updated
            view.text = BulletedEditor.displayText(updated)
            view.selectedRange = NSRange(location: line.location
                + (updated[index].displayPrefix as NSString).length
                + min(relative, (updated[index].text as NSString).length), length: 0)
            styleTodoLinks()
            layoutCounters()
            view.becomeFirstResponder()
            view.scrollRangeToVisible(view.selectedRange)
        }

        func styleTodoLinks() {
            guard let view = textView else { return }
            let fullText = (view.text ?? "") as NSString
            let storage = view.textStorage
            guard storage.length == fullText.length else { return }
            let selection = view.selectedRange
            storage.beginEditing()
            let range = NSRange(location: 0, length: fullText.length)
            storage.addAttributes([.foregroundColor: UIColor.label,
                                   .underlineStyle: 0], range: range)
            var offset = 0
            let font = view.font ?? UIFont.preferredFont(forTextStyle: .body)
            for entry in parent.entries {
                let lineLength = (entry.displayLine as NSString).length
                // Hanging indent: automatic line wraps start exactly where the
                // entry's text starts, not at the main quadrant margin.
                let paragraph = NSMutableParagraphStyle()
                paragraph.firstLineHeadIndent = 0
                paragraph.headIndent = (entry.displayPrefix as NSString)
                    .size(withAttributes: [.font: font]).width
                let paragraphLength = min(lineLength + 1, max(0, fullText.length - offset))
                if paragraphLength > 0 {
                    storage.addAttribute(.paragraphStyle, value: paragraph,
                                         range: NSRange(location: offset, length: paragraphLength))
                }
                if entry.kind == .todo && !entry.text.isEmpty {
                    let beginning = offset + (entry.displayPrefix as NSString).length
                    let length = (entry.text as NSString).length
                    if beginning + length <= fullText.length {
                        storage.addAttributes([.foregroundColor: UIColor.systemBlue,
                                               .underlineStyle: NSUnderlineStyle.single.rawValue],
                                              range: NSRange(location: beginning, length: length))
                    }
                }
                offset += lineLength + 1
            }
            storage.endEditing()
            if NSMaxRange(selection) <= fullText.length { view.selectedRange = selection }
        }

        private func tappedTodoID(at location: CGPoint, in view: UITextView) -> UUID? {
            guard location.x >= 0,
                  location.x < view.bounds.width - 83 else { return nil }
            let position = CGPoint(x: location.x - view.textContainerInset.left,
                                   y: location.y - view.textContainerInset.top)
            let manager = view.layoutManager
            let glyph = manager.glyphIndex(for: position, in: view.textContainer)
            guard glyph < manager.numberOfGlyphs else { return nil }
            let charIndex = manager.characterIndexForGlyph(at: glyph)
            let text = (view.text ?? "") as NSString
            guard charIndex < text.length else { return nil }
            let preceding = text.substring(to: charIndex)
            let index = preceding.filter { $0 == "\n" }.count
            guard parent.entries.indices.contains(index),
                  parent.entries[index].kind == .todo,
                  !parent.entries[index].text.isEmpty else { return nil }
            let fragment = manager.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
            guard position.y >= fragment.minY - 3,
                  position.y <= fragment.maxY + 3,
                  position.x >= fragment.minX,
                  position.x <= fragment.maxX + 3 else { return nil }
            let lineRange = text.lineRange(for: NSRange(location: charIndex, length: 0))
            let bodyStart = lineRange.location
                + (parent.entries[index].displayPrefix as NSString).length
            guard charIndex >= bodyStart else { return nil }
            return parent.entries[index].id
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldReceive touch: UITouch) -> Bool {
            guard let view = textView else { return false }
            return tappedTodoID(at: touch.location(in: view), in: view) != nil
        }

        @objc func openTodoOnTap(_ gesture: UITapGestureRecognizer) {
            guard let view = textView,
                  let id = tappedTodoID(at: gesture.location(in: view), in: view) else { return }
            view.resignFirstResponder()
            parent.onOpenTodo(id)
        }

        // Deleting a separator or the beginning of an entry must also consume
        // the next entry's marker. Otherwise UIKit merges lines as
        // "💭 first💭 second" and a duplicate symbol is left in the text.
        private func mergeEntry(at index: Int, in view: UITextView) -> Bool {
            guard index > 0, parent.entries.indices.contains(index) else { return false }
            let source = (view.text ?? "") as NSString
            let lines = (view.text ?? "").components(separatedBy: "\n")
            guard lines.indices.contains(index) else { return false }
            let precedingLines = Array(lines.prefix(index))
            let previous = precedingLines.joined(separator: "\n")
            let entry = parent.entries[index]
            let current = lines[index]
            let prefix = entry.displayPrefix
            // A mid-autocorrect edit can have an unsynchronized UITextView.
            // In that case avoid destructive changes.
            guard current.hasPrefix(prefix) else { return false }
            let body = String(current.dropFirst(prefix.count))
            let separator = (!previous.isEmpty && !body.isEmpty &&
                !previous.last!.isWhitespace && !body.first!.isWhitespace) ? " " : ""
            let merged = previous + separator + body
            let remaining = lines.dropFirst(index + 1)
            let result = merged + (remaining.isEmpty ? "" : "\n" + remaining.joined(separator: "\n"))
            pendingEdit = (startLine: index - 1, removedBreaks: 1, addedBreaks: 0)
            view.text = result
            view.selectedRange = NSRange(location: (previous + separator).utf16.count, length: 0)
            textViewDidChange(view)
            view.scrollRangeToVisible(view.selectedRange)
            return true
        }

        func textView(_ textView: UITextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {
            let raw = (textView.text ?? "") as NSString
            guard range.location <= raw.length, NSMaxRange(range) <= raw.length else { return false }
            // Single-character Backspace at a list boundary is special.
            // Removing the marker or the separator also removes the obsolete
            // marker from the following entry, rather than duplicating it.
            if text.isEmpty && range.length == 1 {
                let removedChar = raw.substring(with: range)
                let before = raw.substring(to: range.location)
                let lineIndex = before.filter { $0 == "\n" }.count
                if removedChar == "\n" {
                    if mergeEntry(at: lineIndex + 1, in: textView) { return false }
                } else if parent.entries.indices.contains(lineIndex) {
                    let lineStart = raw.lineRange(for: NSRange(location: range.location, length: 0)).location
                    let prefixEnd = lineStart + (parent.entries[lineIndex].displayPrefix as NSString).length
                    if range.location >= lineStart && range.location < prefixEnd {
                        if lineIndex == 0 { return false } // Keep first list marker intact.
                        if mergeEntry(at: lineIndex, in: textView) { return false }
                    }
                }
            }
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
                let index = prior.filter { $0 == "\n" }.count
                let existing = parent.entries.indices.contains(index)
                    ? parent.entries[index] : ACTEntry()
                let insertion = "\n" + existing.displayPrefix
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
            let lines = (textView.text ?? "").components(separatedBy: "\n")
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
               lines.indices.contains(change.startLine + 1),
               lines.count == previous.count + 1 {
                let original = previous[change.startLine]
                let blank = ACTEntry.parseLine(lines[change.startLine], fallback: original)
                let moved = ACTEntry.parseLine(lines[change.startLine + 1], fallback: original)
                insertedBeforeExisting = blank.text.isEmpty
                    && moved.text == original.text && moved.kind == original.kind
            } else {
                insertedBeforeExisting = false
            }
            let updated: [ACTEntry] = lines.enumerated().map { index, rawLine in
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
                let oldEntry: ACTEntry? = oldIndex.flatMap {
                    previous.indices.contains($0) ? previous[$0] : nil
                }
                // New lines inherit type and nesting, but not note or count.
                let inherited = oldEntry ?? (index > 0 ? previous[min(index - 1, previous.count - 1)] : ACTEntry())
                var result = ACTEntry.parseLine(rawLine, fallback: inherited)
                if let oldEntry = oldEntry {
                    result.id = oldEntry.id
                    result.recurrenceCount = oldEntry.recurrenceCount
                    result.note = oldEntry.note
                }
                return result
            }
            if updated != previous { parent.entries = updated }
            styleTodoLinks()
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
