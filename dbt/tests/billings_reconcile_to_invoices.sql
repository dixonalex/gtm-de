-- Sum of billed USD stays within 0.5% of non-void invoice totals in USD.
with billed as (
    select sum(billed_usd) as billed_usd
    from {{ ref('fct_billings') }}
),

invoices as (
    select sum(i.total / fx.conversion_rate) as invoice_usd
    from {{ ref('stg_billing__invoice') }} i
    inner join {{ ref('int_fx__daily_rates') }} fx
        on fx.rate_date = cast(i.created as date)
       and fx.currency_code = i.currency
    where i.status != 'void'
)

select
    billed.billed_usd,
    invoices.invoice_usd
from billed
cross join invoices
where invoices.invoice_usd is null
   or billed.billed_usd is null
   or abs(billed.billed_usd - invoices.invoice_usd) > 0.005 * abs(invoices.invoice_usd)
