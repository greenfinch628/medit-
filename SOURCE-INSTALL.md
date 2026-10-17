# Build and install nex-editm from source

## Prerequisites

macOS 13 or later, full Xcode with Swift 5.9 or later, and Python 3. The first build downloads the pinned HighlighterSwift dependency.

Open Xcode once and complete its first-launch setup. Command Line Tools alone
are not sufficient. Check `xcodebuild -version`; if it points to the wrong tools,
select your Xcode installation (for the usual location):

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

No paid Apple Developer account is needed. The resulting app is locally
ad-hoc signed for this Mac, rather than a notarized download for distribution.
Internet access is required to clone and resolve build dependencies.

## Clone, build, and install

Clone from either host, then run the same installer:

```sh
git clone https://github.com/greenfinch628/nex-editm.git
cd nex-editm
python3 scripts/build-and-install.py --test
```

Or replace the clone command with Gitea (requires access to Scopuli and a
configured SSH key):

```sh
git clone ssh://git@scopuli:2224/scopuli/nex-editm.git
```

The installer builds from this checkout, runs the existing app tests when
`--test` is supplied, verifies the local signature, and installs
`~/Applications/nex-editm.app`. Open that app in Finder. It does not launch the app
automatically or change preferences, recovery data, or configuration files.
Tests may exercise app preferences; use a separate macOS test account when
checking a clean installation.

Quit the installed app before upgrading. An existing app with the expected
bundle identity is retained as a timestamped `.app.backup` beside the new app.
An unrelated app or symbolic link is never replaced. The installer stages the
new app before replacing the old one and restores the backup if replacement
fails. The backup can be restored manually while the app is closed.

To build without installing:

```sh
python3 scripts/build-and-install.py --build-only --test
```

For a different install folder, add `--install-dir /absolute/path`. The default
per-user location needs no administrator privileges. Omit `--test` to skip the
existing tests, for example after the same checkout has already been validated.

## Update and rebuild

From your existing clone, after quitting the app:

```sh
git pull --ff-only
python3 scripts/build-and-install.py --test
```

Use a clean checkout or commit your own changes before updating. Keep only one
daily-use app copy to avoid selecting an older build from app search.

## Test directly on a Mac

Use a separate macOS test account to avoid existing preferences and recovery
masking first-run problems. Starting with the prerequisites above, clone into
a new folder, build with `--test`, open the installed app, and verify editing or
terminal input, tab colors, closing/reopening, and saved-session restoration.
Then rebuild to check that the prior app is backed up and settings are retained.

Validated on Miller on 2026-10-17: Xcode build, existing tests, local signature verification, and installation in `~/Applications` completed successfully. nex-editm passed all 157 executable self-tests.


## Continuing development on Miller

Use `~/XcodeProjects/nex-editm` as the development checkout and the app in
`~/Applications` for everyday use. `origin` points to GitHub and `gitea` to
Scopuli Gitea; `main` tracks `origin/main`. Miller has SSH access to both.

Before work, fetch both remotes and check their main branches agree:

```sh
git fetch origin
git fetch gitea
git status -sb
git rev-parse origin/main gitea/main
git pull --ff-only
```

Before committing and pushing, update `CHANGELOG.md` with an ISO 8601 UTC
timestamp and a categorized description. Build and test on Miller, then commit
the change and changelog together. Publish to both hosts:

```sh
git push origin main
git push gitea main
git ls-remote origin refs/heads/main
git ls-remote gitea refs/heads/main
```

Verify the hashes agree. Push release tags and any release artifacts to both
hosts when creating a release. Never push custom changes to `upstream`.
