# Security Policy

## Supported versions

Security fixes are applied to the latest release and the `main` branch.

## Reporting a vulnerability

Do not open a public issue for a vulnerability that could cause unintended deletion, path traversal, privilege escalation, or disclosure of user data. Use GitHub's private vulnerability reporting feature on this repository. Include reproduction steps, affected paths, macOS version, and the expected safety boundary.

Please allow maintainers reasonable time to investigate before public disclosure. Reports will be acknowledged as soon as practicable, assessed for severity, and coordinated toward a fix and advisory.

## Security boundaries

CleanSweep does not request or bypass administrator privileges. macOS may require Full Disk Access for protected user containers. Users should grant it only after understanding the implications. The application intentionally rejects `/System`, filesystem root, and home-directory deletion targets.
