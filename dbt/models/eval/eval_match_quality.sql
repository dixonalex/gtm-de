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
        nullif(true_order_id, '') as true_order_id,
        nullif(true_opportunity_id, '') as true_opportunity_id
    from read_csv('{{ data_dir() }}/truth/invoice_order.csv', header = true, nullstr = '')
),

predicted_accounts as (
    select
        'v1' as rule_version,
        account_id,
        master_account_id
    from {{ ref('int_accounts__deduped_v1') }}

    union all

    select
        'v2' as rule_version,
        account_id,
        master_account_id
    from {{ ref('int_accounts__deduped_v2') }}

    union all

    select
        'v3' as rule_version,
        account_id,
        master_account_id
    from {{ ref('int_accounts__deduped') }}
),

predicted_invoices as (
    select invoice_id, order_id, opportunity_id, match_method
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
        p.rule_version,
        p.account_id,
        p.master_account_id,
        t.case_type
    from predicted_accounts p
    inner join truth_accounts t on p.account_id = t.account_id
    where p.account_id != p.master_account_id
),

dedup_counts as (
    select
        p.rule_version,
        count(*) as pairs_found,
        count(t.account_id) as true_positives,
        (select count(*) from truth_pairs) as truth_pairs
    from predicted_pairs p
    left join truth_pairs t
        on p.account_id = t.account_id
       and p.master_account_id = t.master_account_id
    group by p.rule_version
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
        p.rule_version,
        p.case_type,
        count(*) as predicted_pairs,
        count(t.account_id) as true_positives
    from predicted_pairs p
    left join truth_pairs t
        on p.account_id = t.account_id
       and p.master_account_id = t.master_account_id
    group by p.rule_version, p.case_type
),

queue_pairs as (
    select account_id_a, account_id_b
    from {{ ref('int_accounts__match_candidates') }}
    where tier = 'review'
),

queue_labeled as (
    select
        q.account_id_a,
        q.account_id_b,
        ta.true_master_account_id = tb.true_master_account_id as is_true_pair
    from queue_pairs q
    inner join truth_accounts ta on q.account_id_a = ta.account_id
    inner join truth_accounts tb on q.account_id_b = tb.account_id
),

missed_by_auto as (
    select t.account_id, t.master_account_id, t.case_type
    from truth_pairs t
    where not exists (
        select 1
        from {{ ref('int_accounts__deduped_v2') }} v
        where v.account_id = t.account_id
          and v.master_account_id = t.master_account_id
    )
),

queue_stats as (
    select
        (select count(*) from queue_pairs) as queue_size,
        (select count(*) filter (where is_true_pair) from queue_labeled) as true_in_queue,
        (select count(*) from missed_by_auto) as missed_pairs,
        (
            select count(*)
            from missed_by_auto m
            where exists (
                select 1
                from queue_pairs q
                where (
                    q.account_id_a = m.account_id and q.account_id_b = m.master_account_id
                ) or (
                    q.account_id_b = m.account_id and q.account_id_a = m.master_account_id
                )
            )
        ) as missed_in_queue,
        (select count(*) from missed_by_auto where case_type = 'typo') as typo_pairs,
        (
            select count(*)
            from missed_by_auto m
            where m.case_type = 'typo'
              and exists (
                  select 1
                  from queue_pairs q
                  where (
                      q.account_id_a = m.account_id and q.account_id_b = m.master_account_id
                  ) or (
                      q.account_id_b = m.account_id and q.account_id_a = m.master_account_id
                  )
              )
        ) as typo_pairs_queued
),

invoice_scored as (
    select
        p.invoice_id,
        p.order_id,
        p.opportunity_id,
        p.match_method,
        t.true_order_id,
        t.true_opportunity_id,
        i.billing_reason,
        abs(i.total) / fx.conversion_rate as abs_usd,
        p.match_method not in ('unmatched', 'opportunity_no_order') as is_order_match,
        p.match_method not in ('unmatched', 'opportunity_no_order')
            and p.order_id = t.true_order_id as is_correct_link,
        t.true_order_id is not null as has_truth_order,
        p.match_method = 'opportunity_no_order'
            and p.opportunity_id = t.true_opportunity_id as is_correct_opportunity,
        t.true_opportunity_id is not null as has_truth_opportunity
    from predicted_invoices p
    left join truth_invoices t on p.invoice_id = t.invoice_id
    left join invoices i on p.invoice_id = i.invoice_id
    left join fx
        on fx.currency_code = i.currency
       and fx.rate_date = i.created_date
),

rule_versions as (
    select distinct rule_version from predicted_accounts
),

metrics as (
    select
        'dedup' as task,
        rule_version,
        'pairs_found' as metric,
        cast(null as varchar) as match_method,
        cast(null as varchar) as case_type,
        cast(null as varchar) as billing_reason,
        cast(pairs_found as double) as value
    from dedup_counts

    union all

    select
        'dedup',
        rule_version,
        'precision',
        null,
        null,
        null,
        true_positives * 1.0 / nullif(pairs_found, 0)
    from dedup_counts

    union all

    select
        'dedup',
        rule_version,
        'recall',
        null,
        null,
        null,
        true_positives * 1.0 / nullif(truth_pairs, 0)
    from dedup_counts

    union all

    select
        'dedup',
        v.rule_version,
        'precision',
        null,
        c.case_type,
        null,
        p.true_positives * 1.0 / nullif(p.predicted_pairs, 0)
    from case_types c
    cross join rule_versions v
    left join dedup_case_predicted p
        on c.case_type = p.case_type
       and v.rule_version = p.rule_version

    union all

    select
        'dedup',
        v.rule_version,
        'recall',
        null,
        c.case_type,
        null,
        coalesce(p.true_positives, 0) * 1.0 / nullif(t.truth_pairs, 0)
    from case_types c
    cross join rule_versions v
    left join dedup_case_predicted p
        on c.case_type = p.case_type
       and v.rule_version = p.rule_version
    left join dedup_case_truth t on c.case_type = t.case_type

    union all

    select
        'dedup',
        'v3',
        'auto_merge_precision',
        null,
        null,
        null,
        true_positives * 1.0 / nullif(pairs_found, 0)
    from dedup_counts
    where rule_version = 'v2'

    union all

    select
        'dedup',
        'v3',
        'auto_merge_recall',
        null,
        null,
        null,
        true_positives * 1.0 / nullif(truth_pairs, 0)
    from dedup_counts
    where rule_version = 'v2'

    union all

    select
        'dedup_queue',
        'v3',
        'queue_size',
        null,
        null,
        null,
        queue_size
    from queue_stats

    union all

    select
        'dedup_queue',
        'v3',
        'queue_precision',
        null,
        null,
        null,
        true_in_queue * 1.0 / nullif(queue_size, 0)
    from queue_stats

    union all

    select
        'dedup_queue',
        'v3',
        'queue_recall',
        null,
        null,
        null,
        missed_in_queue * 1.0 / nullif(missed_pairs, 0)
    from queue_stats

    union all

    select
        'dedup_queue',
        'v3',
        'typo_recall',
        null,
        'typo',
        null,
        typo_pairs_queued * 1.0 / nullif(typo_pairs, 0)
    from queue_stats

    union all

    select
        'invoice_order',
        'v3',
        'accuracy',
        match_method,
        null,
        null,
        count(*) filter (where is_correct_link) * 1.0 / nullif(count(*), 0)
    from invoice_scored
    where is_order_match
    group by match_method

    union all

    select
        'invoice_order',
        'v3',
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
    where s.is_order_match
    group by s.match_method, s.billing_reason

    union all

    select
        'invoice_order',
        'v3',
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
        'v3',
        'recall',
        match_method,
        null,
        null,
        count(*) filter (where is_correct_link) * 1.0
            / (select nullif(count(*) filter (where has_truth_order), 0) from invoice_scored)
    from invoice_scored
    where is_order_match
    group by match_method

    union all

    select
        'invoice_order',
        'v3',
        'value_recall',
        null,
        null,
        null,
        sum(abs_usd) filter (where is_correct_link) / nullif(sum(abs_usd) filter (where has_truth_order), 0)
    from invoice_scored

    union all

    select
        'invoice_order',
        'v3',
        'value_recall',
        null,
        null,
        billing_reason,
        sum(abs_usd) filter (where is_correct_link) / nullif(sum(abs_usd) filter (where has_truth_order), 0)
    from invoice_scored
    group by billing_reason

    union all

    select 'invoice_order', 'v3', 'unmatched', null, null, null, count(*)
    from invoice_scored
    where match_method = 'unmatched'

    union all

    select
        'invoice_order',
        'v3',
        'precision',
        null,
        null,
        null,
        count(*) filter (where is_correct_link) * 1.0 / nullif(count(*) filter (where is_order_match), 0)
    from invoice_scored

    union all

    select
        'invoice_order',
        'v3',
        'recall',
        null,
        null,
        null,
        count(*) filter (where is_correct_link) * 1.0 / nullif(count(*) filter (where has_truth_order), 0)
    from invoice_scored

    union all

    select
        'invoice_order',
        'v3',
        'count',
        match_method,
        null,
        null,
        count(*)
    from invoice_scored
    group by match_method

    union all

    select
        'invoice_opportunity',
        'v3',
        'precision',
        'opportunity_no_order',
        null,
        null,
        count(*) filter (where is_correct_opportunity) * 1.0
            / nullif(count(*) filter (where match_method = 'opportunity_no_order'), 0)
    from invoice_scored

    union all

    select
        'invoice_opportunity',
        'v3',
        'recall',
        'opportunity_no_order',
        null,
        null,
        count(*) filter (where is_correct_opportunity) * 1.0
            / nullif(count(*) filter (where has_truth_opportunity), 0)
    from invoice_scored
)

select * from metrics
