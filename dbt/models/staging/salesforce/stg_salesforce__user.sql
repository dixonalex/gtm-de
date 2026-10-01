with source as (
    select * from {{ source('salesforce', 'user') }}
),

renamed as (
    select
        cast("Id" as varchar) as user_id,
        cast("Name" as varchar) as name,
        cast("Title" as varchar) as title,
        cast("IsActive" as boolean) as is_active,
        cast("CreatedDate" as timestamp) as created_date,
        cast("SystemModstamp" as timestamp) as system_modstamp,
        cast("_loaded_at" as timestamp) as _loaded_at
    from source
)

select * from renamed
