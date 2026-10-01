with orders as (
    select * from {{ ref('stg_salesforce__order') }}
),

opportunities as (
    select
        opportunity_id,
        synced_quote_id
    from {{ ref('stg_salesforce__opportunity') }}
),

accounts as (
    select
        account_id,
        master_account_id
    from {{ ref('int_accounts__deduped') }}
),

invoice_rollup as (
    select
        order_id,
        count(*) as matched_invoice_count,
        count(*) filter (where match_method = 'metadata') as metadata_invoice_count,
        count(*) filter (where match_method like 'fuzzy%') as fuzzy_invoice_count
    from {{ ref('int_invoices__to_order') }}
    where match_method not in ('unmatched', 'opportunity_no_order')
    group by order_id
)

select
    o.order_id,
    o.account_id,
    a.master_account_id,
    o.opportunity_id,
    opp.synced_quote_id,
    o.quote_id,
    o.effective_date,
    o.currency_iso_code,
    o.billing_frequency_c,
    o.status,
    o.is_reduction_order,
    coalesce(inv.matched_invoice_count, 0) as matched_invoice_count,
    coalesce(inv.metadata_invoice_count, 0) as metadata_invoice_count,
    coalesce(inv.fuzzy_invoice_count, 0) as fuzzy_invoice_count
from orders o
left join opportunities opp on o.opportunity_id = opp.opportunity_id
left join accounts a on o.account_id = a.account_id
left join invoice_rollup inv on o.order_id = inv.order_id
