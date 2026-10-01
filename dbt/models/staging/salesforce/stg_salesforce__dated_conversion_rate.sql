with source as (
    select * from {{ source('salesforce', 'dated_conversion_rate') }}
),

renamed as (
    select
        cast("Id" as varchar) as dated_conversion_rate_id,
        cast("IsoCode" as varchar) as iso_code,
        cast("ConversionRate" as decimal(18, 6)) as conversion_rate,
        cast("StartDate" as date) as start_date,
        cast("NextStartDate" as date) as next_start_date,
        cast("CreatedDate" as timestamp) as created_date,
        cast("SystemModstamp" as timestamp) as system_modstamp,
        cast("_loaded_at" as timestamp) as _loaded_at
    from source
)

select * from renamed
