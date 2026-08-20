# Build and Development Guide

## Requirements

- macOS 14 or later
- Swift 6-compatible Xcode or Command Line Tools
- Apple silicon or Intel Mac for source builds
- Git for contribution workflows

No third-party Swift packages are used.

## Clone

```sh
git clone git@github.com:ishouvik/CleanSweet.git
cd CleanSweet
```

The repository is named `CleanSweet`; the product and executable are named `CleanSweep`.

## Development build

```sh
swift build --disable-sandbox
```

On the original development machine, the default Command Line Tools SDK and compiler versions differ. The checked-in scripts select the compatible installed macOS 15.4 SDK when present. A normal matching Xcode installation does not need this workaround.

## Run from Swift Package Manager

```sh
swift run --disable-sandbox CleanSweep
```

## Build the application bundle

```sh
./scripts/build-app.sh
open dist/CleanSweep.app
```

The script creates a release binary, assembles `Contents/MacOS` and `Contents/Resources`, copies `Info.plist`, and applies an ad-hoc local signature. The resulting bundle is intended for local development.

## Validate everything

```sh
./scripts/test.sh
```

This builds the package, runs unit and integration binaries against temporary fixtures, parses every Swift source, validates shell and plist files, builds the release `.app`, and runs packaging smoke checks.

## Xcode

```sh
open Package.swift
```

Choose the `CleanSweep` scheme and My Mac destination. Xcode previews are optional; the production interface uses ordinary SwiftUI composition.

## Distribution

The local build is ad-hoc signed. Public binary distribution requires:

1. An Apple Developer ID Application certificate.
2. Hardened Runtime signing.
3. A notarization submission using `notarytool`.
4. Stapling the notarization ticket.
5. Release checksums and a signed Git tag.

Do not distribute an ad-hoc build as though it were notarized.

## Debugging permissions

macOS privacy controls may reject protected containers. This is expected behavior. Reproduce with a disposable application fixture where possible and preserve the error returned by Foundation. Never work around a failure by broadly changing permissions in application code.
