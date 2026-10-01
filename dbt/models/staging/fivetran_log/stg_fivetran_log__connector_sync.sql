with source as (
    -- salesforce_sync and stripe_sync are the same file. Freshness applies the connector filter.
    select * from {{ source('fivetran_log', 'salesforce_sync') }}
),

renamed as (
    select
        cast(connector_id as varchar) as connector_id,
        cast(sync_start as timestamp) as sync_start,
        cast(sync_end as timestamp) as sync_end,
        cast(status as varchar) as status,
        cast(rows_updated as bigint) as rows_updated
    from source
)

select * from renamed
