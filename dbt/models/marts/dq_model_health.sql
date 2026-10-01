-- Worst of a model's own test results and the freshness of its upstream connector.
with freshness as (
    select connector_id, status
    from {{ ref('dq_connector_freshness') }}
),

tests as (
    select
        model,
        case
            when count(*) filter (where status in ('fail', 'error') and severity = 'error') > 0 then 'ERROR'
            when count(*) filter (where status in ('warn', 'fail', 'error') and severity = 'warn') > 0 then 'WARN'
            else 'PASS'
        end as test_status,
        max(failures) filter (where status in ('fail', 'error')) as failing_rows
    from {{ ref('dq_test_results_latest') }}
    where model is not null
    group by model
),

mapped as (
    select
        m.object_name,
        m.object_kind,
        m.page_name,
        case m.upstream
            when 'salesforce' then (select status from freshness where connector_id = 'salesforce')
            when 'stripe' then (select status from freshness where connector_id = 'stripe')
            else 'PASS'
        end as upstream_status,
        coalesce(t.test_status, 'PASS') as test_status,
        t.failing_rows
    from {{ ref('model_page_map') }} m
    left join tests t on m.object_name = t.model
)

select
    object_name,
    object_kind,
    page_name,
    upstream_status,
    test_status,
    case
        when test_status = 'ERROR' or upstream_status = 'ERROR' then 'ERROR'
        when test_status = 'WARN' or upstream_status = 'WARN' then 'WARN'
        else 'PASS'
    end as status,
    failing_rows
from mapped
