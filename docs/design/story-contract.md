# Story contract

The dashboard design (Paper file "Data Eng & Analytics", page 6 · Applied screens) shows one coherent quarter of a fictional B2B SaaS company. This file is the data spec behind those screens. The generator, seeds, and dbt models must produce data that tells this story; `make story-check` proves it.

## Precision tiers

- **Tier 1, exact.** Named/planted records, policy and SLA values, freshness, test outcomes, and every variance vs plan or quota. Variances are exact because plan and quota are invented: derive the plan/quota seeds from generated actuals minus the scripted variance (plan = actual − gap, where gap = actual − plan), so they hold by construction.
- **Tier 2, level.** Only the ARR book: monthly committed ARR, the ARR bridge components, and Enterprise share, within ±10% of the numbers below. Every other level (bookings, billings, AR, DSO, commits, NRR, GRR, won QTD) follows from the book and is whatever the build produces.
- **Tier 3, invariant.** Relationships and qualitative statements that must hold (listed per page). The story lives here, not in absolute finance levels.
- The build is the truth for every number that isn't Tier 1. The Paper screens get updated to match `docs/design/screen_numbers.json`; numbers quoted below outside Tier 1 are illustrative.

Display rounding: $M to one decimal, $K to whole thousands, percentages to whole numbers.

## Clock

- Pinned extract: `AS_OF=2026-09-30`, "now" = 2026-09-30 17:05 UTC (Wednesday). Fiscal year = calendar year. Q3 FY26 = Jul–Sep, week 13 of 13.
- Latest closed month: **August 2026**, closed 3 Sep 2026, month-end snapshot taken then. September is open (MTD) and must never be labeled or reported as a closed month.
- Last dbt build 16:52 UTC, hourly.

## Freshness and tests (Tier 1)

- Salesforce last sync 16:53 UTC (12 minutes before now), SLA 2h → Pass.
- Stripe/billing last sync 2026-09-29 10:05 UTC (31h), SLA 24h → Warn.
- Test totals after build: exactly **1 Warn** (stripe source freshness) and **1 Error** (JPY amount tie-out on `rpt_bookings_to_billings`, 3 failing rows). Everything else Passes. Known backlog items (below) Pass with a count; they Warn only outside their materiality band. `make build` must finish and record results despite the Error.

## Accounts

Add `Segment__c` (Enterprise, Mid-market, SMB, Startups, Public sector) and `Region__c` (North America, EMEA, APAC) to the Salesforce Account extract. Enterprise is ~49% of ARR.

## Planted records (Tier 1: names, segments, amounts, dates as stated)

| Account | Segment | Where it appears |
|---|---|---|
| Solace Robotics | Mid-market | T1 top gain, new logo +$620K Aug; T4 booked not billed $620K, annual seats, 12 business days at Aug month-end, owner P. Nair |
| Quarry Health | Enterprise | T1 top gain, expansion +$480K |
| Harbor & Pine | Enterprise | T1 top gain, new +$410K; T4 booked not billed $410K, usage commit, 7 bd, T. Wu |
| Quillon Systems | Enterprise | T1 top gain, expansion +$350K; T4 booked not billed $350K, expansion seats, 4 bd, P. Nair |
| Tern Logistics | Mid-market | T1 top gain, new +$240K; T4 booked not billed $240K, premium support, 2 bd, T. Wu |
| Arden Biotech | Mid-market | T4 booked not billed $180K, onboarding, 1 bd, P. Nair |
| Veridian Labs | Mid-market | T1 churn −$140K Aug |
| Northgate Clinics | Public sector | T1 churn −$100K |
| Arcadia Freight | Enterprise | T1 churn −$60K |
| Pellucid AI | Startups | T1 churn −$60K |
| Holloway (Holloway & Co.) | Enterprise | T1 churn −$40K |
| Copperline Media | Enterprise | T1 contraction −$140K |
| Alder & Finch | Mid-market | T1 contraction −$90K |
| Oakridge Analytics, Fennel Systems | Enterprise | Closed won late Aug 2026 ($0.9M ACV together) without an order; orders created 29 Sep, so their ARR lands in September. Named in T1 variance commentary; appear in T3 "resolved in the last 7 days" |
| Harbor County Health $320K (Public, 2nd slip, S. Ito), Ostrava Labs $240K (Ent, 1st, D. Brennan), Cinder Freight $180K (Ent, 1st, D. Brennan), Brightline Dental $140K (SMB, 3rd, L. Moreau), Mosaic Transit $120K (Public, 1st, S. Ito), Orbit Supply $100K (MM, 2nd, K. Adeyemi) | | T2 open opportunities whose close date moved out of Q3 during week 13 (total $1.1M) |
| Meridian Analytics Inc / Meridan Analytics ($310K ARR at stake), Brightwater Systems GmbH / Brightwater Systems ($190K) | | T5 top two pending account-match pairs |
| Halvorsen Group / Halverson Group | | T5 match pair decided "kept separate" by A. Dixon 28 Sep |

T3 open exceptions at now (age in business days vs SLA, amount, owner):

| Record | Exception | Age / SLA | At stake | Owner |
|---|---|---|---|---|
| Northwind Logistics | Won, no order | 9d / 3d | $412K | M. Okafor |
| Halvorsen Group | Invoice unmatched to order | 6d / 5d | $186K | J. Reyes |
| Ostrander Freight | Cancelled order still invoicing | 4d / 2d | $128K | J. Reyes |
| Larkspur Energy | Won, no order | 2d / 3d | $530K | A. Chen |
| Corvid Robotics | Amount ≠ sum of line items | <1d / 3d | $310K | M. Okafor |
| Tidewater Health | Reduction order awaiting approval | 1d / 5d | $240K | M. Okafor |
| Pinecrest Media | Invoice unmatched to order | 3d / 5d | $205K | J. Reyes |
| Saltmarsh Bank | Reduction order awaiting approval | 2d / 5d | $150K | A. Chen |
| Kestrel Bio | Amount ≠ sum of line items | 2d / 3d | $95K | A. Chen |
| Ferrow Studios | Invoice unmatched to order | 1d / 5d | $44K | J. Reyes |

Result: 10 open, $2.3M; 3 past SLA ($726K); 2 breach tomorrow ($625K). "Yesterday" is derived from the daily snapshot (Corvid opened today, so it isn't in yesterday's queue); expect 11 open, ~$2.39M, 2 past SLA. Last 7 days: 23 resolved, $4.8M, median 1.6 days, 2 resolved past SLA. No exception older than ~30 days exists (Deal Desk works the queue daily).

Planted defect: 3 JPY invoices whose amounts arrive in the wrong minor-unit scale (¥ treated as having 2 decimals), $0.1M of mismatch. This is what fails the tie-out test.

## Policy seed (Tier 1, invented; `seeds/policy_thresholds.csv`)

| Key | Value |
|---|---|
| materiality_balance_pct | 1% (ARR and other balances) |
| materiality_flow_pct | 5% (bookings, net new, other flows) |
| materiality_rate_pts | 1 pt (NRR, GRR, attainment). Inclusive. |
| tieout_tolerance_pct | 1% of billings |
| collections_over90_max_pct_of_ar | 2% |
| dso_max_days | 45 |
| commit_burn_band_pts | 5 |
| sla_won_without_order_bd | 3 |
| sla_amount_mismatch_bd | 3 |
| sla_invoice_unmatched_bd | 5 |
| sla_reduction_approval_bd | 5 |
| sla_cancelled_still_invoicing_bd | 2 |
| sla_invoicing_bd | 5 (activation → first invoice) |
| sla_incident_response_hours | 4 |
| freshness_salesforce_hours | 2 |
| freshness_stripe_hours | 24 |

## T1 Executive · Aug 2026 vs plan

- Committed ARR Aug $128.6M, plan $131.0M (−$2.4M, 98%); Jul $124.6M. Monthly actual Jan–Aug 100.4, 103.5, 107.3, 110.8, 114.4, 119.0, 124.6, 128.6 (Tier 2). Plan = actual − gap; gap (actual − plan) Jan–Aug −0.2, −0.6, −0.9, −1.4, −1.9, −2.1, −1.8, −2.4 (Tier 1).
- Aug bridge: opening 124.6, new +3.4, expansion +1.6, contraction −0.6, churn −0.4, reactivation 0, closing 128.6 (Tier 2; bridge must tie exactly).
- Net new ARR Aug $4.0M vs plan $4.6M (87%). By segment actual/plan: Enterprise 2.0/2.4, Mid-market 1.2/1.1, SMB 0.4/0.4, Startups 0.3/0.3, Public sector 0.1/0.4.
- NRR and GRR are trailing 12 months on the cohort of customers active 12 months earlier. Levels follow from the book (Tier 3: company NRR 102–106%, GRR 88–92%). Every segment slice and every region slice, January through August, stays inside NRR 98–112% and GRR 85–95%, and moves at most 1.5 pt month over month. Plan (Tier 1, derived per slice): NRR plan = actual + 0.5 pt, GRR plan = actual + 1 pt.
- Enterprise ARR $66.7M, −$1.1M vs plan. The loss book sits on Enterprise, so the share is about half of company ARR (tier 2 target 49% ±10%). Aug bridge still closes on the planted Enterprise movements (Arcadia, Holloway).
- Top movers Aug: gains Solace, Quarry, Harbor & Pine, Quillon, Tern ($2.1M of $5.0M); losses Veridian, Copperline, Northgate, Alder & Finch, Pellucid ($0.53M of $1.0M).
- Bookings = closed-won new + expansion ACV by close date (Salesforce). ARR = activated orders. So bookings can exceed new + expansion ARR in a month (won-without-order and late activations, e.g. Oakridge and Fennel in August). Plan derived so Jan–Jul beat plan by the contract's margins and August is 89% of plan (Tier 1). Level follows from the data.
- Variance commentary is keyed by (metric, slice). Company committed ARR is M. Alvarez, FP&A, 4 Sep. Segment net-new notes: Enterprise (A. Chen, RevOps, updated 29 Sep, names Oakridge and Fennel), Public sector (J. Okoro, Sales, 5 Sep), Mid-market (R. Patel, Sales, 5 Sep). A slice with no note shows “No commentary for {slice} yet” and never borrows another slice’s text. Every placeholder is requested from Sales leadership on 30 Sep and due 2 Oct, including company bookings. A missing date is omitted, not printed.
- Invariants: ARR behind plan all year and the gap widened in August; Enterprise and Public sector explain the net-new miss; one churned account per remaining segment as listed.

## T2 Sales · Q3 FY26 week 13 vs quota

- Quota Q3 derived (Tier 1) so won QTD = 81%, commit = 91%, best case = 97% of quota. Won QTD and by-month levels follow from bookings; commit call per the contract (week 5 $14.5M → week 13 $13.4M).
- Commit vs quota by segment: Enterprise 6.1/7.2 (85%), Mid-market 3.9/3.6 (108%), SMB 1.3/1.3, Startups 0.9/0.9, Public sector 1.2/1.8 (67%).
- Commit call by week: peaked week 5 at $14.5M, slid $1.1M to $13.4M.
- Pipeline snapshot is weekly (Mondays 06:00 UTC).

## T3 Deal Desk · Wed 30 Sep

See the exceptions table above.

## T4 Finance · Aug 2026 (closed 3 Sep)

- Levels follow from the book. Tier 1: booked not billed at month-end is the 5 named orders ($1.8M), 2 past the invoicing SLA; unmatched invoices are 3 invoices (USD, EUR, JPY) totalling ~$0.4M; July had 1 unmatched invoice.
- Billings: each ARR dollar is invoiced about once a year (mix of annual upfront, quarterly, monthly), plus usage overage in arrears. Tier 3: August billings within ±25% of (ARR ÷ 12 + monthly overage); unmatched share of billings above the 1% tolerance.
- Bookings-to-billings bridge in the contract's categories (bookings → renewals & existing, usage overage, booked not billed, cancels & credits, billed without order → billings) must tie exactly at both ends.
- By invoice currency: USD, EUR, GBP, JPY, CAD, AUD with local and USD billed amounts and unmatched value; unmatched only in USD, EUR, JPY; JPY carries the defect.
- AR aging and DSO. Payment behavior on net-30 terms: most customers pay on time, a minority pay 1–30 and 31–90 days late, a small share goes past 90; invoices over 180 days are written off (uncollectible), so over-90 can't accumulate forever. Collections deteriorate from spring (a growing share of late payers). Tier 3: DSO (month-end AR ÷ trailing-3-month billings × 91) rises Mar→Aug and is 45–50 in August; over-90 roughly doubles Mar→Aug and is 2–3% of AR in August (above the 2% policy); current is the largest bucket every month.
- Usage commits: whatever count and value the book produces. The straight line is the calendar elapsed share of an annual term that is already active on 1 Jan: (day of year) / 365, so 31 Aug is 243/365 = 66.6%. Consumption counted in the chart is usage from 1 Jan onward. Tier 3: consumed share trails that line by 7–12 points in August (about 55–59% consumed), the gap widens over the year, and it is outside the 5-point band.

## T5 Data health · now

- Status by source/model: salesforce Pass; stripe Warn; fct_bookings Pass; fct_billings Warn (upstream stale); rpt_bookings_to_billings Error (3 rows, JPY); fct_arr_monthly Pass; fct_pipeline_snapshot Pass. A model's status is the worst of its own tests and its upstream freshness.
- Incidents seed (`seeds/dq_incidents.csv`): stripe freshness, opened 7h before now; JPY tie-out, opened 2h before now; both owned by A. Dixon; response SLA 4h.
- Backlog (Pass with count): invoices missing order metadata ~7% of invoices; duplicate account pairs pending review; late-arriving Salesforce rows ~1.5%; won without order is a rate: ~4% of deals won in the trailing 90 days arrived without an order (the open ones are the Deal Desk queue).
- Test failure history seed (`seeds/dq_test_history.csv`, labeled simulated): last 30 days by family; freshness has its only failure on 30 Sep (Stripe’s last success is 29 Sep 10:05 UTC, so a 24h SLA cannot fail on the 29th); relationships 2 on 12 Sep and 1 on 13 Sep; reconciliation 1 on 30 Sep; uniqueness none.
- Model-to-page map seed (`seeds/model_page_map.csv`): salesforce → Executive, Sales, Deal Desk; stripe → Finance, Deal Desk; fct_bookings → Executive, Sales, Finance; fct_billings → Finance; rpt_bookings_to_billings → Finance, Deal Desk; fct_arr_monthly → Executive; fct_pipeline_snapshot → Sales.

## Event annotations

`seeds/chart_events.csv`: 2026-06-01, "Commit price change" (appears on the ARR trajectory).
