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
select strftime(month_end, '%b %Y') as month_label, month_end, 'Seats' as product, sum(seats_arr_usd) as arr_usd
from gtm.arr_monthly
group by month_end
union all
select strftime(month_end, '%b %Y'), month_end, 'Support', sum(support_arr_usd)
from gtm.arr_monthly
where (
    select sum(support_arr_usd) / nullif(sum(committed_arr_usd), 0)
    from gtm.arr_monthly
    where month_end = (select max(month_end) from gtm.arr_monthly)
) >= 0.02
group by month_end
union all
select strftime(month_end, '%b %Y'), month_end, 'Commit', sum(commit_arr_usd)
from gtm.arr_monthly
group by month_end
order by month_end, product
```

```sql support_note
select printf('%.1f', 100.0 * sum(support_arr_usd) / nullif(sum(committed_arr_usd), 0)) || '%' as support_label
from gtm.arr_monthly
where month_end = (select max(month_end) from gtm.arr_monthly)
having sum(support_arr_usd) / nullif(sum(committed_arr_usd), 0) < 0.02
```

## Committed ARR · <Value data={arr_headline} column=month_label /> <Value data={arr_headline} column=verb /> <Value data={arr_headline} column=growth_pct fmt=pct0 /> over the last 3 months to <Value data={arr_headline} column=latest_arr fmt=usd1m />

{#if support_note.length}
<p style="color:#64748b;font-size:13px;margin:-8px 0 12px;">Support is {support_note[0].support_label} of committed ARR.</p>
{/if}

<BarChart
    data={arr_stack}
    x=month_label
    y=arr_usd
    series=product
    seriesOrder={['Seats', 'Commit', 'Support']}
    type=stacked
    yFmt=usd1m
    sort=false
    legend=true
/>

```sql bridge_months
select
    printf(
        '%012d|%s',
        cast(epoch(month_end) as bigint),
        strftime(month_end, '%Y-%m-%d')
    ) as month_key,
    strftime(month_end, '%b %Y') as month_label
from gtm.arr_monthly
group by month_end
order by month_key
```

<Dropdown
    data={bridge_months}
    name=month_bridge
    value=month_key
    label=month_label
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
        sum(arr_new_usd) as new_arr,
        sum(arr_expansion_usd) as expansion_arr,
        sum(arr_contraction_usd) as contraction_arr,
        sum(arr_churn_usd) as churn_arr,
        sum(arr_reactivation_usd) as reactivation_arr
    from gtm.arr_monthly
    where month_end = (select month_end from chosen)
)
select 1 as ord, 'New' as step, new_arr / 1000000.0 as amount from totals
union all
select 2, 'Expansion', expansion_arr / 1000000.0 from totals
union all
select 3, 'Contraction', contraction_arr / 1000000.0 from totals
union all
select 4, 'Churn', churn_arr / 1000000.0 from totals
union all
select 5, 'Reactivation', reactivation_arr / 1000000.0 from totals
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
    strftime(month_end, '%b %Y') as month_label,
    sum(opening_arr_usd) as opening_arr,
    sum(committed_arr_usd) as closing_arr,
    sum(committed_arr_usd) - sum(opening_arr_usd) as net_change_usd
from gtm.arr_monthly
where month_end = (select month_end from chosen)
group by month_end
```

## <Value data={bridge_title} column=month_label /> opened at <Value data={bridge_title} column=opening_arr fmt=usd1m />, closed at <Value data={bridge_title} column=closing_arr fmt=usd1m />, net <Value data={bridge_title} column=net_change_usd fmt=usd1m />

<ECharts
    height=360px
    config={{
        dataset: { source: bridge },
        tooltip: { trigger: 'axis' },
        legend: { show: false },
        xAxis: { type: 'category' },
        yAxis: { type: 'value', name: 'USD millions' },
        series: [
            {
                type: 'bar',
                itemStyle: {
                    color: (p) => (Number(p.value?.amount) < 0 ? '#8f3d3d' : '#334155')
                },
                label: {
                    show: true,
                    position: 'top',
                    formatter: (p) => {
                        const v = Number(p.value?.amount);
                        if (!v) return '0';
                        return (v > 0 ? '+' : '') + v.toFixed(1);
                    }
                },
                encode: { x: 'step', y: 'amount' }
            }
        ]
    }}
/>

```sql overage
select strftime(month_end, '%b %Y') as month_label, month_end, sum(usage_overage_run_rate_usd) as usage_overage_run_rate_usd
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
    x=month_label
    y=usage_overage_run_rate_usd
    yFmt=usd1m
    sort=false
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
        a.master_account_id,
        a.committed_arr_usd
    from gtm.arr_monthly a
    inner join latest l on a.month_end = l.month_end
    left join gtm.dim_account m on a.master_account_id = m.account_id
    left join gtm.dim_account p on a.ultimate_parent_account_id = p.account_id
)
select
    '<span>' || customer_name || '</span><span style="display:none">' || customer_id || '</span>' as customer_name,
    count(distinct master_account_id) as entities_rolled_up,
    sum(committed_arr_usd) as committed_arr_usd
from joined
group by customer_name, customer_id
order by committed_arr_usd desc
limit 20
```

<DataTable data={top_customers} rows=20 search=true>
    <Column id=customer_name title="Customer" contentType=html wrap=true/>
    <Column id=entities_rolled_up title="Entities rolled up" fmt=num0/>
    <Column id=committed_arr_usd title="Committed ARR" fmt=usd1m/>
</DataTable>
