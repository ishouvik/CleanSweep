# Architecture

## Overview

CleanSweep is a local macOS application. It has no server component, analytics, account system, or external runtime dependency.

```text
SwiftUI views
    │ user intent and rendered state
    ▼
CleanSweepViewModel (@MainActor)
    ├── CleanupScanner ── read-only filesystem discovery
    └── CleanupExecutor ─ validated deletion or Trash movement
                              │
                              ▼
                    Foundation / AppKit filesystem APIs
```

## Components

### Presentation

`ContentView.swift` composes the scan, review, warning, confirmation, progress, and result states. `MaterialDesignSystem.swift` contains semantic tokens and reusable components. The UI never discovers or removes files directly.

### State coordination

`CleanSweepViewModel` owns the visible candidates and the scan/execution state machine. UI-facing updates are main-actor isolated. Scanning occurs away from the main actor so large directory walks do not freeze the window.

### Discovery

`CleanupScanner` produces immutable candidate metadata: exact URL, category, explanation, allocated size, and selection default. Generic scanning uses an explicit allowlist and quantitative stale-log rules. Application scanning resolves a bundle identifier and exact application name. It does not use fuzzy global search.

### Execution

`CleanupExecutor` revalidates every path immediately before mutation. Generic cleanup permanently removes confirmed regenerable data. Application removal requests graceful termination and moves confirmed targets to Trash. Each failed target produces a structured `CleanupFailure`; one failure does not hide the rest of the result.

### Reporting

Generic removals contribute to `freedBytes`. Trashed applications contribute to `movedToTrashBytes`, because capacity is not released until Trash is emptied. The UI communicates this distinction explicitly.

## Trust boundaries

- The scan result is untrusted by the executor and is revalidated.
- Symlinks are resolved before allowlist checks.
- `/`, the home directory itself, and `/System` are prohibited.
- Tests inject a disposable home directory to prove policy without touching user data.
- The application does not invoke `sudo`, weaken permissions, or silently force-quit software.

## Extending cleanup categories

Add a scanner rule, a category/explanation, an executor allowlist boundary if required, several unit cases, a filesystem integration case, and UI wording explaining consequences. A path should not be added merely because it is large.
