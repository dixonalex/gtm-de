with source as (
    select * from {{ source('salesforce', 'opportunity_history') }}
),

renamed as (
    select
        cast("Id" as varchar) as opportunity_history_id,
        cast("OpportunityId" as varchar) as opportunity_id,
        cast("StageName" as varchar) as stage_name,
        cast("Amount" as decimal(18, 4)) as amount,
        cast("ExpectedRevenue" as decimal(18, 4)) as expected_revenue,
        cast("CloseDate" as date) as close_date,
        cast("Probability" as integer) as probability,
        cast("ForecastCategory" as varchar) as forecast_category,
        cast("CreatedById" as varchar) as created_by_id,
        cast("CreatedDate" as timestamp) as created_date,
        cast("SystemModstamp" as timestamp) as system_modstamp,
        cast("_loaded_at" as timestamp) as _loaded_at
    from source
    where not cast("IsDeleted" as boolean)
)

select * from renamed
