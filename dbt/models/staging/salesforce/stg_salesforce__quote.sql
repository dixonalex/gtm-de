with source as (
    select * from {{ source('salesforce', 'quote') }}
),

renamed as (
    select
        cast("Id" as varchar) as quote_id,
        cast("Name" as varchar) as name,
        cast("QuoteNumber" as varchar) as quote_number,
        cast("OpportunityId" as varchar) as opportunity_id,
        cast("AccountId" as varchar) as account_id,
        cast("Pricebook2Id" as varchar) as pricebook_id,
        cast("Status" as varchar) as status,
        cast("IsSyncing" as boolean) as is_syncing,
        cast("ExpirationDate" as date) as expiration_date,
        cast("Subtotal" as decimal(18, 4)) as subtotal,
        cast("Discount" as decimal(18, 4)) as discount,
        cast("TotalPrice" as decimal(18, 4)) as total_price,
        cast("GrandTotal" as decimal(18, 4)) as grand_total,
        cast("CurrencyIsoCode" as varchar) as currency_iso_code,
        cast("CreatedDate" as timestamp) as created_date,
        cast("SystemModstamp" as timestamp) as system_modstamp,
        cast("_loaded_at" as timestamp) as _loaded_at
    from source
    where not cast("IsDeleted" as boolean)
)

select * from renamed
