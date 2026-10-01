with source as (
    select * from {{ source('salesforce', 'opportunity') }}
),

renamed as (
    select
        cast("Id" as varchar) as opportunity_id,
        cast("AccountId" as varchar) as account_id,
        cast("Name" as varchar) as name,
        cast("Type" as varchar) as type,
        cast("StageName" as varchar) as stage_name,
        cast("Probability" as integer) as probability,
        cast("ForecastCategoryName" as varchar) as forecast_category_name,
        cast("Amount" as decimal(18, 4)) as amount,
        cast("CloseDate" as date) as close_date,
        cast("IsClosed" as boolean) as is_closed,
        cast("IsWon" as boolean) as is_won,
        cast("Won_Without_Order__c" as boolean) as won_without_order,
        cast(nullif("LeadSource", '') as varchar) as lead_source,
        cast("OwnerId" as varchar) as owner_id,
        cast("CurrencyIsoCode" as varchar) as currency_iso_code,
        cast(nullif("Pricebook2Id", '') as varchar) as pricebook_id,
        cast(nullif("SyncedQuoteId", '') as varchar) as synced_quote_id,
        cast("HasOpportunityLineItem" as boolean) as has_opportunity_line_item,
        cast("CreatedDate" as timestamp) as created_date,
        cast("LastModifiedDate" as timestamp) as last_modified_date,
        cast("SystemModstamp" as timestamp) as system_modstamp,
        cast("_loaded_at" as timestamp) as _loaded_at
    from source
    where not cast("IsDeleted" as boolean)
)

select * from renamed
