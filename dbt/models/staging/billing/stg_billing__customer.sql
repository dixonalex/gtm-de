with source as (
    select * from {{ source('billing', 'customer') }}
),

renamed as (
    select
        cast(id as varchar) as customer_id,
        cast(name as varchar) as name,
        cast(email as varchar) as email,
        upper(cast(currency as varchar)) as currency,
        cast(metadata_salesforce_account_id as varchar) as metadata_salesforce_account_id,
        cast(created as timestamp) as created,
        cast(delinquent as boolean) as delinquent,
        cast(_loaded_at as timestamp) as _loaded_at
    from source
)

select * from renamed
