with source as (
    select * from {{ source('billing', 'invoice') }}
),

renamed as (
    select
        cast(id as varchar) as invoice_id,
        cast(customer_id as varchar) as customer_id,
        cast(number as varchar) as invoice_number,
        cast(status as varchar) as status,
        cast(billing_reason as varchar) as billing_reason,
        cast(collection_method as varchar) as collection_method,
        upper(cast(currency as varchar)) as currency,
        {{ stripe_minor_to_major('subtotal', 'currency') }} as subtotal,
        {{ stripe_minor_to_major('total', 'currency') }} as total,
        {{ stripe_minor_to_major('amount_due', 'currency') }} as amount_due,
        {{ stripe_minor_to_major('amount_paid', 'currency') }} as amount_paid,
        {{ stripe_minor_to_major('amount_remaining', 'currency') }} as amount_remaining,
        cast(created as timestamp) as created,
        cast(period_start as date) as period_start,
        cast(period_end as date) as period_end,
        cast(due_date as timestamp) as due_date,
        cast(status_transitions_paid_at as timestamp) as status_transitions_paid_at,
        cast(status_transitions_marked_uncollectible_at as timestamp) as marked_uncollectible_at,
        cast(nullif(metadata_salesforce_order_id, '') as varchar) as metadata_salesforce_order_id,
        cast(_loaded_at as timestamp) as _loaded_at
    from source
)

select * from renamed
