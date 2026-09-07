---
title: Rows
id: guide/rows
---

A row is one entry of a [row model](/guide/row-models): your original datum
plus the id, depth, and grouping information the pipeline gave it. This page
is the port of TanStack's Rows guide.

`Row row` is an opaque type. In TanStack a row is an object with properties
and methods (`row.id`, `row.original`, `row.getValue(...)`); here you read it
through functions that take the row as their last data argument. The type
parameter is your own record type, so `Row Person` is a row over a `Person`.

## Where to get rows from

### Table.findRow

To get one row by its id, use
[`Table.findRow`](/reference/module/Table#findRow). It is TanStack's
`table.getRow`, and it returns a `Maybe` rather than throwing:

```elm snippet=Rows.elm#lookupRow
```

`findRow` takes the row model, not the config, because ids only exist once
rows have been built. It reads `rowsById`.

### Row models

The pipeline builds the rows and hands them back in three shapes:
`model.rows` (the tree), `model.flatRows` (everything flattened), and
`model.rowsById`. The [Row Models](/guide/row-models) guide covers the
stages; these are the two common ways to reach the rows.

#### Render rows

Render from [`Table.rowsInDisplayOrder`](/reference/module/Table#rowsInDisplayOrder)
rather than `model.rows` directly. It is the page in the order you draw it,
with expanded descendants inserted when `Config.paginateExpandedRows` is off.

```elm snippet=RowModels.elm#displayRows
```

#### Get selected rows

[`Table.selectedRowModel`](/reference/module/Table#selectedRowModel) filters
any stage's row model down to the selected rows. See
[Row Selection](/guide/row-selection).

## Row objects

Every reader is a function of the row. Nothing needs the table.

| TanStack | elm-table |
| --- | --- |
| `row.id` | [`rowId`](/reference/module/Table#rowId) |
| `row.index` | [`rowIndex`](/reference/module/Table#rowIndex) |
| `row.depth` | [`rowDepth`](/reference/module/Table#rowDepth) |
| `row.original` | [`rowOriginal`](/reference/module/Table#rowOriginal) |
| `row.subRows` | [`rowSubRows`](/reference/module/Table#rowSubRows) |
| `row.parentId` | [`rowParentId`](/reference/module/Table#rowParentId) |
| `row.originalSubRows` | [`rowOriginalSubRows`](/reference/module/Table#rowOriginalSubRows) |
| `row.groupingColumnId` | [`rowGroupingColumnId`](/reference/module/Table#rowGroupingColumnId) |
| `row.groupingValue` | [`rowGroupingValue`](/reference/module/Table#rowGroupingValue) |
| `row.leafRows` | [`rowLeafRows`](/reference/module/Table#rowLeafRows) |
| `row._valuesCache` on a group row | [`rowAggregatedValues`](/reference/module/Table#rowAggregatedValues) |
| `row.getIsGrouped()` | [`rowIsGrouped`](/reference/module/Table#rowIsGrouped) |
| `row.getValue(columnId)` | [`getValue`](/reference/module/Table#getValue) |
| `row.getUniqueValues(columnId)` | [`getUniqueValues`](/reference/module/Table#getUniqueValues) |
| `row.getLeafRows()` | [`getLeafRows`](/reference/module/Table#getLeafRows) |
| `row.getParentRow()` | [`getParentRow`](/reference/module/Table#getParentRow) |
| `row.getParentRows()` | [`getParentRows`](/reference/module/Table#getParentRows) |
| `row.getAllCells()` | [`getAllCells`](/reference/module/Table#getAllCells) |
| `row.getDisplayIndex()` | [`displayIndex`](/reference/module/Table#displayIndex) |
| `table.getRow(id)` | [`findRow`](/reference/module/Table#findRow) |
| `table.getMaxSubRowDepth()` | [`maxSubRowDepth`](/reference/module/Table#maxSubRowDepth) |
| `row.renderValue(columnId)` | none |

The first group takes only the row. The second group needs more: `getValue`
and `getUniqueValues` take the `Config` (they run your accessors);
`getParentRow`, `getParentRows`, `findRow`, and `maxSubRowDepth` take a
`RowModel` (they look other rows up); `getAllCells` takes both the `Config`
and the `State` (it needs the column order); `displayIndex` takes the
`Config`, the `State`, and a `RowModel`.

`renderValue` has no counterpart because there is no `renderFallbackValue`
option: an absent value reads back as `Value.Null` and you decide what to
draw. See [Values](/guide/values).

### Row ids

Every row has an id that is unique in its row model. By default a root row's
id is its index (`"0"`, `"1"`) and a child's id is its parent's id plus its
own index (`"0.1"`). Override that with
[`Table.withGetRowId`](/reference/module/Table#withGetRowId), which receives
the datum, its index among its siblings, and its parent's row id:

```elm snippet=Rows.elm#config
```

Grouping appends to the id: a group row's id is `columnId:value`, and nested
groups chain with `>`. `Value.Null` keys land under `"null"`.

### Row numbers and display indexes

For a row-number column, use
[`Table.displayIndex`](/reference/module/Table#displayIndex), not `rowIndex`.
`rowIndex` is the row's position among its siblings at the time it was built,
so it does not follow filtering, grouping, sorting, or expansion.
`displayIndex` is the zero-based position in
[`rowsInDisplayOrder`](/reference/module/Table#rowsInDisplayOrder), or `-1`
when the row is not on the current page.

```elm snippet=Rows.elm#rowNumber
```

There is no cache behind it, so it walks the display list once per call. If
you are numbering every row, number the list you already mapped over instead
of calling this per row.

### Access row values

[`Table.getValue`](/reference/module/Table#getValue) reads one cell of one
row by column id. It returns a [`Value`](/guide/values), not a `String`:

```elm snippet=Rows.elm#firstNameOf
```

An unknown column id, or a column with no accessor, gives `Value.Null`
rather than an error. On a group row, `getValue` reads the aggregated value
when the column has one.

[`Table.getUniqueValues`](/reference/module/Table#getUniqueValues) is the
list form that faceting and grouping use. A column with
[`withGetUniqueValues`](/reference/module/Table#withGetUniqueValues) decides
its own; otherwise the cell value is wrapped in a one-item list.

```elm snippet=Rows.elm#departmentValues
```

### Access original row data

[`Table.rowOriginal`](/reference/module/Table#rowOriginal) gives back the
exact record you put in, untouched by any accessor. This is the way to reach
fields you never defined a column for, and it is typed, so no casting:

```elm snippet=Rows.elm#originalOf
```

On a group row, `rowOriginal` is the first leaf row's datum. Check
[`rowIsGrouped`](/reference/module/Table#rowIsGrouped) before treating it as
a real record.

## Sub rows

Grouping and expanding give rows children. Tell the core row model how to
reach the children of your own nested data with
[`Table.withSubRows`](/reference/module/Table#withSubRows).

- [`rowSubRows`](/reference/module/Table#rowSubRows): the row's children, as
  rows.
- [`rowOriginalSubRows`](/reference/module/Table#rowOriginalSubRows): the raw
  children `Config.getSubRows` returned.
- [`rowDepth`](/reference/module/Table#rowDepth): `0` for root rows, `1` for
  their children, and so on. Useful for indenting:

```elm snippet=Rows.elm#indent
```

- [`rowParentId`](/reference/module/Table#rowParentId): the parent's id, when
  there is one.
- [`getParentRow`](/reference/module/Table#getParentRow) and
  [`getParentRows`](/reference/module/Table#getParentRows): the parent, and
  the ancestors from the root down. Both take a `RowModel` to look ids up in:

```elm snippet=Rows.elm#ancestorIds
```

- [`getLeafRows`](/reference/module/Table#getLeafRows): every descendant,
  depth first, not including the row itself.
- [`maxSubRowDepth`](/reference/module/Table#maxSubRowDepth): the deepest
  depth in a row model. A flat model is `0`.

```elm snippet=Rows.elm#deepestRow
```

## Group rows

The grouped stage inserts rows that stand for a group rather than a datum.
[`rowIsGrouped`](/reference/module/Table#rowIsGrouped) tells them apart,
[`rowGroupingColumnId`](/reference/module/Table#rowGroupingColumnId) says
which column the group is on,
[`rowGroupingValue`](/reference/module/Table#rowGroupingValue) is the value
it groups by, and [`rowLeafRows`](/reference/module/Table#rowLeafRows) is
what it was built from:

```elm snippet=Rows.elm#groupLabel
```

[`rowAggregatedValues`](/reference/module/Table#rowAggregatedValues) is the
group row's aggregates keyed by column id. Every leaf column gets an entry,
`Value.Null` included, so `getValue` on a group row never falls through to a
leaf's accessor. See [Grouping](/guide/grouping) and
[Aggregation](/guide/aggregation).

## More row APIs

The per-feature row functions live with their features:
[`getIsRowSelected`](/reference/module/Table#getIsRowSelected) and
[`toggleRowSelected`](/reference/module/Table#toggleRowSelected) in
[Row Selection](/guide/row-selection),
[`getIsExpanded`](/reference/module/Table#getIsExpanded) and
[`toggleExpanded`](/reference/module/Table#toggleExpanded) in
[Expanding](/guide/expanding),
[`getIsRowPinned`](/reference/module/Table#getIsRowPinned) and
[`pinRow`](/reference/module/Table#pinRow) in
[Row Pinning](/guide/row-pinning).

To get from a row to the cells you render, see [Cells](/guide/cells).
