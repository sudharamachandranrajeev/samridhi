# Competitor Research & Gap Analysis — Samridhi (2026-11-05)

Standalone research companion to `2026-11-05-samridhi-plan.md`. This document
does **not** modify the build plan; it documents how seven live wealth/robo
platforms actually implement their product, then separates what a self-hosted,
no-brokerage Flutter app can legitimately replicate from what requires a
licensed financial institution.

---

## 1. Firm-by-firm findings

### 1.1 Betterment

- **Risk profiling**: Deliberately *not* a classic risk-tolerance
  questionnaire. Betterment asks about time horizon per goal (age, target
  date, years to spend the money) rather than subjective "how would you feel
  if the market fell 20%" questions, on the stated belief that time horizon is
  a more reliable predictor of appropriate risk than self-reported tolerance,
  and that frequent portfolio monitoring shortens investors' perceived
  emotional time horizon and makes them feel the investment is riskier than it
  is [Lam, "Robo-Advisors: A Portfolio Management Perspective," Yale Economics
  senior essay, 2023, pp.39–40, citing Betterment Director of Investments &
  Behavioral Finance Dan Egan].
- **Allocation methodology**: Black-Litterman model exclusively (unlike
  Schwab/Wealthfront, which blend historical/CAPM-style estimates with MVO)
  [Lam 2023, p.31; Pirner, "Asset Allocation with Black-Litterman in a Case
  Study of Robo Advisor Betterment," Deutsche Nationalbibliothek Financial
  Research Note 04, Aug 2018]. Betterment uses the market-capitalization
  portfolio as the Black-Litterman prior and tilts from it with its own views
  to build each risk-level portfolio (e.g., its "70% stock" portfolio is
  derived by maximizing a utility function over the tilted efficient frontier)
  [Lam 2023, p.31].
- **Goals-based structure**: Each goal gets its own **glide path** — a
  function mapping time-to-goal to recommended stock/bond mix. For all goal
  types except retirement, the glide path is identical across investors (only
  time horizon varies the allocation); the retirement goal is the one
  exception with a more personalized glide path. Glide paths are built with a
  deliberate downside-risk bias, focusing on the 5th–50th percentile of
  simulated return outcomes rather than the full distribution, which Betterment
  acknowledges can skew recommendations conservative [Lam 2023, pp.39–40].
- **Rebalancing**: Automated, combines threshold-based drift rebalancing with
  cash-flow-based rebalancing (new deposits and dividends preferentially fill
  underweight asset classes before any sell-based rebalance is triggered) —
  consistent with industry-standard practice described in Vanguard's
  rebalancing research (§1.3).
- **Tax-loss harvesting**: Daily automated TLH across taxable accounts,
  swapping into correlated-but-not-identical ETFs to avoid wash sales,
  marketed as "Tax Loss Harvesting+".
- **Fee/business model**: AUM-based advisory fee (≈0.25%/yr tier), no
  separate trading/rebalancing fee; revenue model depends on being a
  registered investment adviser with custody/execution via an affiliated
  broker-dealer.
- **UI/UX for risk & performance**: Risk is presented as a slider on the
  stock/bond mix per goal, with projected outcome ranges (not single point
  forecasts) and a prominent "this is a projection, not a guarantee"
  disclosure pattern typical of the whole category (see §1.8).

### 1.2 Wealthfront

- **Allocation methodology**: Pure Mean-Variance Optimization (Markowitz,
  1952) over an in-house set of asset-class ETFs, explicitly described as
  "the foundation of Modern Portfolio Theory" — no Black-Litterman blend
  [Wealthfront Classic Portfolio Investment Methodology White Paper,
  research.wealthfront.com/whitepapers/investment-methodology/]. The
  optimizer targets **after-tax, net-of-fee** expected return at each risk
  level, not just pre-tax return — a distinguishing design choice. Wealthfront
  computes three representative portfolios per risk level (low/medium/high
  estimated tax rate, based on client-reported income, filing status, state)
  and shows that three tax-tier portfolios get within 0.02% of the
  fully-personalized after-tax-optimal return for any actual combination of
  tax rates [same white paper].
- **Risk scoring**: 1–10 risk score chosen by the client (slider), each score
  mapped to a fixed target allocation on the efficient frontier; score can be
  freely adjusted at any time (self-selected tolerance, not purely computed).
- **Tax-loss harvesting**: Daily, automated, free as part of the advisory fee;
  documented with multi-year realized-harvesting-yield tables by risk score
  [Wealthfront Tax-Loss Harvesting Methodology white paper,
  research.wealthfront.com/whitepapers/tax-loss-harvesting/]. Wash-sale
  management requires monitoring the client's own and (optionally) a spouse's
  linked accounts; Wealthfront explicitly disclaims visibility into unlinked
  external accounts.
- **Direct indexing**: Offered at three tiers — S&P 500 Direct (0.12% fee, min
  $5,000), Nasdaq-100 Direct (0.09%, min $5,000), and full US Direct Indexing
  (up to 100 stocks sampled from the CRSP US Total Market Index plus
  "completion" ETFs, min $100,000, no fee beyond the 0.25% advisory fee) —
  harvesting losses at the individual-stock level rather than the ETF level,
  which produces materially more harvestable loss events because single
  stocks are more volatile than a diversified ETF
  [wealthfront.com/blog/value-of-direct-indexing/,
  wealthfront.com/blog/how-wealthfront-helps-lower-taxes/].
- **Rebalancing**: Uses dividends/deposits to rebalance tax-efficiently first;
  sell-based rebalancing only when cash flows are insufficient; aims to sell
  the most tax-efficient lots first; incoming transferred securities are
  folded into the target allocation without selling where possible to avoid
  realizing gains.
- **Fee/business model**: Flat 0.25% AUM advisory fee across the taxable
  managed account, inclusive of TLH and rebalancing; additional secured
  lending product ("Portfolio Line of Credit") against the portfolio.
- **Predictive methodology**: No tactical/forecast-driven tilting — Wealthfront
  explicitly markets a *passive* philosophy, citing SPIVA data that 78.65% of
  active domestic funds underperformed their benchmark in 2024 (94.11% over 20
  years) as the rationale for not trying to time or forecast markets
  [S&P SPIVA US Year-End 2024 report,
  spglobal.com/spdji/en/documents/spiva/spiva-us-year-end-2024.pdf, cited in
  wealthfront.com/blog/investment-philosophy/].

### 1.3 Vanguard Personal Advisor (Services)

- **Model**: Hybrid human-advisor + automated rebalancing, not a pure robo;
  $50,000 minimum aggregate balance to enroll [investor.vanguard.com/advice/
  personal-hybrid-robo-advisor].
- **Rebalancing research base**: Vanguard has published the most extensive
  public research in the industry on rebalancing trigger design. Key
  findings, directly reusable as design parameters:
  - A **threshold-based** strategy (rebalance only when an asset class drifts
    beyond a tolerance band, e.g. ±5%) dominates pure calendar-based
    rebalancing on a risk-adjusted, cost-adjusted basis
    [Vanguard, "Getting Back on Track: A Guide to Smart Rebalancing," and
    "Rational Rebalancing: An analytical approach to multiasset portfolio
    rebalancing decisions and insights," corporate.vanguard.com /
    vanguardsouthamerica.com PDFs].
  - Empirical table (92 years of data, 60/40 portfolio) shows a monthly-check,
    0%-threshold strategy triggers ~1,100+ rebalancing events vs. an
    annual-check, 10%-threshold strategy triggering only ~14 events, with
    **no statistically robust difference in long-run risk-adjusted return**
    between strategies — the conclusion Vanguard draws is that investors
    should pick a rule they can discipline themselves to follow, rather than
    chase an "optimal" threshold [vanguardsouthamerica.com PDF, Figure cited
    above].
  - For a 60/40 portfolio, a **3% threshold** is estimated optimal if a
    tracking-error budget of ≤20bps is desired; **1–2% thresholds** are
    estimated optimal under tighter constraints
    [vanguardmexico.com, "Rational Rebalancing" PDF].
  - For target-date/glide-path funds specifically, Vanguard's "The
    Rebalancing Edge" paper models a **200/175 basis-point band** (rebalance
    equities up at +200bps drift, down at -175bps) against monthly/quarterly
    calendar rebalancing, finding threshold-based rebalancing produces lower
    estimated transaction cost (5.1bps/yr vs 22.1bps monthly, 18.3bps
    quarterly) while achieving comparable or slightly higher annualized
    return in simulation [corporate.vanguard.com, "The Rebalancing Edge" PDF].
  - Tactic: **direct new cash flows (contributions, dividends, interest, RMDs)
    into underweight asset classes first**, and draw withdrawals from
    overweight classes first, before resorting to sell-based rebalancing —
    this is the standard "cash-flow rebalancing" pattern referenced in the
    Samridhi plan doc [investor.vanguard.com/investor-resources-education/
    portfolio-management/rebalancing-your-portfolio].
- **Fee/business model**: ~0.30% advisory fee (hybrid human+digital), tiered
  down at higher AUM; distinct from the robo-only Vanguard Digital Advisor at
  a lower fee tier.

### 1.4 Schwab Intelligent Portfolios

- **Risk profiling**: Explicit separation of **risk capacity** (objective
  questions: years to retirement, stated goals, time horizon for each goal)
  from **risk tolerance/willingness** (behavioral questions, e.g. "what would
  you do after a significant investment loss") [Lam 2023, p.?, citing
  Schwab's questionnaire design; this capacity/tolerance split mirrors the
  standard financial-planning distinction popularized by Kitces,
  kitces.com/blog/separating-risk-tolerance-from-risk-capacity].
- **Allocation methodology**: Builds forward-looking expected returns using a
  **building-block approach**: current risk-free rate (20-year Treasury
  yield) + historical equity risk premium, assuming P/E expansion observed
  historically will not repeat, then levers this to individual asset classes
  via beta-adjustment to US large-cap returns [Lam 2023, summarizing Schwab's
  published capital markets methodology]. Combined with MVO, it does **not**
  use Black-Litterman. Clients land in one of 80+ pre-built portfolio
  variations rather than a fully bespoke optimization per-client
  [schwab.com/intelligent-portfolios].
- **Instrument selection / ETF screening**: Schwab filters ~2,000+ eligible
  ETFs down to ~50 by excluding inverse/leveraged, actively-managed,
  single-country, and ETFs with <3 months trading history, then ranks
  survivors by tracking fidelity to the target index (not by
  outperformance) and by low operating expense ratio
  [schwab.com/automated-investing/faqs, "Portfolio construction & ETFs"
  section].
- **Rebalancing**: Daily monitoring, trade triggered only when an asset class
  moves outside its allocated **range** (band, not fixed % in the public
  materials) — same threshold philosophy as Vanguard's research. "Portfolio
  won't trade every day... a few times per year" in normal markets, more in
  volatile periods [schwab.com/intelligent-portfolios, "Rebalancing as
  needed"].
- **Tax-loss harvesting**: Opt-in, only for taxable accounts ≥$50,000; daily
  monitored; maintains a **primary/secondary ETF pair per asset class** so a
  harvested position can be swapped into a correlated alternate ETF in the
  same asset class without a wash sale [schwab.com/learn/story/
  overcoming-volatility-with-tax-loss-harvesting — includes a documented case
  study: ~$100k account harvested ~$18,000 (≈15% of account value) across the
  volatile first 9 months of 2022].
  no advisory fee; no advisory fee; revenue instead comes from (a) the cash
  allocation sweep into Schwab Bank deposits, which Schwab earns net interest
  margin on, and (b) management fees on Schwab-affiliated ETFs held in the
  portfolio [schwab.com/learn/story/overcoming-volatility-with-tax-loss-harvesting,
  disclosure section]. This is an important disclosure precedent: "free"
  robo tiers are commonly cross-subsidized by cash-sweep interest, not
  altruism.

### 1.5 Fidelity Go

- **Risk profiling / onboarding**: Lightweight goal + time-horizon intake;
  annual check-in prompting the user to flag life changes, which can trigger a
  strategy adjustment [fidelity.com/wealth/fidelity-go FAQ].
- **Allocation**: Portfolio composed entirely of **zero-expense-ratio Fidelity
  Flex mutual funds** (not ETFs) selected per the client's investment profile
  — notable because it is the only firm in this set built on proprietary
  zero-fee mutual funds rather than ETFs, which removes expense-ratio drag
  entirely but ties the client to Fidelity's fund family
  [fidelity.com/bin-public/.../FGo-FPPA-Supplemental.pdf, product table].
- **Fee/business model**: $0 advisory fee under $25,000 invested; flat 0.35%
  annual fee (on the entire balance, not marginal) once balance reaches
  $25,000+; that tier also unlocks human coaching calls and taxable-account
  tax-loss harvesting. No separate trading/rebalancing fee
  [fidelity.com/wealth/fidelity-go FAQ; unbiased.com/discover/
  financial-advice/fidelity-go-review].
- **Methodology disclosure**: Fidelity publishes a general "Investor Profile
  Questionnaire" detailed methodology (used for its broader guidance tools,
  not Go-specific) describing how questionnaire answers map to a target asset
  allocation [fidelity.com/bin-public/.../IPR_METHODOLOGY.pdf].

### 1.6 Nutmeg → JPMorgan Personal Investing (UK)

- **Status change (material fact for any UK-market comparison)**: Nutmeg,
  the pioneering UK robo-advisor (est. 2012), was acquired by JPMorgan and has
  been **rebranded/absorbed into "JPMorgan Personal Investing"**; the Nutmeg
  consumer brand has been retired [wealthbriefing.com, "Goodbye Nutmeg, Hello
  JP Morgan Personal Investing"]. Any Samridhi UI copy or comparison table
  referencing "Nutmeg" as a live competitor should be updated to JPMorgan
  Personal Investing.
- **Rebalancing (retained methodology description)**: Two rebalancing levers
  — directing **new money** into underweight asset classes first, and
  periodic **sell/buy rebalancing** back to target weights — i.e. the same
  cash-flow-then-threshold pattern as the US firms above
  [nutmegag.com/resource-center/investment/rebalancing-your-portfolio — note:
  this is a since-rebranded UK advisory-group domain, used here only for the
  methodology description, which is consistent with the wider industry
  pattern independently corroborated by Vanguard's research in §1.3].
- **Portfolio construction (automatic, under the new brand)**: Portfolios
  built by a central investment team, automatically rebalanced "at no extra
  cost" to the client's selected risk level
  [support.personalinvesting.jpmorgan.com, "How we manage portfolios — our
  investment process and rebalancing"].
- **Lesson for Samridhi**: brand/ownership churn is common in this sector
  (also true of several other UK robos); the report and any in-app
  comparison content should be dated and should avoid hard-coding brand names
  as permanent facts.

### 1.7 Moneyfarm (UK/EU)

- **Risk profiling**: Publishes consumer-facing educational content
  explicitly distinguishing investor **risk profile** (combination of
  willingness and ability to take risk) from a single "portfolio match," with
  worked examples of profile types [blog.moneyfarm.com/en/saving-and-
  investments/what-level-of-risk-is-right-for-me/].
- **Allocation / product shape**: Seven discrete **risk levels** (1–7), each a
  globally diversified multi-asset portfolio; portfolios are broken down and
  shown to the client by asset type, sector, and geography, built by a
  dedicated in-house "Asset Allocation team" rather than a pure black-box
  optimizer [moneyfarm.com/uk/portfolios/]. This is a simpler, discrete-tier
  model (like Schwab's 80 variations) rather than a continuous per-client
  optimization.
- **Goals framing**: Marketed as "invest according to your goals" with a
  single portfolio recommendation per risk level rather than Betterment-style
  per-goal sub-portfolios — closer to the Schwab/Moneyfarm "single risk-tiered
  portfolio" pattern than to Betterment's/Wealthfront's goals-based glide
  paths.

### 1.8 Cross-cutting UI/UX and forecasting patterns (industry-wide, sourced)

- **Risk is shown as a position on a spectrum, not a number alone**: sliders
  (Wealthfront 1–10, Moneyfarm 1–7, Betterment stock/bond %), always paired
  with a plain-language label and the underlying stock/bond split, consistent
  across every firm reviewed.
- **Performance/forecast is always a range, never a point estimate**, and is
  always accompanied by a standard disclaimer that diversification/asset
  allocation/rebalancing "do not ensure a profit and do not protect against
  losses" — this exact disclosure phrase recurs verbatim across Schwab,
  Fidelity, and Wealthfront legal disclosures, indicating it functions as an
  industry-standard regulatory safe-harbor phrase, not firm-specific
  marketing language.
- **No firm reviewed publishes a firm-specific stock-picking forecast**;
  every published "forward view" is at the **asset-class** level (equity risk
  premium, bond yield, inflation assumption) feeding MVO/Black-Litterman, not
  single-security alpha forecasts. This directly supports the Samridhi plan's
  existing design decision to use the forecasting agent only to tilt
  asset-class-level views, never to drive single-stock bets.
- **Behavioral-gap disclosure**: Betterment has publicly quantified that
  clients who made allocation changes underperformed a simple buy-and-hold of
  their own average allocation by a mean of 22 basis points, and that the gap
  widens with the number of changes made — empirical support for minimizing
  user-initiated manual rebalancing interventions in the UI
  [Lam 2023, p.68, citing Betterment Blog data; see also the "behavior gap"
  literature more broadly, e.g. Dalbar QAIB studies referenced across the
  industry].
- **Academic foundation cited by name across all whitepapers**: Markowitz
  (1952) mean-variance optimization — the 1990 Nobel Prize in Economics is
  explicitly invoked by Wealthfront as the "award-winning research" backing
  Modern Portfolio Theory [wealthfront.com/blog/investment-philosophy/]. The
  SPIVA scorecard (S&P Dow Jones Indices) is the standard citation for the
  "active management underperforms" argument used to justify passive index
  construction [S&P SPIVA US Year-End 2024, spglobal.com].

---

## 2. Gap analysis — what Samridhi can vs. cannot replicate

### 2.1 Fully replicable in a self-hosted, no-brokerage Flutter app

| Capability | Why it's feasible locally | Firm precedent |
|---|---|---|
| Risk-capacity + risk-tolerance questionnaire (separated, per Kitces/Schwab pattern) | Pure logic/UI; no account access needed | Schwab, Moneyfarm |
| Goals-based glide paths (per-goal time horizon → allocation) | Deterministic function of user-entered dates/goals | Betterment |
| Continuous risk slider mapped to a discrete allocation table | Same math, no execution needed | Wealthfront, Moneyfarm |
| MVO / Black-Litterman portfolio construction engine, run on public index/ETF return & covariance data | Pure numerical computation on public market data (already in plan doc) | Wealthfront, Betterment, Schwab |
| ETF/instrument **screening criteria** (expense ratio, tracking fidelity, exclude leveraged/inverse/single-country, min history) applied as a *recommendation filter* over a user-curated or public ETF universe | Just a ranking/filter function over public ETF metadata (no custody) | Schwab's published screening criteria |
| Threshold-based rebalancing **alerts** ("you're 4% overweight equities, rebalance?") with user-configurable band (e.g. 1/3/5/10%) | Pure drift calculation vs. target weights the user already holds (read from Artha) | Vanguard's published threshold research directly parameterizes this |
| Cash-flow rebalancing **suggestions** ("direct your next £500 contribution into bonds") | Logic over Artha-sourced balances; no trade execution | Vanguard, Wealthfront, Betterment, JPMorgan Personal Investing |
| Tax-loss-harvesting **advisory flags** ("this holding is down 8% vs. cost basis and outside its wash-sale window — consider manually harvesting in your own brokerage, note UK bed-and-ISA / 30-day rule" or US-specific 30-day wash-sale warning) — a *suggestion engine*, not an executor | All the math (unrealized loss, wash-sale date window) is derivable from cost-basis data the user already has in Artha | Wealthfront/Schwab TLH logic, adapted to advisory-only |
| Direct-indexing-style **concept demo** (show what stock-level harvesting *would* capture, illustratively, using historical index constituent data) | Educational/illustrative only, not a managed account | Wealthfront US Direct Indexing concept |
| Performance/forecast UI: ranges not point estimates, mandatory "not a guarantee" disclosure, asset-class-level (not single-stock) forecast tilts | UI/content pattern replication, zero regulatory dependency | Universal pattern across all 7 firms |
| Behavioral-gap nudges (warn before a manual reallocation: "investors who changed allocation X times underperformed by Ybps on average") | Pure UX copy + optional local tracking of the user's own override history | Betterment's published behavioral-gap data |
| Fee-comparison module (plan doc's "what would a managed robo have cost you") | Pure arithmetic against published fee schedules in this report | All 7 firms' public fee pages |
| Discrete risk-tier *or* goals-based structure — Samridhi can let the user choose Betterment-style per-goal portfolios or Moneyfarm/Schwab-style single risk-tiered portfolio | Pure product/config decision | Betterment vs. Moneyfarm/Schwab divergence documented above |

### 2.2 Requires a licensed financial institution — must be explicitly scoped OUT

| Capability | Why it's out of scope | Regulatory reality |
|---|---|---|
| **Actual trade execution** (buying/selling real ETFs/funds on the user's behalf) | Requires broker-dealer registration, custody of client assets, best-execution obligations | US: FINRA/SIPC member (Betterment, Wealthfront, Schwab, Fidelity all route through an affiliated broker-dealer). UK/EU: FCA-authorized investment firm |
| **Discretionary portfolio management** (acting on the user's behalf without per-trade confirmation) | Requires SEC/FCA-registered investment adviser status, fiduciary duty, Form ADV / FCA permissions | Every firm reviewed is or uses a registered adviser (e.g. "Strategic Advisers LLC," an SEC-registered RIA, runs Fidelity Go) |
| **Actual automated tax-loss harvesting execution** (selling/buying real securities to realize losses) | Requires brokerage execution + real-time wash-sale monitoring across the client's *actual* linked accounts, which needs account-aggregation/custody rights | Wealthfront/Schwab explicitly disclaim visibility into external unlinked accounts even as a licensed adviser — a self-hosted app without any account linkage is worse-positioned, so this must stay "advisory flag only" |
| **Holding client cash/cash-sweep products** (the Schwab "free because of cash sweep interest" model) | Requires a bank or broker-dealer charter to sweep and hold deposits | Schwab Bank, SSB |
| **Personalized investment advice as defined by securities law** (vs. generic educational/planning tools) | In the US this is the dividing line under the Investment Advisers Act of 1940; in the UK it's FCA's "regulated advice" perimeter (FSMA 2000, RAO) — a tool that outputs a *specific, personalized* buy/sell recommendation tied to the user's actual portfolio can tip into "advice" even without executing it | Must keep Samridhi framed as a **planning/education/simulation tool**, with on-screen disclaimers ("not financial advice," "model output, not a recommendation to buy or sell") on every allocation/rebalancing/TLH screen, mirroring the disclosure language common to all 7 firms |
| **Direct indexing at custody scale** (owning 50–100 individual stocks per client, managing corporate actions, dividends, fractional shares) | Needs brokerage infrastructure (fractional-share execution, corporate-action processing) that a planning-only app cannot provide | Wealthfront US Direct Indexing, S&P 500 Direct |
| **Portfolio-secured lending** (Wealthfront's Portfolio Line of Credit) | Lending against securities requires margin-lending/broker-dealer licensing | Wealthfront Brokerage LLC |
| **Human advisor access / coaching calls** as a licensed advisory service | Requires licensed individuals (Series 65/66 or equivalent, FCA-approved person status) | Fidelity Go, Vanguard Personal Advisor |
| **Guaranteeing or implying specific future returns** | Securities law (US) / FCA financial promotion rules (UK) strictly prohibit return guarantees in retail communications | Universal disclosure language ("past performance does not guarantee future performance") across all 7 firms |

### 2.3 Gray zone — feasible technically, needs careful framing

- **Risk-profiling output framed as "your recommended allocation"**: feasible
  to compute, but copy must read as a *model suggestion for your own
  decision-making*, not personalized regulated advice — add an explicit
  "Samridhi is a planning tool, not a registered investment adviser" banner,
  consistent with how even FCA/SEC-regulated firms over-disclose.
- **Automatic PocketBase-synced multi-device "rebalancing suggestions"**: fine
  as a notification/suggestion; must never auto-generate anything that looks
  like a signed order ticket or pre-filled brokerage trade form, to avoid
  resembling unlicensed order routing.
- **Forecasting/predictive agent (ARIMA/ML/LLM)**: fine to build and show,
  provided (matching every firm's actual practice in §1.8) it stays at
  asset-class level, always shows a range + backtested accuracy + "model, not
  guarantee" disclaimer, and is never used to auto-execute anything.

---

## 3. Prioritized feature list for the developer

### Must-have — v1

1. Risk questionnaire with explicit **capacity** (objective: time horizon,
   income stability, dependents) and **tolerance** (behavioral: reaction to a
   simulated 20% drawdown) sections, scored separately then combined —
   Kitces/Schwab pattern (§1.4, §1.8).
2. Config switch: **goals-based mode** (Betterment-style, one sub-portfolio +
   glide path per goal) vs. **single-risk-tier mode** (Moneyfarm/Schwab-style,
   one portfolio per user) — both backed by the same MVO/Black-Litterman
   engine already scoped in the main plan doc.
3. MVO engine with a small, fixed, user-editable ETF/index universe; apply
   Schwab-style screening filters (exclude leveraged/inverse/<3mo history/
   single-country-only unless user opts in) as a default filter, overridable.
4. Threshold-based drift detector against Artha-sourced holdings, default band
   configurable (suggest 3–5% per asset class per Vanguard's published
   optimum range), surfaced as a dashboard alert, never auto-executed.
5. Cash-flow rebalancing suggestion: when the user logs a new contribution in
   Artha, Samridhi suggests which underweight asset class it should go to.
6. TLH **advisory flag only**: surface unrealized-loss positions past the
   user's locally-tracked wash-sale window, with jurisdiction-aware copy
   (US 30-day wash sale vs. UK bed-and-breakfasting/30-day rule), explicit
   "you must execute this yourself in your own brokerage" language.
7. Performance/allocation UI: range-based projections (never a single number),
   mandatory "model output, not a guarantee / not financial advice" banner on
   every screen that shows an allocation or forecast.
8. Fee-comparison module: static table of the fee schedules in §1 (Betterment
   ~0.25%, Wealthfront 0.25%, Fidelity Go 0%/0.35%, Schwab 0% + cash-sweep
   spread, Vanguard PAS ~0.30%) vs. $0 self-hosted — no claim of real-time
   accuracy, dated snapshot with citation.

### Nice-to-have — v2

1. Behavioral-gap nudge using the user's own override history (Betterment's
   -22bps/change finding as a generic educational citation, plus the user's
   own locally logged "I changed my allocation N times this year" stat).
2. Direct-indexing **illustrative simulator**: show historically how
   stock-level harvesting on an index would have outperformed ETF-level TLH,
   purely educational, using static historical constituent data bundled or
   fetched from a public source — never a real recommendation to buy
   individual stocks for tax purposes.
3. Discrete-tier catalog mode (Schwab's 80-variations / Moneyfarm's 7-levels
   style) as an alternative, simpler UX path next to the full MVO optimizer,
   for users who want "just pick a number 1–7."
4. Jurisdiction-pluggable wrapper rules beyond UK ISA (US 401k/IRA contribution
   limits, wash-sale rules) so the compliance/wrapper agent in the main plan
   can be reused across markets.
5. Backtested forecast accuracy dashboard per forecasting model (classical vs
   ML vs LLM-narrative), echoing Wealthfront's/Betterment's published
   track-record transparency style.

### Out of scope (explicitly, permanently, unless Samridhi becomes a licensed entity)

1. Any real trade execution or brokerage account linkage that can place
   orders.
2. Discretionary management ("Samridhi will rebalance this for you
   automatically without confirmation").
3. Actual cash custody, sweep accounts, or interest-bearing cash products.
4. Securities-backed lending (portfolio line of credit).
5. Any return guarantee or language that could be read as a guarantee.
6. Human-advisor-equivalent personalized advice calls/chat positioned as
   regulated advice (an LLM narrator explaining the *model's* output is fine;
   an LLM claiming to be "your financial advisor" giving personalized buy/sell
   instructions is not).
7. Direct indexing at real custody scale (individual stock ownership,
   corporate-action handling, fractional-share execution).

---

## 4. Sources

- Betterment Black-Litterman case study: Pirner, D., *Asset Allocation with
  Black-Litterman in a case study of Robo Advisor Betterment*, Deutsche
  Nationalbibliothek Financial Research Note 04, Aug 2018. https://d-nb.info/116404222X/34
- Betterment goals-based glide paths & behavioral-gap data: Lam, J.,
  *Robo-Advisors: A Portfolio Management Perspective*, Yale Economics Senior
  Essay, 2023. https://economics.yale.edu/sites/default/files/2023-01/Jonathan_Lam_Senior%20Essay%20Revised.pdf
- Wealthfront Classic Portfolio Investment Methodology White Paper.
  https://research.wealthfront.com/whitepapers/investment-methodology/
- Wealthfront Tax-Loss Harvesting Methodology white paper.
  https://research.wealthfront.com/whitepapers/tax-loss-harvesting/
- Wealthfront, "All About Wealthfront's Investment Philosophy" (SPIVA
  citation). https://www.wealthfront.com/blog/investment-philosophy/
- Wealthfront, "How Wealthfront Helps Lower Your Taxes" (direct indexing
  tiers/fees). https://www.wealthfront.com/blog/how-wealthfront-helps-lower-taxes/
- S&P Dow Jones Indices, SPIVA US Year-End 2024 report.
  https://www.spglobal.com/spdji/en/documents/spiva/spiva-us-year-end-2024.pdf
- Vanguard, "Rebalancing your portfolio: How to rebalance."
  https://investor.vanguard.com/investor-resources-education/portfolio-management/rebalancing-your-portfolio
- Vanguard, "The rebalancing edge: Optimizing target-date fund rebalancing
  through threshold-based strategies."
  https://corporate.vanguard.com/content/dam/corp/research/pdf/the_rebalancing_edge_optimizing_target_date_fund_rebalancing_through_threshold_based_strategies.pdf
- Vanguard, "Rational rebalancing: An analytical approach to multiasset
  portfolio rebalancing decisions and insights."
  https://www.vanguardmexico.com/content/dam/intl/americas/documents/latam/en/2022/10/mx-sa-2558523-rational-rebalancing-an-analytical-approach.pdf
- Vanguard, "Getting back on track: A guide to smart rebalancing."
  https://www.vanguardsouthamerica.com/content/dam/intl/americas/documents/latam/en/sa-2123766-getting-back-on-track.pdf
- Vanguard Personal Advisor enrollment minimum.
  https://investor.vanguard.com/advice/personal-hybrid-robo-advisor
- Schwab Intelligent Portfolios product page (allocation, rebalancing,
  TLH overview). https://www.schwab.com/intelligent-portfolios
- Schwab, "Overcoming Volatility with Tax-loss Harvesting" (case study, fee
  disclosure on cash-sweep revenue model).
  https://www.schwab.com/learn/story/overcoming-volatility-with-tax-loss-harvesting
- Schwab Automated Investing FAQs (ETF screening criteria).
  https://www.schwab.com/automated-investing/faqs
- Fidelity Go product page & FAQ (fees, onboarding).
  https://www.fidelity.com/wealth/fidelity-go
- Fidelity Go Legal Booklet / Client Agreement (fee schedule detail).
  https://www.fidelity.com/bin-public/060_www_fidelity_com/documents/FGo-FPPA-Supplemental.pdf
- Fidelity Investor Profile Questionnaire detailed methodology.
  https://www.fidelity.com/bin-public/060_Guidance_Pages/documents/IPR_METHODOLOGY.pdf
- JPMorgan Personal Investing, "How we manage portfolios — our investment
  process and rebalancing."
  https://support.personalinvesting.jpmorgan.com/?article=115000356972
- WealthBriefing, "Goodbye Nutmeg, Hello JP Morgan Personal Investing" (brand
  status/rebrand confirmation).
  https://www.wealthbriefing.com/html/article.php/goodbye-nutmeg%2C-hello-jp-morgan-personal-investing
- Nutmeg Advisory Group, "Rebalancing Your Portfolio" (methodology
  description, used for the cash-flow + threshold pattern only).
  https://www.nutmegag.com/resource-center/investment/rebalancing-your-portfolio
- Moneyfarm, "Risk Profile: What is it?"
  https://blog.moneyfarm.com/en/saving-and-investments/what-level-of-risk-is-right-for-me/
- Moneyfarm UK portfolios page (7 risk levels).
  https://www.moneyfarm.com/uk/portfolios/
- Kitces.com, "Separating Risk Tolerance From Risk Capacity."
  https://www.kitces.com/blog/separating-risk-tolerance-from-risk-capacity-just-because-you-can-afford-to-take-risk-doesnt-mean-you-should/
- Morgan Stanley, "Direct Indexing: What It Is and Its Benefits" (minimum
  investment context). https://www.morganstanley.com/articles/what-is-direct-indexing-benefits
- Investopedia, "Mastering Investment Risk: The Pyramid Strategy Explained"
  (general risk-tier framing reference).
  https://www.investopedia.com/articles/basics/03/050203.asp
