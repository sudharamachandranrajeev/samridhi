# Changelog

The release workflow publishes the section whose heading contains the tag's
version as the GitHub release notes.

## 0.1.0-alpha.1

First tagged build, for trying the release pipeline and the scaffold. Not
financial advice: the plan engine is a model with illustrative assumptions.

- Flutter app for Windows, Linux and Android on the Brahma core.
- Release workflow: Android APK, Windows installer and portable zip, Linux
  tarball with a user-local installer, `SHA256SUMS.txt`.
- Plan engine, rebalancing bands and cash-flow rebalancing, forecast and
  synthetic backtest (Insights), deterministic agents with an accept-only log.
- Optional BYO AI narration over anonymised, rounded figures.
- Encrypted backup/restore and optional snapshot sync over a self-hosted
  PocketBase server (see docs/self-hosting.md).
- App lock (PIN with rate limiting, optional biometrics), security status,
  in-app updater with checksum verification and rollback.
