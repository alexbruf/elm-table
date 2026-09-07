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
    , taggedRowModel
    )

{-| Column filtering: ports `column-filtering/createFilteredRowModel.ts`,
`column-filtering/filterRowsUtils.ts`, and
`column-filtering/columnFilteringFeature.utils.ts`.

Each filter value is resolved once, before the row loop, with the filter
function's `resolveFilterValue`. That is the placement TanStack uses and it is
what makes `includesString` case-insensitive and `inNumberRange` open-ended.

`_createFilteredRowModel` first writes `row.columnFilters` and
`row.columnFiltersMeta` onto every row of the pre-filtered model, then drops
the rows whose flags hold a `false`. This module does the same in two passes:
[`taggedRowModel`](#taggedRowModel) writes the flags and drops nothing, and
[`filteredRowModel`](#filteredRowModel) filters the tagged tree.

-}

import Dict exposing (Dict)
import Table.FilterFn as FilterFn exposing (FilterFn)
import Table.Internal.Column as Column
import Table.Internal.GlobalFiltering as GlobalFiltering
import Table.Internal.Row as Row
import Table.Internal.Types exposing (Column, ColumnFilter, Config, Row(..), RowFields, RowModel, State)
import Table.Value as Value exposing (Value)



-- RESOLVED FILTERS


{-| One filter of `State.columnFilters` (or one column of the global filter)
paired with the function that applies it and with its already resolved filter
value.
-}
type ResolvedFilter row
    = BuiltIn String (Row row -> Value) FilterFn Value
    | Custom String (Row row -> Value -> Bool) Value
    | CustomMeta String (Row row -> Value -> ( Bool, Maybe Value )) Value


{-| The column id a resolved filter is keyed by in `row.columnFilters`.
-}
filterId : ResolvedFilter row -> String
filterId resolved =
    case resolved of
        BuiltIn columnId _ _ _ ->
            columnId

        Custom columnId _ _ ->
            columnId

        CustomMeta columnId _ _ ->
            columnId


{-| Test one row against one resolved filter.
-}
applyFilter : ResolvedFilter row -> Row row -> Bool
applyFilter resolved row =
    case resolved of
        BuiltIn _ read fn value ->
            FilterFn.filter fn (read row) value

        Custom _ fn value ->
            fn row value

        CustomMeta _ fn value ->
            Tuple.first (fn row value)


{-| Test one row and produce the meta the filter records for it, TanStack's
`filterFn(row, id, value, addMeta)`.
-}
applyFilterWithMeta : ResolvedFilter row -> Row row -> ( Bool, Maybe Value )
applyFilterWithMeta resolved row =
    case resolved of
        BuiltIn _ read fn value ->
            let
                dataValue : Value
                dataValue =
                    read row
            in
            ( FilterFn.filter fn dataValue value
            , case FilterFn.meta fn of
                Nothing ->
                    Nothing

                Just producer ->
                    producer (FilterFn.resolveDataValue fn dataValue) value
            )

        Custom _ fn value ->
            ( fn row value, Nothing )

        CustomMeta _ fn value ->
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
    case (Column.fields col).customFilterMeta of
        Just fn ->
            CustomMeta columnId fn value

        Nothing ->
            case (Column.fields col).customFilter of
                Just fn ->
                    Custom columnId fn value

                Nothing ->
                    let
                        fn : FilterFn
                        fn =
                            filterFnOf cfg model col
                    in
                    BuiltIn columnId (valueReader cfg columnId) fn (FilterFn.resolveFilterValue fn value)


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
            |> List.map (\col -> BuiltIn (Column.id col) (valueReader cfg (Column.id col)) fn resolved)


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


{-| The key `row.columnFilters` stores the global filter's verdict under,
`"__global__"`. The same key `Table.globalFacetKey` uses.
-}
globalFilterKey : String
globalFilterKey =
    "__global__"


{-| The active filters of one call, resolved once. `anyMeta` is settled here
too, so a table whose filters record nothing — every table that does not opt
in — never allocates a meta map or a pass/meta pair per row.
-}
type alias Active row =
    { columns : List (ResolvedFilter row)
    , global : List (ResolvedFilter row)
    , anyMeta : Bool
    }


active : Config row -> State -> RowModel row -> Maybe (Active row)
active cfg state model =
    let
        hasGlobal : Bool
        hasGlobal =
            GlobalFiltering.hasGlobalFilter state
    in
    if List.isEmpty model.rows || (List.isEmpty state.columnFilters && not hasGlobal) then
        Nothing

    else
        let
            columns : List (ResolvedFilter row)
            columns =
                resolveColumnFilters cfg model state

            global : List (ResolvedFilter row)
            global =
                resolveGlobalFilters cfg model state
        in
        if List.isEmpty columns && List.isEmpty global then
            Nothing

        else
            Just
                { columns = columns
                , global = global
                , anyMeta = List.any hasMeta columns || List.any hasMeta global
                }


{-| Can this filter record meta at all?
-}
hasMeta : ResolvedFilter row -> Bool
hasMeta resolved =
    case resolved of
        BuiltIn _ _ fn _ ->
            FilterFn.meta fn /= Nothing

        Custom _ _ _ ->
            False

        CustomMeta _ _ _ ->
            True


{-| The pre-filtered row model with `row.columnFilters` and
`row.columnFiltersMeta` written onto every row, dropping nothing.

TanStack writes these two maps onto the rows of `getPreFilteredRowModel()` in
place, so they are readable there once `getFilteredRowModel()` has run. Rows
are immutable here, so this is the function that hands them back.

-}
taggedRowModel : Config row -> State -> RowModel row -> RowModel row
taggedRowModel cfg state model =
    case active cfg state model of
        Nothing ->
            clearTags model

        Just filters ->
            rebuild (List.map (tagRow filters) model.rows)


{-| Drop the rows that fail the column filters and the global filter.
-}
filteredRowModel : Config row -> State -> RowModel row -> RowModel row
filteredRowModel cfg state model =
    case active cfg state model of
        Nothing ->
            clearTags model

        Just filters ->
            let
                filterableIds : List String
                filterableIds =
                    List.map filterId filters.columns
                        ++ (if List.isEmpty filters.global then
                                []

                            else
                                [ globalFilterKey ]
                           )
            in
            -- The tag is written as each row is visited rather than in a pass
            -- of its own, so a row is rebuilt once. Rows below a parent that
            -- the from-root path drops are never visited and so never tagged;
            -- they are dropped with it either way, and `taggedRowModel` is
            -- the function that tags every row.
            filterRowsWith cfg (tagOne filters) (passesTags filterableIds) model.rows


{-| `for (const id of filterableIds) if (row.columnFilters[id] === false)
return false`.
-}
passesTags : List String -> Row row -> Bool
passesTags filterableIds row =
    let
        flags : Dict String Bool
        flags =
            Row.columnFilters row
    in
    List.all (\columnId -> Dict.get columnId flags /= Just False) filterableIds


{-| Write the two maps onto one row and every row below it.
-}
tagRow : Active row -> Row row -> Row row
tagRow filters row =
    case tagOne filters row of
        Row f ->
            Row { f | subRows = List.map (tagRow filters) f.subRows }


{-| Write the two maps onto one row, leaving its sub-rows alone.
-}
tagOne : Active row -> Row row -> Row row
tagOne filters (Row f) =
    if filters.anyMeta then
        let
            afterColumns : ( Dict String Bool, Dict String Value )
            afterColumns =
                List.foldl (tagColumnFilter (Row f)) ( Dict.empty, Dict.empty ) filters.columns

            ( flags, recorded ) =
                List.foldl (tagGlobalFilter (Row f)) afterColumns filters.global
        in
        withTags f
            (if List.isEmpty filters.global then
                flags

             else
                Dict.insert globalFilterKey
                    (Dict.get globalFilterKey flags == Just True)
                    flags
            )
            recorded

    else
        withTags f (flagsOnly filters (Row f)) Dict.empty


{-| The tagged row, written as a whole record rather than as a record update.

Every row of a filtered model goes through here, and Elm compiles a record
update to a copy loop over the old record plus a second object for the
changed fields, where a full literal is one allocation. It is worth the
duplicated field list: the filtered stage of the 10k-row benchmark spends
about a sixth of its time in this one function.

-}
withTags : RowFields row -> Dict String Bool -> Dict String Value -> Row row
withTags f flags recorded =
    Row
        { id = f.id
        , index = f.index
        , depth = f.depth
        , original = f.original
        , subRows = f.subRows
        , parentId = f.parentId
        , originalSubRows = f.originalSubRows
        , groupingColumnId = f.groupingColumnId
        , groupingValue = f.groupingValue
        , leafRows = f.leafRows
        , aggregatedValues = f.aggregatedValues
        , aggregationResults = f.aggregationResults
        , columnFilters = flags
        , columnFiltersMeta = recorded
        }


{-| The same flags with no meta map to carry along, which is every filter fn
that was not built with `Table.FilterFn.withMeta`.
-}
flagsOnly : Active row -> Row row -> Dict String Bool
flagsOnly filters row =
    let
        columns : Dict String Bool
        columns =
            List.foldl
                (\resolved flags -> Dict.insert (filterId resolved) (applyFilter resolved row) flags)
                Dict.empty
                filters.columns
    in
    if List.isEmpty filters.global then
        columns

    else
        Dict.insert globalFilterKey (rowPassesGlobalFilters filters.global row) columns


tagColumnFilter :
    Row row
    -> ResolvedFilter row
    -> ( Dict String Bool, Dict String Value )
    -> ( Dict String Bool, Dict String Value )
tagColumnFilter row resolved ( flags, recorded ) =
    let
        ( passed, produced ) =
            applyFilterWithMeta resolved row
    in
    ( Dict.insert (filterId resolved) passed flags
    , recordMeta (filterId resolved) produced recorded
    )


{-| The global loop stops at the first column that matches, exactly like the
`break` in `_createFilteredRowModel`, so a later column records no meta.
-}
tagGlobalFilter :
    Row row
    -> ResolvedFilter row
    -> ( Dict String Bool, Dict String Value )
    -> ( Dict String Bool, Dict String Value )
tagGlobalFilter row resolved ( flags, recorded ) =
    if Dict.get globalFilterKey flags == Just True then
        ( flags, recorded )

    else
        let
            ( passed, produced ) =
                applyFilterWithMeta resolved row
        in
        ( if passed then
            Dict.insert globalFilterKey True flags

          else
            flags
        , recordMeta (filterId resolved) produced recorded
        )


recordMeta : String -> Maybe Value -> Dict String Value -> Dict String Value
recordMeta columnId produced recorded =
    case produced of
        Nothing ->
            recorded

        Just value ->
            Dict.insert columnId value recorded


{-| `row.columnFilters = makeObjectMap()` for a model with no active filters.
Nothing is rebuilt when no row carries a tag, which is every row model the
pipeline itself produces.
-}
clearTags : RowModel row -> RowModel row
clearTags model =
    if List.any isTagged model.flatRows then
        rebuild (List.map clearRowTags model.rows)

    else
        model


isTagged : Row row -> Bool
isTagged (Row f) =
    not (Dict.isEmpty f.columnFilters) || not (Dict.isEmpty f.columnFiltersMeta)


clearRowTags : Row row -> Row row
clearRowTags (Row f) =
    Row
        { f
            | columnFilters = Dict.empty
            , columnFiltersMeta = Dict.empty
            , subRows = List.map clearRowTags f.subRows
        }


rebuild : List (Row row) -> RowModel row
rebuild tree =
    let
        flat : List (Row row)
        flat =
            Row.flattenRows tree
    in
    { rows = tree
    , flatRows = flat
    , rowsById = List.foldl (\r acc -> Dict.insert (Row.id r) r acc) Dict.empty flat
    }


{-| `filterRows` of `filterRowsUtils.ts`: `Config.filterFromLeafRows` picks
between filtering parents first and filtering children first, and
`Config.maxLeafRowFilterDepth` stops the descent.
-}
filterRows : Config row -> (Row row -> Bool) -> List (Row row) -> RowModel row
filterRows cfg predicate rows =
    filterRowsWith cfg identity predicate rows


{-| The same walk with a step that rewrites each row as it is visited, which
is how the filtered row model writes its flags without a pass of its own.
-}
filterRowsWith : Config row -> (Row row -> Row row) -> (Row row -> Bool) -> List (Row row) -> RowModel row
filterRowsWith cfg tag predicate rows =
    rebuild
        (if cfg.filterFromLeafRows then
            fromLeafs cfg tag predicate 0 rows

         else
            fromRoot cfg tag predicate 0 rows
        )


fromRoot : Config row -> (Row row -> Row row) -> (Row row -> Bool) -> Int -> List (Row row) -> List (Row row)
fromRoot cfg tag predicate depth rows =
    List.filterMap (keepFromRoot cfg tag predicate depth) rows


keepFromRoot : Config row -> (Row row -> Row row) -> (Row row -> Bool) -> Int -> Row row -> Maybe (Row row)
keepFromRoot cfg tag predicate depth row =
    case tag row of
        Row f ->
            if not (predicate (Row f)) then
                Nothing

            else if not (List.isEmpty f.subRows) && depth < cfg.maxLeafRowFilterDepth then
                Just (Row { f | subRows = fromRoot cfg tag predicate (depth + 1) f.subRows })

            else
                Just (Row f)


fromLeafs : Config row -> (Row row -> Row row) -> (Row row -> Bool) -> Int -> List (Row row) -> List (Row row)
fromLeafs cfg tag predicate depth rows =
    List.filterMap (keepFromLeafs cfg tag predicate depth) rows


keepFromLeafs : Config row -> (Row row -> Row row) -> (Row row -> Bool) -> Int -> Row row -> Maybe (Row row)
keepFromLeafs cfg tag predicate depth row =
    case tag row of
        Row f ->
            if not (List.isEmpty f.subRows) && depth < cfg.maxLeafRowFilterDepth then
                let
                    keptSubRows : List (Row row)
                    keptSubRows =
                        fromLeafs cfg tag predicate (depth + 1) f.subRows
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
