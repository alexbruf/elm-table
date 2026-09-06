module Table.Internal.Grouping exposing
    ( cellIsGrouped
    , cellIsPlaceholder
    , getCanGroup
    , getGroupedIndex
    , getIsGrouped
    , groupedRowModel
    , groupingValueFor
    , resetGrouping
    , rowIsGrouped
    , setGrouping
    , toggleGrouping
    )

{-| Grouping and aggregation: ports
`column-grouping/createGroupedRowModel.ts` and
`column-grouping/columnGroupingFeature.utils.ts`.

`State.grouping` is applied in order. Every level replaces its rows with one
group row per distinct grouping value, and the rows below the last grouping
level keep their own shape with their depth rewritten.

A group row's id is `"<columnId>:<groupingValue>"`, joined to its parent's id
with `>`. Its `aggregatedValues` hold one entry per leaf column: the
inherited value for the grouping column and its ancestors, the aggregate for
a column with an aggregation function, and `Null` for everything else, which
is what TanStack's `getValue` override returns for those.

-}

import Dict exposing (Dict)
import Table.AggregationFn as AggregationFn exposing (AggregationFn)
import Table.Internal.Aggregation as Aggregation
import Table.Internal.Column as Column
import Table.Internal.Row as Row
import Table.Internal.Types exposing (Column, ColumnFields, Config, Row(..), RowModel, State)
import Table.Value as Value exposing (Value(..))



-- THE ROW MODEL


{-| One column of the grouped model, resolved once instead of per row.
-}
type alias Resolved row =
    { id : String
    , groupIndex : Int
    , aggregationFn : Maybe AggregationFn
    , maxDepth : Int
    , read : Row row -> Value
    }


{-| Everything the recursion needs, computed once per call.
-}
type alias Env row =
    { grouping : List String
    , keyReaders : List (Row row -> Value)
    , columns : List (Resolved row)
    , levels : Int
    }


{-| A cell reader with the column looked up once, mirroring
`Table.Internal.Row.getValue`.
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
                    |> Maybe.withDefault Null


{-| Replace the rows with one group row per distinct value of every grouped
column, recursively.

An empty grouping list, a grouping list that names no existing column, or an
empty row model leaves the input untouched. TanStack rewrites `depth` and
`parentId` back onto its shared row objects at that point; Elm rows are
immutable, so the untouched model already carries its natural relationships.

-}
groupedRowModel : Config row -> State -> RowModel row -> RowModel row
groupedRowModel cfg state model =
    let
        byId : Dict String (Column row)
        byId =
            Column.columnsById cfg

        existing : List String
        existing =
            List.filter (\columnId -> Dict.member columnId byId) state.grouping
    in
    if List.isEmpty model.rows || List.isEmpty existing then
        model

    else
        let
            env : Env row
            env =
                { grouping = existing
                , keyReaders = List.map (keyReader cfg) existing
                , columns = List.map (resolveColumn cfg model existing) (Column.leafColumns cfg)
                , levels = List.length existing
                }

            tree : List (Row row)
            tree =
                groupUp env 0 Nothing model.rows

            flat : List (Row row)
            flat =
                Row.flattenRows tree
        in
        { rows = tree
        , flatRows = flat
        , rowsById = List.foldl (\row acc -> Dict.insert (Row.id row) row acc) Dict.empty flat
        }


resolveColumn : Config row -> RowModel row -> List String -> Column row -> Resolved row
resolveColumn cfg model grouping col =
    { id = Column.id col
    , groupIndex = indexOf (Column.id col) grouping
    , aggregationFn = Aggregation.resolveFn cfg model col
    , maxDepth = (Column.fields col).maxAggregationDepth
    , read = valueReader cfg (Column.id col)
    }


{-| `groupBy`'s per-row value: `columnDef.getGroupingValue` when the column
has one, the cell value otherwise.
-}
keyReader : Config row -> String -> (Row row -> Value)
keyReader cfg columnId =
    case Maybe.andThen (Column.fields >> .getGroupingValue) (Column.findColumn cfg columnId) of
        Just fn ->
            \row -> fn (Row.original row) (Row.index row)

        Nothing ->
            valueReader cfg columnId


groupUp : Env row -> Int -> Maybe String -> List (Row row) -> List (Row row)
groupUp env depth parentId rows =
    if depth >= env.levels then
        List.map (rewriteDepth depth) rows

    else
        case ( nth depth env.grouping, nth depth env.keyReaders ) of
            ( Just columnId, Just read ) ->
                groupBy read rows
                    |> List.indexedMap (makeGroup env depth parentId columnId)

            _ ->
                List.map (rewriteDepth depth) rows


{-| The rows below the deepest grouping level keep their shape and get their
depth rewritten, as `groupUpRecursively` does past `existingGrouping.length`.
-}
rewriteDepth : Int -> Row row -> Row row
rewriteDepth depth (Row f) =
    if List.isEmpty f.subRows then
        Row { f | depth = depth }

    else
        Row { f | depth = depth, subRows = List.map (rewriteDepth (depth + 1)) f.subRows }


makeGroup : Env row -> Int -> Maybe String -> String -> Int -> Bucket row -> Row row
makeGroup env depth parentId columnId index bucket =
    let
        groupingValue : Value
        groupingValue =
            bucket.value

        members : List (Row row)
        members =
            bucket.first :: bucket.rest

        groupId : String
        groupId =
            case parentId of
                Just pid ->
                    pid ++ ">" ++ columnId ++ ":" ++ groupKey groupingValue

                Nothing ->
                    columnId ++ ":" ++ groupKey groupingValue

        subRows : List (Row row)
        subRows =
            groupUp env (depth + 1) (Just groupId) members
                |> List.map (adopt groupId)

        leaves : List (Row row)
        leaves =
            terminalRows members
    in
    Row
        { id = groupId
        , index = index
        , depth = depth
        , original =
            case leaves of
                leaf :: _ ->
                    Row.original leaf

                [] ->
                    Row.original bucket.first
        , subRows = subRows
        , parentId = parentId
        , originalSubRows = []
        , groupingColumnId = Just columnId
        , groupingValue = groupingValue
        , leafRows = leaves
        , aggregatedValues = aggregateAll env depth bucket.first members subRows
        }


{-| `subRows.forEach(subRow => subRow.parentId = id)`.
-}
adopt : String -> Row row -> Row row
adopt groupId (Row f) =
    Row { f | parentId = Just groupId }


{-| `normalizeUniqueAggregationRows(rows, Infinity)`: every terminal
descendant, in encounter order.
-}
terminalRows : List (Row row) -> List (Row row)
terminalRows rows =
    List.concatMap terminalRowsOf rows


terminalRowsOf : Row row -> List (Row row)
terminalRowsOf (Row f) =
    if List.isEmpty f.subRows then
        [ Row f ]

    else
        terminalRows f.subRows



-- AGGREGATION


aggregateAll : Env row -> Int -> Row row -> List (Row row) -> List (Row row) -> Dict String Value
aggregateAll env depth first members subRows =
    List.foldl
        (\col acc -> Dict.insert col.id (aggregateOne depth first members subRows col) acc)
        Dict.empty
        env.columns


aggregateOne : Int -> Row row -> List (Row row) -> List (Row row) -> Resolved row -> Value
aggregateOne depth first members subRows col =
    if col.groupIndex >= 0 && col.groupIndex <= depth then
        -- The active grouping column and its ancestors expose the value the
        -- first member of the bucket carries.
        col.read first

    else
        case col.aggregationFn of
            Nothing ->
                Null

            Just fn ->
                case ( canMerge col subRows, AggregationFn.merge fn ) of
                    ( True, Just mergeFn ) ->
                        mergeFn (List.map col.read subRows)

                    _ ->
                        AggregationFn.aggregate fn
                            (List.map col.read (Aggregation.frontier col.maxDepth members))


{-| `canMerge` in `aggregateColumnValue`: every child is a group row of some
other column.
-}
canMerge : Resolved row -> List (Row row) -> Bool
canMerge col subRows =
    not (List.isEmpty subRows)
        && List.all
            (\row ->
                case Row.groupingColumnId row of
                    Just groupingColumnId ->
                        groupingColumnId /= col.id

                    Nothing ->
                        False
            )
            subRows



-- GROUPING KEYS


{-| One bucket of `groupBy`. `first` is split out so a group row always has a
member to take its `original` and its inherited grouping values from.
-}
type alias Bucket row =
    { value : Value
    , first : Row row
    , rest : List (Row row)
    }


{-| `groupBy`, keeping first-seen order and folding the rows into one
dictionary keyed by the stringified grouping value.
-}
groupBy : (Row row -> Value) -> List (Row row) -> List (Bucket row)
groupBy read rows =
    let
        step : Row row -> ( List String, Dict String (Bucket row) ) -> ( List String, Dict String (Bucket row) )
        step row ( order, buckets ) =
            let
                key : String
                key =
                    groupKey (read row)
            in
            case Dict.get key buckets of
                Just bucket ->
                    ( order, Dict.insert key { bucket | rest = row :: bucket.rest } buckets )

                Nothing ->
                    ( key :: order
                    , Dict.insert key { value = read row, first = row, rest = [] } buckets
                    )

        ( reversedOrder, grouped ) =
            List.foldl step ( [], Dict.empty ) rows
    in
    reversedOrder
        |> List.reverse
        |> List.filterMap
            (\key ->
                Dict.get key grouped
                    |> Maybe.map (\bucket -> { bucket | rest = List.reverse bucket.rest })
            )


{-| TanStack keys a bucket with `` `${groupingValue}` ``. `Value.toString`
matches that everywhere except `Null`, which stands for both `null` and
`undefined` here and takes JavaScript's `String(null)`.
-}
groupKey : Value -> String
groupKey value =
    case value of
        Null ->
            "null"

        _ ->
            Value.toString value



-- GROUPING STATE


{-| `column_getCanGroup`: grouping enabled on the table and the column, and
the column has either an accessor or a grouping-value function.
-}
getCanGroup : Config row -> String -> Bool
getCanGroup cfg columnId =
    case Column.findColumn cfg columnId of
        Nothing ->
            False

        Just col ->
            let
                f : ColumnFields row
                f =
                    Column.fields col
            in
            f.enableGrouping
                && cfg.enableGrouping
                && (hasAccessor col || hasGroupingValue f)


hasAccessor : Column row -> Bool
hasAccessor col =
    case Column.accessorFn col of
        Just _ ->
            True

        Nothing ->
            False


hasGroupingValue : ColumnFields row -> Bool
hasGroupingValue f =
    case f.getGroupingValue of
        Just _ ->
            True

        Nothing ->
            False


{-| `column_getIsGrouped`.
-}
getIsGrouped : State -> String -> Bool
getIsGrouped state columnId =
    List.member columnId state.grouping


{-| `column_getGroupedIndex`: `-1` when the column is not grouped.
-}
getGroupedIndex : State -> String -> Int
getGroupedIndex state columnId =
    indexOf columnId state.grouping


{-| `column_toggleGrouping`: append the column, or drop it and keep the rest
in order.
-}
toggleGrouping : String -> State -> State
toggleGrouping columnId state =
    if List.member columnId state.grouping then
        setGrouping (List.filter (\entry -> entry /= columnId) state.grouping) state

    else
        setGrouping (state.grouping ++ [ columnId ]) state


{-| `table_setGrouping`.
-}
setGrouping : List String -> State -> State
setGrouping grouping state =
    { state | grouping = grouping }


{-| `table_resetGrouping table true`.
-}
resetGrouping : State -> State
resetGrouping state =
    setGrouping [] state


{-| `row_getIsGrouped`: a row built by the grouped row model.
-}
rowIsGrouped : Row row -> Bool
rowIsGrouped row =
    case Row.groupingColumnId row of
        Just _ ->
            True

        Nothing ->
            False


{-| `row_getGroupingValue`: the column's `getGroupingValue` when it has one,
the cell value otherwise.
-}
groupingValueFor : Config row -> Row row -> String -> Value
groupingValueFor cfg row columnId =
    case Maybe.andThen (Column.fields >> .getGroupingValue) (Column.findColumn cfg columnId) of
        Just fn ->
            fn (Row.original row) (Row.index row)

        Nothing ->
            Row.getValue cfg row columnId


{-| `cell_getIsGrouped`: the cell of the column this group row groups by.
-}
cellIsGrouped : State -> Row row -> String -> Bool
cellIsGrouped state row columnId =
    getIsGrouped state columnId && Row.groupingColumnId row == Just columnId


{-| `cell_getIsPlaceholder`: the cell of a grouped column that is not this
row's own grouping column.
-}
cellIsPlaceholder : State -> Row row -> String -> Bool
cellIsPlaceholder state row columnId =
    not (cellIsGrouped state row columnId) && getIsGrouped state columnId



-- SMALL HELPERS


indexOf : a -> List a -> Int
indexOf needle list =
    indexHelp needle list 0


indexHelp : a -> List a -> Int -> Int
indexHelp needle list at =
    case list of
        [] ->
            -1

        x :: rest ->
            if x == needle then
                at

            else
                indexHelp needle rest (at + 1)


nth : Int -> List a -> Maybe a
nth at list =
    List.head (List.drop at list)
