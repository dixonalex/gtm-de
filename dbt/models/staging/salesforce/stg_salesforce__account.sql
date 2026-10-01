with source as (
    select * from {{ source('salesforce', 'account') }}
),

renamed as (
    select
        cast("Id" as varchar) as account_id,
        cast("Name" as varchar) as name,
        cast("Type" as varchar) as type,
        cast("Industry" as varchar) as industry,
        cast(nullif("Website", '') as varchar) as website,
        cast("NumberOfEmployees" as bigint) as number_of_employees,
        cast("BillingCountry" as varchar) as billing_country,
        cast(nullif("BillingState", '') as varchar) as billing_state,
        cast("CurrencyIsoCode" as varchar) as currency_iso_code,
        cast("OwnerId" as varchar) as owner_id,
        cast("CreatedDate" as timestamp) as created_date,
        cast("LastModifiedDate" as timestamp) as last_modified_date,
        cast("SystemModstamp" as timestamp) as system_modstamp,
        cast("_loaded_at" as timestamp) as _loaded_at
    from source
    where not cast("IsDeleted" as boolean)
)

select * from renamed
