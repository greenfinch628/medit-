// Welcome to medit-
// Native AppKit editing, with a gedit-inspired interface.
// Option-drag selects a rectangle for column editing.

import Foundation

struct Greeting {
    let name: String

    func message() -> String {
        return "Hello, \(name)!"
    }
}

let greeting = Greeting(name: "Miller")
print(greeting.message())

// Features and functionality
//
// Documents and editing
// - Multiple tabs; click a tab to switch, or Command-N for a new tab.
// - Open UTF-8 text files with Command-O; save with Command-S.
// - File > Save As saves a document under a new name.
// - Undo/redo, cut, copy, paste, and Select All use native Mac shortcuts.
// - Line numbers and a live line/column indicator.
// - Two-column tab stops and horizontal scrolling for long lines.
// - Syntax highlighting follows the saved file's extension.
// - Command-F opens Find; enable Replace for Replace and Replace All.
// - Command-G finds the next match.
// - Hold Option and drag to select a rectangular block.
// - Type, copy, cut, or paste across selected rows; short rows are padded.
//
// Workspaces and recovery
// - File > Open Folder displays an expandable folder tree in the sidebar.
// - Double-click a file to open it; existing files activate their open tab.
// - Drag the sidebar's right divider to resize; the sidebar button hides it.
// - File > Save Workspace As creates a named .medit-workspace file.
// - File > Open Workspace restores its folder, tabs, and unsaved contents.
// - Workspaces save automatically while editing and when the app closes.
// - Tab order, active tab, selection, scrolling, expanded folders, sidebar
//   width/visibility, and window geometry are remembered.
// - Untitled and modified tabs have recovery copies; originals stay untouched
//   until you explicitly save the document.
// - Restore Closed Tab in the application menu reopens archived recovery text.
// - Closing the main window quits the app; open tabs return at next launch.
//
// Appearance and preferences
// - Command-comma opens Settings for independent interface and editor fonts.
// - Save prompts on closing are optional in Settings.
// - Light gray chrome, blue active-tab underline, and a framed workspace.
// - Native macOS menus and the gedit blue-plus application icon.
//
// Later enhancement: Git status indicators.
