module Table.AggregationFn exposing
    ( AggregationFn
    , sum, min, max, extent, mean, median, unique, uniqueCount, count, first, last
    , custom, withMerge
    , aggregate, merge
    )

{-| Built-in aggregation functions, ported from
`row-aggregation/aggregationFns.ts`.

An `AggregationFn` folds the values of a column over a group's leaf rows.
Some also know how to `merge` the results of child groups, which lets nested
groups avoid re-reading every leaf.

Phase 1 replaces the placeholder bodies below.


# Type

@docs AggregationFn


# Built-ins

@docs sum, min, max, extent, mean, median, unique, uniqueCount, count, first, last


# Building your own

@docs custom, withMerge


# Applying

@docs aggregate, merge

-}

import Table.Value exposing (Value(..))


{-| A fold over leaf values plus an optional merge of child results.
-}
type AggregationFn
    = AggregationFn
        { aggregate : List Value -> Value
        , merge : Maybe (List Value -> Value)
        }


{-| Sum of `Number` values; other values count as zero.
-}
sum : AggregationFn
sum =
    placeholder


{-| Smallest `Number` or `Date`; `Null` when there is none.
-}
min : AggregationFn
min =
    placeholder


{-| Largest `Number` or `Date`; `Null` when there is none.
-}
max : AggregationFn
max =
    placeholder


{-| `List [ min, max ]`.
-}
extent : AggregationFn
extent =
    placeholder


{-| Arithmetic mean of numeric values; `Null` when there is none.
-}
mean : AggregationFn
mean =
    placeholder


{-| Median of `Number` values; `Null` when there is none.
-}
median : AggregationFn
median =
    placeholder


{-| Distinct values in first-seen order, as a `List`.
-}
unique : AggregationFn
unique =
    placeholder


{-| Number of distinct values.
-}
uniqueCount : AggregationFn
uniqueCount =
    placeholder


{-| Number of rows.
-}
count : AggregationFn
count =
    placeholder


{-| First row's value, `Null` for no rows.
-}
first : AggregationFn
first =
    placeholder


{-| Last row's value, `Null` for no rows.
-}
last : AggregationFn
last =
    placeholder


{-| Build an aggregation from a fold over leaf values.
-}
custom : (List Value -> Value) -> AggregationFn
custom fold =
    AggregationFn { aggregate = fold, merge = Nothing }


{-| Add a merge step for child-group results.
-}
withMerge : (List Value -> Value) -> AggregationFn -> AggregationFn
withMerge fold (AggregationFn def) =
    AggregationFn { def | merge = Just fold }


{-| Fold leaf values.
-}
aggregate : AggregationFn -> List Value -> Value
aggregate (AggregationFn def) =
    def.aggregate


{-| The merge step, if the aggregation has one.
-}
merge : AggregationFn -> Maybe (List Value -> Value)
merge (AggregationFn def) =
    def.merge


placeholder : AggregationFn
placeholder =
    custom (\values -> Number (toFloat (List.length values)))
