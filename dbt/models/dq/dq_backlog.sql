with fx as (
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

won_without_order as (
    select
        'closed_won_without_order' as exception_type,
        o.opportunity_id as record_id,
        o.close_date as first_seen,
        o.amount / coalesce(fx.conversion_rate, latest.conversion_rate) as usd_at_stake
    from {{ ref('stg_salesforce__opportunity') }} o
    left join fx
        on fx.rate_date = o.close_date
       and fx.currency_code = o.currency_iso_code
    left join latest_fx latest on o.currency_iso_code = latest.currency_code
    where o.is_won
      and not exists (
          select 1
          from {{ ref('stg_salesforce__order') }} ord
          where ord.opportunity_id = o.opportunity_id
      )
),

amount_mismatch as (
    select
        'closed_won_amount_line_mismatch' as exception_type,
        o.opportunity_id as record_id,
        cast(o.last_modified_date as date) as first_seen,
        abs(o.amount - coalesce(l.line_amount, 0))
            / coalesce(fx.conversion_rate, latest.conversion_rate) as usd_at_stake
    from {{ ref('stg_salesforce__opportunity') }} o
    left join (
        select
            opportunity_id,
            sum(total_price) as line_amount
        from {{ ref('stg_salesforce__opportunity_line_item') }}
        group by opportunity_id
    ) l on o.opportunity_id = l.opportunity_id
    left join fx
        on fx.rate_date = o.close_date
       and fx.currency_code = o.currency_iso_code
    left join latest_fx latest on o.currency_iso_code = latest.currency_code
    where o.is_won
      and abs(o.amount - coalesce(l.line_amount, 0)) > 0.01
),

open_exceptions as (
    select * from won_without_order
    union all
    select * from amount_mismatch
)

select
    exception_type,
    record_id,
    first_seen,
    date_diff('day', first_seen, {{ as_of_date() }}) as age_days,
    usd_at_stake
from open_exceptions
