-- Commentary rows for a view slice. The page filters view_segment and view_region.
-- Rows are the balance and flow metrics outside their band, plus bookings.
with base as (
    select * from {{ ref('rpt_executive_month') }}
),

notes as (
    select
        metric,
        coalesce(nullif(segment, ''), 'All') as segment,
        author,
        role,
        updated_on,
        requested_on,
        due_on,
        requested_from,
        commentary
    from {{ ref('variance_commentary') }}
),

rows as (
    select
        month_end,
        month_key,
        'All' as view_segment,
        'All' as view_region,
        1 as sort_order,
        'Committed ARR' as label,
        committed_arr_usd as actual_usd,
        arr_plan_usd as plan_usd,
        'balance' as band,
        'committed_arr' as metric,
        'All' as note_segment
    from base
    where segment = 'All' and region = 'All'
      and abs(committed_arr_usd - arr_plan_usd) / nullif(abs(arr_plan_usd), 0) > 0.01

    union all

    select
        month_end,
        month_key,
        segment,
        'All',
        1,
        'Committed ARR',
        committed_arr_usd,
        arr_plan_usd,
        'balance',
        'committed_arr',
        'All'
    from base
    where segment != 'All' and region = 'All'
      and abs(committed_arr_usd - arr_plan_usd) / nullif(abs(arr_plan_usd), 0) > 0.01

    union all

    select
        month_end,
        month_key,
        'All',
        'All',
        2,
        'Net new ARR · ' || segment,
        net_new_usd,
        net_new_plan_usd,
        'flow',
        'net_new',
        segment
    from base
    where segment != 'All' and region = 'All'
      and abs(net_new_usd - net_new_plan_usd) / nullif(abs(net_new_plan_usd), 0) > 0.05

    union all

    select
        month_end,
        month_key,
        segment,
        'All',
        2,
        'Net new ARR · ' || segment,
        net_new_usd,
        net_new_plan_usd,
        'flow',
        'net_new',
        segment
    from base
    where segment != 'All' and region = 'All'
      and abs(net_new_usd - net_new_plan_usd) / nullif(abs(net_new_plan_usd), 0) > 0.05

    union all

    select
        month_end,
        month_key,
        segment,
        region,
        3,
        'Bookings',
        bookings_usd,
        bookings_plan_usd,
        'flow',
        'bookings',
        'All'
    from base
    where not (segment != 'All' and region != 'All')
)

select
    r.month_end,
    r.month_key,
    r.view_segment,
    r.view_region,
    r.sort_order,
    r.label,
    r.actual_usd,
    r.plan_usd,
    r.actual_usd - r.plan_usd as delta_usd,
    r.actual_usd / nullif(r.plan_usd, 0) as pct_of_plan,
    r.band,
    n.author,
    n.role,
    n.updated_on,
    n.requested_on,
    n.due_on,
    n.requested_from,
    n.commentary
from rows r
left join notes n
    on r.metric = n.metric
   and r.note_segment = n.segment
