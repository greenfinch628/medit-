# medit-

A native macOS plain-text editor using Swift and AppKit, with a gedit-inspired interface.
Requires macOS 13 or later and Xcode with Swift 5.9 or later.

## Build and run

Open `medit-.xcodeproj`, select the `medit-` scheme, then Run (Command-R).
Xcode resolves the pinned HighlighterSwift 3.1.0 package on the first build.

```sh
xcodebuild -project medit-.xcodeproj -scheme medit- -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
open build/Build/Products/Debug/medit-.app
```

For everyday use, build Release and copy the application to `~/Applications/medit-.app`:

```sh
xcodebuild -project medit-.xcodeproj -scheme medit- -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
ditto build/Build/Products/Release/medit-.app "$HOME/Applications/medit-.app"
open "$HOME/Applications/medit-.app"
```

The app is not notarized; the local development build does not require a signing account.
Folder sessions and recovery data remain local in application data.

## Editing

- Command-N creates a tab; Command-O opens files or folders (multiple selection supported).
- Command-S saves; File > Save As writes to a new location.
- Command-W closes the active tab.
- Drag a tab by its title onto another tab to change its order. Folder sessions remember
  the order, and dragging keeps the active document selected. Pinned tabs stay fixed at the left;
  unpinned tabs cannot be dragged before them.
- Click a tab’s pin icon to pin or unpin it. Newly pinned tabs go after the last pinned tab and hide their
  close button. Unpinning moves a tab after the remaining pinned group; Close File or Command-W can still close them explicitly. Pin state is remembered
  with each folder session and across restarts, including untitled drafts.
- Command-F opens the native Find bar; enable Replace for replacement and Replace All.
- Command-G finds the next occurrence.
- Command-comma opens Settings: interface font/size and editor font/size are independent.
  Enter an installed font name (or System for the interface), then press Return.
  Font sizes must be between 8 and 48 points.
- Hold Option and drag to select a rectangle. Type, copy, cut or paste across its rows.
  A single pasted row repeats; multiline paste must contain exactly one line per selected row.
  Short lines are padded when typing. Escape or a normal click exits block mode.
  Monospaced fonts are recommended. Tabs use two-column stops. Lines do not wrap.
- Open ▾ contains Open…, Open Recent, New File, New Window, Close File and Close Folder.
  Open… accepts files and folders; files open as tabs, and an existing tab is selected.
  Open Recent distinguishes files and folders with labels and icons.
- Each folder automatically remembers its editing session in application data. Opening another
  folder preserves the outgoing session and restores the selected folder's tabs, order, active
  document, cursor/selection, scroll positions and sidebar state. Reopening the active folder
  keeps its tabs intact. Opening a folder always shows its sidebar.
- Untitled drafts and unsaved file edits survive switching folders, closing folders and quitting.
  Remembering sessions never saves edits to original documents or creates files inside folders.
  Documents opened without a folder have a separate remembered session.
- Close Folder preserves its session and returns to documents opened without a folder.
  Close File retains the optional save/cancel/keep-recovery prompt.
- Save is a split button: its main portion saves the active document; its arrow offers Save,
  Save As… and Save All. Untitled documents request a filename and location. Save All saves
  modified documents and untitled drafts in the current window, stopping if a save is cancelled.
- Drag the sidebar divider to resize it. The toolbar sidebar control and the × beside Refresh
  hide/show the sidebar without affecting tabs. Refresh reloads the folder tree; returning to
  the app also refreshes it. Directory symlinks are not expanded recursively.
- The hamburger menu contains Preferences…, Help and About medit-. New Window creates an
  independent editor window, with recovery restored at the next launch.
- If an original changes externally, saving a modified recovered tab asks before replacing it.
  Missing folders show a read error without discarding tabs.
- The application menu includes Restore Closed Tab, which opens the recovery archive.

## Recovery and closing

Recovery snapshots live in `~/Library/Application Support/medit-/` and are written atomically
on text changes and periodically. They preserve untitled and modified tab contents without
writing those edits to the original files. A previous snapshot is retained; corrupt snapshots
are preserved and the previous copy is used when available.

By default, closing/quitting does not ask to save. Enable the close prompt in Settings to
choose Save, Cancel or Keep Recovery. Quit restores all open tabs next launch; explicitly
closed unsaved tabs are retained in the Closed Tabs archive and can be reopened from the
application menu. Recovery archives are local and are not automatically deleted.

Clean saved tabs reload current disk contents at restoration. Modified tabs restore recovery
contents; saving warns if the original file has changed externally. Text encoding is detected when opening files, including UTF-8, UTF-16, Windows-1252, and Mac Roman. Existing files retain their detected encoding when saved; new files and Save As use UTF-8 for sharing between macOS and Linux. Existing newline contents are preserved. Binary files are not supported.

## Syntax highlighting

[HighlighterSwift](https://github.com/smittytone/HighlighterSwift), pinned to 3.1.0, supplies
Highlight.js parsing. Only temporary foreground colors are applied to the AppKit layout manager,
so syntax styles do not alter saved text or the selected editor font. Language is inferred from
file extension; untitled files remain Plain Text. The example file demonstrates Swift highlighting.

## Validation

```sh
build/Build/Products/Debug/medit-.app/Contents/MacOS/medit- --self-test
```

Focused tests cover Unicode recovery, folder/active-tab restoration, modified originals,
closed-tab archives, corrupt snapshot fallback, block replacement, repeated multi-caret typing,
multiline block paste, short-row padding and non-destructive syntax highlighting.
UI checks cover tab creation, restart restoration, save/recovery, native find/replace,
font sizes, optional close prompts, folder/file opening, folder switching, automatic restoration and unsaved-draft preservation, and native sidebar resizing. Option-drag geometry still warrants hands-on review;
wide Unicode characters and selections through the middle of tabs have not been exhaustively tested.

## Project structure

- `main.swift`: window, header, gutter, native menus and app lifecycle.
- `Session.swift`: document/session models, recovery store, file actions, tabs, settings and highlighting.
- `BlockTextView.swift`: custom rectangular selection and multi-row edits.
- `Workspace.swift`: folder explorer, split view and automatic folder-session storage/restoration.
- `SelfTests.swift`: focused executable checks.
- `Info.plist`: application identity.
- `Resources/AppIcon.icns`: macOS icon, packaged from the existing gedit blue-plus icon on Scopuli.
  `AppIconSource.png` preserves the original source asset.

Git status badges appear beside sidebar filenames for folders inside a Git repository.
Preferences > Show Git status in sidebar enables/disables them across windows and launches.
M = modified, A = added, D = deleted, R = renamed, C = copied, T = type changed,
? = untracked, ! = merge conflict. Folder badges summarize changes inside them; clean and
ignored files have no badge. Hover for staged/working-tree details. Status refreshes in the
background every three seconds, on Refresh, after saving and when returning to the app.
Badges describe disk contents; the tab's * still indicates unsaved editor changes.
Scanning stops when disabled. Git status is read-only and never stages or commits files.

Git remotes are `github`
(GitHub) and `origin` (Scopuli Gitea); development branch is `main`. The application source and build configuration are maintained in both repositories.
