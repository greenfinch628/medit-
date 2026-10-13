import AppKit

extension Double { func nonzero(_ fallback: Double) -> Double { self > 0 ? self : fallback } }

struct EditorDocument: Codable {
    var id = UUID()
    var title: String
    var path: String?
    var text = ""
    var savedText = ""
    var cursor = 0
    var scrollY: Double = 0
    var scrollX: Double?
    var selectionLength: Int?
    var diskChanged: Bool?
    var dirty: Bool { text != savedText || diskChanged == true }
}
struct EditorSession: Codable {
    var version = 1
    var documents: [EditorDocument]
    var activeIndex: Int
    var workspace: String?
    var workspaceFile: String?
    var sidebar: SidebarState?
    var windowFrame: String?
}

/// Atomic recovery snapshots are independent of the original documents.
final class RecoveryStore {
    let directory: URL
    var sessionURL: URL { directory.appendingPathComponent("session.json") }
    init(directory override: URL? = nil) {
        directory = override ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("medit-", isDirectory: true)
    }
    func load() throws -> EditorSession? {
        guard FileManager.default.fileExists(atPath: sessionURL.path) else { return nil }
        do { return try JSONDecoder().decode(EditorSession.self, from: Data(contentsOf: sessionURL)) }
        catch {
            try? FileManager.default.copyItem(at: sessionURL, to: directory.appendingPathComponent("session.corrupt-\(UUID().uuidString).json"))
            if let data = try? Data(contentsOf: directory.appendingPathComponent("session.previous.json")), let previous = try? JSONDecoder().decode(EditorSession.self, from: data) { return previous }
            throw error
        }
    }
    func save(_ session: EditorSession) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(session)
        if let previous = try? Data(contentsOf: sessionURL) {
            if previous == data { return }
            try previous.write(to: directory.appendingPathComponent("session.previous.json"), options: .atomic)
        }
        try data.write(to: sessionURL, options: .atomic)
    }
    func archive(_ document: EditorDocument) throws {
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("Closed Tabs"), withIntermediateDirectories: true)
        let name = "\(document.id.uuidString)-\(Int(Date().timeIntervalSince1970)).json"
        try JSONEncoder().encode(document).write(to: directory.appendingPathComponent("Closed Tabs").appendingPathComponent(name), options: .atomic)
    }
}

extension AppDelegate {
    func report(_ error: Error) { NSAlert(error: error).runModal() }
    func captureDocument() {
        guard !loading, documents.indices.contains(activeIndex) else { return }
        documents[activeIndex].text = editor.string
        documents[activeIndex].cursor = editor.selectedRange().location
        documents[activeIndex].selectionLength = editor.selectedRange().length
        documents[activeIndex].scrollX = Double(editor.visibleRect.minX)
        documents[activeIndex].scrollY = Double(editor.visibleRect.minY)
    }
    func persistSession() {
        guard !loading, !documents.isEmpty else { return }
        do {
            let snapshot = sessionSnapshot()
            try store.save(snapshot)
            try saveNamedWorkspace(snapshot)
            workspaceSaveError = false
        } catch {
            if !workspaceSaveError { workspaceSaveError = true; report(error) }
        }
    }
    func restoreSession() {
        do {
            if let session = try store.load() { applySession(session, namedURL: session.workspaceFile.map { URL(fileURLWithPath: $0) }) }
        } catch { report(error) }
        if documents.isEmpty { documents = [EditorDocument(title: "Untitled Document 1")]; loadActiveDocument(); applyWorkspaceLayout(nil) }
    }
    func loadActiveDocument() {
        guard documents.indices.contains(activeIndex) else { return }
        loading = true
        editor.blockRanges = []
        editor.breakUndoCoalescing()
        editor.documentUndoManager = undoManagers[documents[activeIndex].id] ?? UndoManager()
        undoManagers[documents[activeIndex].id] = editor.documentUndoManager
        editor.documentUndoManager.disableUndoRegistration()
        editor.textStorage?.setAttributedString(NSAttributedString(string: documents[activeIndex].text, attributes: [.font: editor.font ?? NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)]))
        editor.documentUndoManager.enableUndoRegistration()
        let cursor = min(max(0, documents[activeIndex].cursor), (editor.string as NSString).length)
        editor.setSelectedRange(NSRange(location: cursor, length: min(max(0, documents[activeIndex].selectionLength ?? 0), (editor.string as NSString).length - cursor)))
        editor.scroll(NSPoint(x: max(0, documents[activeIndex].scrollX ?? 0), y: min(documents[activeIndex].scrollY, max(0, editor.bounds.height - (editor.enclosingScrollView?.contentSize.height ?? 0)))))
        editor.enclosingScrollView?.reflectScrolledClipView(editor.enclosingScrollView!.contentView)
        loading = false
        updateWorkspaceTitle()
        applyEditorParagraph(); highlight(); rebuildTabs(); refresh(); window.makeFirstResponder(editor)
    }
    func rebuildTabs() {
        for view in tabItems.arrangedSubviews { tabItems.removeArrangedSubview(view); view.removeFromSuperview() }
        for (index, doc) in documents.enumerated() {
            let tab = NSView(); tab.wantsLayer = true
            tab.layer?.backgroundColor = (index == activeIndex ? EditorPalette.activeTab : EditorPalette.inactiveTab).cgColor
            let select = NSButton(title: (doc.dirty ? "*" : "") + doc.title, target: self, action: #selector(selectTab(_:)))
            select.isBordered = false; select.font = interfaceFont; select.tag = index; select.toolTip = doc.path ?? doc.title
            let close = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close \(doc.title)")!, target: self, action: #selector(closeTab(_:)))
            close.isBordered = false; close.tag = index
            let indicator = NSView(); indicator.wantsLayer = true; indicator.layer?.backgroundColor = (index == activeIndex ? NSColor.systemBlue : NSColor.clear).cgColor
            [select, close, indicator].forEach { tab.addSubview($0); $0.translatesAutoresizingMaskIntoConstraints = false }
            NSLayoutConstraint.activate([tab.heightAnchor.constraint(equalToConstant: 45), tab.widthAnchor.constraint(equalToConstant: max(220, min(360, select.intrinsicContentSize.width + 70))), select.leadingAnchor.constraint(equalTo: tab.leadingAnchor, constant: 16), select.centerYAnchor.constraint(equalTo: tab.centerYAnchor), select.trailingAnchor.constraint(lessThanOrEqualTo: close.leadingAnchor, constant: -10), close.trailingAnchor.constraint(equalTo: tab.trailingAnchor, constant: -14), close.centerYAnchor.constraint(equalTo: tab.centerYAnchor), indicator.leadingAnchor.constraint(equalTo: tab.leadingAnchor), indicator.trailingAnchor.constraint(equalTo: tab.trailingAnchor), indicator.bottomAnchor.constraint(equalTo: tab.bottomAnchor), indicator.heightAnchor.constraint(equalToConstant: 3)])
            tabItems.addArrangedSubview(tab)
        }
        tabItems.layoutSubtreeIfNeeded()
        tabItems.setFrameSize(NSSize(width: tabItems.fittingSize.width, height: 45))
        tabItems.layoutSubtreeIfNeeded()
        if tabItems.arrangedSubviews.indices.contains(activeIndex) { tabItems.scrollToVisible(tabItems.arrangedSubviews[activeIndex].frame) }
    }
    @objc func selectTab(_ sender: NSButton) { captureDocument(); activeIndex = sender.tag; loadActiveDocument(); persistSession() }
    @objc func nextTab() { captureDocument(); activeIndex = (activeIndex + 1) % documents.count; loadActiveDocument() }
    @objc func previousTab() { captureDocument(); activeIndex = (activeIndex + documents.count - 1) % documents.count; loadActiveDocument() }
    @objc func newDocument() {
        captureDocument()
        var number = 1
        while documents.contains(where: { $0.title == "Untitled Document \(number)" }) { number += 1 }
        documents.append(EditorDocument(title: "Untitled Document \(number)")); activeIndex = documents.count - 1
        loadActiveDocument(); persistSession()
    }
    @objc func openDocuments() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        if let workspace { panel.directoryURL = URL(fileURLWithPath: workspace) }
        if panel.runModal() == .OK { for url in panel.urls { openFile(url) } }
    }
    func openFile(_ suppliedURL: URL) {
        let url = suppliedURL.workspaceNormalizedURL
        if url.pathExtension.lowercased() == "medit-workspace" { openWorkspaceFile(url); return }
        captureDocument()
        if let index = documents.firstIndex(where: { $0.path.map { URL(fileURLWithPath: $0).workspaceNormalizedURL.path } == url.path }) { activeIndex = index; loadActiveDocument(); return }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            documents.append(EditorDocument(title: url.lastPathComponent, path: url.path, text: text, savedText: text)); activeIndex = documents.count - 1
            loadActiveDocument(); persistSession()
        } catch { report(error) }
    }
    func application(_ sender: NSApplication, openFiles filenames: [String]) { filenames.forEach { openFile(URL(fileURLWithPath: $0)) }; sender.reply(toOpenOrPrint: .success) }
    @objc func openWorkspace() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.message = "Choose a folder to display in the workspace sidebar."
        if let workspace { panel.directoryURL = URL(fileURLWithPath: workspace) }
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try saveCurrentSessionBeforeSwitch()
                workspaceFile = nil; workspace = url.path; workspaceSaveError = false
                applyWorkspaceLayout(SidebarState()); updateWorkspaceTitle(); persistSession()
            } catch { report(error) }
        }
    }
    @objc func saveDocument() { _ = save(index: activeIndex, asNew: false) }
    @objc func saveAsDocument() { _ = save(index: activeIndex, asNew: true) }
    @discardableResult func save(index: Int, asNew: Bool) -> Bool {
        captureDocument()
        var url = documents[index].path.map { URL(fileURLWithPath: $0) }
        if asNew || url == nil {
            let panel = NSSavePanel(); panel.nameFieldStringValue = documents[index].title
            if let workspace { panel.directoryURL = URL(fileURLWithPath: workspace) }
            guard panel.runModal() == .OK else { return false }; url = panel.url
        }
        guard let url else { return false }
        if !asNew, documents[index].path == url.path, let disk = try? String(contentsOf: url, encoding: .utf8), disk != documents[index].savedText {
            let alert = NSAlert(); alert.messageText = "The file has changed on disk."; alert.informativeText = "Replace it with this tab’s recovered contents, or cancel and use Save As to preserve both versions."
            alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Replace")
            guard alert.runModal() == .alertSecondButtonReturn else { return false }
        }
        do {
            try documents[index].text.write(to: url, atomically: true, encoding: .utf8)
            documents[index].path = url.path; documents[index].title = url.lastPathComponent; documents[index].savedText = documents[index].text; documents[index].diskChanged = false
            rebuildTabs(); highlight(); sidebarController.refreshTree(); persistSession(); return true
        } catch { report(error); return false }
    }
    func approveClose(_ index: Int) -> Bool {
        captureDocument()
        guard documents[index].dirty, UserDefaults.standard.bool(forKey: "promptOnClose") else { return true }
        let alert = NSAlert(); alert.messageText = "Save changes to \(documents[index].title)?"
        alert.informativeText = "Keep Recovery closes this tab and retains its contents in the recovery archive."
        alert.addButton(withTitle: "Save"); alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Keep Recovery")
        let result = alert.runModal()
        return result == .alertThirdButtonReturn || (result == .alertFirstButtonReturn && save(index: index, asNew: false))
    }
    @objc func closeActiveTab() { closeDocument(activeIndex) }
    @objc func closeTab(_ sender: NSButton) { closeDocument(sender.tag) }
    func closeDocument(_ index: Int) {
        guard approveClose(index) else { return }
        do { if documents[index].dirty || documents[index].path == nil { try store.archive(documents[index]) } } catch { report(error); return }
        documents.remove(at: index)
        if index < activeIndex { activeIndex -= 1 }
        activeIndex = min(activeIndex, max(0, documents.count - 1))
        if documents.isEmpty { documents = [EditorDocument(title: "Untitled Document 1")] }
        loadActiveDocument(); persistSession()
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        for i in documents.indices { if !approveClose(i) { return .terminateCancel } }
        do { let snapshot = sessionSnapshot(); try store.save(snapshot); try saveNamedWorkspace(snapshot) } catch { report(error); return .terminateCancel }
        return .terminateNow
    }
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? { editor.documentUndoManager }
    @objc func undoEdit() { editor.blockRanges = []; editor.documentUndoManager.undo() }
    @objc func redoEdit() { editor.blockRanges = []; editor.documentUndoManager.redo() }
    func windowShouldClose(_ sender: NSWindow) -> Bool { NSApp.terminate(nil); return false }
    @objc func showAppMenu(_ sender: NSButton) {
        let menu = NSMenu(); menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Restore Closed Tab…", action: #selector(restoreClosedTab), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Open Folder…", action: #selector(openWorkspace), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Open Workspace…", action: #selector(openNamedWorkspace), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Save Workspace As…", action: #selector(saveWorkspaceAs), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Show/Hide Sidebar", action: #selector(toggleWorkspaceSidebar), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Column Selection Help", action: #selector(columnHelp), keyEquivalent: "").target = self
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.maxY), in: sender)
    }
    @objc func restoreClosedTab() {
        let panel = NSOpenPanel(); panel.directoryURL = store.directory.appendingPathComponent("Closed Tabs"); panel.message = "Choose a closed-tab recovery copy."
        if panel.runModal() == .OK, let url = panel.url {
            do { var doc = try JSONDecoder().decode(EditorDocument.self, from: Data(contentsOf: url)); doc.id = UUID(); captureDocument(); documents.append(doc); activeIndex = documents.count - 1; loadActiveDocument(); persistSession() } catch { report(error) }
        }
    }
    @objc func showAbout() {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [.applicationName: "medit-"]
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"), let icon = NSImage(contentsOf: url) { options[.applicationIcon] = icon }
        NSApp.orderFrontStandardAboutPanel(options: options)
    }
    @objc func columnHelp() {
        let alert = NSAlert(); alert.messageText = "Column / block selection"
        alert.informativeText = "Hold Option and drag across the editor to select a rectangle. Type to replace each selected row, or use Copy, Cut, and Paste. Tabs count as two columns; short rows are padded when you type. Press Escape or click normally to leave block mode."
        alert.runModal()
    }
    func applyEditorParagraph() {
        let paragraph = NSMutableParagraphStyle(); paragraph.tabStops = []
        paragraph.defaultTabInterval = 2 * ("M" as NSString).size(withAttributes: [.font: editor.font!]).width
        editor.defaultParagraphStyle = paragraph
        editor.textStorage?.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: (editor.string as NSString).length))
    }
    func applyFonts() {
        let d = UserDefaults.standard
        editor.font = NSFont(name: d.string(forKey: "editorFont") ?? "Menlo", size: CGFloat(d.double(forKey: "editorSize").nonzero(16))) ?? NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        let paragraph = NSMutableParagraphStyle(); paragraph.tabStops = []
        paragraph.defaultTabInterval = 2 * ("M" as NSString).size(withAttributes: [.font: editor.font!]).width
        editor.defaultParagraphStyle = paragraph
        editor.textStorage?.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: (editor.string as NSString).length))
        func visit(_ view: NSView) {
            if let field = view as? NSTextField { field.font = interfaceFont }
            if let button = view as? NSButton { button.font = interfaceFont }
            view.subviews.forEach(visit)
        }
        if let root = window.contentView { visit(root) }; sidebarController.interfaceFont = interfaceFont; rebuildTabs(); highlight(); refresh()
    }
    @objc func showSettings() {
        if let settingsWindow { settingsWindow.makeKeyAndOrderFront(nil); return }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 340), styleMask: [.titled, .closable], backing: .buffered, defer: false); w.title = "medit- Settings"; w.isReleasedWhenClosed = false
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        let d = UserDefaults.standard
        for (label, key, fallback) in [("Interface font", "interfaceFont", interfaceFont.fontName.hasPrefix(".") ? "System" : interfaceFont.fontName), ("Interface size", "interfaceSize", "17"), ("Editor font", "editorFont", "Menlo"), ("Editor size", "editorSize", "16")] {
            let title = NSTextField(labelWithString: label); title.widthAnchor.constraint(equalToConstant: 150).isActive = true
            let input = NSTextField(string: d.string(forKey: key) ?? fallback); input.identifier = NSUserInterfaceItemIdentifier(key); input.target = self; input.action = #selector(changeSetting(_:)); input.widthAnchor.constraint(equalToConstant: 280).isActive = true
            let row = NSStackView(views: [title, input]); row.spacing = 12; stack.addArrangedSubview(row)
        }
        let prompt = NSButton(checkboxWithTitle: "Ask to save modified tabs when closing", target: self, action: #selector(changePrompt(_:))); prompt.state = d.bool(forKey: "promptOnClose") ? .on : .off; stack.addArrangedSubview(prompt)
        let note = NSTextField(wrappingLabelWithString: "Press Return to apply a font or size. Recovery copies are always kept. Editor fonts should be monospaced for column selection."); stack.addArrangedSubview(note)
        w.contentView!.addSubview(stack); stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: w.contentView!.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: w.contentView!.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: w.contentView!.topAnchor, constant: 24)])
        settingsWindow = w; w.center(); w.makeKeyAndOrderFront(nil)
    }
    @objc func changeSetting(_ sender: NSTextField) {
        guard let key = sender.identifier?.rawValue else { return }
        if key.hasSuffix("Size") {
            guard let size = Double(sender.stringValue), (8...48).contains(size) else { NSSound.beep(); return }; UserDefaults.standard.set(size, forKey: key)
        } else {
            guard sender.stringValue == "System" || NSFont(name: sender.stringValue, size: 16) != nil else { NSSound.beep(); return }; UserDefaults.standard.set(sender.stringValue, forKey: key)
        }
        applyFonts()
    }
    @objc func changePrompt(_ sender: NSButton) { UserDefaults.standard.set(sender.state == .on, forKey: "promptOnClose") }
    /// Apply library colors as temporary display attributes, leaving plain-text storage intact.
    func highlight() {
        guard documents.indices.contains(activeIndex), let layout = editor.layoutManager else { return }
        let full = NSRange(location: 0, length: (editor.string as NSString).length)
        layout.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
        let ext = documents[activeIndex].path.map { URL(fileURLWithPath: $0).pathExtension.lowercased() } ?? ""
        let languages = ["swift": "swift", "py": "python", "js": "javascript", "ts": "typescript", "c": "c", "h": "c", "cpp": "cpp", "rs": "rust", "sh": "bash", "json": "json", "css": "css", "html": "xml", "xml": "xml", "md": "markdown", "yaml": "yaml", "yml": "yaml", "toml": "ini", "sql": "sql", "rb": "ruby", "go": "go", "java": "java"]
        guard let name = languages[ext] else { language.stringValue = "Plain Text"; return }
        language.stringValue = name == "swift" ? "Swift" : name.capitalized
        guard let highlighter = syntaxHighlighter else { return }
        guard let colored = highlighter.highlight(editor.string, as: name), colored.string == editor.string else { return }
        colored.enumerateAttribute(.foregroundColor, in: full) { color, range, _ in
            if let color { layout.addTemporaryAttribute(.foregroundColor, value: color, forCharacterRange: range) }
        }
    }
}
