| Source or mart | Freshness SLA | Test coverage | Severity | Owner |
| --- | --- | --- | --- | --- |
| salesforce.opportunity, opportunity_history | warn 48h, error 7d on `_loaded_at` | source freshness | warn / error | Data |
| salesforce account, user, product, price book, dated rates | none on the row; connector sync covers them | — | — | Data |
| salesforce line items, quote, order, order item | parent row arrival | `_loaded_at` − SystemModstamp > 72h, all Salesforce staging | warn | Data |
| billing.invoice, billing.charge | warn 48h, error 7d on `_loaded_at` | source freshness | warn / error | Data |
| billing customer, invoice line, usage summary | none on the row; connector sync covers them | — | — | Data |
| fivetran_log salesforce sync | warn 2h, error 6h | source freshness, successful syncs | warn / error | Data |
| fivetran_log stripe sync | warn 24h, error 48h | source freshness, successful syncs | warn / error | Data |
| fct_arr_monthly | month-ends through the Salesforce sync date | ARR bridge ties out per master-month | error | Finance |
| fct_billings | invoice freshness | billed USD vs non-void invoice totals within 0.5% | error | Finance |
| fct_bookings | order follows the opportunity parent | every Closed Won is in bookings or an exception with a reason | error | RevOps |
| rpt_quote_to_cash_exceptions | — | won-without-order count > 0; Closed Won amount vs lines; unmatched invoice value above 2% | warn | RevOps / Finance |
| dq_account_review_queue | — | pending pair ARR at stake > $50k; queue size > 100 | warn | RevOps |

An ERROR fails `dbt build`. The ARR bridge, the billings tie-out, or a Closed Won opportunity with neither a booking nor an exception means a published number is wrong, and Finance or RevOps should not use that mart until Data fixes it.

A WARN leaves the build green. It is work still open: a Salesforce row more than 72 hours behind its SystemModstamp, a Closed Won deal with no order, an amount that does not match its lines, unmatched invoices above 2% of invoice value, or a steward pair with more than $50k of ARR at stake. The named owner clears it. A pending queue above 100 pairs is the same kind of warn. Connector freshness warns mean the sync is late; an error-level freshness breach means the extract is too stale to trust.
