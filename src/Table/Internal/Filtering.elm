module Table.Internal.Filtering exposing
    ( ResolvedFilter
    , filterRows
    , filteredRowModel
    , getAutoFilterFn
    , getCanFilter
    , getFilterFn
    , getFilterIndex
    , getFilterValue
    , getIsFiltered
    , resetColumnFilters
    , resolveColumnFilters
    , resolveGlobalFilters
    , rowPassesColumnFilters
    , rowPassesGlobalFilters
    , setColumnFilter
    , setColumnFilters
    , shouldAutoRemoveFilter
    )

{-| Column filtering: ports `column-filtering/createFilteredRowModel.ts`,
`column-filtering/filterRowsUtils.ts`, and
`column-filtering/columnFilteringFeature.utils.ts`.

Each filter value is resolved once, before the row loop, with the filter
function's `resolveFilterValue`. That is the placement TanStack uses and it is
what makes `includesString` case-insensitive and `inNumberRange` open-ended.

-}

import Dict
import Table.FilterFn as FilterFn exposing (FilterFn)
import Table.Internal.Column as Column
import Table.Internal.GlobalFiltering as GlobalFiltering
import Table.Internal.Row as Row
import Table.Internal.Types exposing (Column, ColumnFilter, Config, Row(..), RowModel, State)
import Table.Value as Value exposing (Value)



-- RESOLVED FILTERS


{-| One filter of `State.columnFilters` (or one column of the global filter)
paired with the function that applies it and with its already resolved filter
value.
-}
type ResolvedFilter row
    = BuiltIn (Row row -> Value) FilterFn Value
    | Custom (Row row -> Value -> Bool) Value


{-| Test one row against one resolved filter.
-}
applyFilter : ResolvedFilter row -> Row row -> Bool
applyFilter resolved row =
    case resolved of
        BuiltIn read fn value ->
            FilterFn.filter fn (read row) value

        Custom fn value ->
            fn row value


{-| A cell reader for one column with the column looked up once, so a row
loop does not rebuild the column index on every row.
-}
valueReader : Config row -> String -> (Row row -> Value)
valueReader cfg columnId =
    case Maybe.andThen Column.accessorFn (Column.findColumn cfg columnId) of
        Just accessor ->
            \row ->
                case Dict.get columnId (Row.aggregatedValues row) of
                    Just aggregated ->
                        aggregated

                    Nothing ->
                        accessor (Row.original row)

        Nothing ->
            \row ->
                Dict.get columnId (Row.aggregatedValues row)
                    |> Maybe.withDefault Value.Null


{-| `resolvedColumnFilters` of `_createFilteredRowModel`: every entry of
`State.columnFilters` whose column exists, with its filter value resolved
once.
-}
resolveColumnFilters : Config row -> RowModel row -> State -> List (ResolvedFilter row)
resolveColumnFilters cfg model state =
    List.filterMap (resolveOne cfg model) state.columnFilters


resolveOne : Config row -> RowModel row -> ColumnFilter -> Maybe (ResolvedFilter row)
resolveOne cfg model columnFilter =
    Column.findColumn cfg columnFilter.id
        |> Maybe.map (\col -> resolveFor cfg model col columnFilter.id columnFilter.value)


resolveFor : Config row -> RowModel row -> Column row -> String -> Value -> ResolvedFilter row
resolveFor cfg model col columnId value =
    case (Column.fields col).customFilter of
        Just fn ->
            Custom fn value

        Nothing ->
            let
                fn : FilterFn
                fn =
                    filterFnOf cfg model col
            in
            BuiltIn (valueReader cfg columnId) fn (FilterFn.resolveFilterValue fn value)


{-| `resolvedGlobalFilters`: the same global filter fn and the same resolved
value, once per globally filterable column.
-}
resolveGlobalFilters : Config row -> RowModel row -> State -> List (ResolvedFilter row)
resolveGlobalFilters cfg model state =
    if not (GlobalFiltering.hasGlobalFilter state) then
        []

    else
        let
            fn : FilterFn
            fn =
                GlobalFiltering.getGlobalFilterFn cfg

            resolved : Value
            resolved =
                FilterFn.resolveFilterValue fn state.globalFilter
        in
        GlobalFiltering.globallyFilterableColumns cfg model
            |> List.map (\col -> BuiltIn (valueReader cfg (Column.id col)) fn resolved)


{-| Does this row pass every column filter? AND semantics.
-}
rowPassesColumnFilters : List (ResolvedFilter row) -> Row row -> Bool
rowPassesColumnFilters filters row =
    List.all (\resolved -> applyFilter resolved row) filters


{-| Does this row pass the global filter? OR semantics across the globally
filterable columns; an empty list means the global filter is not applied.
-}
rowPassesGlobalFilters : List (ResolvedFilter row) -> Row row -> Bool
rowPassesGlobalFilters filters row =
    List.isEmpty filters || List.any (\resolved -> applyFilter resolved row) filters



-- THE ROW MODEL


{-| Drop the rows that fail the column filters and the global filter.
-}
filteredRowModel : Config row -> State -> RowModel row -> RowModel row
filteredRowModel cfg state model =
    let
        hasGlobal : Bool
        hasGlobal =
            GlobalFiltering.hasGlobalFilter state
    in
    if List.isEmpty model.rows || (List.isEmpty state.columnFilters && not hasGlobal) then
        model

    else
        let
            columnFilters : List (ResolvedFilter row)
            columnFilters =
                resolveColumnFilters cfg model state

            globalFilters : List (ResolvedFilter row)
            globalFilters =
                resolveGlobalFilters cfg model state
        in
        if List.isEmpty columnFilters && List.isEmpty globalFilters then
            model

        else
            filterRows cfg
                (\row ->
                    rowPassesColumnFilters columnFilters row
                        && rowPassesGlobalFilters globalFilters row
                )
                model.rows


{-| `filterRows` of `filterRowsUtils.ts`: `Config.filterFromLeafRows` picks
between filtering parents first and filtering children first, and
`Config.maxLeafRowFilterDepth` stops the descent.
-}
filterRows : Config row -> (Row row -> Bool) -> List (Row row) -> RowModel row
filterRows cfg predicate rows =
    let
        tree : List (Row row)
        tree =
            if cfg.filterFromLeafRows then
                fromLeafs cfg predicate 0 rows

            else
                fromRoot cfg predicate 0 rows

        flat : List (Row row)
        flat =
            Row.flattenRows tree
    in
    { rows = tree
    , flatRows = flat
    , rowsById = List.foldl (\r acc -> Dict.insert (Row.id r) r acc) Dict.empty flat
    }


fromRoot : Config row -> (Row row -> Bool) -> Int -> List (Row row) -> List (Row row)
fromRoot cfg predicate depth rows =
    List.filterMap (keepFromRoot cfg predicate depth) rows


keepFromRoot : Config row -> (Row row -> Bool) -> Int -> Row row -> Maybe (Row row)
keepFromRoot cfg predicate depth (Row f) =
    if not (predicate (Row f)) then
        Nothing

    else if not (List.isEmpty f.subRows) && depth < cfg.maxLeafRowFilterDepth then
        Just (Row { f | subRows = fromRoot cfg predicate (depth + 1) f.subRows })

    else
        Just (Row f)


fromLeafs : Config row -> (Row row -> Bool) -> Int -> List (Row row) -> List (Row row)
fromLeafs cfg predicate depth rows =
    List.filterMap (keepFromLeafs cfg predicate depth) rows


keepFromLeafs : Config row -> (Row row -> Bool) -> Int -> Row row -> Maybe (Row row)
keepFromLeafs cfg predicate depth (Row f) =
    if not (List.isEmpty f.subRows) && depth < cfg.maxLeafRowFilterDepth then
        let
            keptSubRows : List (Row row)
            keptSubRows =
                fromLeafs cfg predicate (depth + 1) f.subRows
        in
        if not (List.isEmpty keptSubRows) || predicate (Row f) then
            Just (Row { f | subRows = keptSubRows })

        else
            Nothing

    else if predicate (Row f) then
        Just (Row f)

    else
        Nothing



-- FILTER FN RESOLUTION


{-| `column_getAutoFilterFn`: the built-in filter function chosen from the
type of the column's first non-null value.
-}
getAutoFilterFn : Config row -> RowModel row -> String -> FilterFn
getAutoFilterFn cfg model columnId =
    case firstNonNullValue cfg model columnId of
        Value.String _ ->
            FilterFn.includesString

        Value.Number _ ->
            FilterFn.inNumberRange

        Value.Bool _ ->
            FilterFn.equals

        Value.List _ ->
            FilterFn.arrIncludes

        Value.Date _ ->
            FilterFn.inDateRange

        Value.Null ->
            FilterFn.weakEquals


firstNonNullValue : Config row -> RowModel row -> String -> Value
firstNonNullValue cfg model columnId =
    firstNonNullIn cfg model.flatRows columnId


firstNonNullIn : Config row -> List (Row row) -> String -> Value
firstNonNullIn cfg rows columnId =
    case rows of
        [] ->
            Value.Null

        first :: rest ->
            let
                value : Value
                value =
                    Row.getValue cfg first columnId
            in
            if Value.isNull value then
                firstNonNullIn cfg rest columnId

            else
                value


{-| `column_getFilterFn`: the column's own filter function, or the automatic
one. `Nothing` when the column does not exist.
-}
getFilterFn : Config row -> RowModel row -> String -> Maybe FilterFn
getFilterFn cfg model columnId =
    Column.findColumn cfg columnId
        |> Maybe.map (filterFnOf cfg model)


filterFnOf : Config row -> RowModel row -> Column row -> FilterFn
filterFnOf cfg model col =
    case (Column.fields col).filterFn of
        Just fn ->
            fn

        Nothing ->
            getAutoFilterFn cfg model (Column.id col)



-- COLUMN FILTER STATE


{-| `column_getCanFilter`: the column has an accessor and neither the column
nor the table has switched filtering off.
-}
getCanFilter : Config row -> String -> Bool
getCanFilter cfg columnId =
    case Column.findColumn cfg columnId of
        Nothing ->
            False

        Just col ->
            (Column.fields col).enableColumnFilter
                && cfg.enableColumnFilters
                && cfg.enableFilters
                && hasAccessor col


hasAccessor : Column row -> Bool
hasAccessor col =
    case Column.accessorFn col of
        Just _ ->
            True

        Nothing ->
            False


{-| `column_getFilterIndex`: the column's position in `State.columnFilters`,
or `-1`.
-}
getFilterIndex : State -> String -> Int
getFilterIndex state columnId =
    indexOf columnId 0 state.columnFilters


indexOf : String -> Int -> List ColumnFilter -> Int
indexOf columnId at filters =
    case filters of
        [] ->
            -1

        first :: rest ->
            if first.id == columnId then
                at

            else
                indexOf columnId (at + 1) rest


{-| `column_getIsFiltered`.
-}
getIsFiltered : State -> String -> Bool
getIsFiltered state columnId =
    getFilterIndex state columnId > -1


{-| `column_getFilterValue`.
-}
getFilterValue : State -> String -> Maybe Value
getFilterValue state columnId =
    List.filter (\f -> f.id == columnId) state.columnFilters
        |> List.head
        |> Maybe.map .value


{-| `shouldAutoRemoveFilter`. A filter function's own `autoRemove` is
authoritative; without one, `Null` and the empty string are removed.
-}
shouldAutoRemoveFilter : Maybe FilterFn -> Value -> Bool
shouldAutoRemoveFilter filterFn value =
    case filterFn of
        Just fn ->
            FilterFn.autoRemove fn value

        Nothing ->
            Value.isNull value || value == Value.String ""


{-| `column_setFilterValue`: replace the column's entry in place, append it
when there is none, and drop it when `autoRemove` says the value is blank.
-}
setColumnFilter : Config row -> RowModel row -> String -> Value -> State -> State
setColumnFilter cfg model columnId value state =
    let
        filterFn : Maybe FilterFn
        filterFn =
            columnFilterFnFor cfg model columnId
    in
    if shouldAutoRemoveFilter filterFn value then
        { state | columnFilters = List.filter (\f -> f.id /= columnId) state.columnFilters }

    else if getIsFiltered state columnId then
        { state
            | columnFilters =
                List.map
                    (\f ->
                        if f.id == columnId then
                            { id = columnId, value = value }

                        else
                            f
                    )
                    state.columnFilters
        }

    else
        { state | columnFilters = state.columnFilters ++ [ { id = columnId, value = value } ] }


{-| The filter fn `column_setFilterValue` and `table_setColumnFilters`
consult. A column filtered with `withCustomFilter` has no `FilterFn`, so the
default blank rules apply to it.
-}
columnFilterFnFor : Config row -> RowModel row -> String -> Maybe FilterFn
columnFilterFnFor cfg model columnId =
    case Column.findColumn cfg columnId of
        Nothing ->
            Nothing

        Just col ->
            case (Column.fields col).customFilter of
                Just _ ->
                    Nothing

                Nothing ->
                    Just (filterFnOf cfg model col)


{-| `table_setColumnFilters`: store the list, dropping the entries of known
columns whose value should auto-remove.
-}
setColumnFilters : Config row -> RowModel row -> List ColumnFilter -> State -> State
setColumnFilters cfg model filters state =
    { state
        | columnFilters =
            List.filter
                (\f ->
                    case Column.findColumn cfg f.id of
                        Nothing ->
                            True

                        Just _ ->
                            not (shouldAutoRemoveFilter (columnFilterFnFor cfg model f.id) f.value)
                )
                filters
    }


{-| `table_resetColumnFilters table true`: back to the feature default of no
filters.
-}
resetColumnFilters : State -> State
resetColumnFilters state =
    { state | columnFilters = [] }
