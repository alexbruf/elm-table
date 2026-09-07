---
title: Columns
id: guide/columns
---

This page is about the `Column row` values the table works with, not about
writing column definitions. For that, see
[Column Definitions](/guide/column-defs).

It is the port of TanStack's Columns guide. The difference worth stating
first: in TanStack a *column def* is a plain object and the table turns it
into a *column* instance with methods on it. Here there is only one thing.
[`Table.column`](/reference/module/Table#column) returns a `Column row`, the
`with*` builders return a `Column row`, and that is what the table reads. No
construction step happens in between.

`Column row` is opaque, so you read it through functions.

## Where to get columns from

### Header and cell objects

If you are rendering markup, you probably want [headers](/guide/headers) or
[cells](/guide/cells) rather than columns. Neither of them carries a column
though: a header carries `headerColumnId` and a cell carries `columnId`, so
going the other way is a lookup:

```elm snippet=Headers.elm#headerColumn
```

### Column list functions

| TanStack | elm-table |
| --- | --- |
| `table.getColumn(id)` | [`findColumn`](/reference/module/Table#findColumn) |
| `table.getAllColumns()` | `Config.columns`, the record field you built |
| `table.getAllFlatColumns()` | [`allColumns`](/reference/module/Table#allColumns) |
| `table.getAllLeafColumns()` | [`leafColumns`](/reference/module/Table#leafColumns), then [`orderColumns`](/reference/module/Table#orderColumns) |
| `table.getVisibleFlatColumns()` | [`visibleFlatColumns`](/reference/module/Table#visibleFlatColumns) |
| `table.getVisibleLeafColumns()` | [`visibleLeafColumns`](/reference/module/Table#visibleLeafColumns) |
| `column.columns` | [`columnColumns`](/reference/module/Table#columnColumns) |
| `column.getFlatColumns()` | [`columnFlatColumns`](/reference/module/Table#columnFlatColumns) |
| `column.getLeafColumns()` | [`columnLeafColumns`](/reference/module/Table#columnLeafColumns) |
| `table.getStartLeafColumns()` | [`leftLeafColumns`](/reference/module/Table#leftLeafColumns) |
| `table.getCenterLeafColumns()` | [`centerLeafColumns`](/reference/module/Table#centerLeafColumns) |
| `table.getEndLeafColumns()` | [`rightLeafColumns`](/reference/module/Table#rightLeafColumns) |
| `table.getStartVisibleLeafColumns()` | [`leftVisibleLeafColumns`](/reference/module/Table#leftVisibleLeafColumns) |
| `table.getCenterVisibleLeafColumns()` | [`centerVisibleLeafColumns`](/reference/module/Table#centerVisibleLeafColumns) |
| `table.getEndVisibleLeafColumns()` | [`rightVisibleLeafColumns`](/reference/module/Table#rightVisibleLeafColumns) |

The ones that only walk the column tree take just the `Config`. The ones that
depend on order, visibility, or pinning take the `State` as well.

`allColumns` is the flattened tree: every column, group columns included,
each group before its children. TanStack's `getAllColumns()` is the
*unflattened* tree, which here is simply the `columns` field of your `Config`,
since `Config` is a plain record.

`leafColumns` is in definition order. TanStack's `getAllLeafColumns()` also
applies the table order, which is [`orderColumns`](/reference/module/Table#orderColumns)
here.

```elm snippet=Columns.elm#config
```

```elm snippet=Columns.elm#columnTree
```

[`findColumn`](/reference/module/Table#findColumn) searches that same list,
so group columns are found too:

```elm snippet=Columns.elm#salaryWidth
```

## The tree and the leaf list

This is the distinction to get right, because the two lists have different
lengths and different uses.

**The tree** is what you wrote. `allColumns` walks it, `columnColumns` gives
one group's children, `columnDepth` says how deep a column sits, and
`columnParentId` points back up.

```elm snippet=Columns.elm#childLabels
```

```elm snippet=Columns.elm#parentLabel
```

**The leaf list** is the columns that actually produce cells. Group columns
have no accessor and no cells, so they are not in it.
[`columnLeafColumns`](/reference/module/Table#columnLeafColumns) is the
per-column version: the leaves under one column, or the column itself when it
is already a leaf.

```elm snippet=Columns.elm#leafIds
```

```elm snippet=Columns.elm#coveredLeafIds
```

### Which list to render

- **Body cells:**
  [`visibleLeafColumns`](/reference/module/Table#visibleLeafColumns), or
  better, the [cells](/guide/cells) of the row, which are already in that
  order.

```elm snippet=Columns.elm#renderedColumns
```

- **Header cells:** neither. Use
  [`headerGroups`](/reference/module/Table#headerGroups), which turns the
  column tree into header rows with the right `colspan` and `rowspan`. See
  [Header Groups](/guide/header-groups).
- **A column visibility menu:**
  [`allColumns`](/reference/module/Table#allColumns), so the user sees the
  group columns and the already-hidden ones.
  [`visibleFlatColumns`](/reference/module/Table#visibleFlatColumns) is the
  same list minus the hidden columns, which is what you want for a legend or
  an export, not for a menu that turns columns back on.

```elm snippet=Columns.elm#viewColumnMenu
```

## Column objects

| TanStack | elm-table |
| --- | --- |
| `column.id` | [`columnId`](/reference/module/Table#columnId) |
| `column.columnDef.header` | [`columnHeader`](/reference/module/Table#columnHeader) |
| `column.columnDef.footer` | [`columnFooter`](/reference/module/Table#columnFooter) |
| `column.depth` | [`columnDepth`](/reference/module/Table#columnDepth) |
| `column.columns` | [`columnColumns`](/reference/module/Table#columnColumns) |
| `column.parent` | [`columnParentId`](/reference/module/Table#columnParentId) |
| `column.accessorFn` | [`columnAccessor`](/reference/module/Table#columnAccessor) |
| `column.getSize()` | [`columnSize`](/reference/module/Table#columnSize) |
| `column.columnDef.minSize` | [`columnMinSize`](/reference/module/Table#columnMinSize) |
| `column.columnDef.maxSize` | [`columnMaxSize`](/reference/module/Table#columnMaxSize) |
| `column.columnDef` | none, the column is the definition |

### Column ids

Every column has an id, and you always write it yourself:
`Table.column "firstName" ...`. There is no `accessorKey` to derive one from,
because an accessor here is a function rather than a key path, and no header
to fall back on. Ids must be unique across the whole table, group columns
included.

### Column defs

`column.columnDef` has no counterpart. The `Column row` value *is* the
definition, built by `Table.column`, `Table.group`, or `Table.display` and
then piped through `with*` builders. So `columnHeader` reads back what
`withHeader` set, and so on.

`columnHeader` and `columnFooter` are `Maybe String`, since both builders are
optional. Most views fall back to the column id:

```elm snippet=Columns.elm#columnLabel
```

### Nested grouped column properties

- [`columnColumns`](/reference/module/Table#columnColumns): the children of a
  group column, empty on an accessor or display column.
- [`columnDepth`](/reference/module/Table#columnDepth): `0` at the top level,
  stamped by `Table.group` when the column is nested.
- [`columnParentId`](/reference/module/Table#columnParentId): the id of the
  group column above, `Nothing` at the top level. TanStack stores the parent
  column itself; here it is an id, so pair it with `findColumn`.
- [`columnFlatColumns`](/reference/module/Table#columnFlatColumns): one
  column and everything below it, the column itself first.

### Accessors and sizes

[`columnAccessor`](/reference/module/Table#columnAccessor) gives back the
function you passed to `Table.column`, or `Nothing` for a group or display
column. That is the way to tell the three kinds apart:

```elm snippet=Columns.elm#hasAccessor
```

[`columnSize`](/reference/module/Table#columnSize),
[`columnMinSize`](/reference/module/Table#columnMinSize), and
[`columnMaxSize`](/reference/module/Table#columnMaxSize) take the `Config`
because an unset size falls back to `Config.defaultColumn`, which defaults to
`150`, `20`, and `9007199254740991` pixels. They are the static sizes. For
the rendered width, which also accounts for `State.columnSizing`, use
[`getColumnSize`](/reference/module/Table#getColumnSize). See
[Column Sizing](/guide/column-sizing).

## Ordering a column list

[`orderColumns`](/reference/module/Table#orderColumns) puts any column list
into table order: `State.columnOrder` first, unlisted columns behind the
listed ones, then the grouped-column rules.

```elm snippet=Columns.elm#orderedLeafColumns
```

[`orderGroupedColumns`](/reference/module/Table#orderGroupedColumns) applies
only `Config.groupedColumnMode` to a leaf column list, moving the grouped
columns to the front (the default), removing them, or leaving the list alone.

```elm snippet=Columns.elm#groupedFirst
```

`visibleLeafColumns` already runs the ordering, so reach for these two only
when you are building a list of your own. Note that `visibleLeafColumns` is
not pin-ordered, matching TanStack: the pin split happens in
[`visibleCells`](/reference/module/Table#visibleCells) and in the header
functions. See [Column Ordering](/guide/column-ordering) and
[Column Pinning](/guide/column-pinning).

## More column APIs

The per-feature column queries are with their features:
[`columnIsVisible`](/reference/module/Table#columnIsVisible) and
[`columnCanHide`](/reference/module/Table#columnCanHide) in
[Column Visibility](/guide/column-visibility),
[`columnIsPinned`](/reference/module/Table#columnIsPinned) and
[`columnCanPin`](/reference/module/Table#columnCanPin) in
[Column Pinning](/guide/column-pinning),
[`getCanSort`](/reference/module/Table#getCanSort) in
[Sorting](/guide/sorting),
[`getCanFilter`](/reference/module/Table#getCanFilter) in
[Column Filtering](/guide/column-filtering),
[`getCanGroup`](/reference/module/Table#getCanGroup) in
[Grouping](/guide/grouping).

Several of those take a column *id* rather than a `Column row`, because they
only read the `State`. Check the signature in the
[module reference](/reference/module/Table).

## Column rendering

Do not render headers or cells from columns. Use
[headers](/guide/headers) and [cells](/guide/cells), which carry the spans,
the order, and the values. Columns are for lists of columns: a visibility
menu, a grouping picker, a settings panel.
