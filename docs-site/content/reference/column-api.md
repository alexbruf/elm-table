---
title: Column API
id: reference/column-api
---

TanStack's Column API Reference covers two things at once: the column definitions you write (`ColumnDef` and its three shapes) and the column objects the table builds from them (`Column`). elm-table has one type for both, [`Column`](/reference/module/Table#Column), an opaque value built by a constructor and a chain of `with*` builders. This page maps TanStack's entries onto ours; full signatures and doc comments live on the generated [`Table` module page](/reference/module/Table). For prose, see [Column Definitions](/guide/column-defs) and [Columns](/guide/columns).

## Definitions and instances

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `Column` | [`Column`](/reference/module/Table#Column) | Opaque. Read it with the `column*` functions below. |
| `ColumnDef` | [`Column`](/reference/module/Table#Column) | Same type. There is no separate "definition" that the table turns into an instance. |
| `ColumnDefBase` | — | No shared base type. Every builder applies to any `Column`; builders that make no sense for a group or display column are simply unused. |
| `AccessorColumnDef` | [`column`](/reference/module/Table#column) | An id and a `row -> Value` accessor. TanStack's separate accessor-key form has no counterpart: Elm has field access, so `.age >> toFloat >> Value.Number` is the key form. |
| `DisplayColumnDef` | [`display`](/reference/module/Table#display) | An id, no accessor, no children. |
| `GroupColumnDef` | [`group`](/reference/module/Table#group) | An id and the columns nested under it. Group columns produce header rows only. |
| `ColumnDefTemplate` | — | Headers and footers are `String`, set with [`withHeader`](/reference/module/Table#withHeader) and [`withFooter`](/reference/module/Table#withFooter). Cells hold a [`Value`](/reference/module/Table-Value#Value). Turning either into `Html` is your code. |
| `ColumnHelper` | — | No helper object. `column`, `group`, and `display` are ordinary functions. |
| `ColumnMeta` | — | No meta bag on a column. Keep extra per-column data in your own model, keyed by column id. |
| `createColumnHelper` | — | Nothing to bind the row type to: `Table.Column Person` already carries it. |
| `constructColumn` | [`column`](/reference/module/Table#column) | Also [`group`](/reference/module/Table#group) and [`display`](/reference/module/Table#display). Depth and parent id are stamped by `group`, so no table instance is involved. |
| `AccessorFn` | `row -> Value` | The second argument of [`column`](/reference/module/Table#column). It receives the datum only; the row index is passed separately where it matters, as in [`withGetGroupingValue`](/reference/module/Table#withGetGroupingValue). |
| `DeepKeys` | — | A TypeScript type for dotted key paths. Elm reads fields with a function. |
| `DeepValue` | — | Same reason. |
| `AppColumnHelper` | — | React-only. No helper object here. |

## Constructors

| Value | What it makes |
| --- | --- |
| [`column`](/reference/module/Table#column) | An accessor column: an id and a way to read a cell value. |
| [`group`](/reference/module/Table#group) | A group column: an id and the columns nested under it. |
| [`display`](/reference/module/Table#display) | A display column: an id, no accessor, no children. |

## Column builders

Each builder sets one field and returns the column, so they chain with `|>`. The twelve builders that take a `Config` instead are on the [Table API](/reference/table-api) page.

| Builder | What it sets |
| --- | --- |
| [`withHeader`](/reference/module/Table#withHeader) | The header text. |
| [`withFooter`](/reference/module/Table#withFooter) | The footer text. |
| [`withSortFn`](/reference/module/Table#withSortFn) | Sort this column with a built-in sort function. |
| [`withCustomSort`](/reference/module/Table#withCustomSort) | Sort this column with a comparison on whole rows. |
| [`withSortDescFirst`](/reference/module/Table#withSortDescFirst) | Make the first click sort descending. |
| [`withInvertSorting`](/reference/module/Table#withInvertSorting) | Invert the sort direction of this column. |
| [`withSortUndefined`](/reference/module/Table#withSortUndefined) | Decide where `Null` values land when this column is sorted. |
| [`withEnableSorting`](/reference/module/Table#withEnableSorting) | Allow or forbid sorting on this column. |
| [`withEnableMultiSort`](/reference/module/Table#withEnableMultiSort) | Allow or forbid this column in a multi-sort. |
| [`withFilterFn`](/reference/module/Table#withFilterFn) | Filter this column with a built-in filter function. |
| [`withCustomFilter`](/reference/module/Table#withCustomFilter) | Filter this column with a predicate on whole rows. |
| [`withEnableColumnFilter`](/reference/module/Table#withEnableColumnFilter) | Allow or forbid a column filter on this column. |
| [`withEnableGlobalFilter`](/reference/module/Table#withEnableGlobalFilter) | Include or exclude this column from the global filter. |
| [`withAggregationFn`](/reference/module/Table#withAggregationFn) | Aggregate this column's values on group rows. |
| [`withMaxAggregationDepth`](/reference/module/Table#withMaxAggregationDepth) | How far below an aggregated row its aggregation looks for values. |
| [`withGetGroupingValue`](/reference/module/Table#withGetGroupingValue) | Read the value this column groups by, when it differs from the accessor. |
| [`withGetUniqueValues`](/reference/module/Table#withGetUniqueValues) | Read the faceting values of a row, when one cell holds several. |
| [`withEnableGrouping`](/reference/module/Table#withEnableGrouping) | Allow or forbid grouping by this column. |
| [`withEnableHiding`](/reference/module/Table#withEnableHiding) | Allow or forbid hiding this column. |
| [`withEnablePinning`](/reference/module/Table#withEnablePinning) | Allow or forbid pinning this column. |
| [`withSize`](/reference/module/Table#withSize) | This column's size in pixels. |
| [`withMinSize`](/reference/module/Table#withMinSize) | This column's minimum size in pixels. |
| [`withMaxSize`](/reference/module/Table#withMaxSize) | This column's maximum size in pixels. |
| [`withEnableCellSpanning`](/reference/module/Table#withEnableCellSpanning) | Turn one column off for cell spanning even when the table allows it. |
| [`withSpanRows`](/reference/module/Table#withSpanRows) | Merge adjacent rows with equal values into one vertically spanning cell. |
| [`withSpanRowsWhen`](/reference/module/Table#withSpanRowsWhen) | Decide per candidate row whether it joins the vertical run. |
| [`withSpanColumns`](/reference/module/Table#withSpanColumns) | Make this column's cell span that many columns in a given row. |
| [`withEnableCellSelection`](/reference/module/Table#withEnableCellSelection) | Allow or forbid selecting the cells of one column. |

## Reading one column

These take a `Column` alone.

| Reader | What it returns |
| --- | --- |
| [`columnId`](/reference/module/Table#columnId) | The column id. |
| [`columnHeader`](/reference/module/Table#columnHeader) | The header text, when one was set. |
| [`columnFooter`](/reference/module/Table#columnFooter) | The footer text, when one was set. |
| [`columnDepth`](/reference/module/Table#columnDepth) | How deep the column sits in the column tree; top level is `0`. |
| [`columnParentId`](/reference/module/Table#columnParentId) | The id of the group column this column sits under. |
| [`columnColumns`](/reference/module/Table#columnColumns) | The columns nested directly under a group column. |
| [`columnFlatColumns`](/reference/module/Table#columnFlatColumns) | One column and every column below it, the column itself first. |
| [`columnLeafColumns`](/reference/module/Table#columnLeafColumns) | The leaf columns below one column. A leaf column returns itself. |
| [`columnAccessor`](/reference/module/Table#columnAccessor) | The accessor, when the column has one. Group and display columns have none. |

## Reading a column against a config or state

| Reader | What it returns |
| --- | --- |
| [`columnSize`](/reference/module/Table#columnSize) | The column's size in pixels, clamped to its minimum and maximum. |
| [`columnMinSize`](/reference/module/Table#columnMinSize) | The column's minimum size in pixels. |
| [`columnMaxSize`](/reference/module/Table#columnMaxSize) | The column's maximum size in pixels. |
| [`getColumnSize`](/reference/module/Table#getColumnSize) | The rendered width: the committed size from `State.columnSizing` when there is one, otherwise the column's own size and then the configured default. |
| [`getColumnStart`](/reference/module/Table#getColumnStart) | How far from the start of its region a column begins. |
| [`getColumnAfter`](/reference/module/Table#getColumnAfter) | How far from the end of its region a column ends. |
| [`columnIsVisible`](/reference/module/Table#columnIsVisible) | Is this column visible? A group column is visible when any leaf below it is. |
| [`columnCanHide`](/reference/module/Table#columnCanHide) | Can this column be hidden? |
| [`columnIsPinned`](/reference/module/Table#columnIsPinned) | Where is this column pinned? |
| [`columnCanPin`](/reference/module/Table#columnCanPin) | Can this column be pinned? |
| [`columnPinnedIndex`](/reference/module/Table#columnPinnedIndex) | The column's position inside its pinned region. |
| [`columnIndex`](/reference/module/Table#columnIndex) | Where this column sits in one region of the visible leaf columns, or `-1`. |
| [`columnIsFirst`](/reference/module/Table#columnIsFirst) | Is this the first visible column of the region? |
| [`columnIsLast`](/reference/module/Table#columnIsLast) | Is this the last visible column of the region? |
| [`columnCanSpan`](/reference/module/Table#columnCanSpan) | Does this column take part in cell spanning? |

## Column lists

| Reader | What it returns |
| --- | --- |
| [`allColumns`](/reference/module/Table#allColumns) | Every column, group columns included, each group before its children. |
| [`leafColumns`](/reference/module/Table#leafColumns) | Every leaf column, in definition order. |
| [`visibleLeafColumns`](/reference/module/Table#visibleLeafColumns) | The leaf columns a table renders: `State.columnOrder` applied, hidden columns dropped. |
| [`visibleFlatColumns`](/reference/module/Table#visibleFlatColumns) | Every column, group columns included, minus the hidden ones. |
| [`findColumn`](/reference/module/Table#findColumn) | Find a column by id. Group columns are found too. |
| [`orderColumns`](/reference/module/Table#orderColumns) | Put a column list in table order: `State.columnOrder` first, then the grouped-column rules. |
| [`orderGroupedColumns`](/reference/module/Table#orderGroupedColumns) | Apply `Config.groupedColumnMode` to a leaf column list. |
| [`leftLeafColumns`](/reference/module/Table#leftLeafColumns) | The leaf columns pinned to the left, hidden ones included. |
| [`centerLeafColumns`](/reference/module/Table#centerLeafColumns) | The unpinned leaf columns. |
| [`rightLeafColumns`](/reference/module/Table#rightLeafColumns) | The leaf columns pinned to the right, hidden ones included. |
| [`leftVisibleLeafColumns`](/reference/module/Table#leftVisibleLeafColumns) | The visible leaf columns pinned to the left. |
| [`centerVisibleLeafColumns`](/reference/module/Table#centerVisibleLeafColumns) | The visible unpinned leaf columns. |
| [`rightVisibleLeafColumns`](/reference/module/Table#rightVisibleLeafColumns) | The visible leaf columns pinned to the right. |
| [`pinnedLeafColumns`](/reference/module/Table#pinnedLeafColumns) | The leaf columns of one region, chosen by a [`ColumnRegion`](/reference/module/Table#ColumnRegion). |
| [`pinnedVisibleLeafColumns`](/reference/module/Table#pinnedVisibleLeafColumns) | The visible leaf columns of one region. |
| [`pinnedColumns`](/reference/module/Table#pinnedColumns) | All three visible slices at once, in render order. |

The transitions that change a column's state (`pinColumn`, `toggleColumnVisibility`, `setColumnOrder`, `setColumnSize`, and the rest) are grouped by feature on the [Features API](/reference/features-api) page.
