with orders as (
    select
        order_id,
        account_id,
        status as order_status,
        effective_date,
        cancelled_date
    from {{ ref('stg_salesforce__order') }}
),

accounts as (
    select account_id, master_account_id
    from {{ ref('int_accounts__deduped') }}
),

fx as (
    select rate_date, currency_code, conversion_rate
    from {{ ref('int_fx__daily_rates') }}
),

contract as (
    select
        order_id,
        sum(bookings_acv_usd + one_time_usd) as contract_value_usd
    from {{ ref('fct_bookings') }}
    where booking_type != 'cancellation'
    group by order_id
),

expected as (
    select
        s.order_id,
        sum(s.expected_amount / fx.conversion_rate) as expected_billed_to_date_usd
    from {{ ref('int_orders__billing_schedule') }} s
    inner join orders o on s.order_id = o.order_id
    inner join fx
        on fx.rate_date = s.slot_start
       and fx.currency_code = s.currency_iso_code
    where o.order_status != 'Draft'
      and o.effective_date <= {{ as_of_date() }}
      and s.slot_start <= {{ as_of_date() }}
      and (
          o.order_status != 'Cancelled'
          or s.slot_start <= o.cancelled_date
      )
    group by s.order_id
),

-- fct_billings drops void invoices, so a void contributes nothing here.
billed as (
    select
        b.order_id,
        sum(b.billed_usd) filter (
            where not b.is_overage and i.status is distinct from 'void'
        ) as billed_to_date_usd,
        sum(b.billed_usd) filter (
            where b.is_overage and i.status is distinct from 'void'
        ) as overage_billed_usd
    from {{ ref('fct_billings') }} b
    left join {{ ref('stg_billing__invoice') }} i on b.invoice_id = i.invoice_id
    where b.order_id is not null
    group by b.order_id
),

compared as (
    select
        o.order_id,
        o.account_id,
        a.master_account_id,
        o.order_status,
        coalesce(c.contract_value_usd, 0) as contract_value_usd,
        coalesce(e.expected_billed_to_date_usd, 0) as expected_billed_to_date_usd,
        coalesce(b.billed_to_date_usd, 0) as billed_to_date_usd,
        coalesce(b.overage_billed_usd, 0) as overage_billed_usd,
        case
            when o.order_status = 'Activated'
                then coalesce(b.billed_to_date_usd, 0) - coalesce(e.expected_billed_to_date_usd, 0)
        end as variance_usd
    from orders o
    inner join accounts a on o.account_id = a.account_id
    left join contract c on o.order_id = c.order_id
    left join expected e on o.order_id = e.order_id
    left join billed b on o.order_id = b.order_id
)

select
    order_id,
    account_id,
    master_account_id,
    contract_value_usd,
    expected_billed_to_date_usd,
    billed_to_date_usd,
    overage_billed_usd,
    variance_usd,
    case
        when order_status = 'Draft' then 'draft'
        when order_status = 'Cancelled' then 'cancelled'
        when abs(variance_usd) <= 0.01 * abs(expected_billed_to_date_usd)
          or abs(variance_usd) <= 1
            then 'on_schedule'
        when billed_to_date_usd < expected_billed_to_date_usd then 'under_billed'
        else 'over_billed'
    end as status
from compared
