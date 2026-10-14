# medit-

A simple text editor inspired by GNOME gedit that is pleasant to use.

Built for macOS with Swift and AppKit, medit- follows the familiar gedit layout while keeping native Mac window controls, file dialogs and Command shortcuts. Its companion, [gedit-](https://github.com/greenfinch628/gedit-), brings the same approach to Fedora. This is an independent development project, not an official GNOME or gedit release.

## Features

- Open files and folders, browse recent items, and work in multiple windows.
- Save, Save As and Save All, with detected text encoding retained for existing files and UTF-8 for new files and Save As.
- Select rectangular blocks with **Option+drag**, then copy, cut, paste or type across their rows. No plugin is required.
- Restore untitled drafts, unsaved edits, tabs, pins, colors, cursor positions and folder sessions after restarting.
- Keep documents open and report an error if recovery cannot be written.
- Right-click a tab to rename its file. Naming an untitled document saves it in the sidebar folder; existing files are never overwritten.
- Compact movable tabs, a fixed pinned group, individual tab colors and configurable active/inactive colors.
- A folder sidebar with an invisible fixed column for read-only Git status badges. Right-click its folder title and choose Close Folder to leave the sidebar empty; the folder session and unsaved drafts are preserved.
- Native Find, Replace and Replace All, line numbers and a live line/column indicator.
- Configurable tab width and tabs or spaces, available from the bottom controls.
- Syntax highlighting enabled by default, with a fixed scheme and language selection. Bash uses Xcode Default (Light) Swift colors mapped to Bash tokens.
- Optional spelling suggestions and document-only Ignore. Ignoring a word never adds it to a dictionary.
- Independent interface and editor fonts, including system fonts, under Preferences.
- An editable, pinned Welcome.swift with a Hello World example and a Show Welcome on startup preference.

## Build and try

Requires macOS 13 or later and Xcode with Swift 5.9 or later. Open `medit-.xcodeproj`, select the `medit-` scheme, then Run with **Command+R**. Xcode resolves the pinned HighlighterSwift 3.1.0 dependency on the first build.

To build a separate review application while preserving the installed medit- and its data:

```sh
xcodebuild -project medit-.xcodeproj -scheme medit- \
  -configuration Release -derivedDataPath build/review-next \
  CODE_SIGNING_ALLOWED=NO \
  PRODUCT_BUNDLE_IDENTIFIER=com.greenfinch628.medit.review build
ditto build/review-next/Build/Products/Release/medit-.app \
  "$HOME/Applications/medit-next.app"
open "$HOME/Applications/medit-next.app"
```

The review build uses an independent application identity and recovery directory. The installed `~/Applications/medit-.app` remains unchanged. This local development build is not notarized and does not require a signing account.

For a normal development build using the medit- identity:

```sh
xcodebuild -project medit-.xcodeproj -scheme medit- \
  -configuration Debug -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
open build/Build/Products/Debug/medit-.app
```

That normal build shares the existing medit- preferences and recovery data. Use the review build for isolated testing.

## Rectangular selection and column copy/cut/paste

Hold **Option** and drag with the **left mouse button** across the text to select a rectangle.

- **Command+C** copies the selected columns, with one clipboard row per selected line.
- **Command+X** cuts the selected columns while preserving document line breaks.
- **Command+V** pastes across the selected rows. One pasted line repeats on every row; multiline text must contain one line per selected row.
- Typing replaces the selection on each row. Short and blank rows are padded when inserting beyond their ends.
- **Command+Z** undoes a block edit in one step.
- **Esc** or a normal left click leaves rectangular selection.

Without a rectangle, paste behaves normally. Use a monospace font for predictable column alignment. Lines do not wrap. Wide Unicode characters and selections through the middle of tab characters have not been exhaustively tested.

## Directory browser and workspaces

Use **Open…** to choose files or a folder; files open as tabs and an existing tab is selected rather than duplicated. Open Recent distinguishes files and folders. Expand folders with their disclosure arrows and double-click a file to open it. The toolbar sidebar button and sidebar × control show or hide the browser without closing documents. Resize it using the divider; Refresh reloads the tree. Directory symlinks are not expanded recursively.

Right-click a sidebar file for **Rename…** or **Delete…**. Rename keeps unsaved edits and updates the tab and recovery references. Delete asks for confirmation before moving the file to Trash; open copies become unsaved documents so their text remains recoverable. Cancelling or a Trash failure leaves the file intact. These commands apply to files, not folders.

Folder sessions remember tabs, order, pins, colors, tab settings, active document, cursor/selection, scrolling and sidebar state. Switching folders preserves the outgoing session; **Close Folder** returns to documents opened without a folder. Each window has independent recovery, and open windows return on the next launch. Session files are kept in application data, not in the folder being edited.

Git badges occupy a persistent column at the far right: **M** modified, **A** added, **D** deleted, **R** renamed, **C** copied, **T** type changed, **?** untracked and **!** conflict. Folder badges summarize changes beneath them. Preferences → Editing → Show Git status in sidebar controls visibility and scanning. Status refreshes in the background, after saves, on Refresh and when returning to the app. Git status describes files on disk and never stages, commits or writes the index.

## Preferences, colors and Welcome

**Command+,** opens Preferences, with Fonts, Editing, Appearance and Spelling sections. Interface and editor fonts and sizes are independent. Bottom controls change the current document's language, tab width, spaces and spelling; Editing preferences set defaults for new documents. Choosing spaces affects new Tab insertions, not existing text.

Right-click a tab for **Tab Color…** or **Use Default Color**. Appearance sets default active/inactive colors and displays their hex values on matching backgrounds. macOS supplies the color picker. Colors survive recovery. Drag tabs to reorder them; pinned tabs stay at the left, and unpinned tabs cannot move before the pinned group.

Welcome opens pinned by default. Unpinning it closes the tab and unchecks **Preferences → Appearance → Show Welcome on startup**. Unchecking that preference also removes Welcome and prevents session recovery from reopening it. Welcome remains editable; dismissed edits are retained in closed-tab recovery. Other documents are unaffected.

Syntax highlighting follows the file extension or the selected language and can be disabled under Editing. HighlighterSwift supplies parsing; temporary foreground colors do not change the document's text or selected font. Swift, Bash and Markdown are useful starting points; plain text remains uncolored.

A single left-click on an underlined misspelling offers corrections and **× Ignore**. Ignore belongs only to that document, including its recovered session. Spell checking skips shell commands and Markdown code fences; Bash comments and prose can be checked.

## Recovery and closing

By default, closing or quitting preserves unsaved text without asking to save. Enable the optional closing prompt for **Save / Keep Recovery / Cancel**. Explicitly closed unsaved tabs are archived; reopen them through the application menu's **Restore Closed Tab…** command. Archives are local and are not automatically deleted.

Recovery snapshots are written atomically on edits and periodically, with a previous snapshot retained. Corrupt snapshots are preserved and the previous copy is used when available. Recovery preserves edits without writing them to original documents. Clean saved tabs reload disk contents; modified tabs restore recovery contents, and saving warns if the original changed externally. Missing folders report an error without discarding documents.

Normal medit- recovery lives in `~/Library/Application Support/medit-/`. The separate review build uses `~/Library/Application Support/medit-next-review/` and independent preferences. Recovery and archives are local, unencrypted text. A sudden shutdown can lose edits made after the most recent snapshot.

UTF-8, UTF-16, Windows-1252 and Mac Roman are among the detected encodings. Existing files retain their detected encoding when saved; new files and Save As use UTF-8. Existing newline contents are preserved. Ambiguous encoding detection can differ from Fedora. Binary files are not supported.

## Validation

For the separate review build:

```sh
build/review-next/Build/Products/Release/medit-.app/Contents/MacOS/medit- --self-test
```

The current executable checks cover Unicode recovery, modified originals, closed-tab archives, corrupt snapshot fallback, folder sessions, pinned tabs, colors, spelling, highlighting, Git status, block replacement, repeated column typing, multiline block paste, short-row padding and Welcome behavior. The current review build passes 136 checks. Option-drag geometry and complex Unicode column alignment still benefit from hands-on testing.

Use `--session-directory /tmp/medit-review` to isolate recovery for a test run. `--preview /tmp/medit.png` captures the application's own content and exits.

## Source and dependencies

This is an independent AppKit implementation, rather than a patch to upstream gedit. HighlighterSwift is pinned to 3.1.0; dependencies retain their respective license terms. Build output, local preferences, recovery fixtures and backups are excluded from Git.

Application sources are under `medit-/`: `main.swift` handles the window and lifecycle, `Session.swift` documents and recovery, `BlockTextView.swift` rectangular editing, `Workspace.swift` the folder browser, and `SelfTests.swift` executable checks. [Examples/Welcome.swift](Examples/Welcome.swift) is bundled with the application.

## Repositories

Source: [GitHub](https://github.com/greenfinch628/medit-) and [Scopuli Gitea](http://scopuli:3000/scopuli/medit-). Development branch: `main`; remotes are `github` for GitHub and `origin` for Gitea.

Related projects: [gedit- for Fedora](https://github.com/greenfinch628/gedit-) and [gedit-legacy](https://github.com/greenfinch628/gedit-legacy).

## Binary packages

The current review application is built locally with Xcode. No notarized public installer is provided by this workflow. Fedora RPM and Ubuntu DEB packaging belongs to the separate gedit- project; legacy packages do not contain these new editors.
