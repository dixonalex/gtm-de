with orders as (
    select * from {{ ref('stg_salesforce__order') }}
),

order_items as (
    select * from {{ ref('stg_salesforce__order_item') }}
),

products as (
    select product_id, product_code
    from {{ ref('stg_salesforce__product2') }}
),

opportunities as (
    select opportunity_id, close_date
    from {{ ref('stg_salesforce__opportunity') }}
),

accounts as (
    select account_id, master_account_id
    from {{ ref('int_accounts__deduped') }}
),

fx as (
    select rate_date, currency_code, conversion_rate
    from {{ ref('int_fx__daily_rates') }}
),

-- Cancel date is Order.Cancelled_Date__c, staged as cancelled_date.
items as (
    select
        oi.order_item_id,
        oi.order_id,
        o.account_id,
        a.master_account_id,
        o.opportunity_id,
        p.product_code,
        o.currency_iso_code,
        oi.quantity,
        case
            when o.is_reduction_order then 'reduction'
            when o.type = 'Add-On' then 'expansion'
            when o.type = 'Renewal' then 'renewal'
            when o.type = 'New' then 'new'
        end as booking_type,
        case
            when o.opportunity_id is not null then opp.close_date
            else o.effective_date
        end as booking_date,
        o.cancelled_date as cancel_date,
        case
            when oi.end_date is not null then oi.quantity * oi.unit_price
            else 0
        end as acv_local,
        case
            when oi.end_date is null then oi.quantity * oi.unit_price
            else 0
        end as one_time_local
    from order_items oi
    inner join orders o on oi.order_id = o.order_id
    inner join products p on oi.product_id = p.product_id
    inner join accounts a on o.account_id = a.account_id
    left join opportunities opp on o.opportunity_id = opp.opportunity_id
),

valued as (
    select
        i.order_item_id,
        i.order_id,
        i.account_id,
        i.master_account_id,
        i.opportunity_id,
        i.product_code,
        i.currency_iso_code,
        i.quantity,
        i.booking_type,
        i.booking_date,
        i.cancel_date,
        i.acv_local / fx.conversion_rate as bookings_acv_usd,
        i.one_time_local / fx.conversion_rate as one_time_usd
    from items i
    inner join fx
        on fx.rate_date = i.booking_date
       and fx.currency_code = i.currency_iso_code
)

select
    order_item_id,
    order_id,
    account_id,
    master_account_id,
    opportunity_id,
    product_code,
    currency_iso_code,
    quantity,
    booking_type,
    booking_date,
    bookings_acv_usd,
    one_time_usd
from valued

union all

select
    order_item_id,
    order_id,
    account_id,
    master_account_id,
    opportunity_id,
    product_code,
    currency_iso_code,
    -quantity as quantity,
    'cancellation' as booking_type,
    cancel_date as booking_date,
    -bookings_acv_usd as bookings_acv_usd,
    -one_time_usd as one_time_usd
from valued
where cancel_date is not null
