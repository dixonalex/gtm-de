{{ config(severity='error') }}

-- Planted JPY invoices stored at the wrong minor-unit scale.
select
    order_id,
    variance_usd
from {{ ref('rpt_bookings_to_billings') }}
where order_id like '801STORY000050%'
  and abs(variance_usd) > 1000
