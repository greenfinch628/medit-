import AppKit
import UniformTypeIdentifiers

extension URL {
    /// Resolve parent aliases (e.g. /var versus /private/var) while retaining a symlink's own filename.
    var workspaceNormalizedURL: URL {
        guard path != "/" else { return self }
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        let parent = deletingLastPathComponent()
        let resolved = parent.path.withCString { source in buffer.withUnsafeMutableBufferPointer { realpath(source, $0.baseAddress) != nil } }
        let parentPath = resolved ? String(cString: buffer) : parent.path
        return URL(fileURLWithPath: parentPath).appendingPathComponent(lastPathComponent)
    }
}

struct SidebarState: Codable {
    var width: Double = 240
    var hidden = false
    var expandedPaths: [String]? // nil means expand the root for a newly chosen folder.
    var selectedPath: String?
    var scrollY: Double?
}
struct NamedWorkspace: Codable {
    var format = "medit-workspace"
    var version = 1
    var session: EditorSession
}

/// A named file contains the complete session, including independent recovery contents.
final class WorkspaceStore {
    static let contentType = UTType(exportedAs: "com.greenfinch628.medit.workspace", conformingTo: .json)
    func load(_ url: URL) throws -> EditorSession {
        let file = try JSONDecoder().decode(NamedWorkspace.self, from: Data(contentsOf: url))
        guard file.format == "medit-workspace", file.version == 1, file.session.version == 1,
              Set(file.session.documents.map(\.id)).count == file.session.documents.count,
              file.session.documents.allSatisfy({ $0.cursor >= 0 && $0.scrollY.isFinite && ($0.scrollX?.isFinite ?? true) }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return file.session
    }
    func save(_ session: EditorSession, to url: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(NamedWorkspace(session: session))
        if (try? Data(contentsOf: url)) == data { return }
        try data.write(to: url, options: .atomic)
    }
}

final class WorkspaceDividerView: NSSplitView {
    override var dividerThickness: CGFloat { 6 }
    override func drawDivider(in rect: NSRect) {
        EditorPalette.sides.setFill(); rect.fill()
        NSColor.separatorColor.setFill()
        NSRect(x: rect.midX - 0.5, y: rect.minY, width: 1, height: rect.height).fill()
    }
}

/// Own the native split view directly so pane widths are preserved exactly.
final class WorkspaceSplitViewController: NSViewController, NSSplitViewDelegate {
    let splitView = WorkspaceDividerView()
    var splitViewItems: [NSSplitViewItem] = []
    private var desiredWidth: CGFloat = 240
    private var adjusting = false
    override func loadView() {
        splitView.isVertical = true; splitView.dividerStyle = .thin; splitView.delegate = self
        view = splitView
    }
    func addSplitViewItem(_ item: NSSplitViewItem) {
        _ = view
        splitViewItems.append(item); addChild(item.viewController)
        let pane = item.viewController.view; pane.translatesAutoresizingMaskIntoConstraints = true; pane.autoresizingMask = []
        splitView.addSubview(pane)
        layoutPanes()
    }
    func setSidebarWidth(_ width: CGFloat) { desiredWidth = width; layoutPanes() }
    func applyPaneState() { layoutPanes() }
    private func layoutPanes() {
        guard splitViewItems.count == 2, !adjusting else { return }
        adjusting = true; defer { adjusting = false }
        let first = splitViewItems[0]; let last = splitViewItems[1]
        let total = splitView.bounds.width; let height = splitView.bounds.height
        let hidden = first.isCollapsed
        let width = hidden ? 0 : min(max(first.minimumThickness, desiredWidth), min(first.maximumThickness, max(0, total - 160)))
        let divider = hidden || total <= width ? 0 : min(splitView.dividerThickness, total - width)
        first.viewController.view.isHidden = hidden
        first.viewController.view.frame = NSRect(x: 0, y: 0, width: width, height: height)
        last.viewController.view.frame = NSRect(x: width + divider, y: 0, width: max(0, total - width - divider), height: height)
        splitView.needsDisplay = true
    }
    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) { layoutPanes() }
    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard !adjusting, let first = splitViewItems.first, !first.isCollapsed, first.viewController.view.frame.width >= first.minimumThickness else { return }
        desiredWidth = first.viewController.view.frame.width
    }
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat { splitViewItems.first?.minimumThickness ?? 160 }
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat { min(splitViewItems.first?.maximumThickness ?? 420, max(160, splitView.bounds.width - 160)) }
    func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool { false }
    func splitView(_ splitView: NSSplitView, shouldHideDividerAt dividerIndex: Int) -> Bool { splitViewItems.first?.isCollapsed ?? true }
    func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        guard splitViewItems.first?.isCollapsed == false else { return .zero }
        return proposedEffectiveRect.insetBy(dx: -6, dy: 0)
    }
}

final class FolderNode: NSObject {
    let url: URL
    let directory: Bool
    private var cachedChildren: [FolderNode]?
    init(url: URL, directory: Bool) { self.url = url.workspaceNormalizedURL; self.directory = directory }
    func children() throws -> [FolderNode] {
        guard directory else { return [] }
        if let cachedChildren { return cachedChildren }
        let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey], options: [])
        let nodes = try urls.map { child -> FolderNode in
            let values = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey])
            return FolderNode(url: child, directory: values.isDirectory == true && values.isSymbolicLink != true && values.isPackage != true)
        }.sorted {
            if $0.directory != $1.directory { return $0.directory }
            return $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
        }
        cachedChildren = nodes
        return nodes
    }
}

final class FolderSidebarController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    let outline = NSOutlineView()
    let folderTitle = NSTextField(labelWithString: "Workspace")
    let message = NSTextField(wrappingLabelWithString: "Choose File → Open Folder…")
    var root: FolderNode?
    var onOpenFile: ((URL) -> Void)?
    var interfaceFont = NSFont.systemFont(ofSize: 17) { didSet { if isViewLoaded { let saved = state(width: 240, hidden: false); folderTitle.font = interfaceFont; message.font = interfaceFont; outline.rowHeight = max(26, interfaceFont.pointSize + 10); setFolder(root?.url.path, state: saved) } } }
    private var refreshing = false
    override func loadView() {
        let host = NSView(); host.wantsLayer = true; host.layer?.backgroundColor = EditorPalette.workspaceSidebar.cgColor
        let refresh = NSButton(image: NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh workspace")!, target: self, action: #selector(refreshTree))
        refresh.isBordered = false; refresh.toolTip = "Refresh workspace folder"
        folderTitle.font = interfaceFont; folderTitle.lineBreakMode = .byTruncatingMiddle
        message.font = interfaceFont; message.textColor = .secondaryLabelColor
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("files")); column.title = "Files"; outline.addTableColumn(column); outline.outlineTableColumn = column
        outline.headerView = nil; outline.dataSource = self; outline.delegate = self; outline.target = self; outline.doubleAction = #selector(openDoubleClickedFile)
        outline.rowHeight = 27; outline.indentationPerLevel = 15; outline.backgroundColor = EditorPalette.workspaceSidebar
        outline.selectionHighlightStyle = .regular; outline.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        let scroll = NSScrollView(); scroll.documentView = outline; scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true; scroll.autohidesScrollers = true; scroll.backgroundColor = EditorPalette.workspaceSidebar
        [folderTitle, refresh, scroll, message].forEach { host.addSubview($0); $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            folderTitle.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 12), folderTitle.topAnchor.constraint(equalTo: host.topAnchor, constant: 12), folderTitle.trailingAnchor.constraint(equalTo: refresh.leadingAnchor, constant: -8),
            refresh.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -10), refresh.centerYAnchor.constraint(equalTo: folderTitle.centerYAnchor), refresh.widthAnchor.constraint(equalToConstant: 24),
            scroll.topAnchor.constraint(equalTo: folderTitle.bottomAnchor, constant: 12), scroll.leadingAnchor.constraint(equalTo: host.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: host.trailingAnchor), scroll.bottomAnchor.constraint(equalTo: message.topAnchor, constant: -8),
            message.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 12), message.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -12), message.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -10)
        ])
        let frame = NSView(); frame.wantsLayer = true; frame.layer?.backgroundColor = EditorPalette.sides.cgColor
        frame.addSubview(host); host.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([host.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 16), host.trailingAnchor.constraint(equalTo: frame.trailingAnchor), host.topAnchor.constraint(equalTo: frame.topAnchor), host.bottomAnchor.constraint(equalTo: frame.bottomAnchor)])
        view = frame
    }
    func setFolder(_ path: String?, state: SidebarState?) {
        _ = view
        refreshing = true
        root = path.map { FolderNode(url: URL(fileURLWithPath: $0).standardizedFileURL, directory: true) }
        folderTitle.stringValue = root?.url.lastPathComponent ?? "Workspace"
        folderTitle.toolTip = path
        message.stringValue = root == nil ? "Choose File → Open Folder…" : ""
        outline.reloadData()
        if let root {
            let paths = state?.expandedPaths ?? [root.url.path]
            for path in paths.sorted(by: { $0.count < $1.count }) { if let node = node(at: path) { outline.expandItem(node) } }
            if let selected = state?.selectedPath, let node = node(at: selected), outline.row(forItem: node) >= 0 {
                outline.selectRowIndexes(IndexSet(integer: outline.row(forItem: node)), byExtendingSelection: false)
            }
        }
        if let y = state?.scrollY { outline.scroll(NSPoint(x: 0, y: max(0, y))) }
        refreshing = false
    }
    func node(at path: String) -> FolderNode? {
        guard let root else { return nil }
        let target = URL(fileURLWithPath: path).workspaceNormalizedURL.path
        if root.url.path == target { return root }
        let prefix = root.url.path.hasSuffix("/") ? root.url.path : root.url.path + "/"
        guard target.hasPrefix(prefix) else { return nil }
        var current = root
        for part in target.dropFirst(prefix.count).split(separator: "/") {
            guard let child = try? current.children().first(where: { $0.url.lastPathComponent == String(part) }) else { return nil }
            current = child
        }
        return current
    }
    func state(width: Double, hidden: Bool) -> SidebarState {
        var expanded: [String] = []
        for row in 0..<outline.numberOfRows {
            if let node = outline.item(atRow: row) as? FolderNode, outline.isItemExpanded(node) { expanded.append(node.url.path) }
        }
        let selected = outline.item(atRow: outline.selectedRow) as? FolderNode
        return SidebarState(width: width, hidden: hidden, expandedPaths: expanded, selectedPath: selected?.url.path, scrollY: Double(outline.visibleRect.minY))
    }
    @objc func refreshTree() {
        guard !refreshing else { return }
        let saved = state(width: 240, hidden: false)
        setFolder(root?.url.path, state: saved)
    }
    private func children(_ node: FolderNode) -> [FolderNode] {
        do { return try node.children() }
        catch { message.stringValue = "Cannot read \(node.url.lastPathComponent)."; message.toolTip = error.localizedDescription; return [] }
    }
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int { if let node = item as? FolderNode { return children(node).count }; return root == nil ? 0 : 1 }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any { if let node = item as? FolderNode { return children(node)[index] }; return root! }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool { (item as? FolderNode)?.directory ?? false }
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? FolderNode else { return nil }
        let cell = NSTableCellView(); let field = NSTextField(labelWithString: node.url.lastPathComponent)
        field.font = interfaceFont; field.lineBreakMode = .byTruncatingMiddle
        let icon = NSImageView(); icon.image = NSImage(systemSymbolName: node.directory ? "folder" : "doc.text", accessibilityDescription: node.directory ? "Folder" : "File")
        cell.textField = field; cell.imageView = icon; cell.toolTip = node.url.path
        [icon, field].forEach { cell.addSubview($0); $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2), icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor), icon.widthAnchor.constraint(equalToConstant: 18), icon.heightAnchor.constraint(equalToConstant: 18), field.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6), field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6), field.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
        return cell
    }
    @objc func openDoubleClickedFile() {
        guard let node = outline.item(atRow: outline.clickedRow) as? FolderNode else { return }
        if node.directory { if outline.isItemExpanded(node) { outline.collapseItem(node) } else { outline.expandItem(node) } }
        else { onOpenFile?(node.url) }
    }
}

extension AppDelegate {
    func applicationDidBecomeActive(_ notification: Notification) { if window != nil, workspace != nil { sidebarController.refreshTree() } }
    func updateWorkspaceTitle() {
        let name = workspaceFile?.deletingPathExtension().lastPathComponent ?? workspace.map { URL(fileURLWithPath: $0).lastPathComponent }
        window.title = name.map { "medit- — \($0)" } ?? "medit-"
        window.representedURL = workspaceFile
    }
    func sessionSnapshot() -> EditorSession {
        captureDocument()
        if let sidebarItem, !sidebarItem.isCollapsed { sidebarWidth = sidebarController.view.frame.width }
        let sidebar = sidebarController.state(width: Double(sidebarWidth), hidden: sidebarItem?.isCollapsed ?? true)
        return EditorSession(documents: documents, activeIndex: activeIndex, workspace: workspace, workspaceFile: workspaceFile?.path, sidebar: sidebar, windowFrame: window.map { NSStringFromRect($0.frame) })
    }
    func saveNamedWorkspace(_ snapshot: EditorSession) throws { if let workspaceFile { try workspaceStore.save(snapshot, to: workspaceFile) } }
    func saveCurrentSessionBeforeSwitch() throws {
        let snapshot = sessionSnapshot()
        try store.save(snapshot); try saveNamedWorkspace(snapshot)
    }
    func applySession(_ session: EditorSession, namedURL: URL?) {
        loading = true
        documents = session.documents; activeIndex = min(max(0, session.activeIndex), max(0, documents.count - 1))
        workspace = session.workspace; workspaceFile = namedURL; workspaceSaveError = false
        undoManagers.removeAll()
        for i in documents.indices {
            if let path = documents[i].path, let decoded = try? TextFileCodec.read(URL(fileURLWithPath: path)) {
                if documents[i].textEncoding == nil { documents[i].textEncoding = decoded.encoding.rawValue }
                if namedURL != nil { documents[i].diskChanged = decoded.text != documents[i].savedText }
                else if !documents[i].dirty { documents[i].text = decoded.text; documents[i].savedText = decoded.text; documents[i].textEncoding = decoded.encoding.rawValue }
            }
        }
        if documents.isEmpty { documents = [EditorDocument(title: "Untitled Document 1")] }
        if let frame = session.windowFrame {
            var rect = NSRectFromString(frame)
            if rect.width.isFinite, rect.height.isFinite, rect.origin.x.isFinite, rect.origin.y.isFinite, rect.width >= 640, rect.height >= 400, let screen = NSScreen.main?.visibleFrame {
                rect.size.width = min(rect.width, screen.width); rect.size.height = min(rect.height, screen.height)
                rect.origin.x = min(max(rect.minX, screen.minX), screen.maxX - rect.width)
                rect.origin.y = min(max(rect.minY, screen.minY), screen.maxY - rect.height)
                window.setFrame(rect, display: true)
            }
        }
        applyWorkspaceLayout(session.sidebar)
        loading = false; loadActiveDocument()
    }
    func applyWorkspaceLayout(_ state: SidebarState?) {
        sidebarController.interfaceFont = interfaceFont
        sidebarController.setFolder(workspace, state: state)
        sidebarWidth = CGFloat(max(160, state?.width ?? 240))
        sidebarItem.isCollapsed = workspace == nil || state?.hidden == true
        workspaceSplit.applyPaneState()
        window.contentView?.layoutSubtreeIfNeeded()
        if !sidebarItem.isCollapsed { workspaceSplit.setSidebarWidth(sidebarWidth) }
    }
    @objc func toggleWorkspaceSidebar() {
        if workspace == nil { openWorkspace(); return }
        if !sidebarItem.isCollapsed { sidebarWidth = sidebarController.view.frame.width }
        sidebarItem.isCollapsed.toggle()
        workspaceSplit.applyPaneState()
        window.contentView?.layoutSubtreeIfNeeded()
        if !sidebarItem.isCollapsed { workspaceSplit.setSidebarWidth(sidebarWidth) }
        persistSession()
    }
    @objc func refreshWorkspaceSidebar() { sidebarController.refreshTree() }
    @objc func showWorkspaceMenu(_ sender: NSButton) {
        let menu = NSMenu()
        for (name, action) in [("Open Folder…", #selector(openWorkspace)), ("Open Workspace…", #selector(openNamedWorkspace)), ("Save Workspace As…", #selector(saveWorkspaceAs)), ("Show/Hide Sidebar", #selector(toggleWorkspaceSidebar))] {
            menu.addItem(withTitle: name, action: action, keyEquivalent: "").target = self
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.maxY), in: sender)
    }
    @objc func saveWorkspaceAs() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [WorkspaceStore.contentType]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = (workspaceFile?.deletingPathExtension().lastPathComponent ?? workspace.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Workspace") + ".medit-workspace"
        if let workspaceFile { panel.directoryURL = workspaceFile.deletingLastPathComponent() }
        else if let workspace { panel.directoryURL = URL(fileURLWithPath: workspace) }
        panel.message = "Save this folder, tabs, and unsaved contents as a named workspace. It will update automatically."
        guard panel.runModal() == .OK, var url = panel.url else { return }
        if url.pathExtension != "medit-workspace" { url.appendPathExtension("medit-workspace") }
        let previousURL = workspaceFile
        do {
            try saveCurrentSessionBeforeSwitch()
            workspaceFile = url
            let snapshot = sessionSnapshot()
            try workspaceStore.save(snapshot, to: url)
            try store.save(snapshot); workspaceSaveError = false; updateWorkspaceTitle(); sidebarController.refreshTree()
        } catch { workspaceFile = previousURL; report(error) }
    }
    @objc func openNamedWorkspace() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [WorkspaceStore.contentType]; panel.canChooseDirectories = false
        if let workspaceFile { panel.directoryURL = workspaceFile.deletingLastPathComponent() }
        else if let workspace { panel.directoryURL = URL(fileURLWithPath: workspace) }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openWorkspaceFile(url)
    }
    func openWorkspaceFile(_ url: URL) {
        do {
            // Validate first: a bad workspace must not replace the current session.
            let snapshot = try workspaceStore.load(url)
            if workspaceFile?.workspaceNormalizedURL == url.workspaceNormalizedURL { return }
            try saveCurrentSessionBeforeSwitch()
            // Preserve unnamed unsaved tabs before replacing the tab set.
            if workspaceFile == nil {
                for doc in documents where doc.dirty || doc.path == nil { try store.archive(doc) }
            }
            applySession(snapshot, namedURL: url)
            persistSession()
        } catch { report(error) }
    }
}
