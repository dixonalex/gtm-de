with recursive orders as (
    select * from {{ ref('stg_salesforce__order') }}
),

order_items as (
    select * from {{ ref('stg_salesforce__order_item') }}
),

invoices as (
    select * from {{ ref('stg_billing__invoice') }}
),

customers as (
    select * from {{ ref('stg_billing__customer') }}
),

accounts as (
    select * from {{ ref('int_accounts__deduped') }}
),

order_expected as (
    select
        o.order_id,
        o.effective_date,
        o.currency_iso_code,
        a.master_account_id,
        sum(
            case
                when oi.end_date is not null then oi.quantity * oi.unit_price * (
                    case o.billing_frequency_c
                        when 'Annual' then 12
                        when 'Quarterly' then 3
                        when 'Monthly' then 1
                    end
                ) / 12
                else oi.quantity * oi.unit_price
            end
        ) as first_invoice_amount
    from orders o
    inner join order_items oi on o.order_id = oi.order_id
    inner join accounts a on o.account_id = a.account_id
    group by o.order_id, o.effective_date, o.currency_iso_code, a.master_account_id
),

metadata_match as (
    select
        i.invoice_id,
        i.metadata_salesforce_order_id as order_id
    from invoices i
    inner join orders o on i.metadata_salesforce_order_id = o.order_id
    where i.metadata_salesforce_order_id is not null
),

slot_taken as (
    select distinct m.order_id
    from metadata_match m
    inner join invoices i on m.invoice_id = i.invoice_id
    inner join order_expected e on m.order_id = e.order_id
    where abs(i.total - e.first_invoice_amount) <= 0.01 * abs(e.first_invoice_amount)
      and abs(date_diff('day', e.effective_date, cast(i.created as date))) <= 45
),

candidates as (
    select
        i.invoice_id,
        e.order_id,
        abs(i.total - e.first_invoice_amount) as amount_delta,
        abs(date_diff('day', e.effective_date, cast(i.created as date))) as date_delta
    from invoices i
    inner join customers c on i.customer_id = c.customer_id
    inner join accounts ca on c.metadata_salesforce_account_id = ca.account_id
    inner join order_expected e
        on e.master_account_id = ca.master_account_id
       and e.currency_iso_code = i.currency
    left join metadata_match m on i.invoice_id = m.invoice_id
    left join slot_taken s on e.order_id = s.order_id
    where m.invoice_id is null
      and s.order_id is null
      and abs(i.total - e.first_invoice_amount) <= 0.01 * abs(e.first_invoice_amount)
      and abs(date_diff('day', e.effective_date, cast(i.created as date))) <= 45
),

ranked as (
    select
        invoice_id,
        order_id,
        row_number() over (
            order by amount_delta, date_delta, order_id, invoice_id
        ) as rn
    from candidates
),

walk as (
    select
        r.rn,
        r.invoice_id,
        r.order_id,
        r.invoice_id as used_invoices,
        r.order_id as used_orders
    from ranked r
    where r.rn = 1

    union all

    select
        r.rn,
        case
            when not contains(',' || w.used_invoices || ',', ',' || r.invoice_id || ',')
             and not contains(',' || w.used_orders || ',', ',' || r.order_id || ',')
            then r.invoice_id
        end as invoice_id,
        case
            when not contains(',' || w.used_invoices || ',', ',' || r.invoice_id || ',')
             and not contains(',' || w.used_orders || ',', ',' || r.order_id || ',')
            then r.order_id
        end as order_id,
        case
            when not contains(',' || w.used_invoices || ',', ',' || r.invoice_id || ',')
             and not contains(',' || w.used_orders || ',', ',' || r.order_id || ',')
            then w.used_invoices || ',' || r.invoice_id
            else w.used_invoices
        end as used_invoices,
        case
            when not contains(',' || w.used_invoices || ',', ',' || r.invoice_id || ',')
             and not contains(',' || w.used_orders || ',', ',' || r.order_id || ',')
            then w.used_orders || ',' || r.order_id
            else w.used_orders
        end as used_orders
    from walk w
    inner join ranked r on r.rn = w.rn + 1
),

fuzzy_match as (
    select invoice_id, order_id
    from walk
    where invoice_id is not null
)

select
    i.invoice_id,
    coalesce(m.order_id, f.order_id) as order_id,
    case
        when m.invoice_id is not null then 'metadata'
        when f.invoice_id is not null then 'fuzzy'
        else 'unmatched'
    end as match_method
from invoices i
left join metadata_match m on i.invoice_id = m.invoice_id
left join fuzzy_match f on i.invoice_id = f.invoice_id
