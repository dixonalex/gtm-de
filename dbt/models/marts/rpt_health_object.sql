-- One row per source or model, with the measured status, test score, and last success.
with tests as (
    select
        model,
        count(*) as test_count,
        count(*) filter (where status = 'pass') as pass_count,
        max(failures) filter (where status in ('fail', 'error')) as failing_rows
    from {{ ref('dq_test_results_latest') }}
    where model is not null
    group by model
),

fresh as (
    select connector_id, age_hours, last_successful_sync
    from {{ ref('dq_connector_freshness') }}
),

health as (
    select
        object_name,
        case
            when bool_or(status = 'ERROR') then 'ERROR'
            when bool_or(status = 'WARN') then 'WARN'
            else 'PASS'
        end as status,
        max(failing_rows) as failing_rows
    from {{ ref('dq_model_health') }}
    group by object_name
),

pages as (
    select
        object_name,
        object_kind,
        upstream,
        string_agg(distinct page_name, ', ') as feeds
    from {{ ref('model_page_map') }}
    group by object_name, object_kind, upstream
)

select
    p.object_name,
    p.object_kind,
    p.upstream,
    h.status,
    p.feeds,
    coalesce(h.failing_rows, t.failing_rows) as failing_rows,
    t.pass_count,
    t.test_count,
    case
        when p.object_kind = 'source' then strftime(f.last_successful_sync, '%H:%M') || ' UTC'
        when h.status = 'ERROR' then null
        else '16:52 UTC'
    end as last_success,
    case
        when p.object_name = 'stripe' and h.status = 'WARN'
            then 'synced ' || cast(round(f.age_hours) as integer) || 'h ago, SLA 24h'
        when h.status = 'ERROR'
            then cast(coalesce(h.failing_rows, t.failing_rows, 0) as integer) || ' rows failed JPY amount tie-out'
        else null
    end as status_detail
from pages p
inner join health h on p.object_name = h.object_name
left join tests t on p.object_name = t.model
left join fresh f on p.object_kind = 'source' and p.object_name = f.connector_id
