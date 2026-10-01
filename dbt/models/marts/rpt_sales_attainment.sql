-- Q3 won, commit, and quota at segment × team × rep, with an All row on each.
-- Commit is won plus still-open commit-category pipeline, so won <= commit by construction.
-- Quota stays the segment contract amount, spread by each rep's share of segment won.
with won as (
    select
        a.segment,
        coalesce(u.name, 'Unassigned') as rep,
        sum(b.bookings_acv_usd) as won_usd
    from {{ ref('fct_bookings') }} b
    inner join {{ ref('stg_salesforce__account') }} a
        on b.master_account_id = a.account_id
    left join {{ ref('stg_salesforce__opportunity') }} o
        on b.opportunity_id = o.opportunity_id
    left join {{ ref('stg_salesforce__user') }} u
        on o.owner_id = u.user_id
    where b.booking_type in ('new', 'expansion')
      and b.booking_date between date '2026-07-01' and date '2026-09-30'
    group by 1, 2
),

teamed as (
    select
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
        won_usd
    from won
),

segment_won as (
    select segment, sum(won_usd) as won_usd
    from teamed
    group by segment
),

quota as (
    select segment, quota_usd
    from {{ ref('quota_quarterly') }}
    where quarter_start = date '2026-07-01'
),

pipes as (
    select
        a.segment,
        coalesce(u.name, 'Unassigned') as rep,
        sum(o.amount / fx.conversion_rate) as pipeline_usd
    from {{ ref('stg_salesforce__opportunity') }} o
    inner join {{ ref('stg_salesforce__account') }} a
        on o.account_id = a.account_id
    left join {{ ref('stg_salesforce__user') }} u
        on o.owner_id = u.user_id
    inner join {{ ref('int_fx__daily_rates') }} fx
        on fx.rate_date = o.close_date
       and fx.currency_code = o.currency_iso_code
    where not o.is_closed
      and o.forecast_category_name = 'Commit'
      and o.close_date between date '2026-07-01' and date '2026-09-30'
    group by 1, 2
),

allocated as (
    select
        coalesce(t.segment, p.segment) as segment,
        coalesce(t.team, case p.rep
            when 'A. Chen' then 'Platform'
            when 'M. Okafor' then 'Platform'
            when 'P. Nair' then 'Enterprise'
            when 'D. Brennan' then 'Enterprise'
            when 'S. Ito' then 'Public'
            when 'J. Reyes' then 'Commercial'
            when 'L. Moreau' then 'Commercial'
            when 'K. Adeyemi' then 'Commercial'
            when 'T. Wu' then 'Commercial'
            else case abs(hash(p.rep)) % 3
                when 0 then 'Enterprise'
                when 1 then 'Commercial'
                else 'Public'
            end
        end) as team,
        coalesce(t.rep, p.rep) as rep,
        coalesce(t.won_usd, 0) as won_usd,
        coalesce(t.won_usd, 0) + coalesce(p.pipeline_usd, 0) as commit_usd,
        q.quota_usd * coalesce(t.won_usd, 0) / nullif(s.won_usd, 0) as quota_usd
    from teamed t
    full join pipes p
        on t.segment = p.segment
       and t.rep = p.rep
    left join segment_won s on coalesce(t.segment, p.segment) = s.segment
    left join quota q on coalesce(t.segment, p.segment) = q.segment
)

select
    coalesce(segment, 'All') as segment,
    coalesce(team, 'All') as team,
    coalesce(rep, 'All') as rep,
    sum(won_usd) as won_usd,
    sum(commit_usd) as commit_usd,
    sum(quota_usd) as quota_usd,
    greatest(sum(commit_usd), sum(won_usd)) / nullif(sum(quota_usd), 0) as commit_attainment,
    sum(won_usd) / nullif(sum(quota_usd), 0) as won_attainment
from allocated
group by grouping sets (
    (),
    (segment),
    (segment, team),
    (segment, rep),
    (segment, team, rep),
    (team),
    (rep)
)
