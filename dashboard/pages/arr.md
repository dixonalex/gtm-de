---
title: ARR
---

```sql as_of
select as_of_date
from gtm.connector_freshness
limit 1
```

```sql salesforce
select connector, last_successful_sync, age_hours, status
from gtm.connector_freshness
where connector_id = 'salesforce'
```

```sql stripe
select connector, last_successful_sync, age_hours, status
from gtm.connector_freshness
where connector_id = 'stripe'
```

Data as of <Value data={as_of} column=as_of_date />

{#if salesforce[0].status == 'PASS'}
<span style="display:inline-block;margin:0 8px 8px 0;padding:2px 8px;border-radius:999px;font-size:12px;background:#e7efe9;color:#3f6b4e;">{salesforce[0].connector} · {salesforce[0].last_successful_sync} · {salesforce[0].age_hours}h · PASS</span>
{:else if salesforce[0].status == 'WARN'}
<span style="display:inline-block;margin:0 8px 8px 0;padding:2px 8px;border-radius:999px;font-size:12px;background:#f6f0e4;color:#8a5a12;">{salesforce[0].connector} · {salesforce[0].last_successful_sync} · {salesforce[0].age_hours}h · WARN</span>
{:else}
<span style="display:inline-block;margin:0 8px 8px 0;padding:2px 8px;border-radius:999px;font-size:12px;background:#f6e8e6;color:#8f3d3d;">{salesforce[0].connector} · {salesforce[0].last_successful_sync} · {salesforce[0].age_hours}h · ERROR</span>
{/if}
{#if stripe[0].status == 'PASS'}
<span style="display:inline-block;margin:0 8px 8px 0;padding:2px 8px;border-radius:999px;font-size:12px;background:#e7efe9;color:#3f6b4e;">{stripe[0].connector} · {stripe[0].last_successful_sync} · {stripe[0].age_hours}h · PASS</span>
{:else if stripe[0].status == 'WARN'}
<span style="display:inline-block;margin:0 8px 8px 0;padding:2px 8px;border-radius:999px;font-size:12px;background:#f6f0e4;color:#8a5a12;">{stripe[0].connector} · {stripe[0].last_successful_sync} · {stripe[0].age_hours}h · WARN</span>
{:else}
<span style="display:inline-block;margin:0 8px 8px 0;padding:2px 8px;border-radius:999px;font-size:12px;background:#f6e8e6;color:#8f3d3d;">{stripe[0].connector} · {stripe[0].last_successful_sync} · {stripe[0].age_hours}h · ERROR</span>
{/if}

```sql arr_headline
with months as (
    select
        month_end,
        sum(committed_arr_usd) as committed_arr_usd,
        row_number() over (order by month_end desc) as rn
    from gtm.arr_monthly
    group by month_end
)
select
    strftime(latest.month_end, '%b %Y') as month_label,
    latest.committed_arr_usd as latest_arr,
    abs(latest.committed_arr_usd - prior.committed_arr_usd) / nullif(prior.committed_arr_usd, 0) as growth_pct,
    case
        when latest.committed_arr_usd >= prior.committed_arr_usd then 'grew'
        else 'fell'
    end as verb
from months latest
inner join months prior on prior.rn = 4
where latest.rn = 1
```

```sql arr_stack
select month_end, 'Seats' as product, sum(seats_arr_usd) as arr_usd
from gtm.arr_monthly
group by month_end
union all
select month_end, 'Support', sum(support_arr_usd)
from gtm.arr_monthly
group by month_end
union all
select month_end, 'Commit', sum(commit_arr_usd)
from gtm.arr_monthly
group by month_end
order by month_end, product
```

## Committed ARR · <Value data={arr_headline} column=month_label /> <Value data={arr_headline} column=verb /> <Value data={arr_headline} column=growth_pct fmt=pct0 /> over the last 3 months to <Value data={arr_headline} column=latest_arr fmt=usd1m />

<BarChart
    data={arr_stack}
    x=month_end
    y=arr_usd
    series=product
    seriesOrder={['Seats', 'Support', 'Commit']}
    type=stacked
    yFmt=usd1m
    xFmt=shortdate
    legend=true
/>

```sql bridge_months
select
    printf(
        '%012d|%s',
        cast(epoch(month_end) as bigint),
        strftime(month_end, '%Y-%m-%d')
    ) as month_key,
    strftime(month_end, '%Y-%m-%d') as month_end
from gtm.arr_monthly
group by month_end
order by month_key
```

<Dropdown
    data={bridge_months}
    name=month_bridge
    value=month_key
    label=month_end
    title="Bridge month"
    defaultValue={[]}
/>

```sql bridge
with chosen as (
    select coalesce(
        try_cast(nullif(split_part('${inputs.month_bridge.value}', '|', 2), '') as date),
        (select max(month_end) from gtm.arr_monthly)
    ) as month_end
),
totals as (
    select
        sum(opening_arr_usd) as opening_arr,
        sum(arr_new_usd) as new_arr,
        sum(arr_expansion_usd) as expansion_arr,
        sum(arr_contraction_usd) as contraction_arr,
        sum(arr_churn_usd) as churn_arr,
        sum(arr_reactivation_usd) as reactivation_arr,
        sum(committed_arr_usd) as closing_arr
    from gtm.arr_monthly
    where month_end = (select month_end from chosen)
),
steps as (
    select 1 as ord, 'Opening' as step, opening_arr as amount, 'total' as kind from totals
    union all
    select 2, 'New', new_arr, 'change' from totals
    union all
    select 3, 'Expansion', expansion_arr, 'change' from totals
    union all
    select 4, 'Contraction', contraction_arr, 'change' from totals
    union all
    select 5, 'Churn', churn_arr, 'change' from totals
    union all
    select 6, 'Reactivation', reactivation_arr, 'change' from totals
    union all
    select 7, 'Closing', closing_arr, 'total' from totals
),
walk as (
    select
        ord,
        step,
        case
            when kind = 'total' then 0
            when amount >= 0 then (select opening_arr from totals)
                + coalesce(
                    sum(amount) filter (where kind = 'change') over (
                        order by ord
                        rows between unbounded preceding and 1 preceding
                    ),
                    0
                )
            else (select opening_arr from totals)
                + sum(amount) filter (where kind = 'change') over (
                    order by ord
                    rows between unbounded preceding and current row
                )
        end / 1000000.0 as placeholder,
        case when kind = 'change' and amount >= 0 then amount / 1000000.0 end as inc,
        case when kind = 'change' and amount < 0 then abs(amount) / 1000000.0 end as dec,
        case when kind = 'total' then amount / 1000000.0 end as tot
    from steps
)
select ord, step, placeholder, inc, dec, tot
from walk
order by ord
```

```sql bridge_title
with chosen as (
    select coalesce(
        try_cast(nullif(split_part('${inputs.month_bridge.value}', '|', 2), '') as date),
        (select max(month_end) from gtm.arr_monthly)
    ) as month_end
)
select
    month_end,
    sum(committed_arr_usd) - sum(opening_arr_usd) as net_change_usd,
    sum(committed_arr_usd) as closing_arr
from gtm.arr_monthly
where month_end = (select month_end from chosen)
group by month_end
```

## <Value data={bridge_title} column=month_end fmt=shortdate /> closed at <Value data={bridge_title} column=closing_arr fmt=usd1m />, net <Value data={bridge_title} column=net_change_usd fmt=usd1m />

<ECharts
    height=360px
    config={{
        dataset: { source: bridge },
        tooltip: { trigger: 'axis' },
        legend: { show: false },
        xAxis: { type: 'category' },
        yAxis: { type: 'value', name: 'USD millions' },
        series: [
            { type: 'bar', stack: 'bridge', silent: true, itemStyle: { color: 'transparent' }, encode: { x: 'step', y: 'placeholder' } },
            { type: 'bar', stack: 'bridge', itemStyle: { color: '#334155' }, label: { show: true, position: 'top', formatter: (p) => p.value?.inc == null ? '' : Number(p.value.inc).toFixed(1) }, encode: { x: 'step', y: 'inc' } },
            { type: 'bar', stack: 'bridge', itemStyle: { color: '#334155' }, label: { show: true, position: 'bottom', formatter: (p) => p.value?.dec == null ? '' : Number(p.value.dec).toFixed(1) }, encode: { x: 'step', y: 'dec' } },
            { type: 'bar', stack: 'bridge', itemStyle: { color: '#334155' }, label: { show: true, position: 'top', formatter: (p) => p.value?.tot == null ? '' : Number(p.value.tot).toFixed(1) }, encode: { x: 'step', y: 'tot' } }
        ]
    }}
/>

```sql overage
select month_end, sum(usage_overage_run_rate_usd) as usage_overage_run_rate_usd
from gtm.arr_monthly
group by month_end
order by month_end
```

```sql overage_latest
select sum(usage_overage_run_rate_usd) as usage_overage_run_rate_usd
from gtm.arr_monthly
where month_end = (select max(month_end) from gtm.arr_monthly)
```

## Usage overage run-rate is <Value data={overage_latest} column=usage_overage_run_rate_usd fmt=usd1m />, not included in ARR

<LineChart
    data={overage}
    x=month_end
    y=usage_overage_run_rate_usd
    yFmt=usd1m
    xFmt=shortdate
    legend=false
    lineColor=#334155
/>

<ButtonGroup name=entity title="Customer grain">
    <ButtonGroupItem value=billing valueLabel="Billing entity" default/>
    <ButtonGroupItem value=parent valueLabel="Corporate parent"/>
</ButtonGroup>

```sql top_customers
with latest as (
    select max(month_end) as month_end
    from gtm.arr_monthly
),
joined as (
    select
        case
            when '${inputs.entity.value}' = 'parent' then a.ultimate_parent_account_id
            else a.master_account_id
        end as customer_id,
        case
            when '${inputs.entity.value}' = 'parent' then p.name
            else m.name
        end as customer_name,
        a.committed_arr_usd
    from gtm.arr_monthly a
    inner join latest l on a.month_end = l.month_end
    left join gtm.dim_account m on a.master_account_id = m.account_id
    left join gtm.dim_account p on a.ultimate_parent_account_id = p.account_id
)
select
    customer_name,
    customer_id,
    sum(committed_arr_usd) as committed_arr_usd
from joined
group by customer_name, customer_id
order by committed_arr_usd desc
limit 20
```

<DataTable data={top_customers} rows=20 search=true>
    <Column id=customer_name title="Customer"/>
    <Column id=customer_id title="Id"/>
    <Column id=committed_arr_usd title="Committed ARR" fmt=usd1m/>
</DataTable>
