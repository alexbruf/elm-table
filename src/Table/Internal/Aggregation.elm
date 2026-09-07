module Table.Internal.Aggregation exposing
    ( Fold(..)
    , aggregationResults
    , aggregationValue
    , aggregationValueOf
    , cellIsAggregated
    , contextFor
    , frontier
    , getAggregationFn
    , getAutoAggregationFn
    , resolveEntries
    , resolveFold
    )

{-| Aggregation: ports `row-aggregation/rowAggregationFeature.utils.ts`.

TanStack resolves a column's `aggregationFn` option, which defaults to
`'auto'`, then folds the values of a frontier of rows. `'auto'` picks `sum`
for a numeric column and `extent` for a date column, sampled from the first
row of the core row model, and leaves every other column unaggregated.

`Column.aggregationFn` is `Maybe AggregationFn` here, and `Nothing` means
`'auto'`, exactly as `Nothing` means `'auto'` for filter and sort functions.

The option also has a list form, `aggregationFn: ['count', 'mean', { id, … }]`,
which produces one keyed result per entry instead of one scalar;
`Table.withAggregationFns` is that form and
[`aggregationResults`](#aggregationResults) reads it back. A duplicated id is
`undefined` in TanStack and `Null` here, with the key kept.

-}

import Dict exposing (Dict)
import Set exposing (Set)
import Table.AggregationFn as AggregationFn exposing (AggregationFn)
import Table.Internal.Column as Column
import Table.Internal.Row as Row
import Table.Internal.Types exposing (AggregationContext, Column, Config, ContextAggregationFn(..), Row(..), RowModel, State)
import Table.Value exposing (Value(..))


{-| What a column aggregates one result with: a fold over the values, or a
function of the whole `AggregationContext`.
-}
type Fold row
    = Values AggregationFn
    | Context (AggregationContext row -> Value)


{-| Run one fold in a context.
-}
runFold : Fold row -> AggregationContext row -> Value
runFold fold ctx =
    case fold of
        Values fn ->
            AggregationFn.aggregate fn ctx.values

        Context fn ->
            fn ctx


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


{-| The scalar fold of a column: its context function, then its own
aggregation function, then the automatic one.
-}
resolveFold : Config row -> RowModel row -> Column row -> Maybe (Fold row)
resolveFold cfg model col =
    case (Column.fields col).contextAggregationFn of
        Just (ContextAggregationFn fn) ->
            Just (Context fn)

        Nothing ->
            Maybe.map Values (resolveFn cfg model col)


{-| `column_getAggregationFns` for the list option. A duplicated id resolves
to nothing, exactly as TanStack warns and keeps the key with `undefined`.
-}
resolveEntries : List ( String, AggregationFn ) -> List ( String, Maybe AggregationFn )
resolveEntries entries =
    let
        counts : Dict String Int
        counts =
            List.foldl
                (\( entryId, _ ) acc ->
                    Dict.insert entryId (1 + Maybe.withDefault 0 (Dict.get entryId acc)) acc
                )
                Dict.empty
                entries
    in
    List.map
        (\( entryId, fn ) ->
            if Maybe.withDefault 0 (Dict.get entryId counts) > 1 then
                ( entryId, Nothing )

            else
                ( entryId, Just fn )
        )
        entries


{-| Does anything aggregate this column at all? `cell_getIsAggregated` asks
`getAggregationFns().some(entry => !!entry.aggregationFn)`.
-}
hasAnyAggregation : Config row -> RowModel row -> Column row -> Bool
hasAnyAggregation cfg model col =
    case (Column.fields col).aggregationFns of
        Just entries ->
            List.any (\( _, fn ) -> fn /= Nothing) (resolveEntries entries)

        Nothing ->
            resolveFold cfg model col /= Nothing


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


{-| Assemble an `AggregationContext`. `subRows` is empty and `groupingRow` is
`Nothing` for root and caller-supplied-row aggregation, which is TanStack
omitting both properties.
-}
contextFor :
    String
    -> Int
    -> (Row row -> Value)
    -> List (Row row)
    -> List (Row row)
    -> List Value
    -> Maybe (Row row)
    -> AggregationContext row
contextFor columnId maxDepth read rows subRows subRowValues groupingRow =
    { columnId = columnId
    , maxDepth = maxDepth
    , rows = rows
    , values = List.map read rows
    , subRows = subRows
    , subRowValues = subRowValues
    , groupingRow = groupingRow
    }


{-| `column_getAggregationValue()` with no options: aggregate one column over
the rows of the row model handed in, at the column's own
`withMaxAggregationDepth`.

TanStack reads the pre-grouped row model here and resolves `'auto'` against
the core row model; this port samples both from the one model it is given.

`withGetAggregationValue` short-circuits the whole computation and
`Config.manualAggregation` makes a column without one give `Null`, exactly as
`column_getAggregationValue` checks both before it aggregates anything.

-}
aggregationValue : Config row -> RowModel row -> String -> Value
aggregationValue cfg model columnId =
    case Column.findColumn cfg columnId of
        Nothing ->
            Null

        Just col ->
            -- The pipeline's own rows are disjoint nodes of one tree, so this
            -- is `uniqueRows: true`: no duplicate check.
            scalarOver cfg
                model
                col
                (Column.fields col).maxAggregationDepth
                (frontier (Column.fields col).maxAggregationDepth model.rows)


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
    case Column.findColumn cfg columnId of
        Nothing ->
            Null

        Just col ->
            scalarOver cfg model col options.maxDepth (frontierUnique options.maxDepth options.rows)


scalarOver : Config row -> RowModel row -> Column row -> Int -> List (Row row) -> Value
scalarOver cfg model col maxDepth rows =
    let
        ctx : AggregationContext row
        ctx =
            contextFor (Column.id col) maxDepth (\row -> Row.getValue cfg row (Column.id col)) rows [] [] Nothing
    in
    case (Column.fields col).getAggregationValue of
        Just provider ->
            provider ctx

        Nothing ->
            if cfg.manualAggregation then
                Null

            else
                case resolveFold cfg model col of
                    Nothing ->
                        Null

                    Just fold ->
                        runFold fold ctx


{-| The keyed counterpart of [`aggregationValue`](#aggregationValue) for a
column built with `Table.withAggregationFns`: one result per entry id. A
column without the list option gives an empty `Dict`, as does a table with
`Config.manualAggregation`.
-}
aggregationResults : Config row -> RowModel row -> String -> Dict String Value
aggregationResults cfg model columnId =
    case Maybe.andThen (Column.fields >> .aggregationFns) (Column.findColumn cfg columnId) of
        Nothing ->
            Dict.empty

        Just entries ->
            if cfg.manualAggregation then
                Dict.empty

            else
                let
                    maxDepth : Int
                    maxDepth =
                        Maybe.withDefault 0
                            (Maybe.map (Column.fields >> .maxAggregationDepth) (Column.findColumn cfg columnId))

                    ctx : AggregationContext row
                    ctx =
                        contextFor columnId
                            maxDepth
                            (\row -> Row.getValue cfg row columnId)
                            (frontier maxDepth model.rows)
                            []
                            []
                            Nothing
                in
                Dict.fromList
                    (List.map
                        (\( entryId, fn ) ->
                            ( entryId
                            , case fn of
                                Nothing ->
                                    Null

                                Just aggregation ->
                                    AggregationFn.aggregate aggregation ctx.values
                            )
                        )
                        (resolveEntries entries)
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
                && (case Column.findColumn cfg columnId of
                        Nothing ->
                            False

                        Just col ->
                            hasAnyAggregation cfg model col
                   )
