# Status summary — 2026-11-05

Sole writer on `main`. Gate: `flutter analyze && flutter test` — analyze
clean, **124/124 tests** at the time of writing. Detail per phase is in
`2026-11-05-handover.md`; the post-P6 items are in
`2026-11-05-post-p6-v2-backlog.md`.

## Shipped, with evidence

| Area | What | Evidence |
|---|---|---|
| P1 | Holdings, goals, risk questionnaire, MVO target allocation, plan UI | `core/plan_test`, `core/engine_test`, widget tests (empty state, saved answers -> plan + disclosure) |
| P2 | Drift-band + cash-flow rebalancing, SES forecast with band and track record, synthetic-data backtest | `core/rebalance_test` (17), Insights widget test |
| P3 | PocketBase server + migration, Argon2id/XChaCha20 vault, snapshot sync with optimistic concurrency, encrypted backup, self-hosting guide | `sync/sync_test` (14); `sync/pocketbase_transport_test` (5, added in this review: conflict mapping, request body, URL policy, via a mock HTTP client) |
| P4 | BYO LLM clients (key in OS keychain), digest of rounded figures only, deterministic agents, orchestrator, narrator; accept = log intent only | `agents/agents_test` (19), agents-tab widget tests |
| P5 | PIN/biometric lock, issue-report URL, updater with SHA256 verify + rollback, Sentinel (Windows, optional), motion | `security/*`, `update/update_test` (17), `support/issue_report_test`, lock-gate and reduced-motion widget tests |
| P6 | release.yml, Linux/Windows installers, Android build | `workflow_dispatch` run 42023706194: test, version, windows, android, linux green; `bash -n` on scripts |
| Post-P6 | Behavioural nudge, risk tiers 1-7, read-only holdings import, opt-in FLAG_SECURE + root hint, direct-indexing simulator (synthetic) | unit tests per item (`holdings_import_test`, `direct_indexing_test`, `device_security_test`, `plan_test`, `agents_test`) |

## Review pass (this run)

* Read the lib/test layout and mapped each non-generated lib file to a test.
  All logic modules (`core/`, `agents/`, `ai/`, `security/`, `sync/`,
  `update/`, `support/`) are referenced by tests; the untested files are UI
  and platform glue.
* Fixed: `PocketBaseTransport` had no tests; its mapping of the unique-index
  rejection to `SyncConflict` is what stops two devices overwriting each
  other. `signIn` gained an optional `httpClientFactory` so a mock server can
  be injected (no behaviour change by default).
* Added: Settings-page render test (every section builds and scrolls without
  an exception, secure-storage channel stubbed).
* Checked against AGENTS.md: the disclosure banner is on Plan, Insights and
  Agents; no key-shaped strings in `lib/`, `test/` or `docs/`; no code path
  opens Artha's database.
* No TODO/FIXME markers in `lib/` or `test/`.

## Genuinely unverified

* Installing the built APK or Windows installer on a real device.
* Release signing with a real keystore (secrets not available; builds fall
  back to the debug key).
* Linux installer concurrency test (needs `flock`; not on Windows).
* Live push/pull against a running PocketBase server (only the mock-HTTP
  transport test exists).
* A real call to Ollama or a cloud LLM (tests use `MockClient`).
* End-to-end in-app update from a published release; rollback across a DB
  schema change is not automatic (UI tells users to back up first).
* Windows Hello / fingerprint prompts; Sentinel handshake against a live
  service.
* Kotlin `MainActivity` channel (FLAG_SECURE, root row) has only compiled in
  CI; it has not run on a device.
* Most Settings sections (sync, backup, import, updates) have a render smoke
  test only, not interaction tests.

## What I'd build next, in order

1. Artha-side exporter for `samridhi-holdings-v1` (Artha repo; needs your go-ahead to touch it).
2. A device pass: install the APK and the Windows installer, exercise lock,
   FLAG_SECURE, backup/restore and update on real hardware.
3. Live-server test: run `scripts/run-local-server.sh`, push/pull between two
   instances, and record it in the handover.
4. Interaction tests for the sync, backup and import sections.
5. Cost/tax-aware backtest and a second forecasting model (the SES stub is
   close to a mean estimate).
6. Real keystore signing via repo secrets, then a first tagged release.

## Files created or changed in this review

* `lib/sync/pocketbase_transport.dart` (optional HTTP client factory)
* `test/sync/pocketbase_transport_test.dart` (new)
* `test/widget_test.dart` (Settings render test)
* `docs/plan/2026-11-05-status-summary.md` (new), `docs/plan/INDEX.md`
