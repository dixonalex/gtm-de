with source as (
    select * from {{ source('salesforce', 'order_item') }}
),

renamed as (
    select
        cast("Id" as varchar) as order_item_id,
        cast("OrderId" as varchar) as order_id,
        cast("Product2Id" as varchar) as product_id,
        cast("PricebookEntryId" as varchar) as pricebook_entry_id,
        cast(nullif("QuoteLineItemId", '') as varchar) as quote_line_item_id,
        cast(nullif("OriginalOrderItemId", '') as varchar) as original_order_item_id,
        cast("Quantity" as decimal(18, 4)) as quantity,
        cast("ListPrice" as decimal(18, 4)) as list_price,
        cast("UnitPrice" as decimal(18, 4)) as unit_price,
        cast("TotalPrice" as decimal(18, 4)) as total_price,
        cast("ServiceDate" as date) as service_date,
        cast("EndDate" as date) as end_date,
        cast("CurrencyIsoCode" as varchar) as currency_iso_code,
        cast("CreatedDate" as timestamp) as created_date,
        cast("SystemModstamp" as timestamp) as system_modstamp,
        cast("_loaded_at" as timestamp) as _loaded_at
    from source
    where not cast("IsDeleted" as boolean)
)

select * from renamed
