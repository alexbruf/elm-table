---
title: Cells
id: guide/cells
---

A cell is one row crossed with one leaf column. This page is the port of
TanStack's Cells guide.

Unlike `Row`, `Column`, and `Header`, `Cell` is not opaque. It is a plain
record with four fields, built on demand:

```elm
type alias Cell =
    { id : String
    , columnId : String
    , rowId : String
    , value : Value
    }
```

There is no type parameter: a cell holds a resolved
[`Value`](/guide/values), not your record, so `Cell` is the same type for
every table.

## Where to get cells from

Cells come from rows. Nothing stores them, so each of these functions
computes the cells it returns.

| TanStack | elm-table |
| --- | --- |
| `row.getAllCells()` | [`getAllCells`](/reference/module/Table#getAllCells) |
| `row.getVisibleCells()` | [`visibleCells`](/reference/module/Table#visibleCells) |
| `row.getVisibleCellsByColumnId()` | [`visibleCellsByColumnId`](/reference/module/Table#visibleCellsByColumnId) |
| `row.getStartVisibleCells()` | [`leftVisibleCells`](/reference/module/Table#leftVisibleCells) |
| `row.getCenterVisibleCells()` | [`centerVisibleCells`](/reference/module/Table#centerVisibleCells) |
| `row.getEndVisibleCells()` | [`rightVisibleCells`](/reference/module/Table#rightVisibleCells) |

All of them take the `Config`, the `State`, and the row.

[`getAllCells`](/reference/module/Table#getAllCells) gives one cell per leaf
column in column order, hidden columns included.
[`visibleCells`](/reference/module/Table#visibleCells) drops the hidden ones
and puts the left-pinned cells first, then the unpinned ones, then the
right-pinned. That ordering is why `visibleCells` is what you render:

```elm snippet=Cells.elm#viewRow
```

The three pinned lists are for laying the regions out separately, for
instance in three scroll containers:

```elm snippet=Cells.elm#viewPinnedRow
```

[`visibleCellsByColumnId`](/reference/module/Table#visibleCellsByColumnId)
returns the same cells as a `Dict` when you want one specific cell rather
than the row:

```elm snippet=Cells.elm#salaryCell
```

## Cell objects

### Cell ids

`cell.id` is the row id and the column id joined with an underscore, the same
construction TanStack uses:

```elm
{ id = rowId ++ "_" ++ columnId }
```

Grouping changes the row id, so group and aggregated cells get the longer id
their row carries.

```elm snippet=Cells.elm#allCellIds
```

### Cell parent objects

TanStack cells hold references to their parent `row` and `column` objects.
An Elm `Cell` holds ids instead: `cell.rowId` and `cell.columnId`. Get back
to the objects with [`Table.findRow`](/reference/module/Table#findRow) and
[`Table.findColumn`](/reference/module/Table#findColumn) when you need them.

Usually you do not. You already have the row in scope when you map over its
cells, so pass it down instead of looking it up.

### Access cell values

`cell.value` is the value, already resolved. There is no `cell.getValue()`
call to make and no cache to warm, because the cell was built by reading the
accessor once.

`cell.value` is a [`Value`](/guide/values).
[`Value.toString`](/reference/module/Table-Value#toString) applies TanStack's
`String(value)` coercion; pattern matching gives you your own formatting:

```elm snippet=Cells.elm#viewTypedCell
```

`renderValue` has no counterpart. There is no `renderFallbackValue` option:
a missing value is `Value.Null`, and the `case` above decides what it looks
like.

To read a *different* column's value while rendering a cell, go through the
row: `Table.getValue config row otherColumnId`. See [Rows](/guide/rows).

### Access other row data from any cell

TanStack reaches the original datum with `cell.row.original`. A `Cell` has no
row reference, so keep the row in scope while you render:

```elm snippet=Cells.elm#viewRow
```

`viewRow` already has the row; if a cell renderer needs the whole record,
give it `Table.rowOriginal row` as an argument rather than looking the row up
by `cell.rowId`.

## Cell rendering

TanStack renders cells with `flexRender(cell.column.columnDef.cell,
cell.getContext())`, because a column def can carry a `cell` renderer that is
a string, JSX, or a function. There is no `cell` option on an Elm column and
no `flexRender`: you write the `Html` yourself.

```elm snippet=Cells.elm#viewCell
```

That is the whole rendering story. Branch on `cell.columnId` for per-column
markup, or on `cell.value` for per-type markup, in ordinary Elm.
`cell.getContext()` has no counterpart because the arguments it packages
(the table, the row, the column, the cell) are the arguments you already have
or can pass.

## More cell APIs

The state queries about a cell live with their features. Each takes what it
needs rather than hanging off the cell:

- [`cellIsGrouped`](/reference/module/Table#cellIsGrouped),
  [`cellIsPlaceholder`](/reference/module/Table#cellIsPlaceholder) in
  [Grouping](/guide/grouping). Both take the `State`, the row, and a column
  id.
- [`cellIsAggregated`](/reference/module/Table#cellIsAggregated) in
  [Aggregation](/guide/aggregation).
- [`cellIsSelected`](/reference/module/Table#cellIsSelected),
  [`cellIsFocused`](/reference/module/Table#cellIsFocused),
  [`cellCanSelect`](/reference/module/Table#cellCanSelect),
  [`cellTabIndex`](/reference/module/Table#cellTabIndex) in
  [Cell Selection](/guide/cell-selection). These take a `Cell`.
- [`cellRowSpan`](/reference/module/Table#cellRowSpan),
  [`cellColSpan`](/reference/module/Table#cellColSpan),
  [`cellIsCovered`](/reference/module/Table#cellIsCovered) in
  [Cell Spanning](/guide/cell-spanning). These take a `CellSpanIndex` built
  once with [`cellSpanIndex`](/reference/module/Table#cellSpanIndex).

### Cell spanning

Adjacent cells can merge into one rendered cell. A cell with a span of `0` is
covered by another cell's span and must be skipped rather than rendered. The
index is an explicit value here rather than a memoized table method, so build
it once for the rows you are about to draw and pass it down. See
[Cell Spanning](/guide/cell-spanning).
