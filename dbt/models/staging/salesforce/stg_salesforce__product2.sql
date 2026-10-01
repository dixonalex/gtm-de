with source as (
    select * from {{ source('salesforce', 'product2') }}
),

renamed as (
    select
        cast("Id" as varchar) as product_id,
        cast("Name" as varchar) as name,
        cast("ProductCode" as varchar) as product_code,
        cast("Family" as varchar) as family,
        cast("IsActive" as boolean) as is_active,
        cast("QuantityUnitOfMeasure" as varchar) as quantity_unit_of_measure,
        cast(nullif("Description", '') as varchar) as description,
        cast("CreatedDate" as timestamp) as created_date,
        cast("SystemModstamp" as timestamp) as system_modstamp,
        cast("_loaded_at" as timestamp) as _loaded_at
    from source
)

select * from renamed
