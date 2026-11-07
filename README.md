> **This repo is retired and archived.** Its features have moved into
> [Samriddhi](https://github.com/sudharamachandranrajeev/samriddhi) (Tauri app, version 0.2.0 onwards).
> Use that repo for downloads, issues and updates. The code below is kept for reference only.

# Samridhi

Local-first wealth, asset and investment management system for Linux,
Windows and Android. Reads your financial status from **Artha** and builds
a dynamic, risk-aware, diversified investment plan — in the style of
leading robo-advisors, but self-hosted and under your own control.

Status: **planning / early build**. Part of the Brahma suite. See the
[build plan](docs/plan/2026-11-05-samridhi-plan.md) for the full design
and roadmap.

## What it aims to do

* Risk profiling and goals-based sub-portfolios (retirement, house
  deposit, rainy day, general).
* Diversified portfolio construction (mean-variance / Black-Litterman),
  favouring low-cost index funds/ETFs, with room for mutual funds and
  self-directed trading.
* Threshold- and cash-flow-based rebalancing suggestions, backtesting.
* A predictive layer (classical + optional ML/LLM) that tilts the plan
  toward long-run safe investments, always shown with its confidence and
  track record — never a guarantee.
* Self-learning: logs its own forecast/rebalancing accuracy locally and
  recalibrates from that track record.
* Optional agents (market data, risk profiling, portfolio construction,
  forecasting, rebalancing, compliance, narrator) orchestrated on top of
  a quantitative core that works with zero AI configured.
* AI integration is bring-your-own: a local model (Ollama/llama.cpp/LM
  Studio) or your own cloud API key, kept in the OS keychain.
* Self-hosted cross-device sync (PocketBase, end-to-end encrypted), with
  a step-by-step hosting guide.
* In-app updater with rollback, encrypted backup/restore, app lock,
  optional Sentinel security-check integration on Windows, and a
  prefilled "report a problem / request a feature" GitHub issue button.

## Relationship to Artha

Samridhi reads Artha's accounts, balances and holdings (local link or the
same self-hosted sync server) to know your financial status. It never
writes back to Artha's ledger — Artha stays the single source of truth for
what happened; Samridhi is where the forward-looking plan lives.

## Related

* [artha](https://github.com/sudharamachandranrajeev/artha) — personal
  finance, accounting and investment manager (the data source)
* [brahma](https://github.com/sudharamachandranrajeev/brahma) — the
  shared core of the Brahma apps

## License

No licence has been chosen yet; all rights reserved.

## Self-hosting sync

Sync is optional and goes only to a PocketBase server you run yourself; see
[docs/self-hosting.md](docs/self-hosting.md).
