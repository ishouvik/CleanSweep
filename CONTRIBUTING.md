# Contributing to CleanSweep

Thank you for helping improve CleanSweep. Filesystem cleanup software has an unusually high cost of mistakes, so contributions are reviewed with safety, recoverability, and explainability as primary requirements.

## Before starting

For substantial behavior changes, open an issue describing the use case, proposed allowlist boundaries, failure modes, and tests. Small documentation corrections may go directly to a pull request.

By submitting a contribution, you agree that it is licensed under the repository's Apache License 2.0.

## Development setup

1. Install macOS 14 or later and Xcode or compatible Command Line Tools with Swift 6.
2. Fork and clone the repository.
3. Create a focused branch from `main`:

   ```sh
   git switch -c feat/short-description
   ```

4. Build and validate:

   ```sh
   ./scripts/test.sh
   ```

5. Launch the local app without performing deletion tests against real data:

   ```sh
   ./scripts/build-app.sh
   open dist/CleanSweep.app
   ```

## Safety requirements

- A scanner must be read-only.
- Every destructive target must be visible before confirmation.
- New generic targets must be constrained to exact, documented paths beneath an injected home directory.
- Never add broad recursive name matching for application removal.
- Never bypass macOS privacy or container protection.
- Tests must use disposable temporary fixtures; do not delete real user caches in tests.
- Preserve selection semantics: unchecked candidates remain untouched.
- Report partial failure per path and continue safely where possible.
- Application removal remains recoverable through Trash.

## Code style

- Prefer Foundation, AppKit, and SwiftUI over additional dependencies.
- Keep filesystem policy separate from presentation.
- Use semantic Material design tokens instead of literal colors or spacing in screens.
- Keep functions small, make injected dependencies explicit, and return structured errors.
- Treat compiler warnings as defects.

## Tests

Follow the pyramid in [docs/TESTING.md](docs/TESTING.md). Add multiple fast unit cases for each new policy rule, integration coverage for filesystem behavior, and an end-to-end smoke assertion only when packaging or launch behavior changes.

## Commits and pull requests

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` new user-facing behavior
- `fix:` corrected behavior
- `test:` test-only work
- `docs:` documentation-only work
- `refactor:` internal restructuring
- `build:` build or CI changes
- `chore:` maintenance

Pull requests should explain the risk boundary, tests performed, screenshots for UI changes, and any known limitations. Keep unrelated changes out of the same pull request.
