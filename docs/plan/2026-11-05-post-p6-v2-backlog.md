# Post-P6 amendment: v2 backlog (deferred + nice-to-have)

Supersedes nothing; extends the v1 plan after P0-P6. Sources: the plan's
"explicitly deferred" list and the nice-to-have v2 list in
`2026-11-05-competitor-research.md`. Order is by value per risk.

| # | Item | Status |
|---|---|---|
| 1 | Behavioural-gap nudge from the user's own accepted-rebalance log | done (`BehaviorAgent`) |
| 2 | Discrete-tier 1-7 catalog mode | planned |
| 3 | Read-only Artha import | planned (needs Artha schema review; never writes to Artha) |
| 4 | Android screen-capture warning / root-ish detection | planned |
| 5 | Direct-indexing illustrative simulator | planned (education only, synthetic data) |

## 1. Behavioural-gap nudge

`BehaviorAgent` counts the user's own accepted `Rebalancing` suggestions in
the trailing 365 days (from the local `SuggestionLog`, which already records
`decidedAt`). At 3 or more it shows a note citing Betterment's published
~22 bp average shortfall for clients who changed allocations, labelled as one
provider's average and an education reference, not a prediction. No new data
leaves the device; the agent sees only a list of timestamps. Limit: the log
keeps one row per suggestion id, so repeated acceptances of the same id count
once.
