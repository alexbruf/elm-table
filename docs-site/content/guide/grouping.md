---
title: Grouping
id: guide/grouping
---

## Grouping

Grouping replaces the rows of one pipeline stage with **group rows**: one row
per distinct value of a grouped column, holding the matching rows as its
sub-rows. It is how you turn a flat list of people into one row per
department that you can open to see the people inside. This page ports
TanStack Table's *Grouping (React) Guide*.

Grouping runs as the third stage of the [row model
pipeline](/guide/row-models), after filtering and before sorting, so group
rows are sorted by their aggregated values. The values a group row shows for
its other columns come from [Aggregation](/guide/aggregation), and the
open/closed state of a group row comes from [Expanding](/guide/expanding).

### Client-side vs server-side grouping

Client-side grouping needs the whole dataset in the browser, because a group
is only correct when every row that belongs in it is present. When your
server returns one page at a time, or does the grouping itself, set
`manualGrouping = True` and the grouped stage passes its input straight
through. See [Client-Side vs
Server-Side](/guide/client-side-vs-server-side).

### Grouping and column order

Grouping can move columns. Column order is decided in one place,
[`orderColumns`](/reference/module/Table#orderColumns), which applies
`State.columnOrder` first, then `Config.groupedColumnMode`, then column
visibility, and finally the pinning split. So a grouped column is moved to
the front of the leaf column list *after* your own explicit order and
*before* [pinning](/guide/column-pinning) partitions it. See [Column
Ordering](/guide/column-ordering).

## State

Grouping owns one state slice: the ids of the columns to group by, in the
order the groups nest.

```elm
-- in Table.State
grouping : List String

-- in Table.initialState
grouping = []
```

`[ "department", "age" ]` groups by department first, then by age inside each
department.

## Config options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableGrouping` | `Bool` | `True` | Turns grouping off for the whole table. With it `False`, [`getCanGroup`](/reference/module/Table#getCanGroup) is `False` for every column. |
| `groupedColumnMode` | `GroupedColumnMode` | `groupedColumnsReorder` | What the leaf column list does with a grouped column. |
| `manualGrouping` | `Bool` | `False` | Skip the grouped stage. [`groupedRowModel`](/reference/module/Table#groupedRowModel) returns its input unchanged. |

`Config` is a plain record, so you set these with a record update:

```elm snippet=Grouping.elm#config
```

`GroupedColumnMode` is an abstract type with three values, standing in for
TanStack's `'reorder' | 'remove' | false`:

| Value | What it does |
| --- | --- |
| [`groupedColumnsReorder`](/reference/module/Table#groupedColumnsReorder) | Move grouped columns to the front of the leaf column list. This is the default. |
| [`groupedColumnsRemove`](/reference/module/Table#groupedColumnsRemove) | Drop grouped columns from the leaf column list. |
| [`groupedColumnsIgnore`](/reference/module/Table#groupedColumnsIgnore) | Leave the list alone. TanStack's `false`. |

## Column options

| Builder | Type | Default | Description |
| --- | --- | --- | --- |
| [`withEnableGrouping`](/reference/module/Table#withEnableGrouping) | `Bool -> Column row -> Column row` | `True` | Allow or forbid grouping by this column. |
| [`withGetGroupingValue`](/reference/module/Table#withGetGroupingValue) | `(row -> Int -> Value) -> Column row -> Column row` | none | Read the value to group by when it differs from the accessor value. The `Int` is the row's index, mirroring TanStack's `getGroupingValue(originalRow, index, row)`. |
| [`withAggregationFn`](/reference/module/Table#withAggregationFn) | `AggregationFn -> Column row -> Column row` | none (automatic) | The aggregation this column's group rows show. See [Aggregation](/guide/aggregation). |
| [`withMaxAggregationDepth`](/reference/module/Table#withMaxAggregationDepth) | `Int -> Column row -> Column row` | `0` | How far below a group row its aggregation looks for values. |

A column can be grouped when the table and the column both allow it and the
column has either an accessor or a grouping-value function. A grouping-value
function lets you group by something the cell does not show, such as a band
rather than an exact number:

```elm snippet=Grouping.elm#ageBand
```

With a grouping-value function the group id and
[`rowGroupingValue`](/reference/module/Table#rowGroupingValue) carry the band,
while [`getValue`](/reference/module/Table#getValue) on the grouping column
still carries the accessor value of the group's first member. That matches
TanStack.

## Transitions

| Function | Signature | Description |
| --- | --- | --- |
| [`toggleGrouping`](/reference/module/Table#toggleGrouping) | `String -> State -> State` | Append the column to `State.grouping`, or drop it and keep the rest in order. |
| [`setGrouping`](/reference/module/Table#setGrouping) | `List String -> State -> State` | Replace `State.grouping`. |
| [`resetGrouping`](/reference/module/Table#resetGrouping) | `State -> State` | Empty `State.grouping`. |

Like TanStack's `column.toggleGrouping`, `toggleGrouping` does not check
[`getCanGroup`](/reference/module/Table#getCanGroup) itself. Check it in your
click handler if you build grouping controls for columns that may forbid it:

```elm snippet=Grouping.elm#update
```

To set several grouping levels at once, pass the whole list:

```elm snippet=Grouping.elm#groupByDepartmentThenAge
```

## Queries

| Function | Signature | Description |
| --- | --- | --- |
| [`getCanGroup`](/reference/module/Table#getCanGroup) | `Config row -> String -> Bool` | Can this column be grouped? |
| [`getIsGrouped`](/reference/module/Table#getIsGrouped) | `State -> String -> Bool` | Is this column in `State.grouping`? |
| [`getGroupedIndex`](/reference/module/Table#getGroupedIndex) | `State -> String -> Int` | Its position in `State.grouping`, or `-1`. |
| [`rowIsGrouped`](/reference/module/Table#rowIsGrouped) | `Row row -> Bool` | Was this row built by the grouped stage? |
| [`rowGroupingColumnId`](/reference/module/Table#rowGroupingColumnId) | `Row row -> Maybe String` | The column a group row groups by. |
| [`rowGroupingValue`](/reference/module/Table#rowGroupingValue) | `Row row -> Value` | The value a group row groups by. |
| [`rowGroupingValueFor`](/reference/module/Table#rowGroupingValueFor) | `Config row -> Row row -> String -> Value` | The value any row would group by for one column. |
| [`rowLeafRows`](/reference/module/Table#rowLeafRows) | `Row row -> List (Row row)` | The leaf rows a group row was built from. Empty for an ordinary row. |
| [`cellIsGrouped`](/reference/module/Table#cellIsGrouped) | `State -> Row row -> String -> Bool` | Is this the cell of the group row's own grouping column? |
| [`cellIsPlaceholder`](/reference/module/Table#cellIsPlaceholder) | `State -> Row row -> String -> Bool` | Is this the cell of some *other* grouped column? Those render empty. |
| [`preGroupedRowModel`](/reference/module/Table#preGroupedRowModel) | `Config row -> State -> RowModel row -> RowModel row` | The model grouping runs on, which is the filtered one. |
| [`orderGroupedColumns`](/reference/module/Table#orderGroupedColumns) | `Config row -> State -> List (Column row) -> List (Column row)` | Apply `Config.groupedColumnMode` to a leaf column list yourself. |

`Cell` carries its row and column ids rather than a reference to the row, so
`cellIsGrouped` and `cellIsPlaceholder` take the row and the column id.

### Rendering a grouped body

A group row needs three kinds of cell: its own grouping cell, which shows the
grouping value and an expand toggle; the placeholder cells of the other
grouped columns, which stay empty; and the ordinary cells, which on a group
row read back the aggregated value.

```elm snippet=Grouping.elm#viewCell
```

The rows themselves come from the pipeline in the usual way:

```elm snippet=Grouping.elm#viewRow
```

To run only the stages up to grouping, stop at
[`groupedRowModel`](/reference/module/Table#groupedRowModel):

```elm snippet=Grouping.elm#groupedModel
```

### Group row ids and values

Three details are worth knowing before you key `Html` nodes off a group row
id or read a group row's datum.

**Group ids are built from the column id and the grouping value.** A group
row's id is `"<columnId>:<groupingValue>"`, and a nested group joins its
parent's id with `>`. Grouping by department and then by age gives ids like
`department:Engineering` and `department:Engineering>age:36`. An id that
itself contains `:` or `>` can in principle collide. TanStack has the same
property.

**A `Null` grouping value lands under the key `"null"`.** `Value.Null` stands
for both JavaScript `null` and `undefined` in this port, so the two buckets
TanStack would keep apart merge into one here.

**A group row's `original` is its first leaf row's `original`.** The group row
has no datum of its own, so
[`rowOriginal`](/reference/module/Table#rowOriginal) hands you a real row's
datum. Read group rows through
[`rowGroupingValue`](/reference/module/Table#rowGroupingValue),
[`getValue`](/reference/module/Table#getValue), and
[`rowLeafRows`](/reference/module/Table#rowLeafRows) instead.

## Not covered

TanStack's page also describes controlled grouping state through the `atoms`
option or `state.grouping` plus `onGroupingChange`. There is nothing to port:
`State.grouping` is always yours, held in your own model, so it is already
readable anywhere in your application.

`column.getToggleGroupingHandler` has no counterpart either, because the
package produces no event handlers. Write `onClick (GroupToggled columnId)`
yourself.

The automatic resets TanStack performs when the grouped row model recomputes
(`autoResetPageIndex`, `autoResetExpanded`, `autoResetAll`) are not ported.
Nothing recomputes behind your back here, so reset the page index or the
expanded rows in the same `update` branch that changes the grouping.

## Example

[Grouping](https://elm-table-examples.pages.dev/grouping/), ported from
TanStack's Grouping example.

<iframe src="https://elm-table-examples.pages.dev/grouping/" title="Grouping example" loading="lazy"></iframe>
