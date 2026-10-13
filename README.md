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
Workspace snapshots and recovery data remain local and are excluded from Git.

## Editing

- Command-N creates a tab; Command-O opens UTF-8 files (multiple selection supported).
- Command-S saves; File > Save As writes to a new location.
- Command-W closes the active tab.
- Command-F opens the native Find bar; enable Replace for replacement and Replace All.
- Command-G finds the next occurrence.
- Command-comma opens Settings: interface font/size and editor font/size are independent.
  Enter an installed font name (or System for the interface), then press Return.
  Font sizes must be between 8 and 48 points.
- Hold Option and drag to select a rectangle. Type, copy, cut or paste across its rows.
  A single pasted row repeats; multiline paste must contain exactly one line per selected row.
  Short lines are padded when typing. Escape or a normal click exits block mode.
  Monospaced fonts are recommended. Tabs use two-column stops. Lines do not wrap.
- File > Open Folder (also in the header dropdown) displays an expandable folder tree.
  Double-click a file to open a tab; an already-open file activates its existing tab.
- File > Save Workspace As creates a named `.medit-workspace` file. The file updates automatically
  as you edit and on close, preserving folder, tab order, active tab, text (including unsaved
  recovery contents), selection, scroll positions, expanded folders, selected sidebar file,
  sidebar width/visibility and window geometry.
- File > Open Workspace or double-clicking a workspace file restores that named session.
  Switching workspaces first saves the outgoing named workspace. Unnamed unsaved tabs are
  retained in the closed-tab recovery archive before the tab set is replaced.
- Drag the visible divider along the sidebar’s right edge to resize it; the sidebar button or View menu hides/shows it.
  The refresh button reloads the folder tree; switching back to the app also refreshes it.
  Directory symlinks are not expanded recursively. Packages are displayed as files.
- Workspace files store local absolute paths and recovery contents. If original files have
  changed externally, their recovered tab contents remain intact and Save asks before replacing
  the changed originals. Missing folders display a read error without discarding tabs.
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

Clean saved tabs in unnamed sessions reload current disk contents at restart; named workspaces restore their captured contents. Modified tabs restore recovery
contents; saving warns if the original file has changed externally. Files are read and saved
as UTF-8, preserving existing newline contents. Other encodings and binary files are not supported.

## Syntax highlighting

[HighlighterSwift](https://github.com/smittytone/HighlighterSwift), pinned to 3.1.0, supplies
Highlight.js parsing. Only temporary foreground colors are applied to the AppKit layout manager,
so syntax styles do not alter saved text or the selected editor font. Language is inferred from
file extension; untitled files remain Plain Text. The example file demonstrates Swift highlighting.

## Validation

```sh
build/Build/Products/Debug/medit-.app/Contents/MacOS/medit- --self-test
```

Focused tests cover Unicode recovery, workspace/active-tab restoration, modified originals,
closed-tab archives, corrupt snapshot fallback, block replacement, repeated multi-caret typing,
multiline block paste, short-row padding and non-destructive syntax highlighting.
UI checks cover tab creation, restart restoration, save/recovery, native find/replace,
font sizes, optional close prompts, folder/file opening, workspace save-on-close and restoration, and native sidebar resizing. Option-drag geometry still warrants hands-on review;
wide Unicode characters and selections through the middle of tabs have not been exhaustively tested.

## Project structure

- `main.swift`: window, header, gutter, native menus and app lifecycle.
- `Session.swift`: document/session models, recovery store, file actions, tabs, settings and highlighting.
- `BlockTextView.swift`: custom rectangular selection and multi-row edits.
- `Workspace.swift`: folder explorer, split view and named-workspace storage/restoration.
- `SelfTests.swift`: focused executable checks (29 checks).
- `Info.plist`: application identity and native `.medit-workspace` association.
- `Resources/AppIcon.icns`: macOS icon, packaged from the existing gedit blue-plus icon on Scopuli.
  `AppIconSource.png` preserves the original source asset.

Git indicators remain a future enhancement. Git remotes are `github`
(GitHub) and `origin` (Scopuli Gitea); development branch is `main`. The application source and build configuration are maintained in both repositories.
