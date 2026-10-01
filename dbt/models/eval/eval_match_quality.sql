with truth_accounts as (
    select
        account_id,
        true_master_account_id,
        case_type
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

invoices as (
    select
        invoice_id,
        billing_reason,
        currency,
        total,
        cast(created as date) as created_date
    from {{ ref('stg_billing__invoice') }}
),

fx as (
    select rate_date, currency_code, conversion_rate
    from {{ ref('int_fx__daily_rates') }}
),

truth_pairs as (
    select account_id, true_master_account_id as master_account_id, case_type
    from truth_accounts
    where account_id != true_master_account_id
),

predicted_pairs as (
    select
        p.account_id,
        p.master_account_id,
        t.case_type
    from predicted_accounts p
    inner join truth_accounts t on p.account_id = t.account_id
    where p.account_id != p.master_account_id
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

case_types as (
    select * from (
        values
        ('original'),
        ('collision'),
        ('subsidiary'),
        ('typo'),
        ('suffix_url')
    ) as v(case_type)
),

dedup_case_truth as (
    select case_type, count(*) as truth_pairs
    from truth_pairs
    group by case_type
),

dedup_case_predicted as (
    select
        p.case_type,
        count(*) as predicted_pairs,
        count(t.account_id) as true_positives
    from predicted_pairs p
    left join truth_pairs t
        on p.account_id = t.account_id
       and p.master_account_id = t.master_account_id
    group by p.case_type
),

invoice_scored as (
    select
        p.invoice_id,
        p.order_id,
        p.match_method,
        t.true_order_id,
        i.billing_reason,
        abs(i.total) / fx.conversion_rate as abs_usd,
        p.match_method != 'unmatched' and p.order_id = t.true_order_id as is_correct_link,
        t.true_order_id is not null as has_truth_order
    from predicted_invoices p
    left join truth_invoices t on p.invoice_id = t.invoice_id
    left join invoices i on p.invoice_id = i.invoice_id
    left join fx
        on fx.currency_code = i.currency
       and fx.rate_date = i.created_date
),

metrics as (
    select
        'dedup' as task,
        'pairs_found' as metric,
        cast(null as varchar) as match_method,
        cast(null as varchar) as case_type,
        cast(null as varchar) as billing_reason,
        cast(pairs_found as double) as value
    from dedup_counts

    union all

    select 'dedup', 'precision', null, null, null, true_positives * 1.0 / nullif(pairs_found, 0)
    from dedup_counts

    union all

    select 'dedup', 'recall', null, null, null, true_positives * 1.0 / nullif(truth_pairs, 0)
    from dedup_counts

    union all

    select
        'dedup',
        'precision',
        null,
        c.case_type,
        null,
        p.true_positives * 1.0 / nullif(p.predicted_pairs, 0)
    from case_types c
    left join dedup_case_predicted p on c.case_type = p.case_type

    union all

    select
        'dedup',
        'recall',
        null,
        c.case_type,
        null,
        coalesce(p.true_positives, 0) * 1.0 / nullif(t.truth_pairs, 0)
    from case_types c
    left join dedup_case_predicted p on c.case_type = p.case_type
    left join dedup_case_truth t on c.case_type = t.case_type

    union all

    select
        'invoice_order',
        'accuracy',
        match_method,
        null,
        null,
        count(*) filter (where is_correct_link) * 1.0 / nullif(count(*), 0)
    from invoice_scored
    where match_method != 'unmatched'
    group by match_method

    union all

    select
        'invoice_order',
        'recall',
        s.match_method,
        null,
        s.billing_reason,
        count(*) filter (where s.is_correct_link) * 1.0 / nullif(max(t.truth_n), 0)
    from invoice_scored s
    inner join (
        select billing_reason, count(*) filter (where has_truth_order) as truth_n
        from invoice_scored
        group by billing_reason
    ) t on s.billing_reason = t.billing_reason
    group by s.match_method, s.billing_reason

    union all

    select
        'invoice_order',
        'recall',
        null,
        null,
        billing_reason,
        count(*) filter (where is_correct_link) * 1.0
            / nullif(count(*) filter (where has_truth_order), 0)
    from invoice_scored
    group by billing_reason

    union all

    select
        'invoice_order',
        'recall',
        match_method,
        null,
        null,
        count(*) filter (where is_correct_link) * 1.0
            / (select nullif(count(*) filter (where has_truth_order), 0) from invoice_scored)
    from invoice_scored
    group by match_method

    union all

    select
        'invoice_order',
        'value_recall',
        null,
        null,
        null,
        sum(abs_usd) filter (where is_correct_link) / nullif(sum(abs_usd) filter (where has_truth_order), 0)
    from invoice_scored

    union all

    select
        'invoice_order',
        'value_recall',
        null,
        null,
        billing_reason,
        sum(abs_usd) filter (where is_correct_link) / nullif(sum(abs_usd) filter (where has_truth_order), 0)
    from invoice_scored
    group by billing_reason

    union all

    select 'invoice_order', 'unmatched', null, null, null, count(*)
    from invoice_scored
    where match_method = 'unmatched'

    union all

    select
        'invoice_order',
        'precision',
        null,
        null,
        null,
        count(*) filter (where is_correct_link) * 1.0 / nullif(count(*) filter (where match_method != 'unmatched'), 0)
    from invoice_scored

    union all

    select
        'invoice_order',
        'recall',
        null,
        null,
        null,
        count(*) filter (where is_correct_link) * 1.0 / nullif(count(*) filter (where has_truth_order), 0)
    from invoice_scored
)

select * from metrics
