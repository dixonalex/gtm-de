with source as (
    select * from {{ source('billing', 'invoice_line_item') }}
),

renamed as (
    select
        cast(id as varchar) as invoice_line_item_id,
        cast(invoice_id as varchar) as invoice_id,
        cast(type as varchar) as line_type,
        cast(description as varchar) as description,
        cast(quantity as decimal(18, 4)) as quantity,
        {{ stripe_minor_to_major('unit_amount_decimal', 'currency') }} as unit_amount,
        {{ stripe_minor_to_major('amount', 'currency') }} as amount,
        upper(cast(currency as varchar)) as currency,
        cast(period_start as date) as period_start,
        cast(period_end as date) as period_end,
        cast(proration as boolean) as proration,
        cast(metadata_product_code as varchar) as metadata_product_code,
        cast(nullif(metadata_salesforce_order_item_id, '') as varchar) as metadata_salesforce_order_item_id,
        cast(_loaded_at as timestamp) as _loaded_at
    from source
)

select * from renamed
