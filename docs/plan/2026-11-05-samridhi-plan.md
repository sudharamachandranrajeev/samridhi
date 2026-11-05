# Samridhi — build plan v1 (2026-11-05)

Samridhi ("prosperity") is a local-first wealth, asset and investment planning
system that reads the user's financial status from **Artha** (the Brahma
suite's ledger) and turns it into a dynamic, risk-aware, diversified
investment plan — in the style of the better robo-advisors (Betterment,
Wealthfront, Vanguard Personal Advisor, Schwab Intelligent Portfolios), but
self-hosted and under the user's own control.

This is v1: enough to run end to end on real (or sample) data, hostable by
the user, extensible. The user will review this first build and ask for
improvements next.

## 1. Where it sits in the Brahma suite

* Same stack as Artha: Flutter + `brahma_core` (shared design system/data
  conventions), Riverpod, `drift` over SQLite3MultipleCiphers (encrypted
  local DB), self-hosted PocketBase for E2E-encrypted cross-device sync.
* Samridhi does **not** duplicate Artha's ledger. It reads Artha's accounts,
  balances, transactions and existing investment holdings through either:
  1. a local read-only link (same-device: shared encrypted DB export /
     local IPC), or
  2. the same PocketBase sync server, as a second E2E-encrypted collection
     set Artha already writes to — Samridhi subscribes, never writes back
     to Artha's ledger.
* Artha keeps owning "what happened" (accounts, transactions, existing
  portfolio). Samridhi owns "what should happen next" (plan, risk,
  forecasts, rebalancing suggestions).

## 2. Core engine — how the plan gets built

Modelled on published robo-advisor methodology (Betterment/Wealthfront/
Schwab whitepapers, academic mean-variance literature):

1. **Risk profiling** — a short questionnaire (time horizon, loss tolerance,
   income stability, goals) plus observed behaviour (did the user panic-sell
   last drawdown?) produces a risk score and a set of per-goal sub-portfolios
   (retirement, house deposit, rainy-day, general) — goals-based like
   Betterment, not just one aggregate portfolio.
2. **Asset allocation** — mean-variance optimisation (Markowitz efficient
   frontier) with a Black-Litterman-style blend of market-implied returns
   and the forecasting agent's own view, constrained so allocations stay
   sane (no 100% in one asset class, UK ISA/pension wrapper limits respected).
3. **Instrument selection** — prefers low-cost diversified index
   funds/ETFs for the core (matching the academic consensus that passive,
   low-turnover, low-fee investing wins net of fees/tax most of the time);
   mutual funds and direct stock/trading positions are selectable for users
   who want to self-direct a satellite portion.
4. **Monitoring & rebalancing** — threshold-based drift rebalancing plus
   cash-flow-based rebalancing (new contributions buy the underweight
   class first); tax-loss-harvesting suggestions where the user's tax
   wrapper allows it (not inside an ISA).
5. **Predictive layer** — pluggable forecasting models (classical: ARIMA/
   exponential smoothing; ML: gradient-boosted trees; optional LLM-agent
   narrative overlay) produce a forward view used only to *tilt* the
   Black-Litterman blend and flag regime changes — never to drive single-
   stock bets. All predictions are shown with a visible confidence band and
   backtested track record; the system must disclose "this is a model, not
   a guarantee" every time a forecast is surfaced.
6. **"Profit-based business model" view** — Samridhi is self-hosted and
   free to the user, but includes an optional module that shows what an
   equivalent managed/advised portfolio would have cost in fees (echoing
   how robo-advisors sell on low fees) — useful context, not a real fee
   engine, since there's no actual advisory business here.

## 3. Agents (where an LLM/agent framework earns its place)

Agents are optional and gated behind user-provided model keys (local or
cloud) — the quantitative engine above works with zero AI configured.

| Agent | Job | Trigger |
|---|---|---|
| Market data agent | Pull prices/rates/news from public feeds (reuse Artha's BoE/ONS/Frankfurter pattern), normalise, cache locally | Scheduled |
| Risk-profile agent | Turn questionnaire + behaviour history into a risk score and explanation | On onboarding / review |
| Portfolio-construction agent | Run the MVO/Black-Litterman optimiser, propose allocations | After risk profile or data change |
| Forecasting agent | Run/own the predictive models, produce the forward view + confidence | Scheduled, model-pluggable |
| Rebalancing agent | Compare target vs actual, propose trades/contributions split | On drift threshold or new contribution |
| Compliance/wrapper agent | Enforce ISA/pension/account-type rules so suggestions are always legal for the account they're in | Every suggestion |
| Narrator agent (LLM) | Turn the above into a plain-English explanation ("why this plan") | On demand |
| Orchestrator | Sequences the above, never auto-executes a real trade without explicit user approval | Always |

AI integration is BYO, same pattern as Artha's "Ask Artha": user supplies a
local endpoint (Ollama/llama.cpp/LM Studio) or a cloud API key, stored in
the OS keychain; the app never ships a bundled model or hardcoded key.
Agents send only rounded/derived figures, never raw account identifiers.

## 4. Self-learning, local-first, self-hostable

* All data and the optimiser run locally by default; nothing leaves the
  device unless the user turns on sync or AI.
* "Self-learning": the system logs its own forecast accuracy and
  rebalancing outcomes locally, and recalibrates model weights/blend
  ratios from that track record (a local backtest-and-adjust loop) — not a
  claim of continuous online learning from external data without consent.
* Self-hosting guide (own doc, step by step, mirrors Artha's
  `server/README.md` + `docs/install-linux.md` pattern): run the bundled
  PocketBase server on the user's own machine/NAS/VPS, pair devices with a
  QR code, HTTPS requirement for anything not on a private network.

## 5. Platform & delivery

* Targets: Windows, Linux, Android (same three as Artha) from one Flutter
  codebase.
* **In-app updater with rollback**: check GitHub releases, download the
  signed/checksummed build, verify `SHA256SUMS.txt`, stage it, swap
  atomically, keep the previous version cached; "rollback" one tap restores
  it if the new version fails a post-update health check.
* **Fluid, modern UI with motion**: Flutter implicit/physics-based
  animations for the dashboard, portfolio and rebalancing views; respects
  reduced-motion setting.
* **Backup & restore**: encrypted local export/import (same encryption as
  the live DB), same model as Artha.
* **Problem report / feature request**: in-app button opens a prefilled
  GitHub issue (template + URL-encoded body: app version, OS, redacted
  diagnostic snippet) via the browser — no auto-submission, no private data
  attached without the user seeing it first.
* **App lock**: PIN/biometric gate on launch and resume, independent of
  the OS lock, backed by `flutter_secure_storage`.
* **Sentinel security checks**: on Windows, if Sentinel (the existing Rust
  security suite) is installed, Samridhi queries its named-pipe IPC for a
  basic health signal (Defender on, no known tamper) and shows a badge;
  on Linux/Android (where Sentinel doesn't run) Samridhi does its own
  lightweight local checks (DB integrity, screen-capture/recording
  warning, root/jailbreak-ish detection on Android). Never a dependency —
  Samridhi must run standalone.

## 6. Phased roadmap

* **P0 — scaffold**: repo, Flutter skeleton on `brahma_core`, encrypted
  local DB schema (accounts/holdings read-model, goals, risk profile),
  CI (analyze + test on push), AGENTS.md, no AI yet.
* **P1 — manual wealth input + risk profile**: user can enter/import
  holdings (or link Artha locally) without AI; risk questionnaire; MVO
  engine producing a target allocation; static UI.
* **P2 — rebalancing + backtesting**: drift/cash-flow rebalancing
  suggestions, historical backtest view, forecast agent stub (classical
  models only, no LLM required).
* **P3 — sync + self-hosting**: PocketBase server, pairing, step-by-step
  self-host guide, backup/restore.
* **P4 — AI/agents**: BYO local/cloud model wiring, narrator agent,
  orchestrator, agent on/off switches.
* **P5 — platform polish**: in-app updater + rollback, app lock, Sentinel
  integration, motion/UI pass, issue-report prefill.
* **P6 — Android + release**: Android build, `v*` tag release workflow
  (mirrors Artha's), first real-world use, gather feedback for v2.

Each phase ends with a gate: "done when" checks reported PASS/FAIL with the
exact command and output, following the project-wide workflow convention
(`C:\AI\WORKFLOW.md`).

## 7. Explicitly deferred to "suggest improvements" round

Live broker trading execution, real mutual-fund order routing, tax-return
integration, multi-currency hedging strategies, mobile iOS build (Artha
itself doesn't ship iOS either) — flagged for the user to prioritise after
reviewing the first build.
