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
    , headerGroups, footerGroups, flatHeaders, leafHeaders, getLeafHeaders
    , headerId, headerColumnId, headerColSpan, headerRowSpan, headerDepth, headerIndex
    , headerIsPlaceholder, headerPlaceholderId, headerSubHeaders
    , rowId, rowIndex, rowDepth, rowOriginal, rowSubRows, rowParentId, rowOriginalSubRows
    , rowGroupingColumnId, rowGroupingValue, rowLeafRows, rowAggregatedValues
    , getValue, getUniqueValues, getLeafRows, getParentRow, getParentRows, getAllCells
    , findRow, maxSubRowDepth
    , rows, rowsFromList, coreRowModel, coreRowModelFromList
    , filteredRowModel, groupedRowModel, sortedRowModel, expandedRowModel, paginatedRowModel
    , facetedUniqueValues, facetedMinMax
    , facetedRowModel, globalFacetKey
    , getCanFilter, getIsFiltered, getFilterValue, getFilterIndex
    , getFilterFn, getAutoFilterFn, shouldAutoRemoveFilter
    , setColumnFilter, setColumnFilters, resetColumnFilters
    , getCanGlobalFilter, getGlobalFilterFn, globalAutoFilterFn
    , setGlobalFilter, resetGlobalFilter
    , SortDir, sortAsc, sortDesc
    , getCanSort, getCanMultiSort, getIsSorted, getSortIndex
    , getAutoSortFn, getSortFn, getAutoSortDir, getFirstSortDir, getNextSortingOrder
    , toggleSort, setSorting, clearSorting, resetSorting
    , prePaginationRowModel, rowsInDisplayOrder, displayIndex
    , setPage, setPageSize, setPagination
    , resetPageIndex, resetPageSize, resetPagination
    , getPageCount, getPageOptions, getRowCount
    , getCanPreviousPage, getCanNextPage, getCanLastPage
    , previousPage, nextPage, firstPage, lastPage, unlimitedPageSize
    , withRowCanExpand, withIsRowExpanded, withMaxAggregationDepth
    , getCanGroup, getIsGrouped, getGroupedIndex
    , toggleGrouping, setGrouping, resetGrouping
    , rowIsGrouped, rowGroupingValueFor, cellIsGrouped, cellIsPlaceholder
    , preGroupedRowModel
    , getAutoAggregationFn, getAggregationFn
    , aggregationValue, aggregationValueOf, cellIsAggregated
    , preExpandedRowModel
    , getCanExpand, getIsExpanded, getIsAllParentsExpanded
    , getCanSomeRowsExpand, getIsSomeRowsExpanded, getIsAllRowsExpanded, getExpandedDepth
    , toggleExpanded, toggleAllRowsExpanded, setExpanded, resetExpanded
    , SubRowSelection, SelectOptions
    , noSubRowsSelected, someSubRowsSelected, allSubRowsSelected
    , defaultSelectOptions
    , toggleRowSelected, toggleRowSelectedWith
    , toggleAllRowsSelected, toggleAllPageRowsSelected, deselectAllRows
    , setRowSelection, resetRowSelection
    , selectRange, selectRangeWith, canSelectRange
    , getIsRowSelected, getIsSomeRowsSelected
    , getIsAllRowsSelected, getIsAllPageRowsSelected, getIsSomePageRowsSelected
    , getCanSelect, getCanSelectSubRows, getCanMultiSelect
    , getIsSomeSelected, getIsAllSubRowsSelected, subRowSelection
    , selectedRowIds, selectedRowModel
    , ColumnPinPosition, ColumnRegion, RowPinPosition
    , PinRowOptions, PinnedRowsSource, PinnedColumns
    , pinnedLeft, pinnedRight, columnUnpinned
    , allColumnsRegion, leftColumnsRegion, centerColumnsRegion, rightColumnsRegion
    , pinnedTop, pinnedBottom, rowUnpinned
    , defaultPinRowOptions
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
    , pinRow, pinRowWith, setRowPinning, resetRowPinning
    , getIsRowPinned, getRowPinnedIndex, getCanPinRow
    , isSomeRowsPinned, isSomeRowsPinnedTop, isSomeRowsPinnedBottom
    , topRows, bottomRows, centerRows
    , columnIsVisible, columnCanHide, toggleColumnVisibility, setColumnVisibility
    , resetColumnVisibility, toggleAllColumnsVisible
    , isAllColumnsVisible, isSomeColumnsVisible, visibleFlatColumns
    , visibleCells, visibleCellsByColumnId
    , setColumnOrder, resetColumnOrder, orderColumns, orderGroupedColumns
    , columnIndex, columnIsFirst, columnIsLast
    , getColumnSize, getColumnStart, getColumnAfter
    , setColumnSize, setColumnSizing, resetColumnSize, resetColumnSizing
    , getHeaderSize, getHeaderStart
    , totalSize, leftTotalSize, centerTotalSize, rightTotalSize
    , CellSpanIndex, RowSpanContext
    , withCellSpanning, withEnableCellSpanning
    , withSpanRows, withSpanRowsWhen, withSpanColumns, spanAllColumns
    , columnCanSpan, cellSpanIndex, cellSpanIndexRowIds, cellSpanIndexRowSpans
    , cellRowSpan, cellColSpan, cellIsCovered
    , CellSelectionRange, CellSelectionOperation, CellSelectionMode, CellSelectionBounds
    , CellSelectionEdges, CellDirection, SelectionRows
    , includeCells, excludeCells
    , replaceSelection, includeSelection, excludeSelection
    , cellUp, cellDown, cellLeft, cellRight
    , withCellSelection, withCellSelectionWhen
    , withCellRangeSelection, withMultiCellRangeSelection, withEnableCellSelection
    , cellRange, setCellSelection, clearCellSelection
    , selectCellRange, selectCellRangeWith, selectAllCells, setFocusedCell
    , selectCell, extendCellSelectionTo, toggleCellSelection
    , moveCellSelection, extendCellSelection
    , cellCanSelect, cellIsSelected, cellIsFocused, cellTabIndex, cellSelectionEdges
    , focusedCell, cellSelectionBounds, cellSelectionMergeBounds, cellSelectionColumnIndexes
    , selectedCellIds, selectedCellCount, selectedCellRangesData
    , cellSelectionRowIds, cellSelectionColumnIds
    , intersectCellSelectionBounds, subtractCellSelectionBounds, addCellSelectionBounds
    , mergeAdjacentCellSelectionBounds, expandCellSelectionBounds
    , applyCellSelectionBoundsOperations
    -- Phase 3 to 6 entries are the blocks above; elm-format hoists these
    -- markers to the end of the exposing list.
    )

{-| Headless table state and row-model pipeline: a port of TanStack Table
core as pure functions.

There is no table instance. You own the `State`, you own the data, and every
function here takes a `Config row` and a `State` and gives you a value back.


# Columns and headers

Column and header types, the builders that assemble a `Config row`'s column
list, and the readers that walk it back.


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


## Headers

@docs headerGroups, footerGroups, flatHeaders, leafHeaders, getLeafHeaders
@docs headerId, headerColumnId, headerColSpan, headerRowSpan, headerDepth, headerIndex
@docs headerIsPlaceholder, headerPlaceholderId, headerSubHeaders


# Row models

The pipeline that turns your data into a row tree, the readers that walk one
row, and the faceted values later stages sample from it.


## Reading rows

@docs rowId, rowIndex, rowDepth, rowOriginal, rowSubRows, rowParentId, rowOriginalSubRows
@docs rowGroupingColumnId, rowGroupingValue, rowLeafRows, rowAggregatedValues
@docs getValue, getUniqueValues, getLeafRows, getParentRow, getParentRows, getAllCells
@docs findRow, maxSubRowDepth


## The pipeline

@docs rows, rowsFromList, coreRowModel, coreRowModelFromList
@docs filteredRowModel, groupedRowModel, sortedRowModel, expandedRowModel, paginatedRowModel


## Faceting

@docs facetedUniqueValues, facetedMinMax
@docs facetedRowModel, globalFacetKey


# Filtering

Column filters narrow a row model down to the rows that match; the global
filter runs the same comparison across every column that allows it. Every
reader that has to guess something from the data (an `'auto'` filter
function, for instance) takes a `RowModel row` to sample, exactly like
TanStack, which samples the core or filtered row model for the same job.


## Column filter state

@docs getCanFilter, getIsFiltered, getFilterValue, getFilterIndex
@docs getFilterFn, getAutoFilterFn, shouldAutoRemoveFilter
@docs setColumnFilter, setColumnFilters, resetColumnFilters


## Global filter state

@docs getCanGlobalFilter, getGlobalFilterFn, globalAutoFilterFn
@docs setGlobalFilter, resetGlobalFilter


# Sorting

One or more columns order the rows; `withSortDescFirst`, `withInvertSorting`,
and `withSortUndefined` tune how a single column compares.


## Sort direction

@docs SortDir, sortAsc, sortDesc


## Sorting state

@docs getCanSort, getCanMultiSort, getIsSorted, getSortIndex
@docs getAutoSortFn, getSortFn, getAutoSortDir, getFirstSortDir, getNextSortingOrder
@docs toggleSort, setSorting, clearSorting, resetSorting


# Pagination

Slices the pre-pagination row model into pages; `Config.pageCount` and
`Config.rowCount` stand in for a server-side count when the table is not
paginating in memory.


## Pagination state

@docs prePaginationRowModel, rowsInDisplayOrder, displayIndex
@docs setPage, setPageSize, setPagination
@docs resetPageIndex, resetPageSize, resetPagination
@docs getPageCount, getPageOptions, getRowCount
@docs getCanPreviousPage, getCanNextPage, getCanLastPage
@docs previousPage, nextPage, firstPage, lastPage, unlimitedPageSize


# Grouping and aggregation

The grouped row model replaces the rows with one group row per distinct
value of every column in `State.grouping`, recursively, and rolls up every
other column with an `AggregationFn`.

Group rows carry [`rowGroupingColumnId`](#rowGroupingColumnId),
[`rowGroupingValue`](#rowGroupingValue), [`rowLeafRows`](#rowLeafRows), and
[`rowAggregatedValues`](#rowAggregatedValues), and their ids are
`"columnId:groupingValue"` joined to the parent group's id with `>`.


## Grouping and expanding configuration

@docs withRowCanExpand, withIsRowExpanded, withMaxAggregationDepth


## Grouping state

@docs getCanGroup, getIsGrouped, getGroupedIndex
@docs toggleGrouping, setGrouping, resetGrouping
@docs rowIsGrouped, rowGroupingValueFor, cellIsGrouped, cellIsPlaceholder
@docs preGroupedRowModel


## Aggregation

@docs getAutoAggregationFn, getAggregationFn
@docs aggregationValue, aggregationValueOf, cellIsAggregated


# Expanding

Splices the sub-rows of expanded rows back into the row list, according to
`State.expanded`.


## Expanded state

@docs preExpandedRowModel
@docs getCanExpand, getIsExpanded, getIsAllParentsExpanded
@docs getCanSomeRowsExpand, getIsSomeRowsExpanded, getIsAllRowsExpanded, getExpandedDepth
@docs toggleExpanded, toggleAllRowsExpanded, setExpanded, resetExpanded


# Row selection

Row selection propagates to sub-rows and reports `isSomeSelected` and
`isAllSelected` per parent. Every transition is `... -> State -> State` so it
pipes, and every query takes the `Config` and the `State` first, then the
row model or column it is about.


## Selection types

@docs SubRowSelection, SelectOptions
@docs noSubRowsSelected, someSubRowsSelected, allSubRowsSelected
@docs defaultSelectOptions

These are abstract for the same reason as the types above, so they come with
one function per variant.


## Selection state

@docs toggleRowSelected, toggleRowSelectedWith
@docs toggleAllRowsSelected, toggleAllPageRowsSelected, deselectAllRows
@docs setRowSelection, resetRowSelection
@docs selectRange, selectRangeWith, canSelectRange
@docs getIsRowSelected, getIsSomeRowsSelected
@docs getIsAllRowsSelected, getIsAllPageRowsSelected, getIsSomePageRowsSelected
@docs getCanSelect, getCanSelectSubRows, getCanMultiSelect
@docs getIsSomeSelected, getIsAllSubRowsSelected, subRowSelection
@docs selectedRowIds, selectedRowModel


# Pinning

Column pinning returns left, center, and right leaf column lists; row
pinning does the same for rows. Neither one touches the DOM.


## Pinning types

@docs ColumnPinPosition, ColumnRegion, RowPinPosition
@docs PinRowOptions, PinnedRowsSource, PinnedColumns
@docs pinnedLeft, pinnedRight, columnUnpinned
@docs allColumnsRegion, leftColumnsRegion, centerColumnsRegion, rightColumnsRegion
@docs pinnedTop, pinnedBottom, rowUnpinned
@docs defaultPinRowOptions

These are abstract for the same reason as the types above, so they come with
one function per variant.


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


## Row pinning

@docs pinRow, pinRowWith, setRowPinning, resetRowPinning
@docs getIsRowPinned, getRowPinnedIndex, getCanPinRow
@docs isSomeRowsPinned, isSomeRowsPinnedTop, isSomeRowsPinnedBottom
@docs topRows, bottomRows, centerRows


# Column ordering, visibility and sizing

Which columns render, in what order, and how wide each one is.


## Column visibility

@docs columnIsVisible, columnCanHide, toggleColumnVisibility, setColumnVisibility
@docs resetColumnVisibility, toggleAllColumnsVisible
@docs isAllColumnsVisible, isSomeColumnsVisible, visibleFlatColumns
@docs visibleCells, visibleCellsByColumnId


## Column order

@docs setColumnOrder, resetColumnOrder, orderColumns, orderGroupedColumns
@docs columnIndex, columnIsFirst, columnIsLast


## Column sizing

@docs getColumnSize, getColumnStart, getColumnAfter
@docs setColumnSize, setColumnSizing, resetColumnSize, resetColumnSizing
@docs getHeaderSize, getHeaderStart
@docs totalSize, leftTotalSize, centerTotalSize, rightTotalSize


# Cell spanning and cell selection

Spans merge adjacent cells; cell selection tracks rectangular ranges,
focus, and keyboard movement over the visible grid. Optional; ignore this
section if your table does not need either.


## Span index types

@docs CellSpanIndex, RowSpanContext


## Cell spanning

@docs withCellSpanning, withEnableCellSpanning
@docs withSpanRows, withSpanRowsWhen, withSpanColumns, spanAllColumns
@docs columnCanSpan, cellSpanIndex, cellSpanIndexRowIds, cellSpanIndexRowSpans
@docs cellRowSpan, cellColSpan, cellIsCovered


## Cell selection types

@docs CellSelectionRange, CellSelectionOperation, CellSelectionMode, CellSelectionBounds
@docs CellSelectionEdges, CellDirection, SelectionRows
@docs includeCells, excludeCells
@docs replaceSelection, includeSelection, excludeSelection
@docs cellUp, cellDown, cellLeft, cellRight


## Cell selection options

@docs withCellSelection, withCellSelectionWhen
@docs withCellRangeSelection, withMultiCellRangeSelection, withEnableCellSelection


## Cell selection transitions

@docs cellRange, setCellSelection, clearCellSelection
@docs selectCellRange, selectCellRangeWith, selectAllCells, setFocusedCell
@docs selectCell, extendCellSelectionTo, toggleCellSelection
@docs moveCellSelection, extendCellSelection


## Cell selection queries

@docs cellCanSelect, cellIsSelected, cellIsFocused, cellTabIndex, cellSelectionEdges
@docs focusedCell, cellSelectionBounds, cellSelectionMergeBounds, cellSelectionColumnIndexes
@docs selectedCellIds, selectedCellCount, selectedCellRangesData
@docs cellSelectionRowIds, cellSelectionColumnIds


## Cell selection geometry

@docs intersectCellSelectionBounds, subtractCellSelectionBounds, addCellSelectionBounds
@docs mergeAdjacentCellSelectionBounds, expandCellSelectionBounds
@docs applyCellSelectionBoundsOperations

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Set exposing (Set)
import Table.AggregationFn exposing (AggregationFn)
import Table.FilterFn exposing (FilterFn)
import Table.Internal.Aggregation as Aggregation
import Table.Internal.CellSelection as CellSelection
import Table.Internal.CellSelectionGeometry as CellSelectionGeometry
import Table.Internal.CellSpanning as CellSpanning
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

Fields, with the defaults [`config`](#config) sets:

  - `columns : List (Column row)`
  - `getRowId : Maybe (row -> Int -> Maybe String -> String)`, `Nothing` (index paths)
  - `getSubRows : row -> List row`, none
  - `manualSorting`, `manualFiltering`, `manualGrouping`, `manualExpanding`,
    `manualPagination : Bool`, all `False`; `True` makes that stage return its input
  - `enableSorting`, `enableMultiSort`, `enableSortingRemoval`,
    `enableMultiRemove : Bool`, all `True`; `maxMultiSortColCount : Int`, unlimited;
    `sortDescFirst : Maybe Bool`, `Nothing` (automatic per column)
  - `enableFilters`, `enableColumnFilters`, `enableGlobalFilter : Bool`, all `True`;
    `getColumnCanGlobalFilter : Maybe (Column row -> Bool)`, `Nothing` (strings and
    numbers); `filterFromLeafRows : Bool`, `False`; `maxLeafRowFilterDepth : Int`,
    `100`; `globalFilterFn : Maybe FilterFn`, `Nothing` (automatic)
  - `enableGrouping : Bool`, `True`; `groupedColumnMode : GroupedColumnMode`,
    [`groupedColumnsReorder`](#groupedColumnsReorder)
  - `enableExpanding : Bool`, `True`; `getRowCanExpand`,
    `getIsRowExpanded : Maybe (Row row -> Bool)`, `Nothing`;
    `paginateExpandedRows : Bool`, `True`
  - `pageCount`, `rowCount : Maybe Int`, `Nothing` (manual pagination only)
  - `enableRowSelection`, `enableMultiRowSelection`, `enableSubRowSelection`,
    `enableRowPinning : Row row -> Bool`, all `always True`;
    `keepPinnedRows : Bool`, `True`
  - `enableColumnPinning`, `enableHiding : Bool`, `True`;
    `defaultColumn : SizeDefaults`, size 150, min 20, max unlimited
  - `enableCellSpanning`, `enableCellSelection`, `enableCellRangeSelection`,
    `enableMultiCellRangeSelection : Bool`, all `True`;
    `cellSelectionFilter : Maybe (Cell -> Bool)`, `Nothing`

-}
type alias Config row =
    Types.Config row


{-| Every state slice the pipeline reads. Start from
[`initialState`](#initialState) and update it yourself, directly or through
the transition functions in this module.

  - `sorting : List SortColumn`, in priority order
  - `columnFilters : List ColumnFilter`
  - `globalFilter : Value`, `Null` for none
  - `grouping : List String`, column ids in grouping order
  - `expanded : Expanded`
  - `rowSelection : Set String`, selected row ids
  - `pagination : Pagination`
  - `columnOrder : List String`, empty for definition order
  - `columnVisibility : Dict String Bool`, missing means visible
  - `columnPinning : ColumnPinning`
  - `columnSizing : Dict String Float`, missing means the column's own size
  - `rowPinning : RowPinning`
  - `cellSelection : List CellSelectionRange`

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
The second argument is the row's index, mirroring TanStack's
`getGroupingValue(originalRow, index, row)`.
-}
withGetGroupingValue : (row -> Int -> Value) -> Column row -> Column row
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


{-| The deepest row depth in a row model, counting sub-rows and group rows.
A flat model is `0`; one level of sub-rows makes it `1`. Useful for sizing
indentation or the header checkbox of an expanding table.
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


{-| Every distinct value of one column with the number of rows that carry it,
in first-seen order. Pass the pre-filtered row model (usually the core row
model); the count is taken over [`facetedRowModel`](#facetedRowModel), which
applies every filter except this column's own. `List` cells contribute each
item.
-}
facetedUniqueValues : Config row -> State -> RowModel row -> String -> List ( Value, Int )
facetedUniqueValues =
    Faceting.facetedUniqueValues


{-| The smallest and largest `Number` value of one column, or `Nothing` when
it has none. Pass the pre-filtered row model; like
[`facetedUniqueValues`](#facetedUniqueValues) it looks through
[`facetedRowModel`](#facetedRowModel).
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

Pass the core row model: a column without an explicit filter function picks
its automatic one from the first values, and that choice decides the
auto-remove rule.

-}
setColumnFilter : Config row -> RowModel row -> String -> Value -> State -> State
setColumnFilter =
    Filtering.setColumnFilter


{-| Replace `State.columnFilters` wholesale, dropping the entries of known
columns whose value should auto-remove. Pass the core row model, as for
[`setColumnFilter`](#setColumnFilter).
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

The row model is the pre-sorted one (the grouped row model, or the core
row model when nothing is grouped or filtered): the first sort direction of
a column without `sortDescFirst` depends on its values.

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



-- PHASE 4
--
-- Grouping, aggregation, and expansion. Bodies live in
-- src/Table/Internal/{Grouping,Aggregation,Expanding}.elm.
--
-- Every reader that has to resolve an 'auto' aggregation function takes a
-- RowModel row to sample, the way phase 3's 'auto' filter and sort readers
-- do; TanStack samples the core row model for the same job.


{-| Set a per-row override for "can this row expand?", TanStack's
`getRowCanExpand`. It wins over `Config.enableExpanding` and over the
"has sub-rows" rule.
-}
withRowCanExpand : (Row row -> Bool) -> Config row -> Config row
withRowCanExpand =
    Config.withRowCanExpand


{-| Set a per-row override for "is this row expanded?", TanStack's
`getIsRowExpanded`. It wins over `State.expanded` outright.
-}
withIsRowExpanded : (Row row -> Bool) -> Config row -> Config row
withIsRowExpanded =
    Config.withIsRowExpanded


{-| How far below an aggregated row its aggregation looks for values.
`0`, the default, aggregates the rows themselves; `1` aggregates their
children. TanStack's `maxAggregationDepth`.
-}
withMaxAggregationDepth : Int -> Column row -> Column row
withMaxAggregationDepth =
    Column.withMaxAggregationDepth



-- GROUPING STATE


{-| Can this column be grouped? Grouping has to be enabled on the table and
on the column, and the column needs either an accessor or a
[`withGetGroupingValue`](#withGetGroupingValue).
-}
getCanGroup : Config row -> String -> Bool
getCanGroup =
    Grouping.getCanGroup


{-| Is this column in `State.grouping`?
-}
getIsGrouped : State -> String -> Bool
getIsGrouped =
    Grouping.getIsGrouped


{-| Where this column sits in `State.grouping`, or `-1`.
-}
getGroupedIndex : State -> String -> Int
getGroupedIndex =
    Grouping.getGroupedIndex


{-| Add this column to `State.grouping`, or drop it and keep the rest in
order. TanStack's `column_toggleGrouping` does not check
[`getCanGroup`](#getCanGroup) either; its click handler does.
-}
toggleGrouping : String -> State -> State
toggleGrouping =
    Grouping.toggleGrouping


{-| Replace `State.grouping`.
-}
setGrouping : List String -> State -> State
setGrouping =
    Grouping.setGrouping


{-| Empty `State.grouping`.
-}
resetGrouping : State -> State
resetGrouping =
    Grouping.resetGrouping


{-| Was this row built by the grouped row model?
-}
rowIsGrouped : Row row -> Bool
rowIsGrouped =
    Grouping.rowIsGrouped


{-| The value this row groups by for one column:
[`withGetGroupingValue`](#withGetGroupingValue) when the column has one, the
cell value otherwise.
-}
rowGroupingValueFor : Config row -> Row row -> String -> Value
rowGroupingValueFor =
    Grouping.groupingValueFor


{-| Is this the cell of the column its group row groups by? `Cell` carries
its row and column ids, so this takes the row and the column id.
-}
cellIsGrouped : State -> Row row -> String -> Bool
cellIsGrouped =
    Grouping.cellIsGrouped


{-| Is this the cell of a grouped column that is not this row's own grouping
column? Those cells render as placeholders.
-}
cellIsPlaceholder : State -> Row row -> String -> Bool
cellIsPlaceholder =
    Grouping.cellIsPlaceholder


{-| The row model grouping runs on: the filtered one.
-}
preGroupedRowModel : Config row -> State -> RowModel row -> RowModel row
preGroupedRowModel =
    filteredRowModel



-- AGGREGATION


{-| The aggregation function a column with no
[`withAggregationFn`](#withAggregationFn) gets: `sum` for a numeric column,
`extent` for a date column, none for anything else. The kind is read off the
first flat row of the row model handed in.
-}
getAutoAggregationFn : Config row -> RowModel row -> String -> Maybe AggregationFn
getAutoAggregationFn =
    Aggregation.getAutoAggregationFn


{-| The aggregation function of a column: its own, or the automatic one.
-}
getAggregationFn : Config row -> RowModel row -> String -> Maybe AggregationFn
getAggregationFn =
    Aggregation.getAggregationFn


{-| Aggregate one column over the rows of a row model, at the column's own
[`withMaxAggregationDepth`](#withMaxAggregationDepth). TanStack's
`column.getAggregationValue()`.
-}
aggregationValue : Config row -> RowModel row -> String -> Value
aggregationValue =
    Aggregation.aggregationValue


{-| Aggregate one column over a chosen row list and depth, TanStack's
`column.getAggregationValue({ rows, maxDepth })`. Use it for footers and
summaries that the grouped row model does not produce, for example the total
of a column over every filtered row. The row model is only there to resolve
an automatic aggregation function from the column's values; pass the core or
filtered model. `maxDepth` stops the descent into sub-rows; `Nothing` means
the column's own `maxAggregationDepth`.
-}
aggregationValueOf :
    Config row
    -> RowModel row
    -> String
    -> { maxDepth : Int, rows : List (Row row) }
    -> Value
aggregationValueOf =
    Aggregation.aggregationValueOf


{-| Is this cell an aggregated one? True on a group row for a column that is
neither the row's own grouping column nor itself grouped, and that has an
aggregation function.
-}
cellIsAggregated : Config row -> RowModel row -> State -> Row row -> String -> Bool
cellIsAggregated =
    Aggregation.cellIsAggregated



-- EXPANDED STATE


{-| The row model expansion runs on: the sorted one.
-}
preExpandedRowModel : Config row -> State -> RowModel row -> RowModel row
preExpandedRowModel =
    sortedRowModel


{-| Can this row expand? [`withRowCanExpand`](#withRowCanExpand) wins,
otherwise `Config.enableExpanding` has to be on and the row needs sub-rows.
-}
getCanExpand : Config row -> Row row -> Bool
getCanExpand =
    Expanding.rowCanExpand


{-| Is this row expanded? [`withIsRowExpanded`](#withIsRowExpanded) wins,
otherwise `State.expanded` decides.
-}
getIsExpanded : Config row -> State -> Row row -> Bool
getIsExpanded =
    Expanding.rowIsExpanded


{-| Is every ancestor of this row expanded? The row itself is not considered.
-}
getIsAllParentsExpanded : Config row -> State -> RowModel row -> Row row -> Bool
getIsAllParentsExpanded =
    Expanding.getIsAllParentsExpanded


{-| Can any row of this row model expand? TanStack reads the pre-pagination
row model here, so controls can reflect rows that are not on this page.
-}
getCanSomeRowsExpand : Config row -> RowModel row -> Bool
getCanSomeRowsExpand =
    Expanding.getCanSomeRowsExpand


{-| Is any row expanded? `True` for [`expandAll`](#expandAll) and for a
non-empty [`expandedIds`](#expandedIds) set; it does not check that the ids
still exist in the data, which is what TanStack's `getIsSomeRowsExpanded`
does too.
-}
getIsSomeRowsExpanded : State -> Bool
getIsSomeRowsExpanded =
    Expanding.getIsSomeRowsExpanded


{-| Is every expandable row of this row model expanded? An empty
`State.expanded` is `False`, and so is one whose ids match no expandable row.
-}
getIsAllRowsExpanded : Config row -> State -> RowModel row -> Bool
getIsAllRowsExpanded =
    Expanding.getIsAllRowsExpanded


{-| The deepest expanded row id, counted in `.`-separated segments.
-}
getExpandedDepth : Config row -> State -> RowModel row -> Int
getExpandedDepth =
    Expanding.getExpandedDepth


{-| Expand or collapse one row. `Nothing` toggles it. Expanding a row that
cannot expand and any request that matches the current state are no-ops;
collapsing always applies, so a stale id can be cleaned up.

The row model materialises [`expandAll`](#expandAll) into the ids of the rows
that can expand before the change lands. Pass the pre-expanded row model
(the sorted row model, or whatever [`preExpandedRowModel`](#preExpandedRowModel)
gives you), so group rows are included when grouping is on.

-}
toggleExpanded : Config row -> RowModel row -> Row row -> Maybe Bool -> State -> State
toggleExpanded =
    Expanding.toggleExpanded


{-| Expand or collapse every row. `Nothing` toggles on
[`getIsAllRowsExpanded`](#getIsAllRowsExpanded).
-}
toggleAllRowsExpanded : Config row -> RowModel row -> Maybe Bool -> State -> State
toggleAllRowsExpanded =
    Expanding.toggleAllRowsExpanded


{-| Replace `State.expanded`.
-}
setExpanded : Expanded -> State -> State
setExpanded =
    Expanding.setExpanded


{-| Collapse everything: `State.expanded` back to no ids.
-}
resetExpanded : State -> State
resetExpanded =
    Expanding.resetExpanded



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
Pinning removes the row id from the other edge first, so a row is never in
both lists. Whether pinned rows are drawn from the whole data set or only
the current page is `Config.keepPinnedRows`, read by [`topRows`](#topRows)
and [`bottomRows`](#bottomRows). Use [`pinRowWith`](#pinRowWith) to pin a
row's parents or children along with it.
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



-- PHASE 6


{-| The cell span index of the rows a caller renders. Build it with
[`cellSpanIndex`](#cellSpanIndex) and read it with
[`cellRowSpan`](#cellRowSpan), [`cellColSpan`](#cellColSpan), and
[`cellIsCovered`](#cellIsCovered).
-}
type alias CellSpanIndex =
    Types.CellSpanIndex


{-| What a `withSpanRowsWhen` predicate is given for each candidate row. The
run is anchored: `anchorRow` is the row whose cell renders the merged
content, and every later row of the run is tested against it.
-}
type alias RowSpanContext row =
    Types.RowSpanContext row


{-| Allow or forbid cell spanning for the whole table. `False` makes every
cell report a span of `1` and builds no span index.
-}
withCellSpanning : Bool -> Config row -> Config row
withCellSpanning =
    Config.withCellSpanning


{-| Turn one column off for cell spanning even when the table allows it.
-}
withEnableCellSpanning : Bool -> Column row -> Column row
withEnableCellSpanning =
    Column.withEnableCellSpanning


{-| Merge adjacent rows whose value for this column is equal into one
vertically spanning cell. `Null` never merges under this comparison; use
[`withSpanRowsWhen`](#withSpanRowsWhen) to opt in.
-}
withSpanRows : Column row -> Column row
withSpanRows =
    Column.withSpanRows


{-| Decide per candidate row whether it joins the vertical run anchored at
`anchorRow`.
-}
withSpanRowsWhen : (RowSpanContext row -> Bool) -> Column row -> Column row
withSpanRowsWhen =
    Column.withSpanRowsWhen


{-| Make this column's cell span that many columns in the given row, counted
in render order. A span is clamped to the end of the cell's pinned region, so
it never crosses the left, center, or right boundary.
-}
withSpanColumns : (Row row -> Int) -> Column row -> Column row
withSpanColumns =
    Column.withSpanColumns


{-| The stand-in for `Infinity` in a [`withSpanColumns`](#withSpanColumns)
callback: "the rest of my region".
-}
spanAllColumns : Int
spanAllColumns =
    CellSpanning.spanAllColumns


{-| Does this column take part in cell spanning? A column opting out wins
over the table option.
-}
columnCanSpan : Config row -> Column row -> Bool
columnCanSpan =
    CellSpanning.canSpan


{-| Build the span index of the rows a caller renders. Pass the row model you
render, which is normally [`paginatedRowModel`](#paginatedRowModel); row
pinning is read off the state.
-}
cellSpanIndex : Config row -> State -> RowModel row -> CellSpanIndex
cellSpanIndex =
    CellSpanning.spanIndex


{-| The row ids the index was built from, in render order.
-}
cellSpanIndexRowIds : CellSpanIndex -> List String
cellSpanIndexRowIds =
    CellSpanning.spanIndexRowIds


{-| The vertical runs per column id, indexed by render-order row position.
Only columns with at least one run longer than one row appear; a missing
column means every cell in it spans exactly one row.
-}
cellSpanIndexRowSpans : CellSpanIndex -> Dict String (List Int)
cellSpanIndexRowSpans =
    CellSpanning.spanIndexRowSpans


{-| How many rows this cell spans: `1` when it does not span, and `0` when a
spanning cell above covers it. Never render a `0`; skip the cell instead.
-}
cellRowSpan : CellSpanIndex -> Cell -> Int
cellRowSpan =
    CellSpanning.cellRowSpan


{-| How many columns this cell spans: `1` when it does not span, and `0` when
another cell's column span covers it.
-}
cellColSpan : CellSpanIndex -> Cell -> Int
cellColSpan =
    CellSpanning.cellColSpan


{-| Does another cell's span cover this cell? Covered cells carry no content
of their own and must not be rendered.
-}
cellIsCovered : CellSpanIndex -> Cell -> Bool
cellIsCovered =
    CellSpanning.cellIsCovered


{-| One rectangular cell selection, stored as its two defining corners. The
anchor stays put while the focus corner moves during a shift-extend or a
drag, so the pair carries more than a normalized rectangle would. Build one
with [`cellRange`](#cellRange).
-}
type alias CellSelectionRange =
    Types.CellSelectionRange


{-| How a range changes the selection the ranges before it produced.
-}
type alias CellSelectionOperation =
    Types.CellSelectionOperation


{-| Whether a write replaces the selection, adds a rectangle, or subtracts
one.
-}
type alias CellSelectionMode =
    Types.CellSelectionMode


{-| A range resolved into inclusive display-order indexes. Rows are positions
in [`rowsInDisplayOrder`](#rowsInDisplayOrder); columns are positions in the
visible leaf columns in render order.
-}
type alias CellSelectionBounds =
    Types.CellSelectionBounds


{-| Which sides of a selected cell sit on the outer boundary of the
selection, for drawing a spreadsheet-style outline.
-}
type alias CellSelectionEdges =
    Types.CellSelectionEdges


{-| One step of keyboard navigation.
-}
type alias CellDirection =
    Types.CellDirection


{-| The two row models cell selection reads: `prePaginated` fixes the
display-order indexes a range resolves against, so a range spans pages, and
`current` is the page a caller renders, which bounds keyboard navigation and
cell spanning. Without pagination both are the same model.
-}
type alias SelectionRows row =
    Types.SelectionRows row


{-| A range that adds its rectangle to the selection.
-}
includeCells : CellSelectionOperation
includeCells =
    Types.IncludeCells


{-| A range that subtracts its rectangle from the selection.
-}
excludeCells : CellSelectionOperation
excludeCells =
    Types.ExcludeCells


{-| Replace the whole selection with this rectangle.
-}
replaceSelection : CellSelectionMode
replaceSelection =
    Types.ReplaceSelection


{-| Add this rectangle alongside the existing ranges.
-}
includeSelection : CellSelectionMode
includeSelection =
    Types.IncludeSelection


{-| Subtract this rectangle from the existing ranges.
-}
excludeSelection : CellSelectionMode
excludeSelection =
    Types.ExcludeSelection


{-| Move or extend one row up.
-}
cellUp : CellDirection
cellUp =
    Types.CellUp


{-| Move or extend one row down.
-}
cellDown : CellDirection
cellDown =
    Types.CellDown


{-| Move or extend one column left.
-}
cellLeft : CellDirection
cellLeft =
    Types.CellLeft


{-| Move or extend one column right.
-}
cellRight : CellDirection
cellRight =
    Types.CellRight


{-| Allow or forbid cell selection for the whole table.
-}
withCellSelection : Bool -> Config row -> Config row
withCellSelection =
    Config.withCellSelection


{-| Decide per cell whether it can be selected. The predicate replaces the
boolean, exactly like TanStack's `enableCellSelection` in its function form.
-}
withCellSelectionWhen : (Cell -> Bool) -> Config row -> Config row
withCellSelectionWhen =
    Config.withCellSelectionWhen


{-| Allow or forbid extending a cell selection into a range, which is what
shift-click and drag do.
-}
withCellRangeSelection : Bool -> Config row -> Config row
withCellRangeSelection =
    Config.withCellRangeSelection


{-| Allow or forbid adding and subtracting further rectangles, which is what
ctrl-click and meta-click do.
-}
withMultiCellRangeSelection : Bool -> Config row -> Config row
withMultiCellRangeSelection =
    Config.withMultiCellRangeSelection


{-| Allow or forbid selecting the cells of one column.
-}
withEnableCellSelection : Bool -> Column row -> Column row
withEnableCellSelection =
    Column.withEnableCellSelection


{-| A range from its two corners, taken as an inclusion:
`cellRange anchorRowId anchorColumnId focusRowId focusColumnId`.
-}
cellRange : String -> String -> String -> String -> CellSelectionRange
cellRange =
    CellSelection.cellRange


{-| Replace the whole `cellSelection` slice.
-}
setCellSelection : List CellSelectionRange -> State -> State
setCellSelection =
    CellSelection.setCellSelection


{-| Drop every range. This is TanStack's `resetCellSelection(table, true)`;
there is no separate `resetCellSelection` here because the feature default
is the empty list.
-}
clearCellSelection : State -> State
clearCellSelection =
    CellSelection.clearCellSelection


{-| Select a rectangle, replacing the selection.
-}
selectCellRange : CellSelectionRange -> State -> State
selectCellRange =
    CellSelection.selectRange


{-| Select a rectangle with replace, include, or exclude semantics.
-}
selectCellRangeWith : CellSelectionMode -> CellSelectionRange -> State -> State
selectCellRangeWith =
    CellSelection.selectRangeWith


{-| Select every selectable cell as one range.
-}
selectAllCells : Config row -> SelectionRows row -> State -> State
selectAllCells =
    CellSelection.selectAll


{-| Collapse the selection to a single cell at the given coordinates.
-}
setFocusedCell : String -> String -> State -> State
setFocusedCell =
    CellSelection.setFocusedCell


{-| Start a selection at one cell, replacing whatever was selected. This is
the state half of the `mousedown` handler with no modifier key.
-}
selectCell : Config row -> Cell -> State -> State
selectCell =
    CellSelection.selectCell


{-| Move the active range's focus corner to this cell, keeping its anchor and
its operation. This is the state half of a shift-`mousedown` and of a drag's
`mouseenter`. With no active range, or with
[`withCellRangeSelection`](#withCellRangeSelection) off, it selects the cell
instead.
-}
extendCellSelectionTo : Config row -> Cell -> State -> State
extendCellSelectionTo =
    CellSelection.extendSelectionTo


{-| Add a rectangle at this cell alongside the existing ranges, subtracting
instead when the cell is already selected. This is the state half of a ctrl-
or meta-`mousedown`. With
[`withMultiCellRangeSelection`](#withMultiCellRangeSelection) off, it selects
the cell instead.
-}
toggleCellSelection : Config row -> SelectionRows row -> Cell -> State -> State
toggleCellSelection =
    CellSelection.toggleSelection


{-| Move the selection one step, collapsing it to a single cell. Columns that
cannot be selected are skipped over, and a merged cell is one stop. With
nothing selected this selects the first selectable cell.
-}
moveCellSelection : Config row -> SelectionRows row -> CellDirection -> State -> State
moveCellSelection =
    CellSelection.moveSelection


{-| Extend the active range one step, keeping its anchor fixed.
-}
extendCellSelection : Config row -> SelectionRows row -> CellDirection -> State -> State
extendCellSelection =
    CellSelection.extendSelection


{-| Can this cell currently be selected? A column opting out wins over the
table option.
-}
cellCanSelect : Config row -> Cell -> Bool
cellCanSelect =
    CellSelection.canSelect


{-| Does this cell fall inside the final positive selection?
-}
cellIsSelected : Config row -> State -> SelectionRows row -> Cell -> Bool
cellIsSelected =
    CellSelection.isSelected


{-| Is this cell the active cell, the anchor of the most recent range? An
exclusion's active cell is focused even though it is not selected.
-}
cellIsFocused : State -> Cell -> Bool
cellIsFocused =
    CellSelection.isFocused


{-| `0` for the focused cell and `-1` otherwise, for a roving tabindex.
-}
cellTabIndex : State -> Cell -> Int
cellTabIndex =
    CellSelection.tabIndex


{-| Which sides of this cell sit on the outer boundary of the selection. All
four are `False` when the cell is not selected.
-}
cellSelectionEdges : Config row -> State -> SelectionRows row -> Cell -> CellSelectionEdges
cellSelectionEdges =
    CellSelection.edges


{-| The active cell: the anchor of the most recent range.
-}
focusedCell : Config row -> State -> SelectionRows row -> Maybe Cell
focusedCell =
    CellSelection.focusedCell


{-| The final positive selection as disjoint, inclusive display-order index
rectangles, after every include and exclude is applied. A range whose corners
no longer resolve is omitted rather than clamped, so it contributes nothing
while staying in state.
-}
cellSelectionBounds : Config row -> State -> SelectionRows row -> List CellSelectionBounds
cellSelectionBounds =
    CellSelection.selectionBounds


{-| The merged-cell rectangles of the rendered rows, in the same index space.
Selection rectangles grow to enclose these, so a merged cell is always
entirely selected or entirely unselected.
-}
cellSelectionMergeBounds : Config row -> State -> SelectionRows row -> List CellSelectionBounds
cellSelectionMergeBounds =
    CellSelection.mergeBounds


{-| The render-order index of every visible column id.
-}
cellSelectionColumnIndexes : Config row -> State -> Dict String Int
cellSelectionColumnIndexes =
    CellSelection.columnIndexes


{-| The unique ids of all selected cells, in row-major order. Cells another
cell's span covers are skipped, so the ids match what renders.
-}
selectedCellIds : Config row -> State -> SelectionRows row -> List String
selectedCellIds =
    CellSelection.selectedCellIds


{-| How many cells are selected. A merged cell counts once.
-}
selectedCellCount : Config row -> State -> SelectionRows row -> Int
selectedCellCount =
    CellSelection.selectedCellCount


{-| Each final positive region's values as a row-major grid, indexed as
region, then row, then column. Covered cells keep their values so the grid
stays rectangular; serializing it is the caller's job.
-}
selectedCellRangesData : Config row -> State -> SelectionRows row -> List (List (List Value))
selectedCellRangesData =
    CellSelection.selectedRangesData


{-| The ids of all rows the selection intersects.
-}
cellSelectionRowIds : Config row -> State -> SelectionRows row -> List String
cellSelectionRowIds =
    CellSelection.rowIds


{-| The ids of all columns the selection intersects.
-}
cellSelectionColumnIds : Config row -> State -> SelectionRows row -> List String
cellSelectionColumnIds =
    CellSelection.columnIds


{-| The overlap of two rectangles, or `Nothing` when they are disjoint.
-}
intersectCellSelectionBounds : CellSelectionBounds -> CellSelectionBounds -> Maybe CellSelectionBounds
intersectCellSelectionBounds =
    CellSelectionGeometry.intersect


{-| The parts of the first rectangle the second does not cover, as up to four
disjoint rectangles.
-}
subtractCellSelectionBounds : CellSelectionBounds -> CellSelectionBounds -> List CellSelectionBounds
subtractCellSelectionBounds =
    CellSelectionGeometry.subtract


{-| Add a rectangle to a disjoint set, keeping the set disjoint.
-}
addCellSelectionBounds : List CellSelectionBounds -> CellSelectionBounds -> List CellSelectionBounds
addCellSelectionBounds =
    CellSelectionGeometry.add


{-| Fuse rectangles that share a full side into one, to a fixed point.
-}
mergeAdjacentCellSelectionBounds : List CellSelectionBounds -> List CellSelectionBounds
mergeAdjacentCellSelectionBounds =
    CellSelectionGeometry.mergeAdjacent


{-| Grow a rectangle until it fully contains every merged-cell rectangle it
touches.
-}
expandCellSelectionBounds : CellSelectionBounds -> List CellSelectionBounds -> CellSelectionBounds
expandCellSelectionBounds =
    CellSelectionGeometry.expand


{-| Run ordered include and exclude operations, giving the final positive
selection as disjoint rectangles.
-}
applyCellSelectionBoundsOperations : List ( CellSelectionOperation, CellSelectionBounds ) -> List CellSelectionBounds
applyCellSelectionBoundsOperations =
    CellSelectionGeometry.applyOperations
