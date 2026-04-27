# Security Policy

## Supported Releases

For production use, the supported release line is:

- the latest tagged GitHub release

Older tags may continue to work, but fixes and rollout guidance are expected to land on the newest public release first.

## Reporting a Vulnerability

Do not open a public issue for a suspected security vulnerability before maintainers have had a chance to assess it.

Preferred order:

1. Use GitHub's private vulnerability reporting for this repository if it is enabled.
2. If private reporting is unavailable, contact the maintainers out of band and include:
   - affected version or commit
   - impact summary
   - reproduction steps
   - any proposed mitigation

## Release Trust Model

Production installs should prefer tagged releases over branch builds.

Each public release is expected to ship:

- `install.sh`
- `verify-release.sh`
- `SHA256SUMS`
- platform release tarballs

Operators should verify the published `SHA256SUMS` before rollout, and should treat branch-head builds as development artifacts rather than production artifacts.
