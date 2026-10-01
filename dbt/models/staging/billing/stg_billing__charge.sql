with source as (
    select * from {{ source('billing', 'charge') }}
),

renamed as (
    select
        cast(id as varchar) as charge_id,
        cast(invoice_id as varchar) as invoice_id,
        cast(customer_id as varchar) as customer_id,
        {{ stripe_minor_to_major('amount', 'currency') }} as amount,
        {{ stripe_minor_to_major('amount_refunded', 'currency') }} as amount_refunded,
        upper(cast(currency as varchar)) as currency,
        cast(status as varchar) as status,
        cast(paid as boolean) as paid,
        cast(nullif(failure_code, '') as varchar) as failure_code,
        cast(payment_method_type as varchar) as payment_method_type,
        cast(created as timestamp) as created,
        cast(_loaded_at as timestamp) as _loaded_at
    from source
)

select * from renamed
