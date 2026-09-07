---
title: Features API
id: reference/features-api
---

TanStack's Features API Reference lists the feature objects you register on a table, the built-in function registries, and the state types each feature owns. elm-table has no feature registry: every feature is compiled into the package and stays inert until its slice of [`State`](/reference/module/Table#State) is non-empty or its stage is called. So each `*Feature` variable maps to a group of functions rather than to a value. This page maps TanStack's entries onto ours; full signatures and doc comments live on the generated [`Table` module page](/reference/module/Table) and the three function modules.

## Feature registry and core features

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `stockFeatures` | — | Nothing to register. Every feature is always available. |
| `coreFeatures` | — | Same reason. |
| `coreTablesFeature` | [`config`](/reference/module/Table#config), [`initialState`](/reference/module/Table#initialState) | See the [Table API](/reference/table-api). |
| `coreColumnsFeature` | [`column`](/reference/module/Table#column), [`group`](/reference/module/Table#group), [`display`](/reference/module/Table#display) and the column readers | See the [Column API](/reference/column-api). |
| `coreRowsFeature` | the `row*` readers and [`getValue`](/reference/module/Table#getValue) | See the [Row API](/reference/row-api). |
| `coreRowModelsFeature` | [`rows`](/reference/module/Table#rows) and the six stage functions | See [Row Models](/guide/row-models). |
| `coreCellsFeature` | [`getAllCells`](/reference/module/Table#getAllCells), [`visibleCells`](/reference/module/Table#visibleCells) | See the [Cell API](/reference/cell-api). |
| `coreHeadersFeature` | [`headerGroups`](/reference/module/Table#headerGroups) and the `header*` readers | See the [Header API](/reference/header-api). |

## Cell spanning

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `cellSpanningFeature` | [`cellSpanIndex`](/reference/module/Table#cellSpanIndex), [`cellRowSpan`](/reference/module/Table#cellRowSpan), [`cellColSpan`](/reference/module/Table#cellColSpan), [`cellIsCovered`](/reference/module/Table#cellIsCovered), [`columnCanSpan`](/reference/module/Table#columnCanSpan) | Turned on with [`withCellSpanning`](/reference/module/Table#withCellSpanning); per column with [`withSpanRows`](/reference/module/Table#withSpanRows), [`withSpanRowsWhen`](/reference/module/Table#withSpanRowsWhen), [`withSpanColumns`](/reference/module/Table#withSpanColumns), [`withEnableCellSpanning`](/reference/module/Table#withEnableCellSpanning). |

There is no state slice: spans are derived from the rows you render. The index is an explicit value, [`CellSpanIndex`](/reference/module/Table#CellSpanIndex), because nothing is memoized. See [Cell Spanning](/guide/cell-spanning).

## Column filtering

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `columnFilteringFeature` | [`filteredRowModel`](/reference/module/Table#filteredRowModel) and the column-filter queries | [`setColumnFilter`](/reference/module/Table#setColumnFilter), [`setColumnFilters`](/reference/module/Table#setColumnFilters), [`resetColumnFilters`](/reference/module/Table#resetColumnFilters), [`getCanFilter`](/reference/module/Table#getCanFilter), [`getIsFiltered`](/reference/module/Table#getIsFiltered), [`getFilterValue`](/reference/module/Table#getFilterValue), [`getFilterIndex`](/reference/module/Table#getFilterIndex). |
| `ColumnFilter` | [`ColumnFilter`](/reference/module/Table#ColumnFilter) | `{ id : String, value : Value }`. TanStack's `value` is `unknown`. |
| `ColumnFiltersState` | `State.columnFilters : List ColumnFilter` | Same list, same order. |
| `FilterFn` | [`FilterFn`](/reference/module/Table-FilterFn#FilterFn) | Carries `filter`, `resolveFilterValue`, `resolveDataValue`, and `autoRemove`, like TanStack's created filter fn. |
| `FilterFns` | — | No registry. A filter function is passed as a value with [`withFilterFn`](/reference/module/Table#withFilterFn), or as a row predicate with [`withCustomFilter`](/reference/module/Table#withCustomFilter). |
| `FilterFnOption` | — | Same reason. No filter function set means auto; [`getAutoFilterFn`](/reference/module/Table#getAutoFilterFn) picks it and [`getFilterFn`](/reference/module/Table#getFilterFn) resolves it. |
| `FilterMeta` | — | No per-row filter meta. Ranking a fuzzy match is the caller's job; see [Fuzzy Filtering](/guide/fuzzy-filtering). |
| `BuiltInFilterFn` | the values of [`Table.FilterFn`](/reference/module/Table-FilterFn) | Names below. |

See [Column Filtering](/guide/column-filtering).

## Column faceting

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `columnFacetingFeature` | [`facetedRowModel`](/reference/module/Table#facetedRowModel), [`facetedUniqueValues`](/reference/module/Table#facetedUniqueValues), [`facetedMinMax`](/reference/module/Table#facetedMinMax), [`globalFacetKey`](/reference/module/Table#globalFacetKey) | No state slice. Facets are computed from the row model you pass in. |

See [Faceting](/guide/column-faceting).

## Row aggregation

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `rowAggregationFeature` | [`aggregationValue`](/reference/module/Table#aggregationValue), [`aggregationValueOf`](/reference/module/Table#aggregationValueOf), [`cellIsAggregated`](/reference/module/Table#cellIsAggregated), [`rowAggregatedValues`](/reference/module/Table#rowAggregatedValues) | Values are computed by [`groupedRowModel`](/reference/module/Table#groupedRowModel) and stored on the group row. |
| `AggregationFns` | — | No registry. Set one per column with [`withAggregationFn`](/reference/module/Table#withAggregationFn). |
| `AggregationFnOption` | — | Same reason. Unset means auto: [`getAutoAggregationFn`](/reference/module/Table#getAutoAggregationFn) picks `sum` for numbers and `extent` for dates, and [`getAggregationFn`](/reference/module/Table#getAggregationFn) resolves it. TanStack's keyed list form, which produces an object of several results, has no counterpart. |
| `AggregationResult` | [`Value`](/reference/module/Table-Value#Value) | One `Value` per column, never a keyed object. |
| `AggregationContext` | — | An aggregation is `List Value -> Value`. It gets the values, not the table. |
| `AggregationValueContext` | — | Same reason. |
| `AggregationValueResult` | — | There is no "handled" marker, because there is no column-level value override to signal it from. |
| `AggregationMergeContext` | — | A merge is `List Value -> Value` over the child results; see [`withMerge`](/reference/module/Table-AggregationFn#withMerge). |
| `AggregationFnDef` | [`AggregationFn`](/reference/module/Table-AggregationFn#AggregationFn) | Opaque: a fold plus an optional merge. |
| `AggregationFnDescriptor` | — | Only needed to key entries of a multiple result, which has no counterpart. |
| `constructAggregationFn` | [`custom`](/reference/module/Table-AggregationFn#custom) | Add a merge with [`withMerge`](/reference/module/Table-AggregationFn#withMerge). |
| `BuiltInAggregationFn` | the values of [`Table.AggregationFn`](/reference/module/Table-AggregationFn) | Names below. |

How far down an aggregation reads is [`withMaxAggregationDepth`](/reference/module/Table#withMaxAggregationDepth) on the column. See [Aggregation](/guide/aggregation).

## Column grouping

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `columnGroupingFeature` | [`groupedRowModel`](/reference/module/Table#groupedRowModel) and the grouping queries | [`toggleGrouping`](/reference/module/Table#toggleGrouping), [`setGrouping`](/reference/module/Table#setGrouping), [`resetGrouping`](/reference/module/Table#resetGrouping), [`getCanGroup`](/reference/module/Table#getCanGroup), [`getIsGrouped`](/reference/module/Table#getIsGrouped), [`getGroupedIndex`](/reference/module/Table#getGroupedIndex), [`preGroupedRowModel`](/reference/module/Table#preGroupedRowModel). |
| `GroupingState` | `State.grouping : List String` | Column ids, outermost first. |
| `GroupingColumnMode` | [`GroupedColumnMode`](/reference/module/Table#GroupedColumnMode) | The three variants are [`groupedColumnsReorder`](/reference/module/Table#groupedColumnsReorder), [`groupedColumnsRemove`](/reference/module/Table#groupedColumnsRemove), [`groupedColumnsIgnore`](/reference/module/Table#groupedColumnsIgnore). It is not in TanStack's nav list, but it is the type behind `groupedColumnMode`. |

See [Grouping](/guide/grouping).

## Column ordering

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `columnOrderingFeature` | [`setColumnOrder`](/reference/module/Table#setColumnOrder), [`resetColumnOrder`](/reference/module/Table#resetColumnOrder), [`orderColumns`](/reference/module/Table#orderColumns), [`orderGroupedColumns`](/reference/module/Table#orderGroupedColumns), [`columnIndex`](/reference/module/Table#columnIndex), [`columnIsFirst`](/reference/module/Table#columnIsFirst), [`columnIsLast`](/reference/module/Table#columnIsLast) | Ordering composes in one place, `orderColumns`. |
| `ColumnOrderState` | `State.columnOrder : List String` | Column ids. Unlisted columns keep definition order behind the listed ones. |

See [Column Ordering](/guide/column-ordering).

## Column pinning

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `columnPinningFeature` | [`pinColumn`](/reference/module/Table#pinColumn), [`setColumnPinning`](/reference/module/Table#setColumnPinning), [`resetColumnPinning`](/reference/module/Table#resetColumnPinning), [`columnCanPin`](/reference/module/Table#columnCanPin), [`columnIsPinned`](/reference/module/Table#columnIsPinned), [`columnPinnedIndex`](/reference/module/Table#columnPinnedIndex), and the per-region column, header, and cell lists |  |
| `ColumnPinningState` | [`ColumnPinning`](/reference/module/Table#ColumnPinning) | `{ left : List String, right : List String }`. TanStack's fields are `start` and `end`. |
| `ColumnPinningPosition` | [`ColumnPinPosition`](/reference/module/Table#ColumnPinPosition) | [`pinnedLeft`](/reference/module/Table#pinnedLeft), [`pinnedRight`](/reference/module/Table#pinnedRight), [`columnUnpinned`](/reference/module/Table#columnUnpinned) replace `'start' \| 'end' \| false`. |

Which slice a query is about is a [`ColumnRegion`](/reference/module/Table#ColumnRegion) argument rather than an optional position, with [`allColumnsRegion`](/reference/module/Table#allColumnsRegion) standing for TanStack's absent argument. See [Column Pinning](/guide/column-pinning).

## Column resizing

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `columnResizingFeature` | — | No drag session. A resize is a pointer handler in your code that ends in [`setColumnSize`](/reference/module/Table#setColumnSize); the committed width lives in `State.columnSizing`. |
| `columnResizingState` | — | Nothing to store between pointer events. Keep the drag start and delta in your own model. |
| `ColumnResizeMode` | — | You decide whether your handler writes on every move or only on release. |
| `ColumnResizeDirection` | — | No text-direction handling; the sign of the delta is yours. |

See [Column Resizing](/guide/column-resizing).

## Column sizing

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `columnSizingFeature` | [`getColumnSize`](/reference/module/Table#getColumnSize), [`getColumnStart`](/reference/module/Table#getColumnStart), [`getColumnAfter`](/reference/module/Table#getColumnAfter), [`getHeaderSize`](/reference/module/Table#getHeaderSize), [`getHeaderStart`](/reference/module/Table#getHeaderStart), [`totalSize`](/reference/module/Table#totalSize), [`leftTotalSize`](/reference/module/Table#leftTotalSize), [`centerTotalSize`](/reference/module/Table#centerTotalSize), [`rightTotalSize`](/reference/module/Table#rightTotalSize), [`setColumnSize`](/reference/module/Table#setColumnSize), [`setColumnSizing`](/reference/module/Table#setColumnSizing), [`resetColumnSize`](/reference/module/Table#resetColumnSize), [`resetColumnSizing`](/reference/module/Table#resetColumnSizing) |  |
| `ColumnSizingState` | `State.columnSizing : Dict String Float` | Column id to committed width. |

Defaults are a [`SizeDefaults`](/reference/module/Table#SizeDefaults) record set with [`withDefaultColumn`](/reference/module/Table#withDefaultColumn), and per column with [`withSize`](/reference/module/Table#withSize), [`withMinSize`](/reference/module/Table#withMinSize), [`withMaxSize`](/reference/module/Table#withMaxSize). See [Column Sizing](/guide/column-sizing).

## Column visibility

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `columnVisibilityFeature` | [`columnIsVisible`](/reference/module/Table#columnIsVisible), [`columnCanHide`](/reference/module/Table#columnCanHide), [`toggleColumnVisibility`](/reference/module/Table#toggleColumnVisibility), [`setColumnVisibility`](/reference/module/Table#setColumnVisibility), [`resetColumnVisibility`](/reference/module/Table#resetColumnVisibility), [`toggleAllColumnsVisible`](/reference/module/Table#toggleAllColumnsVisible), [`isAllColumnsVisible`](/reference/module/Table#isAllColumnsVisible), [`isSomeColumnsVisible`](/reference/module/Table#isSomeColumnsVisible), [`visibleFlatColumns`](/reference/module/Table#visibleFlatColumns), [`visibleLeafColumns`](/reference/module/Table#visibleLeafColumns) |  |
| `ColumnVisibilityState` | `State.columnVisibility : Dict String Bool` | A column absent from the dict is visible. |

See [Column Visibility](/guide/column-visibility).

## Global filtering

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `globalFilteringFeature` | [`setGlobalFilter`](/reference/module/Table#setGlobalFilter), [`resetGlobalFilter`](/reference/module/Table#resetGlobalFilter), [`getCanGlobalFilter`](/reference/module/Table#getCanGlobalFilter), [`getGlobalFilterFn`](/reference/module/Table#getGlobalFilterFn), [`globalAutoFilterFn`](/reference/module/Table#globalAutoFilterFn) | The global filter runs inside [`filteredRowModel`](/reference/module/Table#filteredRowModel). |

The state slice is `State.globalFilter : Value`, and the function is set with [`withGlobalFilterFn`](/reference/module/Table#withGlobalFilterFn). TanStack has no separate global-filter state type in this nav section. See [Global Filtering](/guide/global-filtering).

## Row expanding

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `rowExpandingFeature` | [`expandedRowModel`](/reference/module/Table#expandedRowModel) and the expansion queries | [`toggleExpanded`](/reference/module/Table#toggleExpanded), [`toggleAllRowsExpanded`](/reference/module/Table#toggleAllRowsExpanded), [`setExpanded`](/reference/module/Table#setExpanded), [`resetExpanded`](/reference/module/Table#resetExpanded), [`getCanExpand`](/reference/module/Table#getCanExpand), [`getIsExpanded`](/reference/module/Table#getIsExpanded), [`getIsAllParentsExpanded`](/reference/module/Table#getIsAllParentsExpanded), [`getExpandedDepth`](/reference/module/Table#getExpandedDepth), [`preExpandedRowModel`](/reference/module/Table#preExpandedRowModel). |
| `ExpandedState` | [`Expanded`](/reference/module/Table#Expanded) | [`expandAll`](/reference/module/Table#expandAll) is TanStack's `true`; [`expandedIds`](/reference/module/Table#expandedIds) takes a `Set String` instead of a record of booleans, and [`expandedIdsOf`](/reference/module/Table#expandedIdsOf) reads it back. |

Per-row overrides are [`withRowCanExpand`](/reference/module/Table#withRowCanExpand) and [`withIsRowExpanded`](/reference/module/Table#withIsRowExpanded) on the `Config`. See [Expanding](/guide/expanding).

## Row pagination

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `rowPaginationFeature` | [`paginatedRowModel`](/reference/module/Table#paginatedRowModel) and the page queries | [`setPage`](/reference/module/Table#setPage), [`setPageSize`](/reference/module/Table#setPageSize), [`setPagination`](/reference/module/Table#setPagination), [`firstPage`](/reference/module/Table#firstPage), [`previousPage`](/reference/module/Table#previousPage), [`nextPage`](/reference/module/Table#nextPage), [`lastPage`](/reference/module/Table#lastPage), [`getPageCount`](/reference/module/Table#getPageCount), [`getPageOptions`](/reference/module/Table#getPageOptions), [`getRowCount`](/reference/module/Table#getRowCount), [`getCanPreviousPage`](/reference/module/Table#getCanPreviousPage), [`getCanNextPage`](/reference/module/Table#getCanNextPage), [`getCanLastPage`](/reference/module/Table#getCanLastPage), [`resetPageIndex`](/reference/module/Table#resetPageIndex), [`resetPageSize`](/reference/module/Table#resetPageSize), [`resetPagination`](/reference/module/Table#resetPagination). |
| `PaginationState` | [`Pagination`](/reference/module/Table#Pagination) | `{ pageIndex : Int, pageSize : Int }`. TanStack's `Infinity` page size is [`unlimitedPageSize`](/reference/module/Table#unlimitedPageSize). |

TanStack renames `setPageIndex` here to `setPage`. The counts read the pre-pagination model, [`prePaginationRowModel`](/reference/module/Table#prePaginationRowModel). See [Pagination](/guide/pagination).

## Row pinning

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `rowPinningFeature` | [`pinRow`](/reference/module/Table#pinRow), [`pinRowWith`](/reference/module/Table#pinRowWith), [`setRowPinning`](/reference/module/Table#setRowPinning), [`resetRowPinning`](/reference/module/Table#resetRowPinning), [`getIsRowPinned`](/reference/module/Table#getIsRowPinned), [`getRowPinnedIndex`](/reference/module/Table#getRowPinnedIndex), [`getCanPinRow`](/reference/module/Table#getCanPinRow), [`isSomeRowsPinned`](/reference/module/Table#isSomeRowsPinned), [`isSomeRowsPinnedTop`](/reference/module/Table#isSomeRowsPinnedTop), [`isSomeRowsPinnedBottom`](/reference/module/Table#isSomeRowsPinnedBottom), [`topRows`](/reference/module/Table#topRows), [`bottomRows`](/reference/module/Table#bottomRows), [`centerRows`](/reference/module/Table#centerRows) |  |
| `RowPinningState` | [`RowPinning`](/reference/module/Table#RowPinning) | `{ top : List String, bottom : List String }`, the same shape. |
| `RowPinningPosition` | [`RowPinPosition`](/reference/module/Table#RowPinPosition) | [`pinnedTop`](/reference/module/Table#pinnedTop), [`pinnedBottom`](/reference/module/Table#pinnedBottom), [`rowUnpinned`](/reference/module/Table#rowUnpinned). |

How much of a row's family is pinned along with it is a [`PinRowOptions`](/reference/module/Table#PinRowOptions) record, with [`defaultPinRowOptions`](/reference/module/Table#defaultPinRowOptions) as the starting point. The pinned lists take a [`PinnedRowsSource`](/reference/module/Table#PinnedRowsSource), both the pre-pagination model and the page. See [Row Pinning](/guide/row-pinning).

## Row selection

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `rowSelectionFeature` | [`toggleRowSelected`](/reference/module/Table#toggleRowSelected), [`toggleRowSelectedWith`](/reference/module/Table#toggleRowSelectedWith), [`toggleAllRowsSelected`](/reference/module/Table#toggleAllRowsSelected), [`toggleAllPageRowsSelected`](/reference/module/Table#toggleAllPageRowsSelected), [`deselectAllRows`](/reference/module/Table#deselectAllRows), [`setRowSelection`](/reference/module/Table#setRowSelection), [`resetRowSelection`](/reference/module/Table#resetRowSelection), [`selectRange`](/reference/module/Table#selectRange), [`selectRangeWith`](/reference/module/Table#selectRangeWith), [`canSelectRange`](/reference/module/Table#canSelectRange), and the `getIs*` and `getCan*` queries |  |
| `RowSelectionState` | `State.rowSelection : Set String` | TanStack's `Record<string, true>` is a set of row ids here. Read it with [`selectedRowIds`](/reference/module/Table#selectedRowIds) or [`selectedRowModel`](/reference/module/Table#selectedRowModel). |

Sub-tree state is [`SubRowSelection`](/reference/module/Table#SubRowSelection) with [`noSubRowsSelected`](/reference/module/Table#noSubRowsSelected), [`someSubRowsSelected`](/reference/module/Table#someSubRowsSelected), [`allSubRowsSelected`](/reference/module/Table#allSubRowsSelected), replacing TanStack's `false | 'some' | 'all'`. TanStack's `ToggleSelectedOptions` is [`SelectOptions`](/reference/module/Table#SelectOptions), with [`defaultSelectOptions`](/reference/module/Table#defaultSelectOptions). The shift-click anchor is caller state, so `selectRange` takes the anchor row id. See [Row Selection](/guide/row-selection).

## Row sorting

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `rowSortingFeature` | [`sortedRowModel`](/reference/module/Table#sortedRowModel) and the sorting queries | [`toggleSort`](/reference/module/Table#toggleSort), [`setSorting`](/reference/module/Table#setSorting), [`clearSorting`](/reference/module/Table#clearSorting), [`resetSorting`](/reference/module/Table#resetSorting), [`getCanSort`](/reference/module/Table#getCanSort), [`getCanMultiSort`](/reference/module/Table#getCanMultiSort), [`getIsSorted`](/reference/module/Table#getIsSorted), [`getSortIndex`](/reference/module/Table#getSortIndex), [`getNextSortingOrder`](/reference/module/Table#getNextSortingOrder). |
| `ColumnSort` | [`SortColumn`](/reference/module/Table#SortColumn) | `{ id : String, desc : Bool }`, the same shape under a different name. |
| `SortingState` | `State.sorting : List SortColumn` | Same list, first entry sorted first. |
| `SortDirection` | [`SortDir`](/reference/module/Table#SortDir) | [`sortAsc`](/reference/module/Table#sortAsc) and [`sortDesc`](/reference/module/Table#sortDesc) replace `'asc'` and `'desc'`. [`getIsSorted`](/reference/module/Table#getIsSorted) returns `Maybe SortDir` rather than `false \| 'asc' \| 'desc'`. |
| `SortFn` | [`SortFn`](/reference/module/Table-SortFn#SortFn) | A comparison on two `Value`s, plus an optional `resolveDataValue` normaliser. |
| `SortFns` | — | No registry. Set one per column with [`withSortFn`](/reference/module/Table#withSortFn), or compare whole rows with [`withCustomSort`](/reference/module/Table#withCustomSort). |
| `SortFnOption` | — | Same reason. Unset means auto: [`getAutoSortFn`](/reference/module/Table#getAutoSortFn) picks it and [`getSortFn`](/reference/module/Table#getSortFn) resolves it. |
| `BuiltInSortFn` | the values of [`Table.SortFn`](/reference/module/Table-SortFn) | Names below. |

Where `Null` values land is [`SortUndefined`](/reference/module/Table#SortUndefined), with [`sortNullsFirst`](/reference/module/Table#sortNullsFirst), [`sortNullsLast`](/reference/module/Table#sortNullsLast), [`sortNullsAsMinusOne`](/reference/module/Table#sortNullsAsMinusOne), [`sortNullsAsPlusOne`](/reference/module/Table#sortNullsAsPlusOne). See [Sorting](/guide/sorting).

## Cell selection

TanStack ships a `cellSelectionFeature` but does not list it in this nav section. It is here for completeness.

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `cellSelectionFeature` | [`selectCell`](/reference/module/Table#selectCell), [`toggleCellSelection`](/reference/module/Table#toggleCellSelection), [`selectCellRange`](/reference/module/Table#selectCellRange), [`selectCellRangeWith`](/reference/module/Table#selectCellRangeWith), [`selectAllCells`](/reference/module/Table#selectAllCells), [`setCellSelection`](/reference/module/Table#setCellSelection), [`clearCellSelection`](/reference/module/Table#clearCellSelection), [`setFocusedCell`](/reference/module/Table#setFocusedCell), [`moveCellSelection`](/reference/module/Table#moveCellSelection), [`extendCellSelection`](/reference/module/Table#extendCellSelection), [`extendCellSelectionTo`](/reference/module/Table#extendCellSelectionTo) |  |
| `CellSelectionState` | `State.cellSelection : List CellSelectionRange` | A list of rectangles, each built with [`cellRange`](/reference/module/Table#cellRange). |
| `CellSelectionRange` | [`CellSelectionRange`](/reference/module/Table#CellSelectionRange) | Two corners plus an operation. TanStack's optional `operation` is required here and defaults to [`includeCells`](/reference/module/Table#includeCells). |
| `CellSelectionRangeOperation` | [`CellSelectionOperation`](/reference/module/Table#CellSelectionOperation) | [`includeCells`](/reference/module/Table#includeCells), [`excludeCells`](/reference/module/Table#excludeCells). |
| `CellSelectionRangeMode` | [`CellSelectionMode`](/reference/module/Table#CellSelectionMode) | [`replaceSelection`](/reference/module/Table#replaceSelection), [`includeSelection`](/reference/module/Table#includeSelection), [`excludeSelection`](/reference/module/Table#excludeSelection). |
| `CellSelectionDirection` | [`CellDirection`](/reference/module/Table#CellDirection) | [`cellUp`](/reference/module/Table#cellUp), [`cellDown`](/reference/module/Table#cellDown), [`cellLeft`](/reference/module/Table#cellLeft), [`cellRight`](/reference/module/Table#cellRight). |
| `CellSelectionBounds` | [`CellSelectionBounds`](/reference/module/Table#CellSelectionBounds) | Inclusive display-order indexes. |
| `CellSelectionEdges` | [`CellSelectionEdges`](/reference/module/Table#CellSelectionEdges) | Which sides of a cell sit on the outer boundary. |

The cell queries are on the [Cell API](/reference/cell-api). The reads that resolve a selection take a [`SelectionRows`](/reference/module/Table#SelectionRows).

### Cell selection reads and geometry

Nothing in TanStack's nav list corresponds to these, so they are listed here.

| Value | What it does |
| --- | --- |
| [`focusedCell`](/reference/module/Table#focusedCell) | The active cell, when there is one. |
| [`selectedCellIds`](/reference/module/Table#selectedCellIds) | The ids of every selected cell. |
| [`selectedCellCount`](/reference/module/Table#selectedCellCount) | How many cells are selected. |
| [`selectedCellRangesData`](/reference/module/Table#selectedCellRangesData) | The values of each selected rectangle, row by row, ready for a clipboard copy. |
| [`cellSelectionRowIds`](/reference/module/Table#cellSelectionRowIds) | The row ids the selection touches. |
| [`cellSelectionColumnIds`](/reference/module/Table#cellSelectionColumnIds) | The column ids the selection touches. |
| [`cellSelectionColumnIndexes`](/reference/module/Table#cellSelectionColumnIndexes) | Column id to display-order index. |
| [`cellSelectionBounds`](/reference/module/Table#cellSelectionBounds) | The selection resolved into rectangles of indexes. |
| [`cellSelectionMergeBounds`](/reference/module/Table#cellSelectionMergeBounds) | The same rectangles with spanning cells folded in. |
| [`intersectCellSelectionBounds`](/reference/module/Table#intersectCellSelectionBounds) | The overlap of two rectangles. |
| [`subtractCellSelectionBounds`](/reference/module/Table#subtractCellSelectionBounds) | One rectangle minus another, as a list. |
| [`addCellSelectionBounds`](/reference/module/Table#addCellSelectionBounds) | Add a rectangle to a list without overlapping the others. |
| [`mergeAdjacentCellSelectionBounds`](/reference/module/Table#mergeAdjacentCellSelectionBounds) | Join touching rectangles. |
| [`expandCellSelectionBounds`](/reference/module/Table#expandCellSelectionBounds) | Grow a rectangle until it covers every span it clips. |
| [`applyCellSelectionBoundsOperations`](/reference/module/Table#applyCellSelectionBoundsOperations) | Fold a list of include and exclude rectangles into the final positive area. |
| [`spanAllColumns`](/reference/module/Table#spanAllColumns) | The span value that means "to the end of the region". |
| [`cellSpanIndexRowIds`](/reference/module/Table#cellSpanIndexRowIds) | The row ids a span index was built over. |
| [`cellSpanIndexRowSpans`](/reference/module/Table#cellSpanIndexRowSpans) | The row spans of a span index, keyed by column id. |

See [Cell Selection](/guide/cell-selection).

## Built-in sort functions

TanStack's `sortFns` object. Every name has the same name here, as a value of [`Table.SortFn`](/reference/module/Table-SortFn). Nothing is missing in either direction.

| TanStack `sortFns` | elm-table |
| --- | --- |
| `alphanumeric` | [`SortFn.alphanumeric`](/reference/module/Table-SortFn#alphanumeric) |
| `alphanumericCaseSensitive` | [`SortFn.alphanumericCaseSensitive`](/reference/module/Table-SortFn#alphanumericCaseSensitive) |
| `basic` | [`SortFn.basic`](/reference/module/Table-SortFn#basic) |
| `datetime` | [`SortFn.datetime`](/reference/module/Table-SortFn#datetime) |
| `text` | [`SortFn.text`](/reference/module/Table-SortFn#text) |
| `textCaseSensitive` | [`SortFn.textCaseSensitive`](/reference/module/Table-SortFn#textCaseSensitive) |

The module also exposes what TanStack keeps outside the registry: [`custom`](/reference/module/Table-SortFn#custom) for `constructSortFn`, [`withResolveDataValue`](/reference/module/Table-SortFn#withResolveDataValue) for overriding a built-in's normaliser, [`compare`](/reference/module/Table-SortFn#compare) and [`resolveDataValue`](/reference/module/Table-SortFn#resolveDataValue) for applying one, and [`splitAlphaNumeric`](/reference/module/Table-SortFn#splitAlphaNumeric), which is TanStack's `reSplitAlphaNumeric`.

## Built-in filter functions

TanStack's `filterFns` object. Every name has the same name here, as a value of [`Table.FilterFn`](/reference/module/Table-FilterFn).

| TanStack `filterFns` | elm-table |
| --- | --- |
| `arrIncludes` | [`FilterFn.arrIncludes`](/reference/module/Table-FilterFn#arrIncludes) |
| `arrIncludesAll` | [`FilterFn.arrIncludesAll`](/reference/module/Table-FilterFn#arrIncludesAll) |
| `arrHas` | [`FilterFn.arrHas`](/reference/module/Table-FilterFn#arrHas) |
| `arrIncludesSome` | [`FilterFn.arrIncludesSome`](/reference/module/Table-FilterFn#arrIncludesSome) |
| `between` | [`FilterFn.between`](/reference/module/Table-FilterFn#between) |
| `betweenInclusive` | [`FilterFn.betweenInclusive`](/reference/module/Table-FilterFn#betweenInclusive) |
| `empty` | [`FilterFn.empty`](/reference/module/Table-FilterFn#empty) |
| `endsWith` | [`FilterFn.endsWith`](/reference/module/Table-FilterFn#endsWith) |
| `equals` | [`FilterFn.equals`](/reference/module/Table-FilterFn#equals) |
| `equalsString` | [`FilterFn.equalsString`](/reference/module/Table-FilterFn#equalsString) |
| `equalsStringSensitive` | [`FilterFn.equalsStringSensitive`](/reference/module/Table-FilterFn#equalsStringSensitive) |
| `inDateRange` | [`FilterFn.inDateRange`](/reference/module/Table-FilterFn#inDateRange) |
| `inNumberRange` | [`FilterFn.inNumberRange`](/reference/module/Table-FilterFn#inNumberRange) |
| `includesString` | [`FilterFn.includesString`](/reference/module/Table-FilterFn#includesString) |
| `includesStringSensitive` | [`FilterFn.includesStringSensitive`](/reference/module/Table-FilterFn#includesStringSensitive) |
| `notEmpty` | [`FilterFn.notEmpty`](/reference/module/Table-FilterFn#notEmpty) |
| `startsWith` | [`FilterFn.startsWith`](/reference/module/Table-FilterFn#startsWith) |
| `weakEquals` | [`FilterFn.weakEquals`](/reference/module/Table-FilterFn#weakEquals) |

Four more filter functions are exported by TanStack but left out of its `filterFns` object, so they are not part of `BuiltInFilterFn`. All four exist here as ordinary values.

| TanStack export | elm-table |
| --- | --- |
| `filterFn_greaterThan` | [`FilterFn.greaterThan`](/reference/module/Table-FilterFn#greaterThan) |
| `filterFn_greaterThanOrEqualTo` | [`FilterFn.greaterThanOrEqualTo`](/reference/module/Table-FilterFn#greaterThanOrEqualTo) |
| `filterFn_lessThan` | [`FilterFn.lessThan`](/reference/module/Table-FilterFn#lessThan) |
| `filterFn_lessThanOrEqualTo` | [`FilterFn.lessThanOrEqualTo`](/reference/module/Table-FilterFn#lessThanOrEqualTo) |

The rest of the module matches TanStack's `constructFilterFn` and the four parts every filter function carries: [`custom`](/reference/module/Table-FilterFn#custom), [`withResolveFilterValue`](/reference/module/Table-FilterFn#withResolveFilterValue), [`withResolveDataValue`](/reference/module/Table-FilterFn#withResolveDataValue), [`withAutoRemove`](/reference/module/Table-FilterFn#withAutoRemove), and the appliers [`filter`](/reference/module/Table-FilterFn#filter), [`resolveFilterValue`](/reference/module/Table-FilterFn#resolveFilterValue), [`resolveDataValue`](/reference/module/Table-FilterFn#resolveDataValue), [`autoRemove`](/reference/module/Table-FilterFn#autoRemove), plus [`toDateTimestamp`](/reference/module/Table-FilterFn#toDateTimestamp).

There is no fuzzy filter in either package. TanStack's fuzzy example builds one with an external ranking library; see [Fuzzy Filtering](/guide/fuzzy-filtering).

## Built-in aggregation functions

TanStack's `aggregationFns` object. Every name has the same name here, as a value of [`Table.AggregationFn`](/reference/module/Table-AggregationFn). Nothing is missing in either direction.

| TanStack `aggregationFns` | elm-table |
| --- | --- |
| `sum` | [`AggregationFn.sum`](/reference/module/Table-AggregationFn#sum) |
| `min` | [`AggregationFn.min`](/reference/module/Table-AggregationFn#min) |
| `max` | [`AggregationFn.max`](/reference/module/Table-AggregationFn#max) |
| `extent` | [`AggregationFn.extent`](/reference/module/Table-AggregationFn#extent) |
| `mean` | [`AggregationFn.mean`](/reference/module/Table-AggregationFn#mean) |
| `median` | [`AggregationFn.median`](/reference/module/Table-AggregationFn#median) |
| `unique` | [`AggregationFn.unique`](/reference/module/Table-AggregationFn#unique) |
| `uniqueCount` | [`AggregationFn.uniqueCount`](/reference/module/Table-AggregationFn#uniqueCount) |
| `count` | [`AggregationFn.count`](/reference/module/Table-AggregationFn#count) |
| `first` | [`AggregationFn.first`](/reference/module/Table-AggregationFn#first) |
| `last` | [`AggregationFn.last`](/reference/module/Table-AggregationFn#last) |

Building and applying one: [`custom`](/reference/module/Table-AggregationFn#custom), [`withMerge`](/reference/module/Table-AggregationFn#withMerge), [`aggregate`](/reference/module/Table-AggregationFn#aggregate), [`merge`](/reference/module/Table-AggregationFn#merge).
