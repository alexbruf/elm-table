---
title: Row API
id: reference/row-api
---

TanStack's Row API Reference covers the row object, the row-model factories you register on a table, and the caches that hold their results. elm-table has the same six stages, but each one is a plain function from a row model to a row model, called in order and never cached. This page maps TanStack's entries onto ours; full signatures and doc comments live on the generated [`Table` module page](/reference/module/Table). For prose, see [Row Models](/guide/row-models) and [Rows](/guide/rows).

## Types

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `Row` | [`Row`](/reference/module/Table#Row) | Opaque. Read it with the `row*` functions below. |
| `RowData` | the `row` type variable | Every function is `Table.Row row` for your own record type. No constraint on it. |
| `RowModel` | [`RowModel`](/reference/module/Table#RowModel) | A plain record: `rows`, `flatRows`, `rowsById`. Every stage takes one and returns one. |
| `constructRow` | — | Rows are built by [`coreRowModel`](/reference/module/Table#coreRowModel). There is no single-row constructor. |

## Row-model factories

TanStack's `create*RowModel` functions return a factory that a table calls when a slice of state changes. Ours are the stage functions themselves: you call them in order, or call [`rows`](/reference/module/Table#rows) to run the whole chain. Each stage is skipped by its `manual` flag on the `Config`.

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `createCoreRowModel` | [`coreRowModel`](/reference/module/Table#coreRowModel) | One row per datum, sub-rows resolved, ids assigned. [`coreRowModelFromList`](/reference/module/Table#coreRowModelFromList) is the `List` form. |
| `createFilteredRowModel` | [`filteredRowModel`](/reference/module/Table#filteredRowModel) | Drops the rows that fail the column filters and the global filter. |
| `createSortedRowModel` | [`sortedRowModel`](/reference/module/Table#sortedRowModel) | Sorts every level of the row tree. |
| `createGroupedRowModel` | [`groupedRowModel`](/reference/module/Table#groupedRowModel) | Replaces the rows with group rows. |
| `createExpandedRowModel` | [`expandedRowModel`](/reference/module/Table#expandedRowModel) | Flattens the expanded branches into the row list. |
| `createPaginatedRowModel` | [`paginatedRowModel`](/reference/module/Table#paginatedRowModel) | Keeps only the rows of the current page. |
| `createFacetedRowModel` | [`facetedRowModel`](/reference/module/Table#facetedRowModel) | The rows one column's facets are computed from: every active filter applied except that column's own. |
| `createFacetedMinMaxValues` | [`facetedMinMax`](/reference/module/Table#facetedMinMax) | The smallest and largest numeric value of one column. |
| `createFacetedUniqueValues` | [`facetedUniqueValues`](/reference/module/Table#facetedUniqueValues) | Every distinct value of one column with the number of rows that carry it. |
| `expandRows` | [`expandedRowModel`](/reference/module/Table#expandedRowModel) | TanStack exports the flattening helper separately; here it is only the stage. [`rowsInDisplayOrder`](/reference/module/Table#rowsInDisplayOrder) does the same job for the rendered page when `paginateExpandedRows` is off. |
| `RowModelFns` | — | No fn registry. A sort or filter function is passed as a value, not looked up by name. |
| `CreateRowModels` | — | No registration step. Call the stages you want. |
| `CachedRowModels` | — | No cache. Recompute on each `update`, or keep the row model in your own model if you would rather not. |

The pipeline order is core, filtered, grouped, sorted, expanded, paginated. That matches TanStack, where `preSorted` is the grouped row model.

## The pipeline

| Value | What it returns |
| --- | --- |
| [`rows`](/reference/module/Table#rows) | The whole pipeline over an `Array` of data, in stage order. |
| [`rowsFromList`](/reference/module/Table#rowsFromList) | The `List` form of `rows`. |
| [`coreRowModel`](/reference/module/Table#coreRowModel) | Stage 1, from an `Array`. |
| [`coreRowModelFromList`](/reference/module/Table#coreRowModelFromList) | Stage 1, from a `List`. |
| [`filteredRowModel`](/reference/module/Table#filteredRowModel) | Stage 2. |
| [`groupedRowModel`](/reference/module/Table#groupedRowModel) | Stage 3. |
| [`sortedRowModel`](/reference/module/Table#sortedRowModel) | Stage 4. |
| [`expandedRowModel`](/reference/module/Table#expandedRowModel) | Stage 5. |
| [`paginatedRowModel`](/reference/module/Table#paginatedRowModel) | Stage 6. |
| [`preGroupedRowModel`](/reference/module/Table#preGroupedRowModel) | The model grouping runs on: the filtered one. |
| [`preExpandedRowModel`](/reference/module/Table#preExpandedRowModel) | The model expansion runs on: the sorted one. |
| [`prePaginationRowModel`](/reference/module/Table#prePaginationRowModel) | The model pagination slices: the expanded one. Row counts and page counts read it. |
| [`selectedRowModel`](/reference/module/Table#selectedRowModel) | Keeps only the selected rows. Replaces TanStack's three selected row models. |

## Faceting

| Value | What it returns |
| --- | --- |
| [`facetedRowModel`](/reference/module/Table#facetedRowModel) | The rows one column's facets are computed from. |
| [`facetedUniqueValues`](/reference/module/Table#facetedUniqueValues) | Distinct values of one column with their row counts. |
| [`facetedMinMax`](/reference/module/Table#facetedMinMax) | The numeric range of one column. |
| [`globalFacetKey`](/reference/module/Table#globalFacetKey) | The column id that stands for the global filter's own facet context, `"__global__"`. |

## Reading one row

These take a `Row` alone.

| Reader | What it returns |
| --- | --- |
| [`rowId`](/reference/module/Table#rowId) | The row id. |
| [`rowIndex`](/reference/module/Table#rowIndex) | The row's index among its siblings. |
| [`rowDepth`](/reference/module/Table#rowDepth) | How deep the row sits in the row tree; root rows are `0`. |
| [`rowOriginal`](/reference/module/Table#rowOriginal) | The original datum this row was built from. |
| [`rowSubRows`](/reference/module/Table#rowSubRows) | The row's children. |
| [`rowParentId`](/reference/module/Table#rowParentId) | The id of the row's parent, when it has one. |
| [`rowOriginalSubRows`](/reference/module/Table#rowOriginalSubRows) | The raw children `Config.getSubRows` returned. |
| [`rowIsGrouped`](/reference/module/Table#rowIsGrouped) | Was this row built by the grouped row model? |
| [`rowGroupingColumnId`](/reference/module/Table#rowGroupingColumnId) | The column a group row groups by. |
| [`rowGroupingValue`](/reference/module/Table#rowGroupingValue) | The value a group row groups by. |
| [`rowLeafRows`](/reference/module/Table#rowLeafRows) | The leaf rows a group row was built from. |
| [`rowAggregatedValues`](/reference/module/Table#rowAggregatedValues) | The aggregated values of a group row, keyed by column id. |
| [`getLeafRows`](/reference/module/Table#getLeafRows) | Every descendant of a row, depth first. |

## Reading a row against a config or a row model

| Reader | What it returns |
| --- | --- |
| [`getValue`](/reference/module/Table#getValue) | One cell value. Unknown columns and columns without an accessor give `Null`. |
| [`getUniqueValues`](/reference/module/Table#getUniqueValues) | The values faceting and grouping use for one cell. |
| [`rowGroupingValueFor`](/reference/module/Table#rowGroupingValueFor) | The value this row groups by for one column. |
| [`getAllCells`](/reference/module/Table#getAllCells) | Every cell of a row, one per leaf column. See the [Cell API](/reference/cell-api). |
| [`findRow`](/reference/module/Table#findRow) | Look a row up by id. |
| [`getParentRow`](/reference/module/Table#getParentRow) | The direct parent of a row. |
| [`getParentRows`](/reference/module/Table#getParentRows) | The ancestors of a row, root first. |
| [`maxSubRowDepth`](/reference/module/Table#maxSubRowDepth) | The deepest row depth in a row model; a flat model is `0`. |
| [`rowsInDisplayOrder`](/reference/module/Table#rowsInDisplayOrder) | The rows a caller renders, in order. |
| [`displayIndex`](/reference/module/Table#displayIndex) | A row's zero-based position in `rowsInDisplayOrder`, or `-1`. |

The per-feature row queries and transitions (selection, pinning, expansion, pagination) are on the [Features API](/reference/features-api) page.
