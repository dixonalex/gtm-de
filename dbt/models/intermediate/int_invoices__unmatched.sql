select
    invoice_id,
    order_id,
    match_method
from {{ ref('int_invoices__to_order') }}
where match_method = 'unmatched'
