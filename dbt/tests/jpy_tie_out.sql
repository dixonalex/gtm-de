{{ config(severity='error') }}

-- Planted JPY invoices stored at the wrong minor-unit scale.
select
    r.order_id,
    r.variance_usd
from {{ ref('rpt_bookings_to_billings') }} r
inner join {{ ref('stg_salesforce__account') }} a on r.account_id = a.account_id
where a.name like 'Yen Defect%'
  and abs(r.variance_usd) > 1000
