| Source or mart | Freshness SLA | Test coverage | Severity | Owner |
| --- | --- | --- | --- | --- |
| salesforce.opportunity, opportunity_history | warn 48h, error 7d on `_loaded_at` | source freshness | warn / error | Data |
| salesforce account, user, product, price book, dated rates | none on the row; connector sync covers them | — | — | Data |
| salesforce staging | parent or connector freshness | `_loaded_at` − SystemModstamp > 72h is an incident when `_loaded_at` is within 7 days of as-of; older rows are backlog | warn | Data |
| billing.invoice, billing.charge | warn 48h, error 7d on `_loaded_at` | source freshness | warn / error | Data |
| billing customer, invoice line, usage summary | none on the row; connector sync covers them | — | — | Data |
| fivetran_log salesforce sync | warn 2h, error 6h | source freshness, successful syncs | warn / error | Data |
| fivetran_log stripe sync | warn 24h, error 48h | source freshness, successful syncs | warn / error | Data |
| fct_arr_monthly | month-ends through the Salesforce sync date | ARR bridge ties out per master-month | error | Finance |
| fct_billings | invoice freshness | billed USD vs non-void invoice totals within 0.5% | error | Finance |
| fct_bookings | order follows the opportunity parent | every Closed Won is in bookings or an exception with a reason | error | RevOps |
| rpt_quote_to_cash_exceptions | — | won-without-order and amount mismatch are incidents when CloseDate or LastModifiedDate is within 7 days of as-of; unmatched invoice value above 2% | warn | RevOps / Finance |
| dq_backlog | — | won-without-order older than 30 days with more than $25k at stake | warn | RevOps |
| dq_account_review_queue | — | pending pair ARR at stake > $50k; queue size > 100 | warn | RevOps |

An ERROR fails `dbt build`. The ARR bridge, the billings tie-out, or a Closed Won opportunity with neither a booking nor an exception means a published number is wrong, and Finance or RevOps should not use that mart until Data fixes it.

A WARN leaves the build green. It is work still open: a new late Salesforce row, a new Closed Won deal with no order, a new amount mismatch, unmatched invoices above 2% of invoice value, an aged won-without-order above $25k, or a steward pair with more than $50k of ARR at stake. The named owner clears it. A pending queue above 100 pairs is the same kind of warn. Connector freshness warns mean the sync is late; an error-level freshness breach means the extract is too stale to trust.

An incident is an open exception whose triggering timestamp is within 7 days of the warehouse as-of date: `_loaded_at` for late Salesforce rows, CloseDate for Closed Won without an order, and LastModifiedDate for an amount mismatch. Older rows stay in `dq_backlog` with first_seen, age_days, and USD at stake where the exception has an amount. A won-without-order older than 30 days with more than $25,000 at stake warns even though it is no longer an incident.
