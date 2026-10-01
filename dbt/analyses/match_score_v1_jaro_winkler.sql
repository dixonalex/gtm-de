-- Failed match_score v1 (Jaro-Winkler), recorded before the edit-distance revision.
--
-- Score = 1.00 * name_jw + 0.20 * domain_equal + 0.20 * country_equal - 1.50 * parent_linked.
-- Blocking was same currency AND (same domain OR the same first 4 characters of the
-- normalized name). The review pool is pairs that v2 did not auto-merge.
--
-- Two failure causes:
-- 1. Prefix blocking lost 8/15 typos. A vowel dropped inside the first four characters
--    ("Northwind" vs "Nrthwind") plus a null website never entered the block.
--    Typo recall cannot exceed 7/15 at any threshold.
-- 2. The Jaro-Winkler prefix bonus cannot separate shared-token company names.
--    The 7 blocked typos score about 1.14-1.15, inside a few thousand false pairs
--    that share a currency and a name prefix. There is no gap.
--
-- Not-auto-merged pairs by score bucket (floor to 0.05):
--   bucket  true_pairs  false_pairs
--   0.60    0           12
--   0.65    0           110
--   0.75    0           10
--   0.80    0           560
--   0.85    0           2996
--   0.90    0           75
--   0.95    0           3
--   1.00    0           8075
--   1.05    0           16825
--   1.10    7           2938
--   1.15    1           45
--
-- Threshold on match_score (higher is a closer match). typo_truth = 15.
--   threshold  queue   true_in_queue  queue_precision  typos_in_queue
--   0.00       31657   8              0.000            7
--   0.50       31657   8              0.000            7
--   0.80       31525   8              0.000            7
--   0.90       27969   8              0.000            7
--   0.95       27894   8              0.000            7
--   1.00       27891   8              0.000            7
--   1.05       19816   8              0.000            7
--   1.10       2991    8              0.003            7
--   1.15       46      1              0.022            1
--   1.20       0       0              null             0
--
-- A queue under 100 only appears at 1.15, which keeps 1 of 15 typos.

with score_buckets as (
    select * from (
        values
        (0.60, 0, 12),
        (0.65, 0, 110),
        (0.75, 0, 10),
        (0.80, 0, 560),
        (0.85, 0, 2996),
        (0.90, 0, 75),
        (0.95, 0, 3),
        (1.00, 0, 8075),
        (1.05, 0, 16825),
        (1.10, 7, 2938),
        (1.15, 1, 45)
    ) as v(bucket, true_pairs, false_pairs)
),

thresholds as (
    select * from (
        values
        (0.00, 31657, 8, 0.000, 7),
        (0.50, 31657, 8, 0.000, 7),
        (0.80, 31525, 8, 0.000, 7),
        (0.90, 27969, 8, 0.000, 7),
        (0.95, 27894, 8, 0.000, 7),
        (1.00, 27891, 8, 0.000, 7),
        (1.05, 19816, 8, 0.000, 7),
        (1.10, 2991, 8, 0.003, 7),
        (1.15, 46, 1, 0.022, 1),
        (1.20, 0, 0, cast(null as double), 0)
    ) as v(threshold, queue, true_in_queue, queue_precision, typos_in_queue)
)

select
    'score_bucket' as table_name,
    bucket as cutoff,
    true_pairs,
    false_pairs,
    cast(null as bigint) as queue,
    cast(null as bigint) as true_in_queue,
    cast(null as double) as queue_precision,
    cast(null as bigint) as typos_in_queue
from score_buckets

union all

select
    'threshold',
    threshold,
    cast(null as bigint),
    cast(null as bigint),
    queue,
    true_in_queue,
    queue_precision,
    typos_in_queue
from thresholds
order by table_name, cutoff
