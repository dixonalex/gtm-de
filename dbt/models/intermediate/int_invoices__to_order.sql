with recursive orders as (
    select * from {{ ref('stg_salesforce__order') }}
),

order_items as (
    select * from {{ ref('stg_salesforce__order_item') }}
),

products as (
    select product_id, product_code
    from {{ ref('stg_salesforce__product2') }}
),

invoices as (
    select * from {{ ref('stg_billing__invoice') }}
),

invoice_lines as (
    select * from {{ ref('stg_billing__invoice_line_item') }}
),

customers as (
    select * from {{ ref('stg_billing__customer') }}
),

accounts as (
    select * from {{ ref('int_accounts__deduped') }}
),

schedule as (
    select * from {{ ref('int_orders__billing_schedule') }}
),

line_flags as (
    select
        invoice_id,
        bool_or(metadata_product_code = 'API-OVER') as has_overage_line,
        bool_or(metadata_product_code in ('SEAT-TEAM', 'SEAT-ENT', 'SUP-PREM', 'API-COMMIT')) as has_recurring_line
    from invoice_lines
    group by invoice_id
),

classified as (
    select
        i.invoice_id,
        i.customer_id,
        i.currency,
        i.total,
        i.period_start,
        i.billing_reason,
        i.metadata_salesforce_order_id,
        case
            when i.total < 0 and i.billing_reason = 'subscription_update' then 'credit'
            when coalesce(f.has_overage_line, false)
                or (
                    i.billing_reason = 'subscription_cycle'
                    and not coalesce(f.has_recurring_line, false)
                )
                then 'overage'
            else 'schedule'
        end as fuzzy_kind
    from invoices i
    left join line_flags f on i.invoice_id = f.invoice_id
),

metadata_match as (
    select
        i.invoice_id,
        i.metadata_salesforce_order_id as order_id
    from classified i
    inner join orders o on i.metadata_salesforce_order_id = o.order_id
    where i.metadata_salesforce_order_id is not null
),

invoice_account as (
    select
        i.invoice_id,
        ca.master_account_id
    from classified i
    inner join customers c on i.customer_id = c.customer_id
    inner join accounts ca on c.metadata_salesforce_account_id = ca.account_id
),

commit_orders as (
    select distinct
        o.order_id,
        o.effective_date,
        o.end_date,
        o.currency_iso_code,
        a.master_account_id
    from orders o
    inner join order_items oi on o.order_id = oi.order_id
    inner join products p on oi.product_id = p.product_id
    inner join accounts a on o.account_id = a.account_id
    where p.product_code = 'API-COMMIT'
      and not o.is_reduction_order
),

edges as (
    -- Metadata invoices occupy the slot they already explain, so fuzzy cannot take it.
    select
        i.invoice_id,
        m.order_id,
        'schedule|' || s.order_id || '|' || cast(s.slot_start as varchar) as slot_key,
        abs(i.total - s.expected_amount) as amount_delta,
        abs(date_diff('day', s.slot_start, i.period_start)) as date_delta,
        s.slot_start,
        0 as priority,
        cast(null as varchar) as match_method
    from metadata_match m
    inner join classified i on m.invoice_id = i.invoice_id
    inner join schedule s on s.order_id = m.order_id
    where i.fuzzy_kind = 'schedule'
      and abs(date_diff('day', s.slot_start, i.period_start)) <= 7
      and abs(i.total - s.expected_amount) <= 0.01 * abs(s.expected_amount)

    union all

    select
        i.invoice_id,
        m.order_id,
        'overage|' || m.order_id || '|' || cast(i.period_start as varchar) as slot_key,
        0 as amount_delta,
        0 as date_delta,
        i.period_start as slot_start,
        0 as priority,
        cast(null as varchar) as match_method
    from metadata_match m
    inner join classified i on m.invoice_id = i.invoice_id
    where i.fuzzy_kind = 'overage'

    union all

    select
        i.invoice_id,
        m.order_id,
        'credit|' || m.order_id as slot_key,
        abs(i.total - o.total_amount) as amount_delta,
        abs(date_diff('day', o.effective_date, i.period_start)) as date_delta,
        o.effective_date as slot_start,
        0 as priority,
        cast(null as varchar) as match_method
    from metadata_match m
    inner join classified i on m.invoice_id = i.invoice_id
    inner join orders o on m.order_id = o.order_id
    where i.fuzzy_kind = 'credit'
      and o.is_reduction_order

    union all

    select
        i.invoice_id,
        s.order_id,
        'schedule|' || s.order_id || '|' || cast(s.slot_start as varchar) as slot_key,
        abs(i.total - s.expected_amount) as amount_delta,
        abs(date_diff('day', s.slot_start, i.period_start)) as date_delta,
        s.slot_start,
        1 as priority,
        'fuzzy_schedule' as match_method
    from classified i
    inner join invoice_account ia on i.invoice_id = ia.invoice_id
    inner join schedule s
        on s.master_account_id = ia.master_account_id
       and s.currency_iso_code = i.currency
    left join metadata_match m on i.invoice_id = m.invoice_id
    where m.invoice_id is null
      and i.fuzzy_kind = 'schedule'
      and abs(date_diff('day', s.slot_start, i.period_start)) <= 7
      and abs(i.total - s.expected_amount) <= 0.01 * abs(s.expected_amount)

    union all

    select
        i.invoice_id,
        o.order_id,
        'overage|' || o.order_id || '|' || cast(i.period_start as varchar) as slot_key,
        0 as amount_delta,
        abs(date_diff('day', o.effective_date, i.period_start)) as date_delta,
        i.period_start as slot_start,
        1 as priority,
        'fuzzy_overage' as match_method
    from classified i
    inner join invoice_account ia on i.invoice_id = ia.invoice_id
    inner join commit_orders o
        on o.master_account_id = ia.master_account_id
       and o.currency_iso_code = i.currency
       and i.period_start >= o.effective_date
       and i.period_start <= o.end_date
    left join metadata_match m on i.invoice_id = m.invoice_id
    where m.invoice_id is null
      and i.fuzzy_kind = 'overage'

    union all

    select
        i.invoice_id,
        o.order_id,
        'credit|' || o.order_id as slot_key,
        abs(i.total - o.total_amount) as amount_delta,
        abs(date_diff('day', o.effective_date, i.period_start)) as date_delta,
        o.effective_date as slot_start,
        1 as priority,
        'fuzzy_credit' as match_method
    from classified i
    inner join invoice_account ia on i.invoice_id = ia.invoice_id
    inner join orders o on o.is_reduction_order and o.currency_iso_code = i.currency
    inner join accounts oa on o.account_id = oa.account_id and oa.master_account_id = ia.master_account_id
    left join metadata_match m on i.invoice_id = m.invoice_id
    where m.invoice_id is null
      and i.fuzzy_kind = 'credit'
      and abs(date_diff('day', o.effective_date, i.period_start)) <= 7
),

ranked as (
    select
        invoice_id,
        order_id,
        slot_key,
        amount_delta,
        date_delta,
        slot_start,
        priority,
        match_method,
        row_number() over (
            order by priority, amount_delta, date_delta, order_id, slot_start, invoice_id
        ) as rn
    from edges
),

walk as (
    select
        r.rn,
        r.invoice_id,
        r.order_id,
        r.match_method,
        r.priority,
        r.invoice_id as used_invoices,
        r.slot_key as used_slots
    from ranked r
    where r.rn = 1

    union all

    select
        r.rn,
        case
            when not contains(',' || w.used_invoices || ',', ',' || r.invoice_id || ',')
             and not contains(',' || w.used_slots || ',', ',' || r.slot_key || ',')
            then r.invoice_id
        end as invoice_id,
        case
            when not contains(',' || w.used_invoices || ',', ',' || r.invoice_id || ',')
             and not contains(',' || w.used_slots || ',', ',' || r.slot_key || ',')
            then r.order_id
        end as order_id,
        case
            when not contains(',' || w.used_invoices || ',', ',' || r.invoice_id || ',')
             and not contains(',' || w.used_slots || ',', ',' || r.slot_key || ',')
            then r.match_method
        end as match_method,
        r.priority,
        case
            when not contains(',' || w.used_invoices || ',', ',' || r.invoice_id || ',')
             and not contains(',' || w.used_slots || ',', ',' || r.slot_key || ',')
            then w.used_invoices || ',' || r.invoice_id
            else w.used_invoices
        end as used_invoices,
        case
            when not contains(',' || w.used_invoices || ',', ',' || r.invoice_id || ',')
             and not contains(',' || w.used_slots || ',', ',' || r.slot_key || ',')
            then w.used_slots || ',' || r.slot_key
            else w.used_slots
        end as used_slots
    from walk w
    inner join ranked r on r.rn = w.rn + 1
),

fuzzy_match as (
    select invoice_id, order_id, match_method
    from walk
    where invoice_id is not null
      and priority = 1
),

won_without_order as (
    select
        o.opportunity_id,
        o.close_date,
        case
            when lines.opportunity_id is not null then lines.line_amount
            else o.amount
        end as match_amount,
        o.currency_iso_code,
        a.master_account_id
    from {{ ref('stg_salesforce__opportunity') }} o
    inner join accounts a on o.account_id = a.account_id
    left join (
        select
            opportunity_id,
            sum(total_price) as line_amount
        from {{ ref('stg_salesforce__opportunity_line_item') }}
        group by opportunity_id
    ) lines on o.opportunity_id = lines.opportunity_id
    where o.is_won
      and not exists (
          select 1
          from orders ord
          where ord.opportunity_id = o.opportunity_id
      )
),

opportunity_ranked as (
    select
        i.invoice_id,
        w.opportunity_id,
        row_number() over (
            partition by i.invoice_id
            order by
                abs(date_diff('day', w.close_date, cast(i.created as date))),
                abs(i.total - w.match_amount),
                w.opportunity_id
        ) as rn
    from invoices i
    inner join invoice_account ia on i.invoice_id = ia.invoice_id
    inner join won_without_order w
        on w.master_account_id = ia.master_account_id
       and w.currency_iso_code = i.currency
    left join metadata_match m on i.invoice_id = m.invoice_id
    left join fuzzy_match f on i.invoice_id = f.invoice_id
    where m.invoice_id is null
      and f.invoice_id is null
      and abs(date_diff('day', w.close_date, cast(i.created as date))) <= 30
      and abs(i.total - w.match_amount) <= 0.01 * abs(w.match_amount)
),

opportunity_match as (
    select invoice_id, opportunity_id
    from opportunity_ranked
    where rn = 1
)

select
    i.invoice_id,
    coalesce(m.order_id, f.order_id) as order_id,
    opp.opportunity_id,
    case
        when m.invoice_id is not null then 'metadata'
        when f.invoice_id is not null then f.match_method
        when opp.invoice_id is not null then 'opportunity_no_order'
        else 'unmatched'
    end as match_method
from invoices i
left join metadata_match m on i.invoice_id = m.invoice_id
left join fuzzy_match f on i.invoice_id = f.invoice_id
left join opportunity_match opp on i.invoice_id = opp.invoice_id
