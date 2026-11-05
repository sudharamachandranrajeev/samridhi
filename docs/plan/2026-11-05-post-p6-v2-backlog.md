# Post-P6 amendment: v2 backlog (deferred + nice-to-have)

Supersedes nothing; extends the v1 plan after P0-P6. Sources: the plan's
"explicitly deferred" list and the nice-to-have v2 list in
`2026-11-05-competitor-research.md`. Order is by value per risk.

| # | Item | Status |
|---|---|---|
| 1 | Behavioural-gap nudge from the user's own accepted-rebalance log | done (`BehaviorAgent`) |
| 2 | Discrete-tier 1-7 catalog mode | done (Plan tab chips; `buildPlan(tier:)`) |
| 3 | Read-only holdings import (file) | done; Artha-side exporter still to be written in the Artha repo |
| 4 | Android screen-capture block (opt-in) / root-ish detection | done (`device_security.dart`, `MainActivity.kt`) |
| 5 | Direct-indexing illustrative simulator | done (`direct_indexing.dart`, Insights card; synthetic data) |

## 1. Behavioural-gap nudge

`BehaviorAgent` counts the user's own accepted `Rebalancing` suggestions in
the trailing 365 days (from the local `SuggestionLog`, which already records
`decidedAt`). At 3 or more it shows a note citing Betterment's published
~22 bp average shortfall for clients who changed allocations, labelled as one
provider's average and an education reference, not a prediction. No new data
leaves the device; the agent sees only a list of timestamps. Limit: the log
keeps one row per suggestion id, so repeated acceptances of the same id count
once.

## 2. Discrete risk tiers 1-7

Optional alternative to per-goal glide paths (Moneyfarm/Schwab style). Tier t
maps to risk score 100*(t-1)/6 and every goal gets that one portfolio.
Stored as setting `plan.tier`; absent means the default per-goal mode. The UI
states plainly that tier mode does not de-risk short-horizon goals, so the
safety cap the default mode applies is deliberately not hidden. Tests:
even spacing/clamping, identical per-goal portfolios, equity rises with tier,
weights sum to 1.

## 3. Read-only holdings import

Artha is a double-entry ledger whose database key sits in Artha's own
keychain entry; Samridhi must not open that database. The link is therefore a
file the user exports and chooses: JSON `samridhi-holdings-v1` or CSV
(`account,wrapper,holding,assetClass,value`). `parseHoldings` validates
strictly (2 MB cap, known asset classes/wrappers, finite non-negative
amounts, errors never echo raw values); Settings > Import holdings shows a
preview and needs a yes. Ids are stable (`imp:<slug>`) so re-importing
updates instead of duplicating; nothing is deleted. **Open item:** Artha does
not yet produce this file; that exporter belongs in the Artha repo and was
not touched here.

## 4. Screen-capture block and root hints (Android)

Settings > Security > "Block screenshots and screen recording" sets
`FLAG_SECURE` through a `dev.samridhi/device` method channel; stored as
`security.blockCapture`, **off by default**, re-applied at launch. The
subtitle says it also blocks the user's own screenshots and problem-report
captures. The security status list gains an informational root row (su binary,
test-keys build, Magisk/Superuser files). It is best-effort, easy to defeat,
never blocks use. Off Android both are no-ops.

## 5. Direct-indexing simulator

`simulateDirectIndexing` on a seeded SYNTHETIC 40-stock universe (4 sectors,
5 years): equal-weight "index" vs a copy that sells any position 10% below
cost into a same-sector peer. Reports harvests, realised losses, the tax they
could offset at an illustrative 20%, final values and annualised tracking
difference. The card says it is synthetic, education only, mostly deferral,
and that wash-sale rules, costs, real index weights and the user's tax rules
are not modelled. Tests: determinism, zero-harvest equals index exactly,
harvesting yields positive losses and nonzero tracking.
