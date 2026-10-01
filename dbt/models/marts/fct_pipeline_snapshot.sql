with opportunities as (
    select
        opportunity_id,
        account_id,
        currency_iso_code
    from {{ ref('stg_salesforce__opportunity') }}
),

history as (
    select * from {{ ref('stg_salesforce__opportunity_history') }}
),

accounts as (
    select account_id, master_account_id
    from {{ ref('int_accounts__deduped') }}
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
),

month_ends as (
    select cast(
        date_trunc('month', gs) + interval 1 month - interval 1 day
        as date
    ) as month_end
    from generate_series(
        date_trunc('month', (select min(cast(created_date as date)) from history)),
        date_trunc('month', {{ as_of_date() }}),
        interval 1 month
    ) t(gs)
    where cast(date_trunc('month', gs) + interval 1 month - interval 1 day as date) <= {{ as_of_date() }}
      and cast(date_trunc('month', gs) + interval 1 month - interval 1 day as date) in (
          select month_end from {{ ref('close_calendar') }} where close_date <= {{ as_of_date() }}
      )
),

as_of as (
    select
        me.month_end,
        h.opportunity_id,
        h.stage_name,
        h.forecast_category,
        h.close_date,
        h.amount,
        h.probability
    from month_ends me
    inner join history h on cast(h.created_date as date) <= me.month_end
    qualify row_number() over (
        partition by me.month_end, h.opportunity_id
        order by h.created_date desc, h.system_modstamp desc, h.opportunity_history_id desc
    ) = 1
)

select
    a.opportunity_id,
    a.month_end,
    o.account_id,
    d.master_account_id,
    a.stage_name,
    a.forecast_category,
    a.close_date,
    a.amount / coalesce(fx.conversion_rate, latest.conversion_rate) as amount_usd,
    a.probability
from as_of a
inner join opportunities o on a.opportunity_id = o.opportunity_id
inner join accounts d on o.account_id = d.account_id
left join fx
    on fx.rate_date = a.close_date
   and fx.currency_code = o.currency_iso_code
left join latest_fx latest on o.currency_iso_code = latest.currency_code
where a.stage_name not in ('Closed Won', 'Closed Lost')
