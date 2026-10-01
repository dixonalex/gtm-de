---
title: Quote-to-cash exceptions
hide_title: true
---

```sql owners
select 'All' as value
union all
select distinct owner_name as value
from gtm.deal_desk
where is_open
order by value
```

```sql kpi
select *
from gtm.deal_slice
where owner_name = '${inputs.owner.value}'
  and exception_type = '${inputs.type.value}'
```

```sql open_rows
select *
from gtm.deal_desk
where is_open
  and ('${inputs.owner.value}' = 'All' or owner_name = '${inputs.owner.value}')
  and ('${inputs.type.value}' = 'All' or exception_type = '${inputs.type.value}')
  and ('${inputs.queue.value}' = 'All' or past_sla)
order by
  case when past_sla then 0 when age_days + 1 = sla_bd then 1 else 2 end,
  amount_usd desc
```

```sql resolved_rows
select *
from gtm.deal_desk
where not is_open
  and resolved_on >= date '2026-09-23'
  and ('${inputs.owner.value}' = 'All' or owner_name = '${inputs.owner.value}')
  and ('${inputs.type.value}' = 'All' or exception_type = '${inputs.type.value}')
order by amount_usd desc
```

```sql freshness
select * from gtm.connector_freshness order by connector_id
```

<UrlSync keys="owner,type,queue" defaults="owner:All,type:All,queue:All" />

<DealDeskView {kpi} openRows={open_rows} resolvedRows={resolved_rows} {freshness}>
  <div slot="controls">
    <Dropdown name="day" title="Period" defaultValue="today">
      <DropdownOption value="today" valueLabel="Wed 30 Sep" />
    </Dropdown>
    <Dropdown name="owner" title="Owner" data={owners} defaultValue="All" />
    <Dropdown name="type" title="Type" defaultValue="All">
      <DropdownOption value="All" valueLabel="All" />
      <DropdownOption value="won_without_order" valueLabel="Won, no order" />
      <DropdownOption value="invoice_unmatched" valueLabel="Invoice unmatched" />
      <DropdownOption value="amount_mismatch" valueLabel="Amount mismatch" />
      <DropdownOption value="reduction_awaiting_approval" valueLabel="Reduction awaiting approval" />
      <DropdownOption value="cancelled_still_invoicing" valueLabel="Cancelled, still invoicing" />
    </Dropdown>
    <Dropdown name="queue" title="Queue" defaultValue="All">
      <DropdownOption value="All" valueLabel="All open" />
      <DropdownOption value="past" valueLabel="Past SLA" />
    </Dropdown>
  </div>
</DealDeskView>
