with orders as (
    select
        order_id,
        account_id,
        status as order_status
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
    inner join fx
        on fx.rate_date = s.slot_start
       and fx.currency_code = s.currency_iso_code
    where s.slot_start <= current_date
    group by s.order_id
),

billed as (
    select
        order_id,
        sum(billed_usd) filter (where not is_overage) as billed_to_date_usd,
        sum(billed_usd) filter (where is_overage) as overage_billed_usd
    from {{ ref('fct_billings') }}
    where order_id is not null
    group by order_id
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
        coalesce(b.billed_to_date_usd, 0) - coalesce(e.expected_billed_to_date_usd, 0) as variance_usd
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
