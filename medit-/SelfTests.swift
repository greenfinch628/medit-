import AppKit

func runSelfTests() {
    setbuf(stdout, nil)
    var checks = 0
    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError("FAIL: \(message)") }
        checks += 1; print("PASS: \(message)")
    }
    do {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("medit-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = RecoveryStore(directory: folder)
        let docs = [EditorDocument(title: "Untitled Document 1", text: "α emoji 🐦\nunsaved", cursor: 3), EditorDocument(title: "code.swift", path: "/tmp/example.swift", text: "let x = 2", savedText: "let x = 1")]
        let session = EditorSession(documents: docs, activeIndex: 1, workspace: "/tmp/workspace")
        try store.save(session)
        let restored = try store.load()!
        check(restored.documents[0].text == docs[0].text, "Unicode untitled recovery")
        check(restored.documents[1].dirty && restored.documents[1].savedText == "let x = 1", "Modified file recovery remains unsaved")
        check(restored.activeIndex == 1 && restored.workspace == "/tmp/workspace", "Active tab and workspace restoration")
        try store.archive(docs[0])
        let archives = try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("Closed Tabs").path)
        check(archives.count == 1, "Closed untitled tab archived")
        var updated = session; updated.documents[0].text = "newer recovery"; try store.save(updated)
        try Data("broken JSON".utf8).write(to: store.sessionURL)
        let fallback = try store.load()!
        check(fallback.documents[0].text == docs[0].text, "Corrupt latest snapshot falls back to previous recovery")
        let recoveryFiles = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        check(recoveryFiles.contains(where: { $0.hasPrefix("session.corrupt-") }), "Corrupt snapshot preserved for diagnosis")
        let view = BlockTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        view.isRichText = false; view.allowsUndo = true; view.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        view.string = "abc\ndef"; view.blockRanges = [NSRange(location: 1, length: 1), NSRange(location: 5, length: 1)]; view.rowPadding = [0,0]
        view.insertText("X", replacementRange: NSRange(location: NSNotFound, length: 0))
        check(view.string == "aXc\ndXf", "Rectangular replacement edits every row")
        view.insertText("Y", replacementRange: NSRange(location: NSNotFound, length: 0))
        check(view.string == "aXYc\ndXYf", "Repeated column typing retains multiple carets")
        view.blockRanges = [NSRange(location: 1, length: 2), NSRange(location: 6, length: 2)]
        view.insertText("1\n2", replacementRange: NSRange(location: NSNotFound, length: 0))
        check(view.string == "a1c\nd2f", "Multiline block paste maps rows")
        view.string = "a\nb"; view.blockRanges = [NSRange(location: 1, length: 0), NSRange(location: 3, length: 0)]; view.rowPadding = [2,2]
        view.insertText("z", replacementRange: NSRange(location: NSNotFound, length: 0))
        check(view.string == "a  z\nb  z", "Short rows padded for column insertion")
        let d = AppDelegate(); d.documents = [EditorDocument(title: "sample.swift", path: "/tmp/sample.swift", text: "let value = 42 // comment")]; d.editor.string = d.documents[0].text; d.highlight()
        var range = NSRange()
        let color = d.editor.layoutManager!.temporaryAttribute(.foregroundColor, atCharacterIndex: 0, effectiveRange: &range)
        check(color != nil && d.language.stringValue == "Swift", "Syntax colors use temporary attributes and detect file type")
        check(d.editor.string == "let value = 42 // comment", "Highlighting leaves document contents untouched")
        let workspaceStore = WorkspaceStore()
        let root = folder.appendingPathComponent("tree").workspaceNormalizedURL
        let subdirectory = root.appendingPathComponent("z-folder")
        try FileManager.default.createDirectory(at: subdirectory, withIntermediateDirectories: true)
        let originalFile = root.appendingPathComponent("a.txt")
        try "original on disk".write(to: originalFile, atomically: true, encoding: .utf8)
        try "nested".write(to: subdirectory.appendingPathComponent("nested.txt"), atomically: true, encoding: .utf8)
        try "hidden".write(to: root.appendingPathComponent(".hidden"), atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("loop"), withDestinationURL: root)
        let children = try FolderNode(url: root, directory: true).children()
        check(children.first?.url.lastPathComponent == "z-folder", "Folder explorer sorts folders before files")
        check(children.contains(where: { $0.url.lastPathComponent == ".hidden" }), "Explorer includes hidden files")
        check(children.first(where: { $0.url.lastPathComponent == "loop" })?.directory == false, "Directory symlinks do not create recursive tree loops")
        var doc = EditorDocument(title: "a.txt", path: originalFile.path, text: "unsaved workspace text", savedText: "original on disk", cursor: 2)
        doc.selectionLength = 4; doc.scrollX = 15
        var workspaceSession = EditorSession(documents: [doc, docs[0]], activeIndex: 0, workspace: root.path)
        workspaceSession.sidebar = SidebarState(width: 285, hidden: false, expandedPaths: [root.path, subdirectory.path], selectedPath: subdirectory.appendingPathComponent("nested.txt").path, scrollY: 0)
        workspaceSession.windowFrame = "{{40, 50}, {900, 650}}"
        let firstWorkspace = folder.appendingPathComponent("First.medit-workspace")
        let secondWorkspace = folder.appendingPathComponent("Second.medit-workspace")
        try workspaceStore.save(workspaceSession, to: firstWorkspace)
        let exact = try workspaceStore.load(firstWorkspace)
        check(exact.documents[0].text == "unsaved workspace text" && exact.documents[1].text == docs[0].text, "Named workspace includes modified and untitled recovery contents")
        check(exact.documents[0].selectionLength == 4 && exact.documents[0].scrollX == 15 && exact.windowFrame == workspaceSession.windowFrame, "Named workspace preserves selection, scroll and window geometry")
        let originalContents = try String(contentsOf: originalFile, encoding: .utf8)
        check(originalContents == "original on disk", "Workspace saving does not overwrite original files")
        var secondSession = workspaceSession; secondSession.documents[0].text = "second independent session"
        try workspaceStore.save(secondSession, to: secondWorkspace)
        workspaceSession.documents[0].text = "updated first session"
        try workspaceStore.save(workspaceSession, to: firstWorkspace)
        let secondUnchanged = try workspaceStore.load(secondWorkspace)
        check(secondUnchanged.documents[0].text == "second independent session", "Named workspaces retain independent tab snapshots")
        let sidebar = FolderSidebarController(); sidebar.setFolder(root.path, state: exact.sidebar)
        let restoredTree = sidebar.state(width: 285, hidden: false)
        check(Set(restoredTree.expandedPaths ?? []) == Set([root.path, subdirectory.path]), "Explorer restores expanded folders")
        sidebar.setFolder(root.path, state: exact.sidebar)
        let alias = root.path.replacingOccurrences(of: "/private/var/", with: "/var/")
        if alias != root.path {
            var aliased = exact.sidebar!; aliased.expandedPaths = aliased.expandedPaths?.map { $0.replacingOccurrences(of: "/private/var/", with: "/var/") }; aliased.selectedPath = aliased.selectedPath?.replacingOccurrences(of: "/private/var/", with: "/var/")
            sidebar.setFolder(alias, state: aliased)
            check(sidebar.state(width: 285, hidden: false).selectedPath == exact.sidebar?.selectedPath, "Alias paths restore the same selected file")
        }
        check(restoredTree.selectedPath == exact.sidebar?.selectedPath, "Explorer restores selected file")
        sidebar.setFolder(root.path, state: SidebarState(expandedPaths: []))
        check(sidebar.state(width: 240, hidden: true).expandedPaths == [], "Collapsed root is restored without reopening it")
        let resizeWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 500), styleMask: [.titled], backing: .buffered, defer: false)
        let split = WorkspaceSplitViewController(); let side = NSSplitViewItem(viewController: sidebar)
        side.minimumThickness = 160; side.maximumThickness = CGFloat.greatestFiniteMagnitude
        side.holdingPriority = NSLayoutConstraint.Priority(rawValue: 260)
        let content = NSViewController(); content.view = NSView()
        split.addSplitViewItem(side); split.addSplitViewItem(NSSplitViewItem(viewController: content))
        split.view.frame = NSRect(x: 0, y: 0, width: 900, height: 500)
        resizeWindow.contentViewController = split
        resizeWindow.contentView?.layoutSubtreeIfNeeded()
        split.splitView.setPosition(300, ofDividerAt: 0)
        resizeWindow.contentView?.layoutSubtreeIfNeeded()
        check(abs(sidebar.view.frame.width - 300) < 1, "Sidebar accepts a user-selected width")
        side.isCollapsed = true; split.applyPaneState(); resizeWindow.contentView?.layoutSubtreeIfNeeded()
        side.isCollapsed = false; split.applyPaneState(); resizeWindow.contentView?.layoutSubtreeIfNeeded(); split.splitView.setPosition(300, ofDividerAt: 0)
        check(abs(sidebar.view.frame.width - 300) < 1, "Sidebar width can be restored after hiding")
        split.setSidebarWidth(550)
        check(abs(sidebar.view.frame.width - 550) < 1, "Sidebar can expand beyond the former width limit")
        let badWorkspace = folder.appendingPathComponent("Bad.medit-workspace")
        try Data("{\"format\":\"medit-workspace\",\"version\":99,\"session\":{\"version\":1,\"documents\":[],\"activeIndex\":0}}".utf8).write(to: badWorkspace)
        var rejected = false
        do { _ = try workspaceStore.load(badWorkspace) } catch { rejected = true }
        check(rejected, "Unsupported workspace versions are rejected")
        let legacy = try JSONDecoder().decode(EditorSession.self, from: JSONEncoder().encode(session))
        check(legacy.sidebar == nil && legacy.workspaceFile == nil && legacy.documents[0].selectionLength == nil, "Existing recovery sessions remain compatible")
        for encoding in [String.Encoding.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .windowsCP1252, .macOSRoman] {
            let sample = "Café — text on macOS and Fedora\r\nSecond line\n"
            let file = folder.appendingPathComponent("encoding-\(encoding.rawValue).txt")
            try sample.write(to: file, atomically: true, encoding: encoding)
            let decoded = try TextFileCodec.read(file)
            check(decoded.text == sample, "Detect text encoding \(encoding.rawValue) without changing newlines")
            try decoded.text.write(to: file, atomically: true, encoding: decoded.encoding)
            let roundTrip = try TextFileCodec.read(file)
            check(roundTrip.text == sample, "Preserve text on encoding-aware save \(encoding.rawValue)")
        }
        let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
        check(iconURL.flatMap { NSImage(contentsOf: $0) }?.isValid == true, "Packaged blue-plus application icon decodes correctly")
        print("\(checks) checks passed")
        exit(0)
    } catch { fatalError("Self-test error: \(error)") }
}
