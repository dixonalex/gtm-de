-- Deal Desk counts at owner × exception type, for today and yesterday, plus the 7-day resolution.
with clock as (
    select cast(now as date) as as_of
    from {{ ref('stg_fivetran_log__extract_clock') }}
),

days as (
    select as_of as snapshot_date, 0 as day_offset from clock
    union all
    select as_of - interval 1 day, 1 from clock
),

open_rows as (
    select
        d.day_offset,
        e.owner_name,
        e.exception_type,
        e.amount_usd,
        case when d.day_offset = 0 then e.age_days else e.age_days - 1 end as age_days,
        e.sla_bd
    from {{ ref('fct_deal_desk_exception') }} e
    cross join days d
    where e.opened_on <= d.snapshot_date
      and (e.resolved_on is null or e.resolved_on > d.snapshot_date)
),

open_agg as (
    select
        day_offset,
        coalesce(owner_name, 'All') as owner_name,
        coalesce(exception_type, 'All') as exception_type,
        count(*) as open_count,
        sum(amount_usd) as open_amount_usd,
        count(*) filter (where age_days > sla_bd) as past_sla_count,
        sum(amount_usd) filter (where age_days > sla_bd) as past_sla_amount_usd,
        count(*) filter (where age_days + 1 = sla_bd) as breach_tomorrow_count,
        sum(amount_usd) filter (where age_days + 1 = sla_bd) as breach_tomorrow_amount_usd
    from open_rows
    group by grouping sets (
        (day_offset),
        (day_offset, owner_name),
        (day_offset, exception_type),
        (day_offset, owner_name, exception_type)
    )
),

movement as (
    select
        coalesce(owner_name, 'All') as owner_name,
        coalesce(exception_type, 'All') as exception_type,
        count(*) filter (where opened_on = (select as_of from clock)) as opened_count,
        coalesce(sum(amount_usd) filter (where opened_on = (select as_of from clock)), 0) as opened_amount_usd,
        count(*) filter (where resolved_on = (select as_of from clock)) as resolved_today_count,
        coalesce(sum(amount_usd) filter (where resolved_on = (select as_of from clock)), 0) as resolved_today_amount_usd
    from {{ ref('fct_deal_desk_exception') }}
    group by grouping sets (
        (),
        (owner_name),
        (exception_type),
        (owner_name, exception_type)
    )
),

resolved as (
    select
        coalesce(owner_name, 'All') as owner_name,
        coalesce(exception_type, 'All') as exception_type,
        count(*) as resolved_count,
        sum(amount_usd) as resolved_amount_usd,
        median(age_days) as resolved_median_days,
        count(*) filter (where past_sla) as resolved_past_sla_count
    from {{ ref('fct_deal_desk_exception') }}
    where not is_open
      and resolved_on >= (select as_of from clock) - interval 7 day
    group by grouping sets (
        (),
        (owner_name),
        (exception_type),
        (owner_name, exception_type)
    )
)

select
    t.owner_name,
    t.exception_type,
    t.open_count,
    t.open_amount_usd,
    t.past_sla_count,
    t.past_sla_amount_usd,
    t.breach_tomorrow_count,
    t.breach_tomorrow_amount_usd,
    y.open_count as yesterday_open_count,
    y.open_amount_usd as yesterday_open_amount_usd,
    y.past_sla_count as yesterday_past_sla_count,
    y.breach_tomorrow_count as yesterday_breach_tomorrow_count,
    m.opened_count,
    m.opened_amount_usd,
    m.resolved_today_count,
    m.resolved_today_amount_usd,
    r.resolved_count,
    r.resolved_amount_usd,
    r.resolved_median_days,
    r.resolved_past_sla_count
from open_agg t
left join open_agg y
    on y.day_offset = 1
   and t.owner_name = y.owner_name
   and t.exception_type = y.exception_type
left join movement m
    on t.owner_name = m.owner_name
   and t.exception_type = m.exception_type
left join resolved r
    on t.owner_name = r.owner_name
   and t.exception_type = r.exception_type
where t.day_offset = 0
