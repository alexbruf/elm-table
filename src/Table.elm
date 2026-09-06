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
    -- Phase 3 and Phase 4 are complete; phase 5 appends below.
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

Grouping, aggregation, and expansion. The grouped row model replaces the rows
with one group row per distinct value of every column in `State.grouping`,
recursively; the expanded row model splices the sub-rows of the expanded rows
back into the row list.

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


## Expanded state

@docs preExpandedRowModel
@docs getCanExpand, getIsExpanded, getIsAllParentsExpanded
@docs getCanSomeRowsExpand, getIsSomeRowsExpanded, getIsAllRowsExpanded, getExpandedDepth
@docs toggleExpanded, toggleAllRowsExpanded, setExpanded, resetExpanded


# Phase 5

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Set exposing (Set)
import Table.AggregationFn exposing (AggregationFn)
import Table.FilterFn exposing (FilterFn)
import Table.Internal.Aggregation as Aggregation
import Table.Internal.Column as Column
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
`column.getAggregationValue({ rows, maxDepth })`. The row model is only there
to resolve an automatic aggregation function.
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


{-| Is any row expanded? [`expandAll`](#expandAll) counts.
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
that can expand before the change lands.

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
