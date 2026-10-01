with source as (
    select * from {{ source('salesforce', 'order') }}
),

renamed as (
    select
        cast("Id" as varchar) as order_id,
        cast("OrderNumber" as varchar) as order_number,
        cast("AccountId" as varchar) as account_id,
        cast(nullif("OpportunityId", '') as varchar) as opportunity_id,
        cast(nullif("QuoteId", '') as varchar) as quote_id,
        cast("Pricebook2Id" as varchar) as pricebook_id,
        cast("Type" as varchar) as type,
        cast("Status" as varchar) as status,
        cast("StatusCode" as varchar) as status_code,
        cast("EffectiveDate" as date) as effective_date,
        cast("EndDate" as date) as end_date,
        cast("ActivatedDate" as timestamp) as activated_date,
        cast("IsReductionOrder" as boolean) as is_reduction_order,
        cast(nullif("OriginalOrderId", '') as varchar) as original_order_id,
        cast("Billing_Frequency__c" as varchar) as billing_frequency_c,
        cast("TotalAmount" as decimal(18, 4)) as total_amount,
        cast("CurrencyIsoCode" as varchar) as currency_iso_code,
        cast("CreatedDate" as timestamp) as created_date,
        cast("LastModifiedDate" as timestamp) as last_modified_date,
        cast("SystemModstamp" as timestamp) as system_modstamp,
        cast("_loaded_at" as timestamp) as _loaded_at
    from source
    where not cast("IsDeleted" as boolean)
)

select * from renamed
