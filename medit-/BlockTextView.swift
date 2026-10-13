import AppKit

/// Rectangular selection is kept separately because AppKit drops multiple empty ranges.
final class BlockTextView: NSTextView {
    var documentUndoManager = UndoManager()
    override var undoManager: UndoManager? { documentUndoManager }
    var blockRanges: [NSRange] = [] { didSet { needsDisplay = true } }
    var blockColumn = 0
    var rowPadding: [Int] = []
    private var anchor: (row: Int, column: Int)?
    private var lines: [NSRange] {
        let text = string as NSString
        var result: [NSRange] = []; var start = 0
        while start < text.length { let range = text.lineRange(for: NSRange(location: start, length: 0)); result.append(range); start = NSMaxRange(range) }
        if text.length == 0 || text.substring(from: max(0, text.length - 1)) == "\n" { result.append(NSRange(location: text.length, length: 0)) }
        return result
    }
    private func contentRange(_ range: NSRange) -> NSRange {
        let text = string as NSString; var end = NSMaxRange(range)
        while end > range.location && [10, 13].contains(Int(text.character(at: end - 1))) { end -= 1 }
        return NSRange(location: range.location, length: end - range.location)
    }
    private func offset(_ range: NSRange, column: Int) -> (Int, Int) {
        let text = (string as NSString).substring(with: contentRange(range)); var col = 0; var utf16 = range.location
        for character in text {
            let width = character == "\t" ? 2 - col % 2 : 1
            if col + width > column { break }
            col += width; utf16 += String(character).utf16.count
        }
        return (utf16, max(0, column - col))
    }
    private func gridPoint(_ point: NSPoint) -> (row: Int, column: Int) {
        let char = characterIndexForInsertion(at: point)
        let row = lines.firstIndex { char < NSMaxRange($0) } ?? max(0, lines.count - 1)
        let width = ("M" as NSString).size(withAttributes: [.font: font ?? NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)]).width
        return (row, max(0, Int(((point.x - textContainerInset.width - (textContainer?.lineFragmentPadding ?? 0)) / width).rounded())))
    }
    override func mouseDown(with event: NSEvent) {
        guard event.modifierFlags.contains(.option) else { blockRanges = []; anchor = nil; super.mouseDown(with: event); return }
        window?.makeFirstResponder(self)
        anchor = gridPoint(convert(event.locationInWindow, from: nil))
        updateBlock(at: convert(event.locationInWindow, from: nil))
        while let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            updateBlock(at: convert(next.locationInWindow, from: nil))
            if next.type == .leftMouseUp { break }
            autoscroll(with: next)
        }
    }
    private func updateBlock(at point: NSPoint) {
        guard let anchor else { return }
        let end = gridPoint(point); let startColumn = min(anchor.column, end.column); let endColumn = max(anchor.column, end.column)
        blockColumn = startColumn; rowPadding = []
        let rows = lines
        blockRanges = (min(anchor.row, end.row)...max(anchor.row, end.row)).map { row in
            let start = offset(rows[row], column: startColumn); let stop = offset(rows[row], column: endColumn)
            rowPadding.append(start.1)
            return NSRange(location: start.0, length: stop.0 - start.0)
        }
        if let first = blockRanges.first { super.setSelectedRange(NSRange(location: first.location, length: 0)) }
    }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let layout = layoutManager, let container = textContainer else { return }
        for range in blockRanges {
            if range.length > 0 {
                let glyphs = layout.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                var rect = layout.boundingRect(forGlyphRange: glyphs, in: container); rect.origin.x += textContainerInset.width; rect.origin.y += textContainerInset.height
                NSColor.selectedTextBackgroundColor.withAlphaComponent(0.35).setFill(); rect.fill()
            } else {
                let rect: NSRect
                if range.location < (string as NSString).length { rect = layout.lineFragmentRect(forGlyphAt: layout.glyphIndexForCharacter(at: range.location), effectiveRange: nil) } else { rect = layout.extraLineFragmentRect }
                let width = ("M" as NSString).size(withAttributes: [.font: font!]).width
                NSColor.systemBlue.setFill(); NSRect(x: textContainerInset.width + (textContainer?.lineFragmentPadding ?? 0) + CGFloat(blockColumn) * width, y: rect.minY + textContainerInset.height, width: 1.5, height: max(rect.height, font!.boundingRectForFont.height)).fill()
            }
        }
    }
    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        guard !blockRanges.isEmpty else { super.insertText(insertString, replacementRange: replacementRange); return }
        let text = (insertString as? NSAttributedString)?.string ?? (insertString as? String ?? "")
        replaceBlock(text)
    }
    private func replaceBlock(_ replacement: String) {
        let rows = replacement.components(separatedBy: "\n")
        guard rows.count == 1 || rows.count == blockRanges.count else { NSSound.beep(); return }
        let original = string as NSString
        let first = blockRanges.first!; let last = blockRanges.last!
        let span = NSRange(location: first.location, length: NSMaxRange(last) - first.location)
        let result = NSMutableString(string: original.substring(with: span))
        for index in blockRanges.indices.reversed() {
            let range = blockRanges[index]
            let value = rows.count == 1 ? rows[0] : rows[index]
            let padding = value.isEmpty ? "" : String(repeating: " ", count: rowPadding.indices.contains(index) ? rowPadding[index] : 0)
            result.replaceCharacters(in: NSRange(location: range.location - span.location, length: range.length), with: padding + value)
        }
        let rowsForReplacement = blockRanges
        blockRanges = []; anchor = nil
        super.insertText(result as String, replacementRange: span)
        var delta = 0
        blockRanges = []
        for index in rowsForReplacement.indices {
            let value = rows.count == 1 ? rows[0] : rows[index]
            let padding = value.isEmpty ? 0 : (rowPadding.indices.contains(index) ? rowPadding[index] : 0)
            let range = rowsForReplacement[index]
            blockRanges.append(NSRange(location: range.location + delta + padding + value.utf16.count, length: 0))
            delta += padding + value.utf16.count - range.length
        }
        blockColumn += rows[0].count
        rowPadding = Array(repeating: 0, count: blockRanges.count)
    }
    override func copy(_ sender: Any?) {
        guard !blockRanges.isEmpty else { super.copy(sender); return }
        let value = blockRanges.map { (string as NSString).substring(with: $0) }.joined(separator: "\n")
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(value, forType: .string)
    }
    override func cut(_ sender: Any?) { guard !blockRanges.isEmpty else { super.cut(sender); return }; copy(sender); replaceBlock("") }
    override func paste(_ sender: Any?) { guard !blockRanges.isEmpty else { super.paste(sender); return }; if let text = NSPasteboard.general.string(forType: .string) { replaceBlock(text) } }
    override func deleteBackward(_ sender: Any?) {
        guard !blockRanges.isEmpty else { super.deleteBackward(sender); return }
        if blockRanges.allSatisfy({ $0.length == 0 }) {
            let text = string as NSString
            blockRanges = blockRanges.map { range in
                guard range.location > 0, ![10,13].contains(Int(text.character(at: range.location - 1))) else { return range }
                return text.rangeOfComposedCharacterSequence(at: range.location - 1)
            }
        }
        replaceBlock("")
    }
    override func keyDown(with event: NSEvent) {
        if [123,124,125,126].contains(Int(event.keyCode)) || event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "z" { blockRanges = []; anchor = nil }
        super.keyDown(with: event)
    }
    override func deleteForward(_ sender: Any?) {
        guard !blockRanges.isEmpty else { super.deleteForward(sender); return }
        if blockRanges.allSatisfy({ $0.length == 0 }) {
            let text = string as NSString
            blockRanges = blockRanges.map { range in
                guard range.location < text.length, ![10,13].contains(Int(text.character(at: range.location))) else { return range }
                return text.rangeOfComposedCharacterSequence(at: range.location)
            }
        }
        replaceBlock("")
    }
    override func cancelOperation(_ sender: Any?) { blockRanges = []; anchor = nil }
}
