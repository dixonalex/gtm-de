select cast(now as timestamp) as now
from {{ source('fivetran_log', 'extract_clock') }}
