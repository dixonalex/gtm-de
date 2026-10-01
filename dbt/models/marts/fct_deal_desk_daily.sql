-- One row per extract day the queue can be compared: as-of, and the business day before it.
with clock as (
    select cast(now as date) as as_of
    from {{ ref('stg_fivetran_log__extract_clock') }}
),

days as (
    select as_of as snapshot_date, 0 as day_offset from clock
    union all
    select as_of - interval 1 day, 1 from clock
),

open_on as (
    select
        d.snapshot_date,
        d.day_offset,
        e.account_name,
        e.record_id,
        e.exception_type,
        e.amount_usd,
        e.owner_name,
        e.sla_bd,
        case
            when d.day_offset = 0 then e.age_days
            else e.age_days - 1
        end as age_days
    from {{ ref('fct_deal_desk_exception') }} e
    cross join days d
    where e.opened_on <= d.snapshot_date
      and (e.resolved_on is null or e.resolved_on > d.snapshot_date)
)

select
    snapshot_date,
    count(*) as open_count,
    sum(amount_usd) as open_amount_usd,
    count(*) filter (where age_days > sla_bd) as past_sla_count,
    sum(amount_usd) filter (where age_days > sla_bd) as past_sla_amount_usd,
    count(*) filter (where age_days + 1 = sla_bd) as breach_tomorrow_count,
    sum(amount_usd) filter (where age_days + 1 = sla_bd) as breach_tomorrow_amount_usd
from open_on
group by snapshot_date
