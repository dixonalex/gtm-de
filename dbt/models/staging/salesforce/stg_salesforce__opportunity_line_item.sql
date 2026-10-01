with source as (
    select * from {{ source('salesforce', 'opportunity_line_item') }}
),

renamed as (
    select
        cast("Id" as varchar) as opportunity_line_item_id,
        cast("OpportunityId" as varchar) as opportunity_id,
        cast("PricebookEntryId" as varchar) as pricebook_entry_id,
        cast("Product2Id" as varchar) as product_id,
        cast("ProductCode" as varchar) as product_code,
        cast("Quantity" as decimal(18, 4)) as quantity,
        cast("ListPrice" as decimal(18, 4)) as list_price,
        cast("UnitPrice" as decimal(18, 4)) as unit_price,
        cast("Discount" as decimal(18, 4)) as discount,
        cast("TotalPrice" as decimal(18, 4)) as total_price,
        cast(nullif("ServiceDate", '') as date) as service_date,
        cast("CurrencyIsoCode" as varchar) as currency_iso_code,
        cast("CreatedDate" as timestamp) as created_date,
        cast("SystemModstamp" as timestamp) as system_modstamp,
        cast("_loaded_at" as timestamp) as _loaded_at
    from source
    where not cast("IsDeleted" as boolean)
)

select * from renamed
