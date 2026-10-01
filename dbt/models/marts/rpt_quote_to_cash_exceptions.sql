with opportunities as (
    select * from {{ ref('stg_salesforce__opportunity') }}
),

opportunity_lines as (
    select opportunity_id, total_price
    from {{ ref('stg_salesforce__opportunity_line_item') }}
),

orders as (
    select opportunity_id
    from {{ ref('stg_salesforce__order') }}
    where opportunity_id is not null
),

accounts as (
    select account_id, master_account_id
    from {{ ref('int_accounts__deduped') }}
),

unmatched as (
    select invoice_id
    from {{ ref('int_invoices__unmatched') }}
),

off_order as (
    select invoice_id, opportunity_id, match_method
    from {{ ref('int_invoices__to_order') }}
    where match_method in ('unmatched', 'opportunity_no_order')
),

invoices as (
    select invoice_id, customer_id, total
    from {{ ref('stg_billing__invoice') }}
),

customers as (
    select customer_id, metadata_salesforce_account_id
    from {{ ref('stg_billing__customer') }}
),

unmatched_masters as (
    select distinct a.master_account_id
    from off_order u
    inner join invoices i on u.invoice_id = i.invoice_id
    inner join customers c on i.customer_id = c.customer_id
    inner join accounts a on c.metadata_salesforce_account_id = a.account_id
),

closed_won_without_order as (
    select
        'closed_won_without_order' as exception_type,
        o.opportunity_id as entity_id,
        o.account_id,
        a.master_account_id,
        um.master_account_id is not null as invoiced_anyway,
        cast(null as decimal(18, 4)) as opportunity_amount,
        cast(null as decimal(18, 4)) as line_amount
    from opportunities o
    inner join accounts a on o.account_id = a.account_id
    left join unmatched_masters um on a.master_account_id = um.master_account_id
    where o.is_won
      and not exists (
          select 1
          from orders ord
          where ord.opportunity_id = o.opportunity_id
      )
),

unmatched_invoices as (
    select
        'unmatched_invoice' as exception_type,
        u.invoice_id as entity_id,
        c.metadata_salesforce_account_id as account_id,
        a.master_account_id,
        cast(null as boolean) as invoiced_anyway,
        cast(null as decimal(18, 4)) as opportunity_amount,
        cast(null as decimal(18, 4)) as line_amount
    from unmatched u
    inner join invoices i on u.invoice_id = i.invoice_id
    left join customers c on i.customer_id = c.customer_id
    left join accounts a on c.metadata_salesforce_account_id = a.account_id
),

line_totals as (
    select
        opportunity_id,
        sum(total_price) as line_amount
    from opportunity_lines
    group by opportunity_id
),

amount_overrides as (
    select
        'amount_line_override' as exception_type,
        o.opportunity_id as entity_id,
        o.account_id,
        a.master_account_id,
        cast(null as boolean) as invoiced_anyway,
        o.amount as opportunity_amount,
        coalesce(l.line_amount, 0) as line_amount
    from opportunities o
    inner join accounts a on o.account_id = a.account_id
    left join line_totals l on o.opportunity_id = l.opportunity_id
    where o.is_won
      and abs(o.amount - coalesce(l.line_amount, 0)) > 0.01
),

billed_without_order as (
    select
        'billed_without_order' as exception_type,
        u.invoice_id as entity_id,
        c.metadata_salesforce_account_id as account_id,
        a.master_account_id,
        cast(null as boolean) as invoiced_anyway,
        o.amount as opportunity_amount,
        i.total as line_amount
    from off_order u
    inner join invoices i on u.invoice_id = i.invoice_id
    inner join opportunities o on u.opportunity_id = o.opportunity_id
    left join customers c on i.customer_id = c.customer_id
    left join accounts a on c.metadata_salesforce_account_id = a.account_id
    where u.match_method = 'opportunity_no_order'
)

select * from closed_won_without_order
union all
select * from unmatched_invoices
union all
select * from amount_overrides
union all
select * from billed_without_order
