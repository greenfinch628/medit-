// Welcome to medit-
// A familiar place to write, designed to be pleasant to use.
// Native AppKit editing, with a gedit-inspired interface.
// Open a file or folder, then start editing. Folder sessions are automatic.

import Foundation

struct Greeting {
    let name: String

    func message() -> String {
        return "Hello, \(name)!"
    }
}

let greeting = Greeting(name: "World")
print(greeting.message())

// Run this example in Terminal: swift Welcome.swift
// Expected output: Hello, World!

// Toolbar and menus
// - Left: Open dropdown, Show/Hide Sidebar, then New Tab.
// - Right: Save split button, then the hamburger menu.
// - Open contains Open..., Open Recent, New File, New Window,
//   Close File and Close Folder. Recent items distinguish files and folders.
// - New File and New Tab both create an empty untitled document.
// - Click Save to save the active document; its arrow offers Save,
//   Save As... and Save All. Untitled documents request a filename/location.
// - Save All saves modified documents in the current window.
// - The hamburger menu contains Preferences..., Help and About medit-.
//
// Tabs and editing
// - Rounded folder-style tabs have thin borders and a blue active underline.
// - Tabs are compact, with separate space for the overflow scrollbar.
// - Drag a tab by its title onto another tab to reorder it.
// - Click the pin icon to pin/unpin. Pinned tabs stay fixed at the left.
// - Each new pin goes immediately after the last pinned tab.
// - Unpinned tabs cannot be dragged before the pinned group.
// - Unpinning moves a tab after the remaining pinned group.
// - Pinned tabs hide their close button; Close File or Command-W still closes.
// - Pin states and tab order are remembered with each folder's session.
// - Command-N creates a tab; Command-O opens files or folders.
// - Opening an already-open file selects its existing tab.
// - Command-S saves; Save As... chooses a new filename or location.
// - Undo/redo, cut, copy, paste and Select All use native Mac shortcuts.
// - Line numbers, a live line/column indicator and configurable tab stops.
// - Text encoding is detected and retained when saving existing files.
// - New files and Save As use UTF-8. Original newline contents are preserved.
// - Syntax highlighting is enabled by default and follows the file extension.
// - Preferences > Edit can disable highlighting; both editors use one Classic scheme.
// - Command-F opens Find; enable Replace for Replace and Replace All.
// - Command-G finds the next match.
// - Hold Option and drag for rectangular block selection.
// - Type, copy, cut or paste across its rows; short rows are padded.
//
// Folders, sidebar and recovery
// - Open... accepts files or folders. Opening a folder shows its sidebar.
// - Double-click a sidebar file to open it; expand folders to browse their files.
// - Resize the sidebar with its right divider. Refresh reloads its contents.
// - The x beside Refresh hides the sidebar; the toolbar control brings it back.
// - Hiding the sidebar does not close the folder or change any document.
// - Every folder automatically remembers its tabs, order, pins, active document,
//   cursor/selection, scrolling, expanded folders and sidebar state.
// - Switching folders preserves the outgoing session and restores the next one.
// - Close Folder preserves its session and returns to documents without a folder.
// - Close Folder is disabled when no folder is open.
// - Untitled drafts and unsaved edits survive folder switches and quitting.
// - Sessions live in application data; no workspace file is created in a folder.
// - Remembering sessions never writes unsaved edits into original documents.
// - Closing a file retains the existing optional Save/Cancel/Keep Recovery prompt.
// - Restore Closed Tab in the application menu reopens archived recovery text.
// - New Window opens an independent editor; open windows return at next launch.
//
// Git status in the sidebar
// - Git badges are on by default for folders inside a Git repository.
// - M modified, A added, D deleted, R renamed, C copied, T type changed,
//   ? untracked, ! merge conflict. Clean and ignored files have no badge.
// - Folder badges indicate changes inside them, including deleted files.
// - Hover over a file's badge for staged/working-tree details.
// - Status refreshes automatically, on Refresh, after saving and on app activation.
// - Git status describes files on disk; the tab's * marks unsaved editor changes.
// - Preferences > Edit > Show Git status in sidebar turns badges on/off.
// - Badges occupy a fixed column at the far right, without a visible divider.
// - The preference is remembered across launches. No Git scan runs while disabled.
// - Git indicators are read-only: they do not stage, commit or change repository files.
//
// Preferences and appearance
// - Command-comma opens Preferences for independent interface/editor fonts and sizes.
// - Optional close prompts and Git badges can be toggled in Preferences.
// - Appearance provides active/inactive tab colors with matching color swatches.
// - Individual tabs have a Tab Color command in their context menu.
// - Set tab width and choose tabs or spaces in the bottom controls.
// - Enable optional spell checking in Preferences > Spelling.
// - Single-click an underlined word for suggestions or x Ignore.
// - Ignore applies to this document only, survives recovery, and never adds
//   the word to any dictionary. Other documents still flag the word.
// - Light gray chrome and compact folder-style tabs.
