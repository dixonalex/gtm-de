with source as (
    select * from {{ source('salesforce', 'pricebook_entry') }}
),

renamed as (
    select
        cast("Id" as varchar) as pricebook_entry_id,
        cast("Pricebook2Id" as varchar) as pricebook_id,
        cast("Product2Id" as varchar) as product_id,
        cast("ProductCode" as varchar) as product_code,
        cast("CurrencyIsoCode" as varchar) as currency_iso_code,
        cast("UnitPrice" as decimal(18, 4)) as unit_price,
        cast("IsActive" as boolean) as is_active,
        cast("UseStandardPrice" as boolean) as use_standard_price,
        cast("CreatedDate" as timestamp) as created_date,
        cast("SystemModstamp" as timestamp) as system_modstamp,
        cast("_loaded_at" as timestamp) as _loaded_at
    from source
)

select * from renamed
