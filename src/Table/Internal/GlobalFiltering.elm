module Table.Internal.GlobalFiltering exposing
    ( autoFilterFn
    , getCanGlobalFilter
    , getGlobalFilterFn
    , globallyFilterableColumns
    , hasGlobalFilter
    , resetGlobalFilter
    , setGlobalFilter
    )

{-| Ports `global-filtering/globalFilteringFeature.utils.ts`.

The global filter is one value applied with one filter function across every
column that answers `True` to [`getCanGlobalFilter`](#getCanGlobalFilter),
with OR semantics: a row survives when any of those columns matches.

-}

import Table.FilterFn as FilterFn exposing (FilterFn)
import Table.Internal.Column as Column
import Table.Internal.Row as Row
import Table.Internal.Types exposing (Column, Config, Row, RowModel, State)
import Table.Value as Value exposing (Value)


{-| `table_getGlobalAutoFilterFn`: global filtering defaults to
`includesString`.
-}
autoFilterFn : FilterFn
autoFilterFn =
    FilterFn.includesString


{-| `table_getGlobalFilterFn`. `Config.globalFilterFn = Nothing` is
TanStack's `'auto'`.
-}
getGlobalFilterFn : Config row -> FilterFn
getGlobalFilterFn cfg =
    Maybe.withDefault autoFilterFn cfg.globalFilterFn


{-| Is the global filter value worth applying? Mirrors TanStack's
`globalFilter !== undefined && globalFilter !== null && globalFilter !== ''`.
-}
hasGlobalFilter : State -> Bool
hasGlobalFilter state =
    not (Value.isNull state.globalFilter) && state.globalFilter /= Value.String ""


{-| `column_getCanGlobalFilter`. The row model is sampled by the default
`getColumnCanGlobalFilter` predicate, which keeps a column only when its
first non-null value is a string or a number.
-}
getCanGlobalFilter : Config row -> RowModel row -> String -> Bool
getCanGlobalFilter cfg model columnId =
    case Column.findColumn cfg columnId of
        Nothing ->
            False

        Just col ->
            canGlobalFilter cfg model col


canGlobalFilter : Config row -> RowModel row -> Column row -> Bool
canGlobalFilter cfg model col =
    ((Column.fields col).enableGlobalFilter /= Just False)
        && cfg.enableGlobalFilter
        && cfg.enableFilters
        && predicate cfg model col
        && hasAccessor col


hasAccessor : Column row -> Bool
hasAccessor col =
    case Column.accessorFn col of
        Just _ ->
            True

        Nothing ->
            False


predicate : Config row -> RowModel row -> Column row -> Bool
predicate cfg model col =
    case cfg.getColumnCanGlobalFilter of
        Just fn ->
            fn col

        Nothing ->
            defaultCanGlobalFilter model col


{-| The stock `getColumnCanGlobalFilter` option: an explicit
`withEnableGlobalFilter True` opts in, otherwise the column's first non-null
value has to be a string or a number.
-}
defaultCanGlobalFilter : RowModel row -> Column row -> Bool
defaultCanGlobalFilter model col =
    if (Column.fields col).enableGlobalFilter == Just True then
        True

    else
        case firstNonNullValue model col of
            Value.String _ ->
                True

            Value.Number _ ->
                True

            _ ->
                False


firstNonNullValue : RowModel row -> Column row -> Value
firstNonNullValue model col =
    case Column.accessorFn col of
        Nothing ->
            Value.Null

        Just accessor ->
            firstNonNull accessor model.flatRows


firstNonNull : (row -> Value) -> List (Row row) -> Value
firstNonNull accessor rows =
    case rows of
        [] ->
            Value.Null

        first :: rest ->
            let
                value : Value
                value =
                    accessor (Row.original first)
            in
            if Value.isNull value then
                firstNonNull accessor rest

            else
                value


{-| Every leaf column the global filter runs against.
-}
globallyFilterableColumns : Config row -> RowModel row -> List (Column row)
globallyFilterableColumns cfg model =
    List.filter (canGlobalFilter cfg model) (Column.leafColumns cfg)


{-| `table_setGlobalFilter`.
-}
setGlobalFilter : Value -> State -> State
setGlobalFilter value state =
    { state | globalFilter = value }


{-| `table_resetGlobalFilter table true`: back to the feature default,
which is `Null`.
-}
resetGlobalFilter : State -> State
resetGlobalFilter state =
    { state | globalFilter = Value.Null }
