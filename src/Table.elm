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
    , SortDir, sortAsc, sortDesc
    , getCanFilter, getIsFiltered, getFilterValue, getFilterIndex
    , getFilterFn, getAutoFilterFn, shouldAutoRemoveFilter
    , setColumnFilter, setColumnFilters, resetColumnFilters
    , getCanGlobalFilter, getGlobalFilterFn, globalAutoFilterFn
    , setGlobalFilter, resetGlobalFilter
    , facetedRowModel, globalFacetKey
    , getCanSort, getCanMultiSort, getIsSorted, getSortIndex
    , getAutoSortFn, getSortFn, getAutoSortDir, getFirstSortDir, getNextSortingOrder
    , toggleSort, setSorting, clearSorting, resetSorting
    , prePaginationRowModel, rowsInDisplayOrder, displayIndex
    , setPage, setPageSize, setPagination
    , resetPageIndex, resetPageSize, resetPagination
    , getPageCount, getPageOptions, getRowCount
    , getCanPreviousPage, getCanNextPage, getCanLastPage
    , previousPage, nextPage, firstPage, lastPage, unlimitedPageSize
    , ColumnPinPosition, ColumnRegion, RowPinPosition, SubRowSelection
    , SelectOptions, PinRowOptions, PinnedRowsSource, PinnedColumns
    , pinnedLeft, pinnedRight, columnUnpinned
    , allColumnsRegion, leftColumnsRegion, centerColumnsRegion, rightColumnsRegion
    , pinnedTop, pinnedBottom, rowUnpinned
    , noSubRowsSelected, someSubRowsSelected, allSubRowsSelected
    , defaultSelectOptions, defaultPinRowOptions
    , columnIsVisible, columnCanHide, toggleColumnVisibility, setColumnVisibility
    , resetColumnVisibility, toggleAllColumnsVisible
    , isAllColumnsVisible, isSomeColumnsVisible, visibleFlatColumns
    , visibleCells, visibleCellsByColumnId
    , setColumnOrder, resetColumnOrder, orderColumns, orderGroupedColumns
    , columnIndex, columnIsFirst, columnIsLast
    , pinColumn, setColumnPinning, resetColumnPinning
    , columnCanPin, columnIsPinned, columnPinnedIndex
    , isSomeColumnsPinned, isSomeColumnsPinnedLeft, isSomeColumnsPinnedRight
    , leftLeafColumns, centerLeafColumns, rightLeafColumns, pinnedLeafColumns
    , leftVisibleLeafColumns, centerVisibleLeafColumns, rightVisibleLeafColumns
    , pinnedVisibleLeafColumns, pinnedColumns
    , leftHeaderGroups, centerHeaderGroups, rightHeaderGroups
    , leftFooterGroups, centerFooterGroups, rightFooterGroups
    , leftFlatHeaders, centerFlatHeaders, rightFlatHeaders
    , leftLeafHeaders, centerLeafHeaders, rightLeafHeaders
    , leftVisibleCells, centerVisibleCells, rightVisibleCells
    , getColumnSize, getColumnStart, getColumnAfter
    , setColumnSize, setColumnSizing, resetColumnSize, resetColumnSizing
    , getHeaderSize, getHeaderStart
    , totalSize, leftTotalSize, centerTotalSize, rightTotalSize
    , toggleRowSelected, toggleRowSelectedWith
    , toggleAllRowsSelected, toggleAllPageRowsSelected, deselectAllRows
    , setRowSelection, resetRowSelection
    , selectRange, selectRangeWith, canSelectRange
    , getIsRowSelected, getIsSomeRowsSelected
    , getIsAllRowsSelected, getIsAllPageRowsSelected, getIsSomePageRowsSelected
    , getCanSelect, getCanSelectSubRows, getCanMultiSelect
    , getIsSomeSelected, getIsAllSubRowsSelected, subRowSelection
    , selectedRowIds, selectedRowModel
    , pinRow, pinRowWith, setRowPinning, resetRowPinning
    , getIsRowPinned, getRowPinnedIndex, getCanPinRow
    , isSomeRowsPinned, isSomeRowsPinnedTop, isSomeRowsPinnedBottom
    , topRows, bottomRows, centerRows
    -- Phase 3
    -- Phase 4
    -- Phase 5 entries are the block above: elm-format hoists these markers
    -- to the end of the exposing list.
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

Filtering, faceting, sorting, and pagination. Every reader that has to guess
something from the data (`'auto'` filter and sort functions, the default
global-filter predicate, the automatic first sort direction) takes a
`RowModel row` to sample, exactly like TanStack, which samples the core or
filtered row model for the same job.


## Sort direction

@docs SortDir, sortAsc, sortDesc


## Column filter state

@docs getCanFilter, getIsFiltered, getFilterValue, getFilterIndex
@docs getFilterFn, getAutoFilterFn, shouldAutoRemoveFilter
@docs setColumnFilter, setColumnFilters, resetColumnFilters


## Global filter state

@docs getCanGlobalFilter, getGlobalFilterFn, globalAutoFilterFn
@docs setGlobalFilter, resetGlobalFilter


## Faceted row model

@docs facetedRowModel, globalFacetKey


## Sorting state

@docs getCanSort, getCanMultiSort, getIsSorted, getSortIndex
@docs getAutoSortFn, getSortFn, getAutoSortDir, getFirstSortDir, getNextSortingOrder
@docs toggleSort, setSorting, clearSorting, resetSorting


## Pagination state

@docs prePaginationRowModel, rowsInDisplayOrder, displayIndex
@docs setPage, setPageSize, setPagination
@docs resetPageIndex, resetPageSize, resetPagination
@docs getPageCount, getPageOptions, getRowCount
@docs getCanPreviousPage, getCanNextPage, getCanLastPage
@docs previousPage, nextPage, firstPage, lastPage, unlimitedPageSize


# Phase 4


# Phase 5

Selection, pinning, ordering, visibility, and sizing. Every transition is
`... -> State -> State` so it pipes, and every query takes the `Config` and
the `State` first, then the row model or column it is about.


## Phase 5 types

@docs ColumnPinPosition, ColumnRegion, RowPinPosition, SubRowSelection
@docs SelectOptions, PinRowOptions, PinnedRowsSource, PinnedColumns

The four unions are abstract for the same reason as the phase 2 ones, so
they come with one function per variant.

@docs pinnedLeft, pinnedRight, columnUnpinned
@docs allColumnsRegion, leftColumnsRegion, centerColumnsRegion, rightColumnsRegion
@docs pinnedTop, pinnedBottom, rowUnpinned
@docs noSubRowsSelected, someSubRowsSelected, allSubRowsSelected
@docs defaultSelectOptions, defaultPinRowOptions


## Column visibility

@docs columnIsVisible, columnCanHide, toggleColumnVisibility, setColumnVisibility
@docs resetColumnVisibility, toggleAllColumnsVisible
@docs isAllColumnsVisible, isSomeColumnsVisible, visibleFlatColumns
@docs visibleCells, visibleCellsByColumnId


## Column order

@docs setColumnOrder, resetColumnOrder, orderColumns, orderGroupedColumns
@docs columnIndex, columnIsFirst, columnIsLast


## Column pinning

@docs pinColumn, setColumnPinning, resetColumnPinning
@docs columnCanPin, columnIsPinned, columnPinnedIndex
@docs isSomeColumnsPinned, isSomeColumnsPinnedLeft, isSomeColumnsPinnedRight
@docs leftLeafColumns, centerLeafColumns, rightLeafColumns, pinnedLeafColumns
@docs leftVisibleLeafColumns, centerVisibleLeafColumns, rightVisibleLeafColumns
@docs pinnedVisibleLeafColumns, pinnedColumns
@docs leftHeaderGroups, centerHeaderGroups, rightHeaderGroups
@docs leftFooterGroups, centerFooterGroups, rightFooterGroups
@docs leftFlatHeaders, centerFlatHeaders, rightFlatHeaders
@docs leftLeafHeaders, centerLeafHeaders, rightLeafHeaders
@docs leftVisibleCells, centerVisibleCells, rightVisibleCells


## Column sizing

@docs getColumnSize, getColumnStart, getColumnAfter
@docs setColumnSize, setColumnSizing, resetColumnSize, resetColumnSizing
@docs getHeaderSize, getHeaderStart
@docs totalSize, leftTotalSize, centerTotalSize, rightTotalSize


## Row selection

@docs toggleRowSelected, toggleRowSelectedWith
@docs toggleAllRowsSelected, toggleAllPageRowsSelected, deselectAllRows
@docs setRowSelection, resetRowSelection
@docs selectRange, selectRangeWith, canSelectRange
@docs getIsRowSelected, getIsSomeRowsSelected
@docs getIsAllRowsSelected, getIsAllPageRowsSelected, getIsSomePageRowsSelected
@docs getCanSelect, getCanSelectSubRows, getCanMultiSelect
@docs getIsSomeSelected, getIsAllSubRowsSelected, subRowSelection
@docs selectedRowIds, selectedRowModel


## Row pinning

@docs pinRow, pinRowWith, setRowPinning, resetRowPinning
@docs getIsRowPinned, getRowPinnedIndex, getCanPinRow
@docs isSomeRowsPinned, isSomeRowsPinnedTop, isSomeRowsPinnedBottom
@docs topRows, bottomRows, centerRows

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Set exposing (Set)
import Table.AggregationFn exposing (AggregationFn)
import Table.FilterFn exposing (FilterFn)
import Table.Internal.Column as Column
import Table.Internal.ColumnOrdering as ColumnOrdering
import Table.Internal.ColumnPinning as ColumnPinning
import Table.Internal.ColumnSizing as ColumnSizing
import Table.Internal.ColumnVisibility as ColumnVisibility
import Table.Internal.Config as Config
import Table.Internal.CoreRowModel as CoreRowModel
import Table.Internal.Expanding as Expanding
import Table.Internal.Faceting as Faceting
import Table.Internal.Filtering as Filtering
import Table.Internal.GlobalFiltering as GlobalFiltering
import Table.Internal.Grouping as Grouping
import Table.Internal.Header as Header
import Table.Internal.Pagination as Pagination
import Table.Internal.Row as Row
import Table.Internal.RowPinning as RowPinning
import Table.Internal.RowSelection as RowSelection
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
withRowSelection : (Row row -> Bool) -> Config row -> Config row
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



-- PHASE 3
--
-- Filtering, faceting, sorting, and pagination. Bodies live in
-- src/Table/Internal/{Filtering,GlobalFiltering,Faceting,Sorting,Pagination}.elm.


{-| A sort direction.
-}
type alias SortDir =
    Types.SortDir


{-| Ascending.
-}
sortAsc : SortDir
sortAsc =
    Types.Asc


{-| Descending.
-}
sortDesc : SortDir
sortDesc =
    Types.Desc



-- COLUMN FILTER STATE


{-| Can this column carry a column filter? It needs an accessor, and neither
the column nor `Config.enableColumnFilters` nor `Config.enableFilters` may
have switched filtering off.

The filtered row model does not consult this: a `State.columnFilters` entry
for a column that answers `False` is still applied, matching TanStack.

-}
getCanFilter : Config row -> String -> Bool
getCanFilter =
    Filtering.getCanFilter


{-| Does `State.columnFilters` hold an entry for this column?
-}
getIsFiltered : State -> String -> Bool
getIsFiltered =
    Filtering.getIsFiltered


{-| This column's current filter value, when it has one.
-}
getFilterValue : State -> String -> Maybe Value
getFilterValue =
    Filtering.getFilterValue


{-| This column's position in `State.columnFilters`, or `-1`.
-}
getFilterIndex : State -> String -> Int
getFilterIndex =
    Filtering.getFilterIndex


{-| The filter function a column filters with: the one set with
`withFilterFn`, or the automatic choice. `Nothing` when the column does not
exist.

Pass the core row model; the automatic choice samples it.

-}
getFilterFn : Config row -> RowModel row -> String -> Maybe FilterFn
getFilterFn =
    Filtering.getFilterFn


{-| The filter function `'auto'` picks for a column, from the type of its
first non-null value: `includesString` for strings, `inNumberRange` for
numbers, `equals` for booleans, `arrIncludes` for lists, `inDateRange` for
dates, and `weakEquals` when every value is `Null`.
-}
getAutoFilterFn : Config row -> RowModel row -> String -> FilterFn
getAutoFilterFn =
    Filtering.getAutoFilterFn


{-| Should a filter value be dropped from state instead of stored? A filter
function's own rule wins; without one, `Null` and the empty string are
dropped.
-}
shouldAutoRemoveFilter : Maybe FilterFn -> Value -> Bool
shouldAutoRemoveFilter =
    Filtering.shouldAutoRemoveFilter


{-| Set one column's filter value: replaced in place when the column already
has one, appended otherwise, and removed when
[`shouldAutoRemoveFilter`](#shouldAutoRemoveFilter) says the value is blank.
-}
setColumnFilter : Config row -> RowModel row -> String -> Value -> State -> State
setColumnFilter =
    Filtering.setColumnFilter


{-| Replace `State.columnFilters` wholesale, dropping the entries of known
columns whose value should auto-remove.
-}
setColumnFilters : Config row -> RowModel row -> List ColumnFilter -> State -> State
setColumnFilters =
    Filtering.setColumnFilters


{-| Clear every column filter.
-}
resetColumnFilters : State -> State
resetColumnFilters =
    Filtering.resetColumnFilters



-- GLOBAL FILTER STATE


{-| Does the global filter run against this column? It needs an accessor,
`Config.enableGlobalFilter` and `Config.enableFilters` have to be on, the
column must not opt out, and `Config.getColumnCanGlobalFilter` (whose default
keeps a column only when its first non-null value is a string or a number)
has to agree.
-}
getCanGlobalFilter : Config row -> RowModel row -> String -> Bool
getCanGlobalFilter =
    GlobalFiltering.getCanGlobalFilter


{-| The filter function the global filter uses: `Config.globalFilterFn`, or
[`globalAutoFilterFn`](#globalAutoFilterFn).
-}
getGlobalFilterFn : Config row -> FilterFn
getGlobalFilterFn =
    GlobalFiltering.getGlobalFilterFn


{-| The global filter's automatic function: `Table.FilterFn.includesString`.
-}
globalAutoFilterFn : FilterFn
globalAutoFilterFn =
    GlobalFiltering.autoFilterFn


{-| Set the global filter value.
-}
setGlobalFilter : Value -> State -> State
setGlobalFilter =
    GlobalFiltering.setGlobalFilter


{-| Clear the global filter.
-}
resetGlobalFilter : State -> State
resetGlobalFilter =
    GlobalFiltering.resetGlobalFilter



-- FACETING


{-| The rows a column's facets are computed from: the pre-filtered rows with
every active filter applied except that column's own, so a filter UI keeps
showing the values the user could switch to.

Pass the row model you handed to [`filteredRowModel`](#filteredRowModel).
Passing [`globalFacetKey`](#globalFacetKey) as the column id excludes the
global filter instead of a column filter.

-}
facetedRowModel : Config row -> State -> RowModel row -> String -> RowModel row
facetedRowModel =
    Faceting.facetedRowModel


{-| The column id that stands for the global filter's own facet context,
`"__global__"`. Passing it to [`facetedRowModel`](#facetedRowModel),
[`facetedUniqueValues`](#facetedUniqueValues) or
[`facetedMinMax`](#facetedMinMax) aggregates across every globally
filterable column.
-}
globalFacetKey : String
globalFacetKey =
    Faceting.globalFacetKey



-- SORTING STATE


{-| Can this column be sorted? It needs an accessor and both the column and
`Config.enableSorting` have to allow it.
-}
getCanSort : Config row -> String -> Bool
getCanSort =
    Sorting.getCanSort


{-| Can this column join a multi-sort? The column's own setting wins over
`Config.enableMultiSort`.
-}
getCanMultiSort : Config row -> String -> Bool
getCanMultiSort =
    Sorting.getCanMultiSort


{-| This column's sort direction, or `Nothing` when it is not sorted.
-}
getIsSorted : State -> String -> Maybe SortDir
getIsSorted =
    Sorting.getIsSorted


{-| This column's position in `State.sorting`, or `-1`.
-}
getSortIndex : State -> String -> Int
getSortIndex =
    Sorting.getSortIndex


{-| The sort function `'auto'` picks for a column. The first ten rows of the
row model are sampled: a date gives `datetime`, a string holding digits gives
`alphanumeric`, any other string gives `text`, and anything else gives
`basic`.

Pass the filtered row model, which is what TanStack samples.

-}
getAutoSortFn : Config row -> RowModel row -> String -> SortFn
getAutoSortFn =
    Sorting.getAutoSortFn


{-| The sort function a column sorts with: the one set with `withSortFn`, or
the automatic choice. A column set up with `withCustomSort` compares whole
rows and has no `SortFn`, so this reports its automatic choice while the row
model uses the custom comparison.
-}
getSortFn : Config row -> RowModel row -> String -> SortFn
getSortFn =
    Sorting.getSortFn


{-| The direction a column starts sorting in when nothing says otherwise: the
first non-null value among the first ten rows decides, strings ascending and
everything else descending.
-}
getAutoSortDir : Config row -> RowModel row -> String -> SortDir
getAutoSortDir =
    Sorting.getAutoSortDir


{-| The direction the first click on a column sorts in: the column's
`withSortDescFirst` wins, then `Config.sortDescFirst`, then
[`getAutoSortDir`](#getAutoSortDir).
-}
getFirstSortDir : Config row -> RowModel row -> String -> SortDir
getFirstSortDir =
    Sorting.getFirstSortDir


{-| The next step of a column's sort cycle. `Nothing` means the next step
removes the sort, which `Config.enableSortingRemoval` and (in a multi-sort)
`Config.enableMultiRemove` can forbid.
-}
getNextSortingOrder : Config row -> RowModel row -> State -> String -> Bool -> Maybe SortDir
getNextSortingOrder =
    Sorting.getNextSortingOrder


{-| Step a column's sort: add it, replace the sort with it, flip its
direction, or remove it.

`desc = Just d` sets the direction outright instead of stepping the cycle.
`multi = True` asks to add to the existing sort rather than replace it, which
happens only when [`getCanMultiSort`](#getCanMultiSort) allows it;
`Config.maxMultiSortColCount` caps how many columns a multi-sort keeps.

-}
toggleSort : Config row -> RowModel row -> String -> { desc : Maybe Bool, multi : Bool } -> State -> State
toggleSort =
    Sorting.toggleSort


{-| Replace `State.sorting`.
-}
setSorting : List SortColumn -> State -> State
setSorting =
    Sorting.setSorting


{-| Remove one column from `State.sorting`, leaving the others in order.
-}
clearSorting : String -> State -> State
clearSorting =
    Sorting.clearSorting


{-| Clear every sort.
-}
resetSorting : State -> State
resetSorting =
    Sorting.resetSorting



-- PAGINATION STATE


{-| The row model pagination slices, which is the expanded row model. The
row counts and page counts below all read it.
-}
prePaginationRowModel : Config row -> State -> RowModel row -> RowModel row
prePaginationRowModel =
    expandedRowModel


{-| The rows a caller renders, in order. With
`Config.paginateExpandedRows = False` the expanded descendants that the
pre-pagination row model does not carry are inserted here.
-}
rowsInDisplayOrder : Config row -> State -> RowModel row -> List (Row row)
rowsInDisplayOrder =
    Pagination.rowsInDisplayOrder


{-| A row's zero-based position in
[`rowsInDisplayOrder`](#rowsInDisplayOrder), or `-1` when it is not there.
-}
displayIndex : Config row -> State -> RowModel row -> Row row -> Int
displayIndex cfg state model row =
    positionOf (Row.id row) 0 (rowsInDisplayOrder cfg state model)


positionOf : String -> Int -> List (Row row) -> Int
positionOf wanted at candidates =
    case candidates of
        [] ->
            -1

        first :: rest ->
            if Row.id first == wanted then
                at

            else
                positionOf wanted (at + 1) rest


{-| Go to a page, clamped to `[0, Config.pageCount - 1]` when
`Config.pageCount` is set. A `Config.pageCount` of `Just -1` means the count
is unknown and clamps nothing.
-}
setPage : Config row -> Int -> State -> State
setPage =
    Pagination.setPage


{-| Change the page size, at least `1`. The page index moves so the row that
was at the top of the page stays in view.
-}
setPageSize : Int -> State -> State
setPageSize =
    Pagination.setPageSize


{-| Replace `State.pagination`.
-}
setPagination : Pagination -> State -> State
setPagination =
    Pagination.setPagination


{-| Back to page 0.
-}
resetPageIndex : Config row -> State -> State
resetPageIndex =
    Pagination.resetPageIndex


{-| Back to a page size of 10.
-}
resetPageSize : State -> State
resetPageSize =
    Pagination.resetPageSize


{-| Back to page 0 with a page size of 10.
-}
resetPagination : State -> State
resetPagination =
    Pagination.resetPagination


{-| How many pages there are: `Config.pageCount` when it is set, otherwise
[`getRowCount`](#getRowCount) divided by the page size, rounded up.
-}
getPageCount : Config row -> State -> RowModel row -> Int
getPageCount =
    Pagination.getPageCount


{-| Every page index, `[0, 1, ...]`.
-}
getPageOptions : Config row -> State -> RowModel row -> List Int
getPageOptions =
    Pagination.getPageOptions


{-| How many rows pagination is slicing: `Config.rowCount` when it is set,
otherwise the rows of the pre-pagination row model.
-}
getRowCount : Config row -> RowModel row -> Int
getRowCount =
    Pagination.getRowCount


{-| Is there a page before this one?
-}
getCanPreviousPage : State -> Bool
getCanPreviousPage =
    Pagination.getCanPreviousPage


{-| Is there a page after this one? An unknown page count always says yes.
-}
getCanNextPage : Config row -> State -> RowModel row -> Bool
getCanNextPage =
    Pagination.getCanNextPage


{-| Is there a known last page after this one?
-}
getCanLastPage : Config row -> State -> RowModel row -> Bool
getCanLastPage =
    Pagination.getCanLastPage


{-| Go back one page, clamped at 0.
-}
previousPage : Config row -> State -> State
previousPage =
    Pagination.previousPage


{-| Go forward one page.
-}
nextPage : Config row -> State -> State
nextPage =
    Pagination.nextPage


{-| Go to page 0.
-}
firstPage : Config row -> State -> State
firstPage =
    Pagination.firstPage


{-| Go to the last page. A no-op when the page count is unknown or empty.
-}
lastPage : Config row -> State -> RowModel row -> State
lastPage =
    Pagination.lastPage


{-| The page size that puts every row on one page. Elm has no `Infinity` for
`Int`, so this is `Number.MAX_SAFE_INTEGER` where TanStack writes `Infinity`.
-}
unlimitedPageSize : Int
unlimitedPageSize =
    Pagination.unlimitedPageSize



-- PHASE 5
-- Selection, pinning, ordering, visibility, sizing.
-- TYPES


{-| Where a column is pinned: [`pinnedLeft`](#pinnedLeft),
[`pinnedRight`](#pinnedRight), or [`columnUnpinned`](#columnUnpinned).
TanStack calls these `'start'`, `'end'`, and `false`.
-}
type alias ColumnPinPosition =
    Types.ColumnPinPosition


{-| Which slice of the visible leaf columns a query is about.
[`allColumnsRegion`](#allColumnsRegion) is TanStack's absent `position`
argument and means the whole visible list in table order.
-}
type alias ColumnRegion =
    Types.ColumnRegion


{-| Where a row is pinned: [`pinnedTop`](#pinnedTop),
[`pinnedBottom`](#pinnedBottom), or [`rowUnpinned`](#rowUnpinned).
-}
type alias RowPinPosition =
    Types.RowPinPosition


{-| How much of a parent row's sub-tree is selected.
-}
type alias SubRowSelection =
    Types.SubRowSelection


{-| The options of a selection toggle. `selectChildren` also writes the
row's sub-tree; `deselectParents` drops the ancestors of a row that is being
deselected.
-}
type alias SelectOptions =
    Types.SelectOptions


{-| The options of [`pinRowWith`](#pinRowWith): pin the row's leaf rows and
its ancestors along with it.
-}
type alias PinRowOptions =
    Types.PinRowOptions


{-| The two row models the pinned row lists read from. With
`Config.keepPinnedRows` on, a pinned row is taken from `prePaginated` even
when it is off the current page; with it off, only `current` is searched.
-}
type alias PinnedRowsSource row =
    Types.PinnedRowsSource row


{-| The three visible column slices of a pinned table.
-}
type alias PinnedColumns row =
    Types.PinnedColumns row


{-| Pinned to the left edge. TanStack's `'start'`.
-}
pinnedLeft : ColumnPinPosition
pinnedLeft =
    Types.PinnedLeft


{-| Pinned to the right edge. TanStack's `'end'`.
-}
pinnedRight : ColumnPinPosition
pinnedRight =
    Types.PinnedRight


{-| Not pinned. Passing this to [`pinColumn`](#pinColumn) unpins the column.
-}
columnUnpinned : ColumnPinPosition
columnUnpinned =
    Types.ColumnUnpinned


{-| Every visible leaf column, in table order, with no pin partitioning.
-}
allColumnsRegion : ColumnRegion
allColumnsRegion =
    Types.AllColumns


{-| The columns pinned to the left edge.
-}
leftColumnsRegion : ColumnRegion
leftColumnsRegion =
    Types.LeftColumns


{-| The columns that are not pinned.
-}
centerColumnsRegion : ColumnRegion
centerColumnsRegion =
    Types.CenterColumns


{-| The columns pinned to the right edge.
-}
rightColumnsRegion : ColumnRegion
rightColumnsRegion =
    Types.RightColumns


{-| Pinned to the top of the table.
-}
pinnedTop : RowPinPosition
pinnedTop =
    Types.PinnedTop


{-| Pinned to the bottom of the table.
-}
pinnedBottom : RowPinPosition
pinnedBottom =
    Types.PinnedBottom


{-| Not pinned. Passing this to [`pinRow`](#pinRow) unpins the row.
-}
rowUnpinned : RowPinPosition
rowUnpinned =
    Types.RowUnpinned


{-| No selectable descendant of this row is selected.
-}
noSubRowsSelected : SubRowSelection
noSubRowsSelected =
    Types.NoSubRowsSelected


{-| Some, but not all, selectable descendants are selected.
-}
someSubRowsSelected : SubRowSelection
someSubRowsSelected =
    Types.SomeSubRowsSelected


{-| Every selectable descendant is selected.
-}
allSubRowsSelected : SubRowSelection
allSubRowsSelected =
    Types.AllSubRowsSelected


{-| `selectChildren` on, `deselectParents` off: TanStack's defaults.
-}
defaultSelectOptions : SelectOptions
defaultSelectOptions =
    RowSelection.defaultSelectOptions


{-| Pin the row alone, without its leaf rows or its ancestors.
-}
defaultPinRowOptions : PinRowOptions
defaultPinRowOptions =
    { includeLeafRows = False
    , includeParentRows = False
    }



-- COLUMN VISIBILITY


{-| Is this column visible? A group column is visible when any leaf below it
is.
-}
columnIsVisible : State -> Column row -> Bool
columnIsVisible =
    ColumnVisibility.isVisible


{-| Can this column be hidden? Both the column flag and `Config.enableHiding`
have to allow it.
-}
columnCanHide : Config row -> Column row -> Bool
columnCanHide =
    ColumnVisibility.canHide


{-| Show or hide one column; `Nothing` flips it. A group column writes every
hideable leaf below it, because visibility is keyed by leaf column id.
-}
toggleColumnVisibility : Config row -> Column row -> Maybe Bool -> State -> State
toggleColumnVisibility =
    ColumnVisibility.toggleVisibility


{-| Replace the whole visibility map.
-}
setColumnVisibility : Dict String Bool -> State -> State
setColumnVisibility =
    ColumnVisibility.setColumnVisibility


{-| Clear the visibility map, which shows every column again.
-}
resetColumnVisibility : State -> State
resetColumnVisibility =
    ColumnVisibility.resetColumnVisibility


{-| Show or hide every leaf column; `Nothing` flips the current state.
Columns that cannot hide stay visible.
-}
toggleAllColumnsVisible : Config row -> Maybe Bool -> State -> State
toggleAllColumnsVisible =
    ColumnVisibility.toggleAllColumnsVisible


{-| Is every leaf column visible?
-}
isAllColumnsVisible : Config row -> State -> Bool
isAllColumnsVisible =
    ColumnVisibility.isAllColumnsVisible


{-| Is at least one leaf column visible?
-}
isSomeColumnsVisible : Config row -> State -> Bool
isSomeColumnsVisible =
    ColumnVisibility.isSomeColumnsVisible


{-| Every column of the table, group columns included, minus the hidden ones.
-}
visibleFlatColumns : Config row -> State -> List (Column row)
visibleFlatColumns =
    ColumnVisibility.visibleFlatColumns


{-| The cells of one row whose column is visible: left-pinned first, then the
unpinned cells in table order, then the right-pinned ones.
-}
visibleCells : Config row -> State -> Row row -> List Cell
visibleCells =
    ColumnPinning.visibleCells


{-| The visible cells of one row keyed by column id.
-}
visibleCellsByColumnId : Config row -> State -> Row row -> Dict String Cell
visibleCellsByColumnId =
    ColumnPinning.visibleCellsByColumnId



-- COLUMN ORDER


{-| Replace `State.columnOrder`.
-}
setColumnOrder : List String -> State -> State
setColumnOrder =
    ColumnOrdering.setColumnOrder


{-| Drop `State.columnOrder`, restoring definition order.
-}
resetColumnOrder : State -> State
resetColumnOrder =
    ColumnOrdering.resetColumnOrder


{-| Put a column list in table order: `State.columnOrder` first, unlisted
columns behind the listed ones, then the grouped-column rules.
-}
orderColumns : Config row -> State -> List (Column row) -> List (Column row)
orderColumns =
    ColumnOrdering.orderColumns


{-| Apply `Config.groupedColumnMode` to a leaf column list: move the grouped
columns to the front, remove them, or leave the list alone.
-}
orderGroupedColumns : Config row -> State -> List (Column row) -> List (Column row)
orderGroupedColumns =
    ColumnOrdering.orderGroupedColumns


{-| Where this column sits in one region of the visible leaf columns, or `-1`
when it is not in that region.
-}
columnIndex : Config row -> State -> ColumnRegion -> Column row -> Int
columnIndex =
    ColumnOrdering.columnIndex


{-| Is this the first visible column of the region?
-}
columnIsFirst : Config row -> State -> ColumnRegion -> Column row -> Bool
columnIsFirst =
    ColumnOrdering.isFirstColumn


{-| Is this the last visible column of the region?
-}
columnIsLast : Config row -> State -> ColumnRegion -> Column row -> Bool
columnIsLast =
    ColumnOrdering.isLastColumn



-- COLUMN PINNING


{-| Pin one column to an edge, or unpin it with
[`columnUnpinned`](#columnUnpinned). A group column pins every leaf below it.
-}
pinColumn : ColumnPinPosition -> Column row -> State -> State
pinColumn =
    ColumnPinning.pinColumn


{-| Replace the column pinning state.
-}
setColumnPinning : ColumnPinning -> State -> State
setColumnPinning =
    ColumnPinning.setColumnPinning


{-| Unpin every column.
-}
resetColumnPinning : State -> State
resetColumnPinning =
    ColumnPinning.resetColumnPinning


{-| Can this column be pinned? At least one leaf below it has to allow it and
`Config.enableColumnPinning` has to be on.
-}
columnCanPin : Config row -> Column row -> Bool
columnCanPin =
    ColumnPinning.canPin


{-| Where is this column pinned? A group column reports the region of its
first pinned leaf, left before right.
-}
columnIsPinned : State -> Column row -> ColumnPinPosition
columnIsPinned =
    ColumnPinning.isPinned


{-| The column's position inside its pinned region. Unpinned columns give
`0`, matching TanStack.
-}
columnPinnedIndex : State -> Column row -> Int
columnPinnedIndex =
    ColumnPinning.pinnedIndex


{-| Is any column pinned to either edge?
-}
isSomeColumnsPinned : State -> Bool
isSomeColumnsPinned =
    ColumnPinning.isSomeColumnsPinned


{-| Is any column pinned to the left edge?
-}
isSomeColumnsPinnedLeft : State -> Bool
isSomeColumnsPinnedLeft =
    ColumnPinning.isSomeColumnsPinnedLeft


{-| Is any column pinned to the right edge?
-}
isSomeColumnsPinnedRight : State -> Bool
isSomeColumnsPinnedRight =
    ColumnPinning.isSomeColumnsPinnedRight


{-| The leaf columns pinned left, in pinning-state order.
-}
leftLeafColumns : Config row -> State -> List (Column row)
leftLeafColumns =
    ColumnPinning.leftLeafColumns


{-| The leaf columns that are not pinned, in table order.
-}
centerLeafColumns : Config row -> State -> List (Column row)
centerLeafColumns =
    ColumnPinning.centerLeafColumns


{-| The leaf columns pinned right, in pinning-state order.
-}
rightLeafColumns : Config row -> State -> List (Column row)
rightLeafColumns =
    ColumnPinning.rightLeafColumns


{-| The leaf columns of one region, hidden columns included.
-}
pinnedLeafColumns : Config row -> State -> ColumnRegion -> List (Column row)
pinnedLeafColumns =
    ColumnPinning.pinnedLeafColumns


{-| The visible leaf columns pinned left.
-}
leftVisibleLeafColumns : Config row -> State -> List (Column row)
leftVisibleLeafColumns =
    ColumnPinning.leftVisibleLeafColumns


{-| The visible leaf columns that are not pinned.
-}
centerVisibleLeafColumns : Config row -> State -> List (Column row)
centerVisibleLeafColumns =
    ColumnPinning.centerVisibleLeafColumns


{-| The visible leaf columns pinned right.
-}
rightVisibleLeafColumns : Config row -> State -> List (Column row)
rightVisibleLeafColumns =
    ColumnPinning.rightVisibleLeafColumns


{-| The visible leaf columns of one region.
[`allColumnsRegion`](#allColumnsRegion) gives
[`visibleLeafColumns`](#visibleLeafColumns) unchanged.
-}
pinnedVisibleLeafColumns : Config row -> State -> ColumnRegion -> List (Column row)
pinnedVisibleLeafColumns =
    ColumnPinning.pinnedVisibleLeafColumns


{-| The three visible column slices at once, in render order.
-}
pinnedColumns : Config row -> State -> PinnedColumns row
pinnedColumns =
    ColumnPinning.pinnedColumns


{-| The header rows of the left-pinned columns.
-}
leftHeaderGroups : Config row -> State -> List (HeaderGroup row)
leftHeaderGroups =
    Header.leftHeaderGroups


{-| The header rows of the unpinned columns.
-}
centerHeaderGroups : Config row -> State -> List (HeaderGroup row)
centerHeaderGroups =
    Header.centerHeaderGroups


{-| The header rows of the right-pinned columns.
-}
rightHeaderGroups : Config row -> State -> List (HeaderGroup row)
rightHeaderGroups =
    Header.rightHeaderGroups


{-| The footer rows of the left-pinned columns.
-}
leftFooterGroups : Config row -> State -> List (HeaderGroup row)
leftFooterGroups =
    Header.leftFooterGroups


{-| The footer rows of the unpinned columns.
-}
centerFooterGroups : Config row -> State -> List (HeaderGroup row)
centerFooterGroups =
    Header.centerFooterGroups


{-| The footer rows of the right-pinned columns.
-}
rightFooterGroups : Config row -> State -> List (HeaderGroup row)
rightFooterGroups =
    Header.rightFooterGroups


{-| Every header of the left-pinned header rows.
-}
leftFlatHeaders : Config row -> State -> List (Header row)
leftFlatHeaders =
    Header.leftFlatHeaders


{-| Every header of the center header rows.
-}
centerFlatHeaders : Config row -> State -> List (Header row)
centerFlatHeaders =
    Header.centerFlatHeaders


{-| Every header of the right-pinned header rows.
-}
rightFlatHeaders : Config row -> State -> List (Header row)
rightFlatHeaders =
    Header.rightFlatHeaders


{-| The left-pinned headers that have no sub-headers.
-}
leftLeafHeaders : Config row -> State -> List (Header row)
leftLeafHeaders =
    Header.leftLeafHeaders


{-| The center headers that have no sub-headers.
-}
centerLeafHeaders : Config row -> State -> List (Header row)
centerLeafHeaders =
    Header.centerLeafHeaders


{-| The right-pinned headers that have no sub-headers.
-}
rightLeafHeaders : Config row -> State -> List (Header row)
rightLeafHeaders =
    Header.rightLeafHeaders


{-| The visible cells of one row pinned left, in pinning-state order.
-}
leftVisibleCells : Config row -> State -> Row row -> List Cell
leftVisibleCells =
    ColumnPinning.leftVisibleCells


{-| The visible cells of one row whose column is not pinned.
-}
centerVisibleCells : Config row -> State -> Row row -> List Cell
centerVisibleCells =
    ColumnPinning.centerVisibleCells


{-| The visible cells of one row pinned right, in pinning-state order.
-}
rightVisibleCells : Config row -> State -> Row row -> List Cell
rightVisibleCells =
    ColumnPinning.rightVisibleCells



-- COLUMN SIZING


{-| The rendered width of a column: the committed size from
`State.columnSizing` when there is one, otherwise the column's own size and
then the configured default, clamped between `minSize` and `maxSize`.
-}
getColumnSize : Config row -> State -> Column row -> Float
getColumnSize =
    ColumnSizing.getSize


{-| How far from the start of its region a column begins.
-}
getColumnStart : Config row -> State -> ColumnRegion -> Column row -> Float
getColumnStart =
    ColumnSizing.getStart


{-| How far from the end of its region a column ends.
-}
getColumnAfter : Config row -> State -> ColumnRegion -> Column row -> Float
getColumnAfter =
    ColumnSizing.getAfter


{-| Commit one column's size.
-}
setColumnSize : String -> Float -> State -> State
setColumnSize =
    ColumnSizing.setColumnSize


{-| Replace the whole sizing map.
-}
setColumnSizing : Dict String Float -> State -> State
setColumnSizing =
    ColumnSizing.setColumnSizing


{-| Drop one column's committed size, leaving the other columns alone.
-}
resetColumnSize : String -> State -> State
resetColumnSize =
    ColumnSizing.resetColumnSize


{-| Drop every committed size.
-}
resetColumnSizing : State -> State
resetColumnSizing =
    ColumnSizing.resetColumnSizing


{-| The width of a header: its column's size for a leaf header, the sum of
the sub-header widths for a parent header.
-}
getHeaderSize : Config row -> State -> Header row -> Float
getHeaderSize =
    ColumnSizing.headerSize


{-| How far from the start of its header row a header begins. Pass the
headers of the row the header belongs to.
-}
getHeaderStart : Config row -> State -> List (Header row) -> Header row -> Float
getHeaderStart =
    ColumnSizing.headerStart


{-| The width of the whole table: the sum of the top header row.
-}
totalSize : Config row -> State -> Float
totalSize =
    ColumnSizing.totalSize


{-| The width of the left-pinned region.
-}
leftTotalSize : Config row -> State -> Float
leftTotalSize =
    ColumnSizing.leftTotalSize


{-| The width of the unpinned region.
-}
centerTotalSize : Config row -> State -> Float
centerTotalSize =
    ColumnSizing.centerTotalSize


{-| The width of the right-pinned region.
-}
rightTotalSize : Config row -> State -> Float
rightTotalSize =
    ColumnSizing.rightTotalSize



-- ROW SELECTION


{-| Select or deselect one row; `Nothing` flips it. Sub-rows follow along.
The row model is only read for the parent chain, so the core row model is
the usual argument.
-}
toggleRowSelected : Config row -> RowModel row -> Row row -> Maybe Bool -> State -> State
toggleRowSelected cfg model row value state =
    RowSelection.toggleRowSelectedWith cfg RowSelection.defaultSelectOptions model row value state


{-| [`toggleRowSelected`](#toggleRowSelected) with explicit
[`SelectOptions`](#SelectOptions).
-}
toggleRowSelectedWith : Config row -> SelectOptions -> RowModel row -> Row row -> Maybe Bool -> State -> State
toggleRowSelectedWith =
    RowSelection.toggleRowSelectedWith


{-| Select or deselect every row of the given model; `Nothing` flips on the
current all-selected state. Pass the filtered row model, which is what
TanStack's pre-grouped model is.
-}
toggleAllRowsSelected : Config row -> RowModel row -> Maybe Bool -> State -> State
toggleAllRowsSelected =
    RowSelection.toggleAllRowsSelected


{-| Select or deselect every row of the current page. Pass the paginated row
model.
-}
toggleAllPageRowsSelected : Config row -> RowModel row -> Maybe Bool -> State -> State
toggleAllPageRowsSelected =
    RowSelection.toggleAllPageRowsSelected


{-| Clear the selection, ids of rows that cannot be selected included. This
is TanStack's `deselectAll` option.
-}
deselectAllRows : State -> State
deselectAllRows =
    RowSelection.deselectAllRows


{-| Replace the selection.
-}
setRowSelection : Set String -> State -> State
setRowSelection =
    RowSelection.setRowSelection


{-| Clear the selection.
-}
resetRowSelection : State -> State
resetRowSelection =
    RowSelection.resetRowSelection


{-| Select or deselect every row between an anchor id and this row, in
display order. Pass the pre-pagination row model (the expanded row model):
like TanStack's `getRowsInDisplayOrder`, the range ignores the current page
and honours `Config.paginateExpandedRows`, so a shift-click can span pages.
Falls back to an ordinary toggle when the range is not usable, which is what
the shift-click handler does.
-}
selectRange : Config row -> RowModel row -> String -> Row row -> Bool -> State -> State
selectRange cfg model anchorId row value state =
    RowSelection.selectRangeWith cfg RowSelection.defaultSelectOptions model anchorId row value state


{-| [`selectRange`](#selectRange) with explicit
[`SelectOptions`](#SelectOptions).
-}
selectRangeWith : Config row -> SelectOptions -> RowModel row -> String -> Row row -> Bool -> State -> State
selectRangeWith =
    RowSelection.selectRangeWith


{-| Would a range from this anchor to this row be selected as a range? Both
endpoints have to be in the display order of the pre-pagination row model
and allow multi-selection.
-}
canSelectRange : Config row -> State -> RowModel row -> String -> Row row -> Bool
canSelectRange =
    RowSelection.canSelectRange


{-| Is this row selected?
-}
getIsRowSelected : State -> Row row -> Bool
getIsRowSelected =
    RowSelection.isRowSelected


{-| Is anything selected at all?
-}
getIsSomeRowsSelected : State -> Bool
getIsSomeRowsSelected =
    RowSelection.isSomeRowsSelected


{-| Is every selectable row of the given model selected? Pass the filtered
row model.
-}
getIsAllRowsSelected : Config row -> State -> RowModel row -> Bool
getIsAllRowsSelected =
    RowSelection.isAllRowsSelected


{-| Is every selectable row of the current page selected?
-}
getIsAllPageRowsSelected : Config row -> State -> RowModel row -> Bool
getIsAllPageRowsSelected =
    RowSelection.isAllPageRowsSelected


{-| Is any row of the current page selected, or partly selected?
-}
getIsSomePageRowsSelected : Config row -> State -> RowModel row -> Bool
getIsSomePageRowsSelected =
    RowSelection.isSomePageRowsSelected


{-| Can this row be selected?
-}
getCanSelect : Config row -> Row row -> Bool
getCanSelect =
    RowSelection.canSelect


{-| Can selecting this row select its sub-rows?
-}
getCanSelectSubRows : Config row -> Row row -> Bool
getCanSelectSubRows =
    RowSelection.canSelectSubRows


{-| Can this row take part in a multi-row selection?
-}
getCanMultiSelect : Config row -> Row row -> Bool
getCanMultiSelect =
    RowSelection.canMultiSelect


{-| Is part, but not all, of this row's sub-tree selected?
-}
getIsSomeSelected : Config row -> State -> Row row -> Bool
getIsSomeSelected =
    RowSelection.isSomeSelected


{-| Is this row's whole sub-tree selected?
-}
getIsAllSubRowsSelected : Config row -> State -> Row row -> Bool
getIsAllSubRowsSelected =
    RowSelection.isAllSubRowsSelected


{-| How much of this row's sub-tree is selected.
-}
subRowSelection : Config row -> State -> Row row -> SubRowSelection
subRowSelection =
    RowSelection.subRowSelection


{-| The selected row ids.
-}
selectedRowIds : State -> List String
selectedRowIds =
    RowSelection.selectedRowIds


{-| Keep only the selected rows of a row model. Selected descendants of
unselected parents stay in `flatRows` and `rowsById` but not in `rows`,
exactly like TanStack's `selectRowsFn`. TanStack's three selected row models
are this function over the core, the filtered, and the sorted row model.
-}
selectedRowModel : State -> RowModel row -> RowModel row
selectedRowModel =
    RowSelection.selectedRowModel



-- ROW PINNING


{-| Pin one row to an edge, or unpin it with [`rowUnpinned`](#rowUnpinned).
-}
pinRow : RowPinPosition -> Row row -> State -> State
pinRow position row state =
    RowPinning.pinRowWith position
        defaultPinRowOptions
        { rows = [], flatRows = [], rowsById = Dict.empty }
        row
        state


{-| [`pinRow`](#pinRow) with the leaf rows or the ancestors of the row pinned
along with it. The row model is where the ancestors are looked up.
-}
pinRowWith : RowPinPosition -> PinRowOptions -> RowModel row -> Row row -> State -> State
pinRowWith =
    RowPinning.pinRowWith


{-| Replace the row pinning state.
-}
setRowPinning : RowPinning -> State -> State
setRowPinning =
    RowPinning.setRowPinning


{-| Unpin every row.
-}
resetRowPinning : State -> State
resetRowPinning =
    RowPinning.resetRowPinning


{-| Where is this row pinned?
-}
getIsRowPinned : State -> Row row -> RowPinPosition
getIsRowPinned =
    RowPinning.isPinned


{-| The row's position among the pinned rows that are actually shown, or `-1`
when it is not pinned.
-}
getRowPinnedIndex : Config row -> State -> PinnedRowsSource row -> Row row -> Int
getRowPinnedIndex =
    RowPinning.pinnedIndex


{-| Can this row be pinned?
-}
getCanPinRow : Config row -> Row row -> Bool
getCanPinRow =
    RowPinning.canPin


{-| Is any row pinned at either edge?
-}
isSomeRowsPinned : State -> Bool
isSomeRowsPinned =
    RowPinning.isSomeRowsPinned


{-| Is any row pinned to the top?
-}
isSomeRowsPinnedTop : State -> Bool
isSomeRowsPinnedTop =
    RowPinning.isSomeRowsPinnedTop


{-| Is any row pinned to the bottom?
-}
isSomeRowsPinnedBottom : State -> Bool
isSomeRowsPinnedBottom =
    RowPinning.isSomeRowsPinnedBottom


{-| The rows pinned to the top, in pinning-state order.
-}
topRows : Config row -> State -> PinnedRowsSource row -> List (Row row)
topRows =
    RowPinning.topRows


{-| The rows pinned to the bottom, in pinning-state order.
-}
bottomRows : Config row -> State -> PinnedRowsSource row -> List (Row row)
bottomRows =
    RowPinning.bottomRows


{-| The rows of the current page that are not pinned.
-}
centerRows : State -> RowModel row -> List (Row row)
centerRows =
    RowPinning.centerRows
