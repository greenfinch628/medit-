# Change tracking and repositories

For every future user-visible change, add a short entry to CHANGELOG.md under
its application/version heading. Use an ISO 8601 UTC timestamp and a Keep a
Changelog category, for example:

`- 2026-10-15T21:00:00Z — Fixed: Short description of the change.`

Use Added, Changed, Deprecated, Removed, Fixed, or Security as appropriate.
Create a new application/version heading for each release. The initial baseline
contains only the current heading; baseline preparation is intentionally omitted.
Package-manager changelogs retain their required native formats and history.

All source commits, branches, release tags, packaging recipes, and release
artifacts must be synchronized to both GitHub and Scopuli Gitea. A release is
complete only after both destinations have been verified. Do not push to upstream.
