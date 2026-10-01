---
title: Pipeline and tests
hide_title: true
---

```sql sources
select 'All' as value
union all
select distinct upstream as value from gtm.health_object
order by value
```

```sql models
select 'All' as value
union all
select object_name as value from gtm.health_object where object_kind != 'source'
order by value
```

```sql objects
select *
from gtm.health_object
where ('${inputs.source.value}' = 'All' or upstream = '${inputs.source.value}')
  and ('${inputs.model.value}' = 'All' or object_name = '${inputs.model.value}')
  and ('${inputs.severity.value}' = 'All' or status = '${inputs.severity.value}')
order by case object_name
    when 'salesforce' then 1
    when 'stripe' then 2
    when 'fct_bookings' then 3
    when 'fct_pipeline_snapshot' then 4
    when 'fct_arr_monthly' then 5
    when 'fct_billings' then 6
    when 'rpt_bookings_to_billings' then 7
    else 8
  end
```

```sql tally
select * from gtm.health_tally
```

```sql incidents
select * from gtm.incidents
```

```sql issues
select * from gtm.known_issues order by sort_order
```

```sql tests
select * from gtm.test_days order by family, failed_on
```

```sql reviews
select * from gtm.review_queue order by queue_rank
```

<UrlSync keys="source,model,severity" defaults="source:All,model:All,severity:All" />

<DataHealthView {objects} {tally} {incidents} {issues} {tests} {reviews}>
  <div slot="controls">
    <Dropdown name="source" title="Source" data={sources} defaultValue="All" />
    <Dropdown name="model" title="Model" data={models} defaultValue="All" />
    <Dropdown name="severity" title="Severity" defaultValue="All">
      <DropdownOption value="All" valueLabel="All" />
      <DropdownOption value="PASS" valueLabel="Pass" />
      <DropdownOption value="WARN" valueLabel="Warn" />
      <DropdownOption value="ERROR" valueLabel="Error" />
    </Dropdown>
  </div>
</DataHealthView>
