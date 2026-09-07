module Table.Internal.Column exposing
    ( accessorFn
    , allColumns
    , children
    , column
    , columnsById
    , depth
    , display
    , fields
    , findColumn
    , flatColumns
    , flatColumnsOf
    , footer
    , group
    , header
    , id
    , isVisible
    , leafColumns
    , leafColumnsOf
    , maxSize
    , minSize
    , orderColumns
    , orderGroupedColumns
    , orderedLeafColumns
    , parentId
    , size
    , visibleLeafColumns
    , withAggregationFn
    , withCustomFilter
    , withCustomSort
    , withEnableCellSelection
    , withEnableCellSpanning
    , withEnableColumnFilter
    , withEnableGlobalFilter
    , withEnableGrouping
    , withEnableHiding
    , withEnableMultiSort
    , withEnablePinning
    , withEnableResizing
    , withEnableSorting
    , withFilterFn
    , withFooter
    , withGetGroupingValue
    , withGetUniqueValues
    , withHeader
    , withInvertSorting
    , withMaxAggregationDepth
    , withMaxSize
    , withMinSize
    , withSize
    , withSortDescFirst
    , withSortFn
    , withSortUndefined
    , withSpanColumns
    , withSpanRows
    , withSpanRowsWhen
    )

{-| Column construction, column accessors, and the column lists a table
derives from its configuration.

Ports `core/columns/constructColumn.ts` and
`core/columns/coreColumnsFeature.utils.ts`.

-}

import Dict exposing (Dict)
import Table.AggregationFn exposing (AggregationFn)
import Table.FilterFn exposing (FilterFn)
import Table.Internal.Types exposing (Column(..), ColumnFields, Config, GroupedColumnMode(..), Row, RowSpanContext, SortUndefined, SpanRows(..), State)
import Table.SortFn exposing (SortFn)
import Table.Value exposing (Value)



-- CONSTRUCTION


{-| An accessor column: an id and a way to read the cell value of a row.
-}
column : String -> (row -> Value) -> Column row
column columnId accessor =
    let
        base : ColumnFields row
        base =
            emptyFields columnId
    in
    Column { base | accessorFn = Just accessor }


{-| A group column: an id and the columns nested under it. Group columns have
no accessor and no cells.
-}
group : String -> List (Column row) -> Column row
group columnId childColumns =
    let
        base : ColumnFields row
        base =
            emptyFields columnId
    in
    Column { base | columns = stamp columnId 1 childColumns }


{-| A display column: an id, no accessor, no children.
-}
display : String -> Column row
display columnId =
    Column (emptyFields columnId)


emptyFields : String -> ColumnFields row
emptyFields columnId =
    { id = columnId
    , accessorFn = Nothing
    , columns = []
    , depth = 0
    , parentId = Nothing
    , header = Nothing
    , footer = Nothing
    , sortFn = Nothing
    , customSort = Nothing
    , sortDescFirst = Nothing
    , invertSorting = False
    , sortUndefined = Nothing
    , enableSorting = True
    , enableMultiSort = Nothing
    , filterFn = Nothing
    , customFilter = Nothing
    , enableColumnFilter = True
    , enableGlobalFilter = Nothing
    , aggregationFn = Nothing
    , maxAggregationDepth = 0
    , getGroupingValue = Nothing
    , getUniqueValues = Nothing
    , enableGrouping = True
    , enableHiding = True
    , enablePinning = True
    , size = Nothing
    , minSize = Nothing
    , maxSize = Nothing
    , enableCellSpanning = True
    , spanColumns = Nothing
    , spanRows = Nothing
    , enableCellSelection = True
    , enableResizing = True
    }


{-| Re-stamp a subtree with its parent id and depth.
-}
stamp : String -> Int -> List (Column row) -> List (Column row)
stamp parent atDepth =
    List.map
        (\(Column f) ->
            Column
                { f
                    | depth = atDepth
                    , parentId = Just parent
                    , columns = stamp f.id (atDepth + 1) f.columns
                }
        )


update : (ColumnFields row -> ColumnFields row) -> Column row -> Column row
update fn (Column f) =
    Column (fn f)



-- OPTIONS


{-| Set the header text.
-}
withHeader : String -> Column row -> Column row
withHeader text =
    update (\f -> { f | header = Just text })


{-| Set the footer text.
-}
withFooter : String -> Column row -> Column row
withFooter text =
    update (\f -> { f | footer = Just text })


{-| Sort this column with a built-in sort function.
-}
withSortFn : SortFn -> Column row -> Column row
withSortFn fn =
    update (\f -> { f | sortFn = Just fn })


{-| Sort this column with a comparison on whole rows.
-}
withCustomSort : (Row row -> Row row -> Order) -> Column row -> Column row
withCustomSort fn =
    update (\f -> { f | customSort = Just fn })


{-| Make the first click on this column sort descending.
-}
withSortDescFirst : Bool -> Column row -> Column row
withSortDescFirst flag =
    update (\f -> { f | sortDescFirst = Just flag })


{-| Invert the sort direction of this column.
-}
withInvertSorting : Bool -> Column row -> Column row
withInvertSorting flag =
    update (\f -> { f | invertSorting = flag })


{-| Decide where `Null` values land when this column is sorted.
-}
withSortUndefined : SortUndefined -> Column row -> Column row
withSortUndefined placement =
    update (\f -> { f | sortUndefined = Just placement })


{-| Allow or forbid sorting on this column.
-}
withEnableSorting : Bool -> Column row -> Column row
withEnableSorting flag =
    update (\f -> { f | enableSorting = flag })


{-| Allow or forbid this column in a multi-sort.
-}
withEnableMultiSort : Bool -> Column row -> Column row
withEnableMultiSort flag =
    update (\f -> { f | enableMultiSort = Just flag })


{-| Filter this column with a built-in filter function.
-}
withFilterFn : FilterFn -> Column row -> Column row
withFilterFn fn =
    update (\f -> { f | filterFn = Just fn })


{-| Filter this column with a predicate on whole rows.
-}
withCustomFilter : (Row row -> Value -> Bool) -> Column row -> Column row
withCustomFilter fn =
    update (\f -> { f | customFilter = Just fn })


{-| Allow or forbid a column filter on this column.
-}
withEnableColumnFilter : Bool -> Column row -> Column row
withEnableColumnFilter flag =
    update (\f -> { f | enableColumnFilter = flag })


{-| Include or exclude this column from the global filter.
-}
withEnableGlobalFilter : Bool -> Column row -> Column row
withEnableGlobalFilter flag =
    update (\f -> { f | enableGlobalFilter = Just flag })


{-| Aggregate this column's values on group rows.
-}
withAggregationFn : AggregationFn -> Column row -> Column row
withAggregationFn fn =
    update (\f -> { f | aggregationFn = Just fn })


{-| Read the value this column groups by, when it differs from the accessor.
The second argument is the row's index, as in TanStack.
-}
withGetGroupingValue : (row -> Int -> Value) -> Column row -> Column row
withGetGroupingValue fn =
    update (\f -> { f | getGroupingValue = Just fn })


{-| How far below each aggregated row the aggregation looks for its values.
`0`, the default, aggregates the rows themselves.
-}
withMaxAggregationDepth : Int -> Column row -> Column row
withMaxAggregationDepth levels =
    update (\f -> { f | maxAggregationDepth = Basics.max 0 levels })


{-| Read the faceting values of a row, when one cell holds several.
-}
withGetUniqueValues : (row -> List Value) -> Column row -> Column row
withGetUniqueValues fn =
    update (\f -> { f | getUniqueValues = Just fn })


{-| Allow or forbid grouping by this column.
-}
withEnableGrouping : Bool -> Column row -> Column row
withEnableGrouping flag =
    update (\f -> { f | enableGrouping = flag })


{-| Allow or forbid hiding this column.
-}
withEnableHiding : Bool -> Column row -> Column row
withEnableHiding flag =
    update (\f -> { f | enableHiding = flag })


{-| Allow or forbid pinning this column.
-}
withEnablePinning : Bool -> Column row -> Column row
withEnablePinning flag =
    update (\f -> { f | enablePinning = flag })


{-| Set this column's size in pixels.
-}
withSize : Float -> Column row -> Column row
withSize px =
    update (\f -> { f | size = Just px })


{-| Set this column's minimum size in pixels.
-}
withMinSize : Float -> Column row -> Column row
withMinSize px =
    update (\f -> { f | minSize = Just px })


{-| Set this column's maximum size in pixels.
-}
withMaxSize : Float -> Column row -> Column row
withMaxSize px =
    update (\f -> { f | maxSize = Just px })


{-| Merge adjacent rows whose value for this column is equal. Ports
`spanRows: true`.
-}
withSpanRows : Column row -> Column row
withSpanRows =
    update (\f -> { f | spanRows = Just SpanRowsOnEqualValues })


{-| Decide per candidate row whether it joins the vertical run anchored at
`anchorRow`. Ports `spanRows` in its predicate form.
-}
withSpanRowsWhen : (RowSpanContext row -> Bool) -> Column row -> Column row
withSpanRowsWhen fn =
    update (\f -> { f | spanRows = Just (SpanRowsWhen fn) })


{-| Make this column's cell span that many columns in the given row, counted
in render order and clamped to the end of the cell's pinned region. Ports
`spanColumns`.
-}
withSpanColumns : (Row row -> Int) -> Column row -> Column row
withSpanColumns fn =
    update (\f -> { f | spanColumns = Just fn })


{-| Turn this column off for cell spanning even when the table allows it.
Ports the column-level `enableCellSpanning`.
-}
withEnableCellSpanning : Bool -> Column row -> Column row
withEnableCellSpanning enabled =
    update (\f -> { f | enableCellSpanning = enabled })


{-| Allow or forbid selecting the cells of this column. Ports the
column-level `enableCellSelection`.
-}
withEnableCellSelection : Bool -> Column row -> Column row
withEnableCellSelection enabled =
    update (\f -> { f | enableCellSelection = enabled })


{-| Allow or forbid resizing this column by dragging. Ports the column-level
`enableResizing`.
-}
withEnableResizing : Bool -> Column row -> Column row
withEnableResizing enabled =
    update (\f -> { f | enableResizing = enabled })



-- ACCESSORS


{-| The record behind a column, for the other internal modules.
-}
fields : Column row -> ColumnFields row
fields (Column f) =
    f


{-| The column id.
-}
id : Column row -> String
id (Column f) =
    f.id


{-| The header text, when one was set.
-}
header : Column row -> Maybe String
header (Column f) =
    f.header


{-| The footer text, when one was set.
-}
footer : Column row -> Maybe String
footer (Column f) =
    f.footer


{-| How deep the column sits in the column tree. Top level is `0`.
-}
depth : Column row -> Int
depth (Column f) =
    f.depth


{-| The columns nested under a group column.
-}
children : Column row -> List (Column row)
children (Column f) =
    f.columns


{-| The id of the group column this column sits under.
-}
parentId : Column row -> Maybe String
parentId (Column f) =
    f.parentId


{-| The accessor, when the column has one.
-}
accessorFn : Column row -> Maybe (row -> Value)
accessorFn (Column f) =
    f.accessorFn


{-| This column's size, falling back to the configured default.
-}
size : Config row -> Column row -> Float
size cfg (Column f) =
    clamp (Maybe.withDefault cfg.defaultColumn.minSize f.minSize)
        (Maybe.withDefault cfg.defaultColumn.maxSize f.maxSize)
        (Maybe.withDefault cfg.defaultColumn.size f.size)


{-| This column's minimum size, falling back to the configured default.
-}
minSize : Config row -> Column row -> Float
minSize cfg (Column f) =
    Maybe.withDefault cfg.defaultColumn.minSize f.minSize


{-| This column's maximum size, falling back to the configured default.
-}
maxSize : Config row -> Column row -> Float
maxSize cfg (Column f) =
    Maybe.withDefault cfg.defaultColumn.maxSize f.maxSize



-- COLUMN LISTS


{-| The top level column tree, as configured.
-}
allColumns : Config row -> List (Column row)
allColumns cfg =
    cfg.columns


{-| Every column of the table, group columns included, each group before its
children.
-}
flatColumns : Config row -> List (Column row)
flatColumns cfg =
    List.concatMap flatColumnsOf cfg.columns


{-| A column and every column below it, the column itself first.
-}
flatColumnsOf : Column row -> List (Column row)
flatColumnsOf (Column f) =
    Column f :: List.concatMap flatColumnsOf f.columns


{-| The leaf columns below one column. A leaf column returns itself.
-}
leafColumnsOf : Column row -> List (Column row)
leafColumnsOf (Column f) =
    if List.isEmpty f.columns then
        [ Column f ]

    else
        List.concatMap leafColumnsOf f.columns


{-| Every leaf column of the table, in definition order.
-}
leafColumns : Config row -> List (Column row)
leafColumns cfg =
    List.concatMap leafColumnsOf cfg.columns


{-| Every leaf column in table order: `State.columnOrder` applied first, then
the grouped-column rules of `Config.groupedColumnMode`. Ports
`table_getAllLeafColumns`.
-}
orderedLeafColumns : Config row -> State -> List (Column row)
orderedLeafColumns cfg state =
    orderColumns cfg state (leafColumns cfg)


{-| The leaf columns a table renders: table order applied, hidden columns
dropped. Ports `table_getVisibleLeafColumns`.

Column pinning splits this list into left, center, and right; the split
happens after this function, not inside it, exactly as in TanStack.

-}
visibleLeafColumns : Config row -> State -> List (Column row)
visibleLeafColumns cfg state =
    orderedLeafColumns cfg state
        |> List.filter (isVisible state)


{-| Put a column list in table order: `State.columnOrder` first, then
`orderGroupedColumns`. Ports `table_getOrderColumnsFn`.
-}
orderColumns : Config row -> State -> List (Column row) -> List (Column row)
orderColumns cfg state columns =
    applyColumnOrder state columns
        |> orderGroupedColumns cfg state


{-| Reorder columns by `State.columnOrder`, keeping unlisted columns in their
original order behind the listed ones.
-}
applyColumnOrder : State -> List (Column row) -> List (Column row)
applyColumnOrder state columns =
    if List.isEmpty state.columnOrder then
        columns

    else
        let
            byId : Dict String (Column row)
            byId =
                List.foldl (\c acc -> Dict.insert (id c) c acc) Dict.empty columns

            wanted : List String
            wanted =
                dedupe state.columnOrder []
                    |> List.filter (\cid -> Dict.member cid byId)
        in
        List.filterMap (\cid -> Dict.get cid byId) wanted
            ++ List.filter (\c -> not (List.member (id c) wanted)) columns


{-| Apply `Config.groupedColumnMode` to a leaf column list: `reorder` moves
the grouped columns to the front in grouping order, `remove` drops them, and
`ignore` leaves the list alone. Ports `orderColumns`.
-}
orderGroupedColumns : Config row -> State -> List (Column row) -> List (Column row)
orderGroupedColumns cfg state columns =
    if List.isEmpty state.grouping then
        columns

    else
        let
            nonGrouping : List (Column row)
            nonGrouping =
                List.filter (\c -> not (List.member (id c) state.grouping)) columns
        in
        case cfg.groupedColumnMode of
            GroupedColumnsIgnore ->
                columns

            GroupedColumnsRemove ->
                nonGrouping

            GroupedColumnsReorder ->
                let
                    byId : Dict String (Column row)
                    byId =
                        List.foldl (\c acc -> Dict.insert (id c) c acc) Dict.empty columns
                in
                List.filterMap (\cid -> Dict.get cid byId) state.grouping ++ nonGrouping


dedupe : List String -> List String -> List String
dedupe ids seen =
    case ids of
        [] ->
            List.reverse seen

        first :: rest ->
            if List.member first seen then
                dedupe rest seen

            else
                dedupe rest (first :: seen)


{-| Is this column visible? A group column is visible when any of its leaf
columns is.
-}
isVisible : State -> Column row -> Bool
isVisible state (Column f) =
    if List.isEmpty f.columns then
        Dict.get f.id state.columnVisibility
            |> Maybe.withDefault True

    else
        List.any (isVisible state) f.columns


{-| Every column of the table keyed by id, group columns included.
-}
columnsById : Config row -> Dict String (Column row)
columnsById cfg =
    List.foldl (\c acc -> Dict.insert (id c) c acc) Dict.empty (flatColumns cfg)


{-| Find a column by id. Group columns are found too.
-}
findColumn : Config row -> String -> Maybe (Column row)
findColumn cfg columnId =
    Dict.get columnId (columnsById cfg)
