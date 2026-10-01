-- Daily failure counts for 1–30 Sep, zero-filled, including Uniqueness.
with days as (
    select cast(date '2026-09-01' + i * interval 1 day as date) as failed_on
    from range(0, 30) t(i)
),

families as (
    select unnest(['freshness', 'relationships', 'reconciliation', 'uniqueness']) as family
)

select
    f.family,
    d.failed_on,
    coalesce(h.failure_count, 0) as failure_count
from families f
cross join days d
left join {{ ref('dq_test_history') }} h
    on h.family = f.family
   and h.failed_on = d.failed_on
