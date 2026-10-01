---
title: Data Quality
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

```sql dq_headline
select
    count(*) filter (where status = 'warn') as warn_count,
    count(*) filter (where status in ('fail', 'error')) as error_count
from gtm.test_results
```

## <Value data={dq_headline} column=warn_count fmt=num0 /> tests warn and <Value data={dq_headline} column=error_count fmt=num0 /> error

```sql freshness
select
    connector,
    last_successful_sync,
    age_hours,
    case status
        when 'PASS' then '<span style="display:inline-block;padding:2px 8px;border-radius:999px;font-size:12px;background:#e7efe9;color:#3f6b4e;">PASS</span>'
        when 'WARN' then '<span style="display:inline-block;padding:2px 8px;border-radius:999px;font-size:12px;background:#f6f0e4;color:#8a5a12;">WARN</span>'
        else '<span style="display:inline-block;padding:2px 8px;border-radius:999px;font-size:12px;background:#f6e8e6;color:#8f3d3d;">ERROR</span>'
    end as status
from gtm.connector_freshness
order by connector
```

<DataTable data={freshness} rows=10>
    <Column id=connector title="Connector"/>
    <Column id=last_successful_sync title="Last successful sync"/>
    <Column id=age_hours title="Age (hours)" fmt=num0/>
    <Column id=status title="Status" contentType=html/>
</DataTable>

```sql row_freshness
select
    case object_name
        when 'opportunity' then 'Opportunity'
        when 'opportunity_history' then 'Opportunity history'
        when 'invoice' then 'Invoice'
        when 'charge' then 'Charge'
    end as object_name,
    max_loaded_at,
    age_hours,
    sla,
    case status
        when 'PASS' then '<span style="display:inline-block;padding:2px 8px;border-radius:999px;font-size:12px;background:#e7efe9;color:#3f6b4e;">PASS</span>'
        when 'WARN' then '<span style="display:inline-block;padding:2px 8px;border-radius:999px;font-size:12px;background:#f6f0e4;color:#8a5a12;">WARN</span>'
        else '<span style="display:inline-block;padding:2px 8px;border-radius:999px;font-size:12px;background:#f6e8e6;color:#8f3d3d;">ERROR</span>'
    end as status
from gtm.row_arrival_freshness
order by object_name
```

<DataTable data={row_freshness} rows=10>
    <Column id=object_name title="Object"/>
    <Column id=max_loaded_at title="Newest row"/>
    <Column id=age_hours title="Age (hours)" fmt=num0/>
    <Column id=sla title="SLA"/>
    <Column id=status title="Status" contentType=html/>
</DataTable>

```sql arrival_lag
select
    strftime(week_start, '%Y-%m-%d') as week_start,
    case object_name
        when 'opportunity' then 'Opportunity'
        when 'opportunity_history' then 'Opportunity history'
        when 'opportunity_line_item' then 'Opportunity line'
        when 'account' then 'Account'
        when 'order' then 'Order'
        when 'order_item' then 'Order item'
        when 'quote' then 'Quote'
        when 'quote_line_item' then 'Quote line'
        when 'product2' then 'Product'
        when 'pricebook2' then 'Price book'
        when 'pricebook_entry' then 'Price book entry'
        when 'user' then 'User'
        when 'dated_conversion_rate' then 'Dated conversion rate'
        else object_name
    end as object_name,
    p95_lag_hours
from gtm.arrival_lag_weekly
where week_start >= (select max(week_start) - interval '12 weeks' from gtm.arrival_lag_weekly)
order by week_start
```

## Salesforce arrival lag, p95 hours

<LineChart
    data={arrival_lag}
    x=week_start
    y=p95_lag_hours
    series=object_name
    yFmt=num0
    sort=false
    height=220
    legend=true
/>

```sql tests
select
    name,
    model,
    severity,
    case
        when status = 'pass' then '<span style="display:inline-block;padding:2px 8px;border-radius:999px;font-size:12px;background:#e7efe9;color:#3f6b4e;">PASS</span>'
        when status = 'warn' then '<span style="display:inline-block;padding:2px 8px;border-radius:999px;font-size:12px;background:#f6f0e4;color:#8a5a12;">WARN</span>'
        else '<span style="display:inline-block;padding:2px 8px;border-radius:999px;font-size:12px;background:#f6e8e6;color:#8f3d3d;">ERROR</span>'
    end as status,
    failures
from gtm.test_results
order by
    case status when 'fail' then 0 when 'error' then 1 when 'warn' then 2 else 3 end,
    severity,
    name
```

<DataTable data={tests} rows=20 search=true>
    <Column id=status title="Status" contentType=html/>
    <Column id=severity title="Severity"/>
    <Column id=name title="Test"/>
    <Column id=model title="Model"/>
    <Column id=failures title="Failures" fmt=num0/>
</DataTable>

```sql aging
select
    case exception_type
        when 'closed_won_without_order' then 'Won without order'
        when 'closed_won_amount_line_mismatch' then 'Amount ≠ lines'
    end as exception_type,
    case
        when age_days <= 7 then '0–7d'
        when age_days <= 30 then '8–30d'
        when age_days <= 90 then '31–90d'
        else '90d+'
    end as age_bucket,
    min(case
        when age_days <= 7 then 1
        when age_days <= 30 then 2
        when age_days <= 90 then 3
        else 4
    end) as bucket_ord,
    count(*) as items
from gtm.backlog
group by 1, 2
order by bucket_ord
```

```sql aging_headline
select
    case exception_type
        when 'closed_won_without_order' then 'Won without order'
        when 'closed_won_amount_line_mismatch' then 'Amount ≠ lines'
    end as exception_type,
    count(*) as items
from gtm.backlog
group by exception_type
order by items desc
limit 1
```

## <Value data={aging_headline} column=exception_type /> is the largest open backlog, <Value data={aging_headline} column=items fmt=num0 /> items

<BarChart
    data={aging}
    x=age_bucket
    y=items
    series=exception_type
    type=grouped
    yFmt=num0
    sort=false
    legend=true
/>

```sql queue
select
    q.queue_rank,
    '<span>' || q.name_a || '</span><span style="display:none">' || q.account_id_a || '</span>' as name_a,
    '<span>' || q.name_b || '</span><span style="display:none">' || q.account_id_b || '</span>' as name_b,
    q.name_edit_distance,
    concat_ws(
        ', ',
        case
            when q.website_a is not null and q.website_a = q.website_b then 'same website'
            else 'different website'
        end,
        case
            when q.billing_country_a = q.billing_country_b then 'same country'
            else 'different country'
        end
    ) as signals,
    q.arr_at_stake_usd,
    r.github_repo,
    case
        when r.github_repo is null then null
        else 'https://github.com/' || r.github_repo
            || '/issues/new?template=account-match.yml'
            || '&account_id_a=' || q.account_id_a
            || '&account_id_b=' || q.account_id_b
    end as decide_url
from gtm.review_queue q
cross join config.github_repo r
order by q.queue_rank
```

```sql queue_headline
select count(*) as pairs, sum(arr_at_stake_usd) as arr_at_stake_usd
from gtm.review_queue
```

```sql repo
select github_repo
from config.github_repo
```

## <Value data={queue_headline} column=pairs fmt=num0 /> pairs are waiting, <Value data={queue_headline} column=arr_at_stake_usd fmt=usd1m /> of ARR at stake

{#if repo[0] && repo[0].github_repo}
<DataTable data={queue} rows=25 search=true>
    <Column id=queue_rank title="Rank" fmt=num0/>
    <Column id=name_a title="Account A" contentType=html wrap=true/>
    <Column id=name_b title="Account B" contentType=html wrap=true/>
    <Column id=name_edit_distance title="Edit distance" fmt=num0/>
    <Column id=signals title="Signals" wrap=true/>
    <Column id=arr_at_stake_usd title="ARR at stake" fmt=usd0k/>
    <Column id=decide_url title="Decide" contentType=link linkLabel=Decide openInNewTab=true/>
</DataTable>
{:else}
<DataTable data={queue} rows=25 search=true>
    <Column id=queue_rank title="Rank" fmt=num0/>
    <Column id=name_a title="Account A" contentType=html wrap=true/>
    <Column id=name_b title="Account B" contentType=html wrap=true/>
    <Column id=name_edit_distance title="Edit distance" fmt=num0/>
    <Column id=signals title="Signals" wrap=true/>
    <Column id=arr_at_stake_usd title="ARR at stake" fmt=usd0k/>
</DataTable>
{/if}

```sql eval_dedup
select
    metric,
    case
        when metric like '%precision%' or metric like '%recall%' then round(max(value) filter (where rule_version = 'v1'), 3)
        else round(max(value) filter (where rule_version = 'v1'), 0)
    end as v1,
    case
        when metric like '%precision%' or metric like '%recall%' then round(max(value) filter (where rule_version = 'v2'), 3)
        else round(max(value) filter (where rule_version = 'v2'), 0)
    end as v2,
    case
        when metric like '%precision%' or metric like '%recall%' then round(max(value) filter (where rule_version = 'v3'), 3)
        else round(max(value) filter (where rule_version = 'v3'), 0)
    end as v3
from gtm.eval_quality
where task in ('dedup', 'dedup_queue')
  and match_method is null
  and (case_type is null or metric = 'typo_recall')
group by metric
order by metric
```

## Match rules, v1 through v3

<DataTable data={eval_dedup} rows=20>
    <Column id=metric title="Metric"/>
    <Column id=v1 title="v1"/>
    <Column id=v2 title="v2"/>
    <Column id=v3 title="v3"/>
</DataTable>
