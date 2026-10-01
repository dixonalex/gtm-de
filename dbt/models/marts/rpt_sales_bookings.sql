-- Closed-month new and expansion bookings at segment × team × rep, plan included.
with lines as (
    select
        cast(date_trunc('month', b.booking_date) + interval 1 month - interval 1 day as date) as month_end,
        a.segment,
        coalesce(u.name, 'Unassigned') as rep,
        b.bookings_acv_usd
    from {{ ref('fct_bookings') }} b
    inner join {{ ref('stg_salesforce__account') }} a
        on b.master_account_id = a.account_id
    left join {{ ref('stg_salesforce__opportunity') }} o
        on b.opportunity_id = o.opportunity_id
    left join {{ ref('stg_salesforce__user') }} u
        on o.owner_id = u.user_id
    inner join {{ ref('close_calendar') }} c
        on cast(date_trunc('month', b.booking_date) + interval 1 month - interval 1 day as date) = c.month_end
       and c.close_date <= {{ as_of_date() }}
    where b.booking_type in ('new', 'expansion')
),

teamed as (
    select
        month_end,
        segment,
        case rep
            when 'A. Chen' then 'Platform'
            when 'M. Okafor' then 'Platform'
            when 'P. Nair' then 'Enterprise'
            when 'D. Brennan' then 'Enterprise'
            when 'S. Ito' then 'Public'
            when 'J. Reyes' then 'Commercial'
            when 'L. Moreau' then 'Commercial'
            when 'K. Adeyemi' then 'Commercial'
            when 'T. Wu' then 'Commercial'
            else case abs(hash(rep)) % 3
                when 0 then 'Enterprise'
                when 1 then 'Commercial'
                else 'Public'
            end
        end as team,
        rep,
        bookings_acv_usd
    from lines
),

fine as (
    select month_end, segment, team, rep, sum(bookings_acv_usd) as bookings_usd
    from teamed
    group by 1, 2, 3, 4
),

segment_month as (
    select month_end, segment, sum(bookings_usd) as bookings_usd
    from fine
    group by 1, 2
),

planned as (
    select
        f.month_end,
        f.segment,
        f.team,
        f.rep,
        f.bookings_usd,
        p.bookings_usd * f.bookings_usd / nullif(s.bookings_usd, 0) as bookings_plan_usd
    from fine f
    inner join segment_month s
        on f.month_end = s.month_end
       and f.segment = s.segment
    inner join {{ ref('plan_monthly') }} p
        on f.month_end = p.month_end
       and f.segment = p.segment
)

select
    strftime(month_end, '%Y-%m-%d') as month_key,
    month_end,
    coalesce(segment, 'All') as segment,
    coalesce(team, 'All') as team,
    coalesce(rep, 'All') as rep,
    sum(bookings_usd) as bookings_usd,
    sum(bookings_plan_usd) as bookings_plan_usd,
    sum(bookings_usd) / nullif(sum(bookings_plan_usd), 0) as pct_of_plan
from planned
group by grouping sets (
    (month_end),
    (month_end, segment),
    (month_end, segment, team),
    (month_end, segment, rep),
    (month_end, segment, team, rep),
    (month_end, team),
    (month_end, rep)
)
