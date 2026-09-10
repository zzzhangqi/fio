# Linux static fio packages

The **Linux static binaries** workflow builds the pinned official fio 3.42
source commit on native amd64 and arm64 GitHub runners, with the official upstream
[musl compatibility fix](https://github.com/axboe/fio/commit/a84eece62edd46c1f4c8047f1052ac6181fc8b3e)
backported (one redundant header include removed). It uses a digest-pinned
Alpine 3.22.1 container and musl static linking, with native CPU tuning disabled.
The existing upstream CI is independent of this packaging workflow.

## Build and download

After merging the workflow into the default branch, open **Actions → Linux static
binaries → Run workflow**. Leave `release_tag` empty to build artifacts only.
Download the `fio-linux-static` artifact from the completed run. It contains:

- `fio-linux-amd64.tar.gz`
- `fio-linux-arm64.tar.gz`
- `fio-source.tar.gz` (the matching source with the upstream fix applied)
- `SHA256SUMS`

Each binary archive includes `fio`, `COPYING`, the upstream compatibility patch,
`BUILDINFO.txt`, `config.log`, and
`sync-smoke.json`. Check downloads with `sha256sum -c SHA256SUMS` on Linux before
embedding the executable in an installer. Preserve the corresponding source and
license with distributed releases.

To prepare a release, run manually with a new tag such as `static-fio-3.42-1`.
Both architectures must pass before the workflow creates a **draft** release.
Review and publish the draft in GitHub Releases. Existing releases are not
overwritten; use a new tag for each packaging revision.

## Validation and upgrades

The workflow runs upstream `make test`, rejects ELF interpreter/shared-library
dependencies, and executes the resulting musl binary on Ubuntu outside Alpine.
A bounded synchronous-write test checks successful I/O and valid `fdatasync` P99
JSON statistics. Runner disk speed is informational and never a release gate.
These tests do not replace validation on the installer's supported Linux systems.

To upgrade, change `FIO_SOURCE_COMMIT` to a reviewed official release commit and
update this document. Remove the backport and its metadata when upgrading to a
release that already contains it. The packaging scripts are checked out separately.
To update the builder, change its version
and multi-platform digest together. Installed Alpine package versions are recorded
in `BUILDINFO.txt`; package repositories can change, so identical binary hashes
across rebuilds are not guaranteed. Pin release artifacts by their checksums.
