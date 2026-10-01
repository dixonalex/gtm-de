---
title: Engine scratch
hide_title: true
---

Stock Evidence only. One dropdown and one input query, for checking whether the browser DuckDB worker starts.

```sql probe
select count(*) as n
from gtm.executive_month
where segment = '${inputs.x.value}'
```

<Dropdown name="x" title="Segment" defaultValue="All">
  <DropdownOption value="All" valueLabel="All" />
  <DropdownOption value="Enterprise" valueLabel="Enterprise" />
</Dropdown>

{probe[0].n}
