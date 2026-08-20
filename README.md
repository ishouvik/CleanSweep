# CleanSweep

[![CI](https://github.com/ishouvik/CleanSweet/actions/workflows/ci.yml/badge.svg)](https://github.com/ishouvik/CleanSweet/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-black.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-orange.svg)](https://www.swift.org/)

CleanSweep is a native, scan-first macOS cleanup utility. It finds a conservative set of regenerable caches and stale files, or safely prepares an application and its exact associated files for removal. Nothing changes until the user reviews the paths, sees the risks, and confirms.

> The GitHub repository is named **CleanSweet**. The application, executable, and Swift target are named **CleanSweep**.

## Features

- Conservative generic scanning for known package caches, temporary downloads, updater residue, stale logs, and obsolete VS Code extensions.
- Drag-and-drop `.app` selection.
- Exact bundle-identifier and exact application-name matching for associated files.
- Full path, explanation, category, size, and selection state for every candidate.
- Visible danger guidance and a second explicit confirmation.
- Progress, current-path reporting, cooperative cancellation, and structured partial errors.
- Graceful quit request before application removal.
- Recoverable application removal through macOS Trash.
- Immediate freed-space reporting for cache deletion and separate moved-to-Trash totals.
- Native dependency-free Material-inspired SwiftUI design system.
- Unit, filesystem integration, and packaged-app smoke tests.

## Safety model

CleanSweep treats safety policy as part of the product, not an implementation detail:

1. Scanning is read-only.
2. The user reviews every candidate.
3. The interface explains consequences before enabling confirmation.
4. The executor resolves symlinks and revalidates every path.
5. Root, the home directory itself, and `/System` are prohibited.
6. Generic cleanup is restricted to explicit home-directory allowlists.
7. Application discovery avoids fuzzy global filename searches.
8. Applications go to Trash; generic regenerable caches are permanently removed.
9. macOS permission failures are reported rather than bypassed.

CleanSweep does **not** clean AWS sessions, active Codex cache, arbitrary macOS service caches, project artifacts, installed packages, toolchains, or personal documents through its generic scan.

## Generic cleanup coverage

| Category | Examples | Consequence |
|---|---|---|
| Package caches | npm, Homebrew, uv, Sentry CLI, Hugging Face | Downloads may recur; tools may start more slowly once |
| Temporary downloads | npx packages | A later command may download the package again |
| Updater residue | VS Code, Google Updater | Updaters may recreate their working data |
| Microsoft Teams cache | Teams cache directory | Teams may rebuild cache on next launch |
| Stale logs | Files over 1 MB, unchanged for seven days | Diagnostic history is permanently lost |
| VS Code extensions | Versions superseded according to `package.json` | Only the newest installed version is retained |

## Requirements

- macOS 14 or later
- Swift 6-compatible Xcode or Command Line Tools
- Apple silicon or Intel Mac for source builds

No external Swift dependencies are required.

## Clone and build

```sh
git clone git@github.com:ishouvik/CleanSweet.git
cd CleanSweet
./scripts/test.sh
./scripts/build-app.sh
```

The packaged application is written to:

```text
dist/CleanSweep.app
```

Launch it with:

```sh
open dist/CleanSweep.app
```

Alternatively, run directly through Swift Package Manager:

```sh
swift run --disable-sandbox CleanSweep
```

See [Build and Development Guide](docs/DEVELOPMENT.md) for Xcode, toolchain compatibility, packaging, signing, and notarization details.

## Usage

### Generic cleanup

1. Select **Clean Caches**.
2. Press **Scan Mac**. This makes no changes.
3. Review every candidate and uncheck anything you want to retain.
4. Read the risk banner.
5. Press **Review and confirm**.
6. Verify the count and size, then press **Confirm Permanent Cleanup**, or cancel.
7. Monitor progress and review freed space or per-path errors.

### Remove an application

1. Select **Uninstall App**.
2. Drag a `.app` into the drop surface or use **Choose Application…**.
3. Review the application and exact associated-file matches.
4. Uncheck any support data you want to preserve.
5. Press **Review and confirm**, then **Confirm Move to Trash**.
6. Inspect the result before deciding whether to empty Trash.

Moving items to Trash does not free disk capacity immediately. CleanSweep reports those bytes separately from space freed by permanent cache deletion.

## Permissions

Ordinary user-owned files need no administrator access. macOS may deny protected containers. If you grant Full Disk Access under **System Settings → Privacy & Security**, understand that this substantially increases the application's filesystem reach. CleanSweep never invokes `sudo` or changes permissions automatically.

## Architecture

The SwiftUI presentation layer delegates to `CleanSweepViewModel`, which coordinates a read-only `CleanupScanner` and a separately validating `CleanupExecutor`. See [Architecture](docs/ARCHITECTURE.md) for the state flow, trust boundaries, and extension rules.

## Testing

The project follows the Google test pyramid:

- Many fast policy/model unit assertions.
- Fewer temporary-filesystem integration cases.
- A small final `.app` packaging smoke layer.

Run every layer:

```sh
./scripts/test.sh
```

See [Testing Strategy](docs/TESTING.md) for the cases, isolation model, commands, and contribution expectations.

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) first. Cleanup rules must remain explainable, narrowly scoped, testable with disposable fixtures, and independently revalidated before mutation.

Commits follow [Conventional Commits](https://www.conventionalcommits.org/). See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

Copyright 2026 Shouvik Mukherjee.

CleanSweep is open-source software under the [Apache License 2.0](LICENSE). It may be used, modified, and distributed for personal or commercial purposes subject to that license's terms. The license includes an explicit patent grant and warranty/liability disclaimer.
