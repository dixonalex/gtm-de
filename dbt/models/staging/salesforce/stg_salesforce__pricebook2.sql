with source as (
    select * from {{ source('salesforce', 'pricebook2') }}
),

renamed as (
    select
        cast("Id" as varchar) as pricebook_id,
        cast("Name" as varchar) as name,
        cast("IsActive" as boolean) as is_active,
        cast("IsStandard" as boolean) as is_standard,
        cast(nullif("Description", '') as varchar) as description,
        cast("CreatedDate" as timestamp) as created_date,
        cast("SystemModstamp" as timestamp) as system_modstamp,
        cast("_loaded_at" as timestamp) as _loaded_at
    from source
)

select * from renamed
