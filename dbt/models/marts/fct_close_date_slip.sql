with history as (
    select
        opportunity_id,
        close_date,
        cast(created_date as date) as changed_on,
        lag(close_date) over (
            partition by opportunity_id
            order by created_date, system_modstamp, opportunity_history_id
        ) as previous_close_date
    from {{ ref('stg_salesforce__opportunity_history') }}
),

slips as (
    select
        opportunity_id,
        previous_close_date,
        close_date,
        changed_on,
        date_diff('day', previous_close_date, close_date) as days_slipped
    from history
    where previous_close_date is not null
      and close_date > previous_close_date
      and changed_on >= date_trunc('quarter', {{ as_of_date() }})
      and changed_on <= {{ as_of_date() }}
),

opportunities as (
    select
        opportunity_id,
        account_id,
        name,
        currency_iso_code,
        amount
    from {{ ref('stg_salesforce__opportunity') }}
),

accounts as (
    select account_id, name
    from {{ ref('stg_salesforce__account') }}
),

fx as (
    select rate_date, currency_code, conversion_rate
    from {{ ref('int_fx__daily_rates') }}
),

latest_fx as (
    select currency_code, conversion_rate
    from fx
    qualify row_number() over (
        partition by currency_code
        order by rate_date desc
    ) = 1
)

select
    s.opportunity_id,
    o.name as opportunity_name,
    a.name as account_name,
    s.previous_close_date,
    s.close_date,
    s.changed_on,
    s.days_slipped,
    o.amount / coalesce(fx.conversion_rate, latest.conversion_rate) as amount_usd
from slips s
inner join opportunities o on s.opportunity_id = o.opportunity_id
inner join accounts a on o.account_id = a.account_id
left join fx
    on fx.rate_date = s.changed_on
   and fx.currency_code = o.currency_iso_code
left join latest_fx latest on o.currency_iso_code = latest.currency_code
