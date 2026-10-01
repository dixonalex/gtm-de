with source as (
    select * from {{ source('billing', 'usage_record_summary') }}
),

renamed as (
    select
        cast(id as varchar) as usage_record_summary_id,
        cast(customer_id as varchar) as customer_id,
        cast(metadata_salesforce_order_item_id as varchar) as metadata_salesforce_order_item_id,
        cast(period_start as date) as period_start,
        cast(period_end as date) as period_end,
        cast(total_usage as decimal(18, 4)) as total_usage,
        cast(_loaded_at as timestamp) as _loaded_at
    from source
)

select * from renamed
