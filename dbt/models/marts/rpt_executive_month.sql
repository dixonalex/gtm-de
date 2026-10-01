-- One row per closed month × segment × region, including an All row on each dimension.
-- Rates and plan percentages are computed here. A page selects a row; it does not sum.
with bridge as (
    select
        month_end,
        segment,
        region,
        opening_arr_usd,
        arr_new_usd,
        arr_expansion_usd,
        arr_contraction_usd,
        arr_churn_usd,
        arr_reactivation_usd,
        committed_arr_usd,
        arr_new_usd + arr_expansion_usd + arr_contraction_usd + arr_churn_usd + arr_reactivation_usd as net_new_usd
    from {{ ref('fct_arr_bridge') }}
),

rolled as (
    select
        month_end,
        coalesce(segment, 'All') as segment,
        coalesce(region, 'All') as region,
        sum(opening_arr_usd) as opening_arr_usd,
        sum(arr_new_usd) as arr_new_usd,
        sum(arr_expansion_usd) as arr_expansion_usd,
        sum(arr_contraction_usd) as arr_contraction_usd,
        sum(arr_churn_usd) as arr_churn_usd,
        sum(arr_reactivation_usd) as arr_reactivation_usd,
        sum(committed_arr_usd) as committed_arr_usd,
        sum(net_new_usd) as net_new_usd
    from bridge
    group by grouping sets (
        (month_end),
        (month_end, segment),
        (month_end, region),
        (month_end, segment, region)
    )
),

plan_segment as (
    select
        month_end,
        segment,
        arr_usd as arr_plan_usd,
        net_new_usd as net_new_plan_usd,
        bookings_usd as bookings_plan_usd,
        nrr_plan,
        grr_plan
    from {{ ref('plan_monthly') }}
    union all
    select
        month_end,
        'All',
        sum(arr_usd),
        sum(net_new_usd),
        sum(bookings_usd),
        max(nrr_plan),
        max(grr_plan)
    from {{ ref('plan_monthly') }}
    group by month_end
),

booked as (
    select
        cast(date_trunc('month', b.booking_date) + interval 1 month - interval 1 day as date) as month_end,
        a.segment,
        a.region,
        sum(b.bookings_acv_usd) as bookings_usd
    from {{ ref('fct_bookings') }} b
    inner join {{ ref('stg_salesforce__account') }} a
        on b.master_account_id = a.account_id
    where b.booking_type in ('new', 'expansion')
    group by 1, 2, 3
),

booked_rolled as (
    select
        month_end,
        coalesce(segment, 'All') as segment,
        coalesce(region, 'All') as region,
        sum(bookings_usd) as bookings_usd
    from booked
    group by grouping sets (
        (month_end),
        (month_end, segment),
        (month_end, region),
        (month_end, segment, region)
    )
),

cohort as (
    select
        later.month_end,
        later.segment,
        later.region,
        earlier.committed_arr_usd as starting_arr_usd,
        later.committed_arr_usd as ending_arr_usd
    from {{ ref('fct_arr_monthly') }} earlier
    inner join {{ ref('fct_arr_monthly') }} later
        on earlier.master_account_id = later.master_account_id
       and later.month_end = cast(earlier.month_end + interval 12 month as date)
    where earlier.committed_arr_usd > 0
),

rates as (
    select
        month_end,
        coalesce(segment, 'All') as segment,
        coalesce(region, 'All') as region,
        sum(ending_arr_usd) / nullif(sum(starting_arr_usd), 0) as nrr,
        sum(least(ending_arr_usd, starting_arr_usd)) / nullif(sum(starting_arr_usd), 0) as grr
    from cohort
    group by grouping sets (
        (month_end),
        (month_end, segment),
        (month_end, region),
        (month_end, segment, region)
    )
),

joined as (
    select
        r.month_end,
        strftime(r.month_end, '%Y-%m-%d') as month_key,
        r.segment,
        r.region,
        r.opening_arr_usd,
        r.arr_new_usd,
        r.arr_expansion_usd,
        r.arr_contraction_usd,
        r.arr_churn_usd,
        r.arr_reactivation_usd,
        r.committed_arr_usd,
        r.net_new_usd,
        case
            when r.region = 'All' then p.arr_plan_usd
            else p.arr_plan_usd * r.committed_arr_usd / nullif(seg.committed_arr_usd, 0)
        end as arr_plan_usd,
        case
            when r.region = 'All' then p.net_new_plan_usd
            else p.net_new_plan_usd * r.committed_arr_usd / nullif(seg.committed_arr_usd, 0)
        end as net_new_plan_usd,
        coalesce(b.bookings_usd, 0) as bookings_usd,
        case
            when r.region = 'All' then p.bookings_plan_usd
            else p.bookings_plan_usd * coalesce(b.bookings_usd, 0) / nullif(bseg.bookings_usd, 0)
        end as bookings_plan_usd,
        p.nrr_plan,
        p.grr_plan,
        n.nrr,
        n.grr
    from rolled r
    left join plan_segment p
        on r.month_end = p.month_end
       and r.segment = p.segment
    left join rolled seg
        on r.month_end = seg.month_end
       and r.segment = seg.segment
       and seg.region = 'All'
    left join booked_rolled b
        on r.month_end = b.month_end
       and r.segment = b.segment
       and r.region = b.region
    left join booked_rolled bseg
        on r.month_end = bseg.month_end
       and r.segment = bseg.segment
       and bseg.region = 'All'
    left join rates n
        on r.month_end = n.month_end
       and r.segment = n.segment
       and r.region = n.region
)

select
    month_end,
    month_key,
    segment,
    region,
    opening_arr_usd,
    arr_new_usd,
    arr_expansion_usd,
    arr_contraction_usd,
    arr_churn_usd,
    arr_reactivation_usd,
    committed_arr_usd,
    arr_plan_usd,
    committed_arr_usd / nullif(arr_plan_usd, 0) as arr_pct_of_plan,
    net_new_usd,
    net_new_plan_usd,
    net_new_usd / nullif(net_new_plan_usd, 0) as net_new_pct_of_plan,
    bookings_usd,
    bookings_plan_usd,
    bookings_usd / nullif(bookings_plan_usd, 0) as bookings_pct_of_plan,
    nrr,
    nrr_plan,
    grr,
    grr_plan,
    lag(committed_arr_usd) over (partition by segment, region order by month_end) as prior_arr_usd,
    lag(net_new_usd) over (partition by segment, region order by month_end) as prior_net_new_usd,
    lag(bookings_usd) over (partition by segment, region order by month_end) as prior_bookings_usd,
    lag(nrr) over (partition by segment, region order by month_end) as prior_nrr,
    lag(grr) over (partition by segment, region order by month_end) as prior_grr,
    lag(month_end) over (partition by segment, region order by month_end) as prior_month_end
from joined
