module Table.Internal.Aggregation exposing
    ( aggregationValue
    , aggregationValueOf
    , cellIsAggregated
    , frontier
    , getAggregationFn
    , getAutoAggregationFn
    , resolveFn
    )

{-| Aggregation: ports `row-aggregation/rowAggregationFeature.utils.ts`.

TanStack resolves a column's `aggregationFn` option, which defaults to
`'auto'`, then folds the values of a frontier of rows. `'auto'` picks `sum`
for a numeric column and `extent` for a date column, sampled from the first
row of the core row model, and leaves every other column unaggregated.

`Column.aggregationFn` is `Maybe AggregationFn` here, and `Nothing` means
`'auto'`, exactly as `Nothing` means `'auto'` for filter and sort functions.

-}

import Set exposing (Set)
import Table.AggregationFn as AggregationFn exposing (AggregationFn)
import Table.Internal.Column as Column
import Table.Internal.Row as Row
import Table.Internal.Types exposing (Column, Config, Row(..), RowModel, State)
import Table.Value exposing (Value(..))


{-| `column_getAutoAggregationFn`: `sum` for a numeric column, `extent` for a
date column, nothing for anything else. The value is sampled from the first
flat row of the row model handed in, which is the core row model in TanStack.
-}
getAutoAggregationFn : Config row -> RowModel row -> String -> Maybe AggregationFn
getAutoAggregationFn cfg model columnId =
    case List.head model.flatRows of
        Nothing ->
            Nothing

        Just row ->
            case Row.getValue cfg row columnId of
                Number _ ->
                    Just AggregationFn.sum

                Date _ ->
                    Just AggregationFn.extent

                _ ->
                    Nothing


{-| `column_getAggregationFns` for a scalar option: the column's own
aggregation function, or the automatic one when it has none.
-}
getAggregationFn : Config row -> RowModel row -> String -> Maybe AggregationFn
getAggregationFn cfg model columnId =
    case Column.findColumn cfg columnId of
        Nothing ->
            Nothing

        Just col ->
            resolveFn cfg model col


{-| The same resolution with the column already in hand.
-}
resolveFn : Config row -> RowModel row -> Column row -> Maybe AggregationFn
resolveFn cfg model col =
    case (Column.fields col).aggregationFn of
        Just fn ->
            Just fn

        Nothing ->
            getAutoAggregationFn cfg model (Column.id col)


{-| `normalizeUniqueAggregationRows`: the rows `maxDepth` levels below the
ones handed in, in encounter order. A branch that ends before `maxDepth`
contributes its deepest row.

This is the form for rows the pipeline produced itself, which are disjoint
nodes of one tree and so need no duplicate check.

-}
frontier : Int -> List (Row row) -> List (Row row)
frontier maxDepth rows =
    if maxDepth <= 0 then
        rows

    else
        List.concatMap (frontierOf maxDepth) rows


frontierOf : Int -> Row row -> List (Row row)
frontierOf maxDepth (Row f) =
    if List.isEmpty f.subRows then
        [ Row f ]

    else
        frontier (maxDepth - 1) f.subRows


{-| `normalizeAggregationRows`: the same frontier for a caller-supplied row
list, which may hold a row and one of its own ancestors. The first occurrence
of a row id wins and later ones are dropped.
-}
frontierUnique : Int -> List (Row row) -> List (Row row)
frontierUnique maxDepth rows =
    dedup (frontier maxDepth rows) Set.empty []


dedup : List (Row row) -> Set String -> List (Row row) -> List (Row row)
dedup queue seen acc =
    case queue of
        [] ->
            List.reverse acc

        row :: rest ->
            let
                rowId : String
                rowId =
                    Row.id row
            in
            if Set.member rowId seen then
                dedup rest seen acc

            else
                dedup rest (Set.insert rowId seen) (row :: acc)


{-| `column_getAggregationValue()` with no options: aggregate one column over
the rows of the row model handed in, at the column's own
`withMaxAggregationDepth`.

TanStack reads the pre-grouped row model here and resolves `'auto'` against
the core row model; this port samples both from the one model it is given.

-}
aggregationValue : Config row -> RowModel row -> String -> Value
aggregationValue cfg model columnId =
    case Column.findColumn cfg columnId of
        Nothing ->
            Null

        Just col ->
            case resolveFn cfg model col of
                Nothing ->
                    Null

                Just fn ->
                    -- The pipeline's own rows are disjoint nodes of one tree,
                    -- so this is `uniqueRows: true`: no duplicate check.
                    AggregationFn.aggregate fn
                        (List.map (\row -> Row.getValue cfg row columnId)
                            (frontier (Column.fields col).maxAggregationDepth model.rows)
                        )


{-| `column_getAggregationValue({ maxDepth, rows })`: aggregate one column
over a caller-chosen set of rows and depth. The `RowModel row` is only there
to resolve an `'auto'` aggregation function.
-}
aggregationValueOf :
    Config row
    -> RowModel row
    -> String
    -> { maxDepth : Int, rows : List (Row row) }
    -> Value
aggregationValueOf cfg model columnId options =
    case getAggregationFn cfg model columnId of
        Nothing ->
            Null

        Just fn ->
            AggregationFn.aggregate fn
                (List.map (\row -> Row.getValue cfg row columnId)
                    (frontierUnique options.maxDepth options.rows)
                )


{-| `cell_getIsAggregated`: true on a group row for a column that is not the
row's own grouping column, is not itself grouped, and has an aggregation
function.
-}
cellIsAggregated : Config row -> RowModel row -> State -> Row row -> String -> Bool
cellIsAggregated cfg model state row columnId =
    case Row.groupingColumnId row of
        Nothing ->
            False

        Just groupingColumnId ->
            (groupingColumnId /= columnId)
                && not (List.member columnId state.grouping)
                && hasAggregationFn cfg model columnId


hasAggregationFn : Config row -> RowModel row -> String -> Bool
hasAggregationFn cfg model columnId =
    case getAggregationFn cfg model columnId of
        Just _ ->
            True

        Nothing ->
            False
