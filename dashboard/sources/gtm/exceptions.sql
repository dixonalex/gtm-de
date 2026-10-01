with as_of as (
    select max(as_of_date) as as_of_date
    from dq.dq_connector_freshness
),

billed as (
    select
        'billed_without_order' as exception_type,
        e.entity_id,
        date_diff('day', min(b.invoice_date), any_value(a.as_of_date)) as age_days,
        sum(b.billed_usd) as usd_at_stake
    from marts.rpt_quote_to_cash_exceptions e
    inner join marts.fct_billings b on e.entity_id = b.invoice_id
    cross join as_of a
    where e.exception_type = 'billed_without_order'
    group by e.entity_id
),

backlog as (
    select
        exception_type,
        record_id as entity_id,
        age_days,
        usd_at_stake
    from dq.dq_backlog
    where exception_type in (
        'closed_won_without_order',
        'closed_won_amount_line_mismatch'
    )
)

select * from billed
union all
select * from backlog
