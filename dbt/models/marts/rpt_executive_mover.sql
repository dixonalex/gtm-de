-- Top five gains and losses for every segment × region slice, with the side total on each row.
with named as (
    select
        m.month_end,
        strftime(m.month_end, '%Y-%m-%d') as month_key,
        m.segment,
        m.region,
        a.name as account_name,
        m.net_movement_usd,
        case
            when m.arr_new_usd > 0
             and m.arr_new_usd >= m.arr_expansion_usd
             and m.arr_new_usd >= m.arr_reactivation_usd then 'New'
            when m.arr_expansion_usd > 0
             and m.arr_expansion_usd >= m.arr_reactivation_usd then 'Expansion'
            when m.arr_reactivation_usd > 0 then 'Reactivation'
            when m.arr_churn_usd < 0
             and abs(m.arr_churn_usd) >= abs(m.arr_contraction_usd) then 'Churn'
            else 'Contraction'
        end as kind
    from {{ ref('fct_arr_movement') }} m
    inner join {{ ref('stg_salesforce__account') }} a
        on m.master_account_id = a.account_id
    where m.net_movement_usd != 0
),

grains as (
    select month_key, month_end, 'All' as segment, 'All' as region, account_name, kind, net_movement_usd
    from named
    union all
    select month_key, month_end, segment, 'All', account_name, kind, net_movement_usd
    from named
    union all
    select month_key, month_end, 'All', region, account_name, kind, net_movement_usd
    from named
    union all
    select month_key, month_end, segment, region, account_name, kind, net_movement_usd
    from named
),

sided as (
    select
        *,
        case when net_movement_usd > 0 then 'gain' else 'loss' end as side
    from grains
),

ranked as (
    select
        *,
        row_number() over (
            partition by month_end, segment, region, side
            order by abs(net_movement_usd) desc, account_name
        ) as rank,
        sum(net_movement_usd) over (partition by month_end, segment, region, side) as side_total_usd
    from sided
)

select
    month_key,
    month_end,
    segment,
    region,
    side,
    rank,
    account_name,
    kind,
    net_movement_usd,
    side_total_usd,
    sum(net_movement_usd) over (partition by month_end, segment, region, side) as top_total_usd
from ranked
where rank <= 5
