---
title: Data health
---

```sql health
select * from gtm.model_health
```

```sql page_map
select * from gtm.page_map
```

```sql incidents
select * from gtm.incidents
```

```sql history
select * from gtm.test_history
```

```sql queue
select * from gtm.review_queue
```

```sql tests
select * from gtm.test_results
```

```sql freshness
select * from gtm.connector_freshness
```

```sql backlog
select * from gtm.dq_backlog
```

<DataHealthView
  {health}
  pageMap={page_map}
  {incidents}
  {history}
  {queue}
  {tests}
  {freshness}
  {backlog}
/>
