# Samridhi — rules for every coding agent

Local-first wealth, asset and investment planning system. Reads the
user's financial status from **Artha** (never writes back to Artha's
ledger) and builds a dynamic, risk-aware, diversified investment plan,
with optional BYO-AI agents on top of a quantitative core that works with
no AI configured at all.

This file is the single source of project rules for every agent and tool
(Claude Code, Codex CLI, Gemini CLI, OpenCode, Cursor, Aider, local
models). A `CLAUDE.md`, if added, imports this file and adds only
Claude-Code-specific detail — never duplicate rules there.

Full plan: `docs/plan/2026-11-05-samridhi-plan.md` (v1, baseline).
Amendments: `docs/plan/YYYY-MM-DD-*.md`, newest wins; index with phase
placement: `docs/plan/INDEX.md`.

## Session protocol (any agent, any tool)

* **Start:** read this file, the newest plan doc, `docs/plan/INDEX.md` and
  the newest `*-handover.md` if one exists.
* **Before multi-step work:** post a short plan and wait for approval.
* **End:** update the handover, commit (small commits), run
  `flutter analyze && flutter test` before every commit.
* **One writer at a time** once a second agent/tool is in play — branch
  per agent/tool (`claude/topic`, `codex/topic`), PRs with CI green before
  merge.

## Rules

* Samridhi reads Artha's data; it never writes to Artha's database or
  ledger. Any two-way sync idea needs explicit user approval first.
* No live trade, transfer or order execution of any kind without an
  explicit user "yes" at the moment of the action — the orchestrator agent
  never auto-executes.
* AI/agents are opt-in and BYO (local endpoint or the user's own cloud API
  key, kept in the OS keychain/secure storage). No bundled model, no
  hardcoded key, no telemetry to a third party by default.
* Agents receive only rounded/derived figures, never raw account numbers,
  names or identifiers.
* Every forecast or AI-generated suggestion is shown with its confidence/
  track record and a "this is a model, not advice" disclosure — never
  presented as certain.
* Public-repo scrub: no private financial figures, API keys, tokens or
  real holdings in commits, issues, docs or screenshots. Sample/synthetic
  data only in the repo (mirrors Artha's `screenshots_test.dart` pattern).
* Before deleting/overwriting/renaming any existing file: show the change,
  wait for yes. Reads are free.
* New docs/reports: `YYYY-MM-DD-descriptive-name.md`. End each task
  listing files created or changed.
* Done = test or runtime evidence recorded in the task's report. A mock
  is not a feature.
* Secrets only in the OS keychain/Credential Manager, never in files,
  logs, commits or chat.
* No installs, pushes, tags, releases or GitHub issue creation without
  asking first, unless the user has given a standing approval rule for
  that action (recorded here when they do).

## Tech stack (matches Artha / Brahma suite)

* Flutter + `brahma_core` (shared design system), Riverpod.
* `drift` over SQLite3MultipleCiphers for the encrypted local DB.
* Self-hosted PocketBase for optional E2E-encrypted cross-device sync
  (separate collections from Artha's; same server can host both).
* Targets: Windows, Linux, Android.
