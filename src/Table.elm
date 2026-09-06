module Table
    exposing
    -- Phase 2
    ( Column, Config, State, Row, RowModel, Header, HeaderGroup, Cell
    , Expanded, SortUndefined, GroupedColumnMode
    , SortColumn, ColumnFilter, Pagination, ColumnPinning, RowPinning, SizeDefaults
    , expandAll, expandedIds, expandedIdsOf
    , sortNullsFirst, sortNullsLast, sortNullsAsMinusOne, sortNullsAsPlusOne
    , groupedColumnsReorder, groupedColumnsRemove, groupedColumnsIgnore
    , config, initialState
    , withGetRowId, withSubRows, withDefaultColumn, withGlobalFilterFn, withRowSelection
    , column, group, display
    , withHeader, withFooter
    , withSortFn, withCustomSort, withSortDescFirst, withInvertSorting, withSortUndefined
    , withEnableSorting, withEnableMultiSort
    , withFilterFn, withCustomFilter, withEnableColumnFilter, withEnableGlobalFilter
    , withAggregationFn, withGetGroupingValue, withGetUniqueValues, withEnableGrouping
    , withEnableHiding, withEnablePinning
    , withSize, withMinSize, withMaxSize
    , columnId, columnHeader, columnFooter, columnDepth, columnColumns, columnParentId, columnAccessor
    , columnSize, columnMinSize, columnMaxSize
    , allColumns, leafColumns, visibleLeafColumns, findColumn
    , columnFlatColumns, columnLeafColumns
    , rowId, rowIndex, rowDepth, rowOriginal, rowSubRows, rowParentId, rowOriginalSubRows
    , rowGroupingColumnId, rowGroupingValue, rowLeafRows, rowAggregatedValues
    , getValue, getUniqueValues, getLeafRows, getParentRow, getParentRows, getAllCells
    , findRow, maxSubRowDepth
    , headerGroups, footerGroups, flatHeaders, leafHeaders, getLeafHeaders
    , headerId, headerColumnId, headerColSpan, headerRowSpan, headerDepth, headerIndex
    , headerIsPlaceholder, headerPlaceholderId, headerSubHeaders
    , rows, rowsFromList, coreRowModel, coreRowModelFromList
    , filteredRowModel, groupedRowModel, sortedRowModel, expandedRowModel, paginatedRowModel
    , facetedUniqueValues, facetedMinMax
    -- Phase 3
    -- Phase 4
    -- Phase 5
    )

{-| Headless table state and row-model pipeline: a port of TanStack Table
core as pure functions.

There is no table instance. You own the `State`, you own the data, and every
function here takes a `Config row` and a `State` and gives you a value back.


# Phase 2


## Types

@docs Column, Config, State, Row, RowModel, Header, HeaderGroup, Cell
@docs Expanded, SortUndefined, GroupedColumnMode
@docs SortColumn, ColumnFilter, Pagination, ColumnPinning, RowPinning, SizeDefaults

Elm cannot re-export the variants of a type that is declared in another
module, so the three unions above are abstract here and come with one
function per variant.

@docs expandAll, expandedIds, expandedIdsOf
@docs sortNullsFirst, sortNullsLast, sortNullsAsMinusOne, sortNullsAsPlusOne
@docs groupedColumnsReorder, groupedColumnsRemove, groupedColumnsIgnore


## Configuration

@docs config, initialState
@docs withGetRowId, withSubRows, withDefaultColumn, withGlobalFilterFn, withRowSelection


## Building columns

@docs column, group, display
@docs withHeader, withFooter
@docs withSortFn, withCustomSort, withSortDescFirst, withInvertSorting, withSortUndefined
@docs withEnableSorting, withEnableMultiSort
@docs withFilterFn, withCustomFilter, withEnableColumnFilter, withEnableGlobalFilter
@docs withAggregationFn, withGetGroupingValue, withGetUniqueValues, withEnableGrouping
@docs withEnableHiding, withEnablePinning
@docs withSize, withMinSize, withMaxSize


## Reading columns

@docs columnId, columnHeader, columnFooter, columnDepth, columnColumns, columnParentId, columnAccessor
@docs columnSize, columnMinSize, columnMaxSize
@docs allColumns, leafColumns, visibleLeafColumns, findColumn
@docs columnFlatColumns, columnLeafColumns


## Reading rows

@docs rowId, rowIndex, rowDepth, rowOriginal, rowSubRows, rowParentId, rowOriginalSubRows
@docs rowGroupingColumnId, rowGroupingValue, rowLeafRows, rowAggregatedValues
@docs getValue, getUniqueValues, getLeafRows, getParentRow, getParentRows, getAllCells
@docs findRow, maxSubRowDepth


## Headers

@docs headerGroups, footerGroups, flatHeaders, leafHeaders, getLeafHeaders
@docs headerId, headerColumnId, headerColSpan, headerRowSpan, headerDepth, headerIndex
@docs headerIsPlaceholder, headerPlaceholderId, headerSubHeaders


## The pipeline

@docs rows, rowsFromList, coreRowModel, coreRowModelFromList
@docs filteredRowModel, groupedRowModel, sortedRowModel, expandedRowModel, paginatedRowModel


## Faceting

@docs facetedUniqueValues, facetedMinMax


# Phase 3


# Phase 4


# Phase 5

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Set exposing (Set)
import Table.AggregationFn exposing (AggregationFn)
import Table.FilterFn exposing (FilterFn)
import Table.Internal.Column as Column
import Table.Internal.Config as Config
import Table.Internal.CoreRowModel as CoreRowModel
import Table.Internal.Expanding as Expanding
import Table.Internal.Faceting as Faceting
import Table.Internal.Filtering as Filtering
import Table.Internal.Grouping as Grouping
import Table.Internal.Header as Header
import Table.Internal.Pagination as Pagination
import Table.Internal.Row as Row
import Table.Internal.Sorting as Sorting
import Table.Internal.Types as Types
import Table.SortFn exposing (SortFn)
import Table.Value exposing (Value)



-- TYPES


{-| A column definition. Build one with [`column`](#column),
[`group`](#group), or [`display`](#display).
-}
type alias Column row =
    Types.Column row


{-| Everything about a table that is not state: the columns, how to find row
ids and sub-rows, and every feature flag.

It is a plain record, so `{ cfg | manualSorting = True }` works for any flag
that has no builder. Later versions of this package may add fields, which is
a breaking change for code that pattern matches on the record but not for
record update.

-}
type alias Config row =
    Types.Config row


{-| Every state slice the pipeline reads. Start from
[`initialState`](#initialState) and update it yourself.
-}
type alias State =
    Types.State


{-| One row of a row model.
-}
type alias Row row =
    Types.Row row


{-| The output of a pipeline stage: the row tree, the same rows flattened
depth first, and a lookup by row id.
-}
type alias RowModel row =
    Types.RowModel row


{-| One header cell.
-}
type alias Header row =
    Types.Header row


{-| One header row.
-}
type alias HeaderGroup row =
    Types.HeaderGroup row


{-| One cell of one row, computed on demand.
-}
type alias Cell =
    Types.Cell


{-| Which rows are expanded. `ExpandAll` is TanStack's `expanded: true`.
-}
type alias Expanded =
    Types.Expanded


{-| Where `Null` values land when a column is sorted.
-}
type alias SortUndefined =
    Types.SortUndefined


{-| What the leaf column list does with grouped columns.
-}
type alias GroupedColumnMode =
    Types.GroupedColumnMode


{-| One entry of `State.sorting`.
-}
type alias SortColumn =
    Types.SortColumn


{-| One entry of `State.columnFilters`.
-}
type alias ColumnFilter =
    Types.ColumnFilter


{-| The page the paginated row model returns.
-}
type alias Pagination =
    Types.Pagination


{-| Column ids pinned to either edge.
-}
type alias ColumnPinning =
    Types.ColumnPinning


{-| Row ids pinned to the top or the bottom.
-}
type alias RowPinning =
    Types.RowPinning


{-| The default sizing of a column, in pixels.
-}
type alias SizeDefaults =
    Types.SizeDefaults


{-| Every row is expanded, whatever `State.rowSelection` holds. TanStack's
`expanded: true`.
-}
expandAll : Expanded
expandAll =
    Types.ExpandAll


{-| Only the rows with these ids are expanded.
-}
expandedIds : Set String -> Expanded
expandedIds =
    Types.ExpandedIds


{-| The expanded row ids, or `Nothing` when every row is expanded.
-}
expandedIdsOf : Expanded -> Maybe (Set String)
expandedIdsOf expanded =
    case expanded of
        Types.ExpandAll ->
            Nothing

        Types.ExpandedIds ids ->
            Just ids


{-| Sort `Null` cell values before every other value.
-}
sortNullsFirst : SortUndefined
sortNullsFirst =
    Types.SortNullsFirst


{-| Sort `Null` cell values after every other value. This is the default.
-}
sortNullsLast : SortUndefined
sortNullsLast =
    Types.SortNullsLast


{-| Sort `Null` cell values as if they compared `-1` against anything else,
TanStack's `sortUndefined: -1`.
-}
sortNullsAsMinusOne : SortUndefined
sortNullsAsMinusOne =
    Types.SortNullsAsMinusOne


{-| Sort `Null` cell values as if they compared `1` against anything else,
TanStack's `sortUndefined: 1`.
-}
sortNullsAsPlusOne : SortUndefined
sortNullsAsPlusOne =
    Types.SortNullsAsPlusOne


{-| Move grouped columns to the front of the leaf column list.
-}
groupedColumnsReorder : GroupedColumnMode
groupedColumnsReorder =
    Types.GroupedColumnsReorder


{-| Drop grouped columns from the leaf column list.
-}
groupedColumnsRemove : GroupedColumnMode
groupedColumnsRemove =
    Types.GroupedColumnsRemove


{-| Leave grouped columns where they are.
-}
groupedColumnsIgnore : GroupedColumnMode
groupedColumnsIgnore =
    Types.GroupedColumnsIgnore



-- CONFIGURATION


{-| A configuration for a list of columns, with TanStack's defaults for every
flag.

    config [ Table.column "firstName" (.firstName >> Value.String) ]

-}
config : List (Column row) -> Config row
config =
    Config.config


{-| The state a table starts in: nothing sorted, nothing filtered, nothing
grouped, page 0 of size 10.
-}
initialState : State
initialState =
    Config.initialState


{-| Give rows stable ids. The function receives the datum, its index among
its siblings, and its parent's row id.

Without it, root rows are `"0"`, `"1"`, and children are `"0.1"`, `"0.2"`.

-}
withGetRowId : (row -> Int -> Maybe String -> String) -> Config row -> Config row
withGetRowId =
    Config.withGetRowId


{-| Tell the core row model how to reach a row's children.
-}
withSubRows : (row -> List row) -> Config row -> Config row
withSubRows =
    Config.withSubRows


{-| Override the default column sizing (`150`, `20`, `9007199254740991`).
-}
withDefaultColumn : SizeDefaults -> Config row -> Config row
withDefaultColumn =
    Config.withDefaultColumn


{-| Set the filter function the global filter uses.
-}
withGlobalFilterFn : FilterFn -> Config row -> Config row
withGlobalFilterFn =
    Config.withGlobalFilterFn


{-| Decide per row whether it can be selected.
-}
withRowSelection : (row -> Bool) -> Config row -> Config row
withRowSelection =
    Config.withRowSelection



-- BUILDING COLUMNS


{-| An accessor column: an id and a way to read a cell value.

    Table.column "age" (.age >> toFloat >> Value.Number)

-}
column : String -> (row -> Value) -> Column row
column =
    Column.column


{-| A group column: an id and the columns nested under it. Group columns have
no accessor and no cells, they only produce header rows.
-}
group : String -> List (Column row) -> Column row
group =
    Column.group


{-| A display column: an id, no accessor, no children.
-}
display : String -> Column row
display =
    Column.display


{-| Set the header text.
-}
withHeader : String -> Column row -> Column row
withHeader =
    Column.withHeader


{-| Set the footer text.
-}
withFooter : String -> Column row -> Column row
withFooter =
    Column.withFooter


{-| Sort this column with a built-in sort function.
-}
withSortFn : SortFn -> Column row -> Column row
withSortFn =
    Column.withSortFn


{-| Sort this column with a comparison on whole rows.
-}
withCustomSort : (Row row -> Row row -> Order) -> Column row -> Column row
withCustomSort =
    Column.withCustomSort


{-| Make the first click on this column sort descending.
-}
withSortDescFirst : Bool -> Column row -> Column row
withSortDescFirst =
    Column.withSortDescFirst


{-| Invert the sort direction of this column.
-}
withInvertSorting : Bool -> Column row -> Column row
withInvertSorting =
    Column.withInvertSorting


{-| Decide where `Null` values land when this column is sorted.
-}
withSortUndefined : SortUndefined -> Column row -> Column row
withSortUndefined =
    Column.withSortUndefined


{-| Allow or forbid sorting on this column.
-}
withEnableSorting : Bool -> Column row -> Column row
withEnableSorting =
    Column.withEnableSorting


{-| Allow or forbid this column in a multi-sort.
-}
withEnableMultiSort : Bool -> Column row -> Column row
withEnableMultiSort =
    Column.withEnableMultiSort


{-| Filter this column with a built-in filter function.
-}
withFilterFn : FilterFn -> Column row -> Column row
withFilterFn =
    Column.withFilterFn


{-| Filter this column with a predicate on whole rows.
-}
withCustomFilter : (Row row -> Value -> Bool) -> Column row -> Column row
withCustomFilter =
    Column.withCustomFilter


{-| Allow or forbid a column filter on this column.
-}
withEnableColumnFilter : Bool -> Column row -> Column row
withEnableColumnFilter =
    Column.withEnableColumnFilter


{-| Include or exclude this column from the global filter.
-}
withEnableGlobalFilter : Bool -> Column row -> Column row
withEnableGlobalFilter =
    Column.withEnableGlobalFilter


{-| Aggregate this column's values on group rows.
-}
withAggregationFn : AggregationFn -> Column row -> Column row
withAggregationFn =
    Column.withAggregationFn


{-| Read the value this column groups by, when it differs from the accessor.
-}
withGetGroupingValue : (row -> Value) -> Column row -> Column row
withGetGroupingValue =
    Column.withGetGroupingValue


{-| Read the faceting values of a row, when one cell holds several.
-}
withGetUniqueValues : (row -> List Value) -> Column row -> Column row
withGetUniqueValues =
    Column.withGetUniqueValues


{-| Allow or forbid grouping by this column.
-}
withEnableGrouping : Bool -> Column row -> Column row
withEnableGrouping =
    Column.withEnableGrouping


{-| Allow or forbid hiding this column.
-}
withEnableHiding : Bool -> Column row -> Column row
withEnableHiding =
    Column.withEnableHiding


{-| Allow or forbid pinning this column.
-}
withEnablePinning : Bool -> Column row -> Column row
withEnablePinning =
    Column.withEnablePinning


{-| Set this column's size in pixels.
-}
withSize : Float -> Column row -> Column row
withSize =
    Column.withSize


{-| Set this column's minimum size in pixels.
-}
withMinSize : Float -> Column row -> Column row
withMinSize =
    Column.withMinSize


{-| Set this column's maximum size in pixels.
-}
withMaxSize : Float -> Column row -> Column row
withMaxSize =
    Column.withMaxSize



-- READING COLUMNS


{-| The column id.
-}
columnId : Column row -> String
columnId =
    Column.id


{-| The header text, when one was set.
-}
columnHeader : Column row -> Maybe String
columnHeader =
    Column.header


{-| The footer text, when one was set.
-}
columnFooter : Column row -> Maybe String
columnFooter =
    Column.footer


{-| How deep the column sits in the column tree. Top level is `0`.
-}
columnDepth : Column row -> Int
columnDepth =
    Column.depth


{-| The columns nested under a group column.
-}
columnColumns : Column row -> List (Column row)
columnColumns =
    Column.children


{-| The id of the group column this column sits under.
-}
columnParentId : Column row -> Maybe String
columnParentId =
    Column.parentId


{-| The accessor, when the column has one. Group and display columns have
none.
-}
columnAccessor : Column row -> Maybe (row -> Value)
columnAccessor =
    Column.accessorFn


{-| This column's size in pixels, clamped to its minimum and maximum.
-}
columnSize : Config row -> Column row -> Float
columnSize =
    Column.size


{-| This column's minimum size in pixels.
-}
columnMinSize : Config row -> Column row -> Float
columnMinSize =
    Column.minSize


{-| This column's maximum size in pixels.
-}
columnMaxSize : Config row -> Column row -> Float
columnMaxSize =
    Column.maxSize


{-| Every column, group columns included, each group before its children.
-}
allColumns : Config row -> List (Column row)
allColumns =
    Column.flatColumns


{-| Every leaf column, in definition order.
-}
leafColumns : Config row -> List (Column row)
leafColumns =
    Column.leafColumns


{-| The leaf columns a table renders: `State.columnOrder` applied, hidden
columns dropped.
-}
visibleLeafColumns : Config row -> State -> List (Column row)
visibleLeafColumns =
    Column.visibleLeafColumns


{-| One column and every column below it, the column itself first.
-}
columnFlatColumns : Column row -> List (Column row)
columnFlatColumns =
    Column.flatColumnsOf


{-| The leaf columns below one column. A leaf column returns itself.
-}
columnLeafColumns : Column row -> List (Column row)
columnLeafColumns =
    Column.leafColumnsOf


{-| Find a column by id. Group columns are found too.
-}
findColumn : Config row -> String -> Maybe (Column row)
findColumn =
    Column.findColumn



-- READING ROWS


{-| The row id.
-}
rowId : Row row -> String
rowId =
    Row.id


{-| The row's index among its siblings.
-}
rowIndex : Row row -> Int
rowIndex =
    Row.index


{-| How deep the row sits in the row tree. Root rows are `0`.
-}
rowDepth : Row row -> Int
rowDepth =
    Row.depth


{-| The original datum this row was built from.
-}
rowOriginal : Row row -> row
rowOriginal =
    Row.original


{-| The row's children.
-}
rowSubRows : Row row -> List (Row row)
rowSubRows =
    Row.subRows


{-| The id of the row's parent, when it has one.
-}
rowParentId : Row row -> Maybe String
rowParentId =
    Row.parentId


{-| The raw children `Config.getSubRows` returned for this row.
-}
rowOriginalSubRows : Row row -> List row
rowOriginalSubRows =
    Row.originalSubRows


{-| The column a group row groups by, when the row is a group row.
-}
rowGroupingColumnId : Row row -> Maybe String
rowGroupingColumnId =
    Row.groupingColumnId


{-| The value a group row groups by.
-}
rowGroupingValue : Row row -> Value
rowGroupingValue =
    Row.groupingValue


{-| The leaf rows a group row was built from. Empty for ordinary rows.
-}
rowLeafRows : Row row -> List (Row row)
rowLeafRows =
    Row.leafRows


{-| The aggregated values of a group row, keyed by column id.
-}
rowAggregatedValues : Row row -> Dict String Value
rowAggregatedValues =
    Row.aggregatedValues


{-| Read one cell value. Unknown columns and columns without an accessor give
`Null`.
-}
getValue : Config row -> Row row -> String -> Value
getValue =
    Row.getValue


{-| The values faceting and grouping use for one cell. A column with
[`withGetUniqueValues`](#withGetUniqueValues) decides them; otherwise the cell
value is wrapped in a one-item list.
-}
getUniqueValues : Config row -> Row row -> String -> List Value
getUniqueValues =
    Row.getUniqueValues


{-| Every descendant of a row, depth first. The row itself is not included.
-}
getLeafRows : Row row -> List (Row row)
getLeafRows =
    Row.getLeafRows


{-| The direct parent of a row, looked up in a row model.
-}
getParentRow : RowModel row -> Row row -> Maybe (Row row)
getParentRow =
    Row.getParentRow


{-| The ancestors of a row, from the root down to its direct parent.
-}
getParentRows : RowModel row -> Row row -> List (Row row)
getParentRows =
    Row.getParentRows


{-| One cell per leaf column, in leaf column order. Hidden columns are
included.
-}
getAllCells : Config row -> State -> Row row -> List Cell
getAllCells =
    Row.getAllCells


{-| Look a row up by id.
-}
findRow : RowModel row -> String -> Maybe (Row row)
findRow =
    Row.findRow


{-| The deepest row depth in a row model. A flat model is `0`.
-}
maxSubRowDepth : RowModel row -> Int
maxSubRowDepth =
    Row.maxSubRowDepth



-- HEADERS


{-| The header rows of a table, top row first.
-}
headerGroups : Config row -> State -> List (HeaderGroup row)
headerGroups =
    Header.headerGroups


{-| The footer rows: the header rows bottom row first.
-}
footerGroups : Config row -> State -> List (HeaderGroup row)
footerGroups =
    Header.footerGroups


{-| Every header of every header row.
-}
flatHeaders : Config row -> State -> List (Header row)
flatHeaders =
    Header.flatHeaders


{-| The leaf headers reachable from the top header row.
-}
leafHeaders : Config row -> State -> List (Header row)
leafHeaders =
    Header.leafHeaders


{-| The descendants of a header, deepest first, with the header itself last.
-}
getLeafHeaders : Header row -> List (Header row)
getLeafHeaders =
    Header.getLeafHeaders


{-| The header id. Placeholder headers get a compound id.
-}
headerId : Header row -> String
headerId =
    Header.id


{-| The id of the column this header renders.
-}
headerColumnId : Header row -> String
headerColumnId =
    Header.columnId


{-| How many leaf columns this header spans.
-}
headerColSpan : Header row -> Int
headerColSpan =
    Header.colSpan


{-| How many header rows this header spans. `0` means a header above already
covers this cell.
-}
headerRowSpan : Header row -> Int
headerRowSpan =
    Header.rowSpan


{-| Which header row this header belongs to, counted from `1` at the top.
-}
headerDepth : Header row -> Int
headerDepth =
    Header.depth


{-| The header's position in its header row.
-}
headerIndex : Header row -> Int
headerIndex =
    Header.index


{-| Is this a filler header standing in for a column that has no group at
this level?
-}
headerIsPlaceholder : Header row -> Bool
headerIsPlaceholder =
    Header.isPlaceholder


{-| How many placeholders for the same column came before this one.
-}
headerPlaceholderId : Header row -> Maybe String
headerPlaceholderId =
    Header.placeholderId


{-| The headers nested under this one.
-}
headerSubHeaders : Header row -> List (Header row)
headerSubHeaders =
    Header.subHeaders



-- THE PIPELINE


{-| The whole pipeline: core, filtered, grouped, sorted, expanded,
paginated, in that order.

A `manual` flag on the config skips its stage and passes the row model
through unchanged.

-}
rows : Config row -> State -> Array row -> RowModel row
rows cfg state data =
    rowsFromList cfg state (Array.toList data)


{-| The `List` form of [`rows`](#rows).
-}
rowsFromList : Config row -> State -> List row -> RowModel row
rowsFromList cfg state data =
    coreRowModelFromList cfg state data
        |> filteredRowModel cfg state
        |> groupedRowModel cfg state
        |> sortedRowModel cfg state
        |> expandedRowModel cfg state
        |> paginatedRowModel cfg state


{-| The untouched row model: one row per datum, sub-rows resolved, ids
assigned.
-}
coreRowModel : Config row -> State -> Array row -> RowModel row
coreRowModel =
    CoreRowModel.coreRowModel


{-| The `List` form of [`coreRowModel`](#coreRowModel).
-}
coreRowModelFromList : Config row -> State -> List row -> RowModel row
coreRowModelFromList =
    CoreRowModel.fromList


{-| Drop the rows that fail the column filters and the global filter.
`Config.manualFiltering` skips this stage.
-}
filteredRowModel : Config row -> State -> RowModel row -> RowModel row
filteredRowModel cfg state model =
    if cfg.manualFiltering then
        model

    else
        Filtering.filteredRowModel cfg state model


{-| Replace the rows with group rows. `Config.manualGrouping` skips this
stage.
-}
groupedRowModel : Config row -> State -> RowModel row -> RowModel row
groupedRowModel cfg state model =
    if cfg.manualGrouping then
        model

    else
        Grouping.groupedRowModel cfg state model


{-| Sort every level of the row tree. `Config.manualSorting` skips this
stage.
-}
sortedRowModel : Config row -> State -> RowModel row -> RowModel row
sortedRowModel cfg state model =
    if cfg.manualSorting then
        model

    else
        Sorting.sortedRowModel cfg state model


{-| Flatten the expanded branches into the row list.
`Config.manualExpanding` skips this stage.
-}
expandedRowModel : Config row -> State -> RowModel row -> RowModel row
expandedRowModel cfg state model =
    if cfg.manualExpanding then
        model

    else
        Expanding.expandedRowModel cfg state model


{-| Keep only the rows of the current page. `Config.manualPagination` skips
this stage.
-}
paginatedRowModel : Config row -> State -> RowModel row -> RowModel row
paginatedRowModel cfg state model =
    if cfg.manualPagination then
        model

    else
        Pagination.paginatedRowModel cfg state model



-- FACETING


{-| Every distinct value of one column with the number of rows that carry it.
The body lands in phase 3.
-}
facetedUniqueValues : Config row -> State -> RowModel row -> String -> List ( Value, Int )
facetedUniqueValues =
    Faceting.facetedUniqueValues


{-| The smallest and largest numeric value of one column. The body lands in
phase 3.
-}
facetedMinMax : Config row -> State -> RowModel row -> String -> Maybe ( Float, Float )
facetedMinMax =
    Faceting.facetedMinMax
