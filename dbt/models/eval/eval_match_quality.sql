with truth_accounts as (
    select
        account_id,
        true_master_account_id
    from read_csv('../data/truth/account_duplicates.csv', header = true, nullstr = '')
),

truth_invoices as (
    select
        invoice_id,
        nullif(true_order_id, '') as true_order_id
    from read_csv('../data/truth/invoice_order.csv', header = true, nullstr = '')
),

predicted_accounts as (
    select account_id, master_account_id
    from {{ ref('int_accounts__deduped') }}
),

predicted_invoices as (
    select invoice_id, order_id, match_method
    from {{ ref('int_invoices__to_order') }}
),

truth_pairs as (
    select account_id, true_master_account_id as master_account_id
    from truth_accounts
    where account_id != true_master_account_id
),

predicted_pairs as (
    select account_id, master_account_id
    from predicted_accounts
    where account_id != master_account_id
),

dedup_counts as (
    select
        (select count(*) from predicted_pairs) as pairs_found,
        (
            select count(*)
            from predicted_pairs p
            inner join truth_pairs t
                on p.account_id = t.account_id
               and p.master_account_id = t.master_account_id
        ) as true_positives,
        (select count(*) from truth_pairs) as truth_pairs
),

invoice_scored as (
    select
        p.invoice_id,
        p.order_id,
        p.match_method,
        t.true_order_id,
        p.match_method != 'unmatched' and p.order_id = t.true_order_id as is_correct_link,
        t.true_order_id is not null as has_truth_order
    from predicted_invoices p
    left join truth_invoices t on p.invoice_id = t.invoice_id
)

select
    'dedup' as task,
    'pairs_found' as metric,
    cast(null as varchar) as match_method,
    cast(pairs_found as double) as value
from dedup_counts

union all

select
    'dedup',
    'precision',
    null,
    true_positives * 1.0 / nullif(pairs_found, 0)
from dedup_counts

union all

select
    'dedup',
    'recall',
    null,
    true_positives * 1.0 / nullif(truth_pairs, 0)
from dedup_counts

union all

select
    'invoice_order',
    'accuracy',
    match_method,
    count(*) filter (where is_correct_link) * 1.0 / nullif(count(*), 0)
from invoice_scored
where match_method in ('metadata', 'fuzzy')
group by match_method

union all

select
    'invoice_order',
    'unmatched',
    null,
    count(*)
from invoice_scored
where match_method = 'unmatched'

union all

select
    'invoice_order',
    'precision',
    null,
    count(*) filter (where is_correct_link) * 1.0 / nullif(count(*) filter (where match_method != 'unmatched'), 0)
from invoice_scored

union all

select
    'invoice_order',
    'recall',
    null,
    count(*) filter (where is_correct_link) * 1.0 / nullif(count(*) filter (where has_truth_order), 0)
from invoice_scored
