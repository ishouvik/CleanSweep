# Testing Strategy

CleanSweep follows the Google test-pyramid principle: many fast, isolated tests at the base; fewer filesystem integrations in the middle; and a very small number of expensive whole-artifact checks at the top. The goal is not a particular percentage but fast diagnosis, realistic boundary coverage, and minimal brittle UI automation.

```text
                 ┌────────────────────┐
                 │ End-to-end smoke   │  Few: packaged artifact
                 └─────────┬──────────┘
                    ┌──────┴──────┐
                    │ Integration │     Some: temporary filesystem
                    └──────┬──────┘
               ┌───────────┴───────────┐
               │      Unit tests       │  Many: policy and models
               └───────────────────────┘
```

## Unit layer

Runner: `Tests/Unit/UnitTestRunner.swift`

The unit layer verifies:

- negative byte counts are safely formatted;
- candidates default to selected and derive safe display names;
- `/System` applications are rejected;
- malformed bundles without identifiers are rejected;
- semantic version comparison retains `1.10.0` over `1.2.9`;
- only obsolete VS Code extension directories become candidates.

These tests do not mutate user data. Extension manifests live under a unique temporary directory.

## Integration layer

Runner: `Tests/Integration/IntegrationTestRunner.swift`

The integration layer creates a disposable home-directory tree and verifies:

- known npm cache discovery;
- stale-log size and age thresholds;
- preservation of recent logs;
- deletion of selected allowlisted cache files;
- preservation of unchecked candidates;
- rejection and preservation of paths outside the allowlist;
- exact application bundle and associated-cache discovery.

Production objects receive the temporary home directory through dependency injection. Tests never redirect or clean the real home directory.

## End-to-end smoke layer

Runner: `scripts/run-e2e-smoke.sh`

The smoke layer builds the release application and verifies:

- the executable is present and executable;
- bundle identifier and package type are correct;
- the bundle has a valid ad-hoc signature;
- the executable is a 64-bit Mach-O binary.

It intentionally does not automate destructive clicks or empty Trash. UI behavior should be assessed manually with disposable fixtures until a macOS UI harness can guarantee isolation.

## Running tests

All layers:

```sh
./scripts/test.sh
```

Swift unit and integration layers only:

```sh
./scripts/run-swift-tests.sh
```

Packaging smoke only:

```sh
./scripts/run-e2e-smoke.sh
```

## Adding tests

Put deterministic policy logic at the unit layer. Use integration tests when Foundation filesystem behavior matters. Add an end-to-end assertion only for a contract observable from the final `.app`. Every regression fix should first add a failing test at the lowest layer capable of reproducing it.
