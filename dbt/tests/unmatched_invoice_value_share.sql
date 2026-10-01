{{ config(severity='warn') }}

-- Unmatched non-void invoice value above 2% of total non-void invoice value.
with invoices as (
    select
        i.invoice_id,
        i.total / fx.conversion_rate as invoice_usd,
        m.match_method
    from {{ ref('stg_billing__invoice') }} i
    inner join {{ ref('int_fx__daily_rates') }} fx
        on fx.rate_date = cast(i.created as date)
       and fx.currency_code = i.currency
    left join {{ ref('int_invoices__to_order') }} m
        on i.invoice_id = m.invoice_id
    where i.status != 'void'
)

select
    sum(invoice_usd) as total_invoice_usd,
    sum(case when match_method = 'unmatched' then invoice_usd else 0 end) as unmatched_invoice_usd
from invoices
having sum(case when match_method = 'unmatched' then invoice_usd else 0 end)
    > 0.02 * sum(invoice_usd)
