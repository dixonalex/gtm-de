with syncs as (
    select
        connector_id,
        max(sync_end) as last_successful_sync
    from {{ ref('stg_fivetran_log__connector_sync') }}
    where status = 'SUCCESSFUL'
      and connector_id in ('salesforce', 'stripe')
    group by connector_id
),

aged as (
    select
        {{ as_of_date() }} as as_of_date,
        connector_id,
        last_successful_sync,
        date_diff('hour', last_successful_sync, timezone('UTC', current_timestamp)) as age_hours
    from syncs
)

select
    as_of_date,
    connector_id,
    last_successful_sync,
    age_hours,
    case
        when connector_id = 'salesforce' and age_hours >= 6 then 'ERROR'
        when connector_id = 'salesforce' and age_hours >= 2 then 'WARN'
        when connector_id = 'stripe' and age_hours >= 48 then 'ERROR'
        when connector_id = 'stripe' and age_hours >= 24 then 'WARN'
        else 'PASS'
    end as status
from aged
