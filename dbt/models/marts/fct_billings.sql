with invoices as (
    select * from {{ ref('stg_billing__invoice') }}
),

lines as (
    select * from {{ ref('stg_billing__invoice_line_item') }}
),

matched as (
    select invoice_id, order_id
    from {{ ref('int_invoices__to_order') }}
),

orders as (
    select order_id, account_id
    from {{ ref('stg_salesforce__order') }}
),

customers as (
    select customer_id, metadata_salesforce_account_id
    from {{ ref('stg_billing__customer') }}
),

accounts as (
    select account_id, master_account_id
    from {{ ref('int_accounts__deduped') }}
),

fx as (
    select rate_date, currency_code, conversion_rate
    from {{ ref('int_fx__daily_rates') }}
)

select
    l.invoice_line_item_id,
    l.invoice_id,
    m.order_id,
    coalesce(oa.master_account_id, ca.master_account_id) as master_account_id,
    l.metadata_product_code as product_code,
    l.currency,
    cast(i.created as date) as invoice_date,
    l.amount / fx.conversion_rate as billed_usd,
    case
        when i.total = 0 then 0
        else i.amount_paid * (l.amount / i.total) / fx.conversion_rate
    end as paid_usd,
    l.metadata_product_code = 'API-OVER' as is_overage
from lines l
inner join invoices i on l.invoice_id = i.invoice_id
inner join fx
    on fx.rate_date = cast(i.created as date)
   and fx.currency_code = l.currency
left join matched m on l.invoice_id = m.invoice_id
left join orders o on m.order_id = o.order_id
left join accounts oa on o.account_id = oa.account_id
left join customers c on i.customer_id = c.customer_id
left join accounts ca on c.metadata_salesforce_account_id = ca.account_id
where i.status != 'void'
