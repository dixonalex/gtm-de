with truth_accounts as (
    select
        account_id,
        true_master_account_id,
        case_type
    from read_csv('{{ data_dir() }}/truth/account_duplicates.csv', header = true, nullstr = '')
),

truth_invoices as (
    select
        invoice_id,
        nullif(true_order_id, '') as true_order_id
    from read_csv('{{ data_dir() }}/truth/invoice_order.csv', header = true, nullstr = '')
),

predicted_accounts as (
    select account_id, master_account_id
    from {{ ref('int_accounts__deduped') }}
),

predicted_invoices as (
    select invoice_id, order_id, match_method
    from {{ ref('int_invoices__to_order') }}
),

invoices as (
    select invoice_id, customer_id, billing_reason
    from {{ ref('stg_billing__invoice') }}
),

customers as (
    select customer_id, metadata_salesforce_account_id
    from {{ ref('stg_billing__customer') }}
),

dedup_joined as (
    select
        p.account_id,
        p.master_account_id as predicted_id,
        t.true_master_account_id as truth_id,
        t.case_type
    from predicted_accounts p
    inner join truth_accounts t on p.account_id = t.account_id
),

invoice_joined as (
    select
        p.invoice_id,
        p.order_id as predicted_id,
        t.true_order_id as truth_id,
        p.match_method,
        i.billing_reason,
        ta.case_type
    from predicted_invoices p
    left join truth_invoices t on p.invoice_id = t.invoice_id
    left join invoices i on p.invoice_id = i.invoice_id
    left join customers c on i.customer_id = c.customer_id
    left join truth_accounts ta on c.metadata_salesforce_account_id = ta.account_id
)

select
    'dedup' as task,
    'false_positive' as error_type,
    account_id as entity_id,
    predicted_id,
    truth_id,
    case_type,
    cast(null as varchar) as billing_reason,
    cast(null as varchar) as match_method
from dedup_joined
where predicted_id != account_id
  and predicted_id != truth_id

union all

select
    'dedup',
    'false_negative',
    account_id,
    predicted_id,
    truth_id,
    case_type,
    null,
    null
from dedup_joined
where truth_id != account_id
  and predicted_id != truth_id

union all

select
    'invoice_order',
    'false_positive',
    invoice_id,
    predicted_id,
    truth_id,
    case_type,
    billing_reason,
    match_method
from invoice_joined
where match_method != 'unmatched'
  and (truth_id is null or predicted_id is distinct from truth_id)

union all

select
    'invoice_order',
    'false_negative',
    invoice_id,
    predicted_id,
    truth_id,
    case_type,
    billing_reason,
    match_method
from invoice_joined
where truth_id is not null
  and (match_method = 'unmatched' or predicted_id is distinct from truth_id)
