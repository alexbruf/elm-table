---
title: Expanding
id: guide/expanding
---

## Expanding

Expanding shows and hides extra rows below a row. It covers two things at
once: opening a parent row to reveal its child rows, and opening any row to
reveal a detail panel of your own making. This page ports TanStack Table's
*Expanding Feature (React) Guide*.

Expanding is the fifth stage of the [row model pipeline](/guide/row-models).
The expanded stage inserts the sub-rows of every expanded row into the row
list, so what comes out is a flat list you can render one `tr` at a time.
Group rows produced by [Grouping](/guide/grouping) are ordinary expandable
rows, so the same toggle opens and closes a group.

### Sub-rows as expanded data

Sub-rows come from your data. Tell the core row model how to reach a row's
children with
[`withSubRows`](/reference/module/Table#withSubRows), and every row gets its
children as sub-rows all the way down:

```elm snippet=Expanding.elm#config
```

`withSubRows` runs for every row and every sub-row, so keep it cheap. Elm has
no recursive type alias, so a nested record needs a custom type:

```elm snippet=Expanding.elm#nodeFields
```

### A detail panel instead of sub-rows

[`getCanExpand`](/reference/module/Table#getCanExpand) is `False` for a row
with no sub-rows. Override it with
[`withRowCanExpand`](/reference/module/Table#withRowCanExpand) when a row's
expanded content is not table rows at all but something you render yourself:

```elm snippet=Expanding.elm#detailConfig
```

Then render the panel as a second `tr` keyed off
[`getIsExpanded`](/reference/module/Table#getIsExpanded). The package has
nothing to do with what goes inside it:

```elm snippet=Expanding.elm#viewRowAndPanel
```

## State

Expanding owns one state slice. `Expanded` is an abstract type with two
cases, standing in for TanStack's `true | Record<string, boolean>`:

```elm
-- in Table.State
expanded : Expanded

-- in Table.initialState
expanded = Table.expandedIds Set.empty
```

| Value | Meaning |
| --- | --- |
| [`expandAll`](/reference/module/Table#expandAll) | Every row is expanded. TanStack's `expanded: true`. |
| [`expandedIds`](/reference/module/Table#expandedIds) | Only the rows whose ids are in this `Set String` are expanded. |

Read the slice back with
[`expandedIdsOf`](/reference/module/Table#expandedIdsOf), which is `Nothing`
for `expandAll`:

```elm snippet=Expanding.elm#expandedRowIds
```

Writing the slice directly is
[`setExpanded`](/reference/module/Table#setExpanded):

```elm snippet=Expanding.elm#expandEverything
```

```elm snippet=Expanding.elm#expandOnly
```

## Config options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableExpanding` | `Bool` | `True` | Turns expanding off for the whole table. |
| `getSubRows` | `row -> List row` | `\_ -> []` | Where a row's children come from. Set it with [`withSubRows`](/reference/module/Table#withSubRows). |
| `getRowCanExpand` | `Maybe (Row row -> Bool)` | `Nothing` | A per-row override for "can this row expand?". Set it with [`withRowCanExpand`](/reference/module/Table#withRowCanExpand). It wins over `enableExpanding` and over the "has sub-rows" rule. |
| `getIsRowExpanded` | `Maybe (Row row -> Bool)` | `Nothing` | A per-row override for "is this row expanded?". Set it with [`withIsRowExpanded`](/reference/module/Table#withIsRowExpanded). It wins over `State.expanded` outright. |
| `paginateExpandedRows` | `Bool` | `True` | With it `False`, expanded sub-rows always render on their parent's page, so a page can hold more rows than the page size. See [Pagination](/guide/pagination). |
| `manualExpanding` | `Bool` | `False` | Skip the expanded stage. [`expandedRowModel`](/reference/module/Table#expandedRowModel) returns its input unchanged, and the rows you pass in are assumed to be expanded already. |

With `paginateExpandedRows = False` the expanded stage is a pass-through and
the sub-rows are inserted by the paginated stage instead, after the page has
been sliced. That is what puts a row's descendants on the same page as the
row, and it is why
[`rowsInDisplayOrder`](/reference/module/Table#rowsInDisplayOrder), not the
page's `.rows`, is what you render. The one exception is
`manualPagination = True`: with no page slice to run in, the expansion goes
back to the expanded stage, matching TanStack.

Two options on the filtering side change which rows survive to be expanded:
`filterFromLeafRows` makes a parent survive when any descendant matches, and
`maxLeafRowFilterDepth` bounds how deep that search goes. Both are described
in [Column Filtering](/guide/column-filtering).

## Column options

Expanding has no column builders. Sub-rows are a property of the data, so
they are configured on the `Config` with
[`withSubRows`](/reference/module/Table#withSubRows), not per column.

## Transitions

| Function | Signature | Description |
| --- | --- | --- |
| [`toggleExpanded`](/reference/module/Table#toggleExpanded) | `Config row -> RowModel row -> Row row -> Maybe Bool -> State -> State` | Expand or collapse one row. `Nothing` toggles it. |
| [`toggleAllRowsExpanded`](/reference/module/Table#toggleAllRowsExpanded) | `Config row -> RowModel row -> Maybe Bool -> State -> State` | Expand or collapse every row. `Nothing` toggles on [`getIsAllRowsExpanded`](/reference/module/Table#getIsAllRowsExpanded). |
| [`setExpanded`](/reference/module/Table#setExpanded) | `Expanded -> State -> State` | Replace the slice. |
| [`resetExpanded`](/reference/module/Table#resetExpanded) | `State -> State` | Collapse everything, back to no ids. |

`toggleExpanded` takes a `RowModel` because it has to materialise
[`expandAll`](/reference/module/Table#expandAll) into the ids of the rows
that can expand before it can collapse one of them. Give it the
pre-expanded model, which is the sorted one:

```elm snippet=Expanding.elm#preExpanded
```

```elm snippet=Expanding.elm#update
```

Expanding a row that cannot expand is a no-op, and so is any request that
matches the current state. Collapsing always applies, so a stale id can be
cleaned up.

## Queries

| Function | Signature | Description |
| --- | --- | --- |
| [`getCanExpand`](/reference/module/Table#getCanExpand) | `Config row -> Row row -> Bool` | Can this row expand? |
| [`getIsExpanded`](/reference/module/Table#getIsExpanded) | `Config row -> State -> Row row -> Bool` | Is this row expanded? |
| [`getIsAllParentsExpanded`](/reference/module/Table#getIsAllParentsExpanded) | `Config row -> State -> RowModel row -> Row row -> Bool` | Is every ancestor of this row expanded? The row itself is not considered. |
| [`getCanSomeRowsExpand`](/reference/module/Table#getCanSomeRowsExpand) | `Config row -> RowModel row -> Bool` | Can any row of this model expand? |
| [`getIsSomeRowsExpanded`](/reference/module/Table#getIsSomeRowsExpanded) | `State -> Bool` | Is any row expanded? `expandAll` counts. |
| [`getIsAllRowsExpanded`](/reference/module/Table#getIsAllRowsExpanded) | `Config row -> State -> RowModel row -> Bool` | Is every expandable row expanded? An empty slice is `False`. |
| [`getExpandedDepth`](/reference/module/Table#getExpandedDepth) | `Config row -> State -> RowModel row -> Int` | The deepest expanded row id, counted in `.`-separated segments. |
| [`preExpandedRowModel`](/reference/module/Table#preExpandedRowModel) | `Config row -> State -> RowModel row -> RowModel row` | The model expansion runs on, which is the sorted one. |

The package adds no toggle UI. Write the button yourself and hide it when the
row cannot expand:

```elm snippet=Expanding.elm#viewExpander
```

The table-wide controls read the same way:

```elm snippet=Expanding.elm#viewToolbar
```

TanStack reads the pre-pagination row model for
[`getCanSomeRowsExpand`](/reference/module/Table#getCanSomeRowsExpand) so a
control can reflect rows that are not on the current page. Give it the same
model.

## Not covered

Controlled state through the `atoms` option or `state.expanded` plus
`onExpandedChange` has nothing to port: `State.expanded` is always yours.
`row.getToggleExpandedHandler` and `table.getToggleAllRowsExpandedHandler` are
not ported either, because the package produces no event handlers.

`autoResetExpanded` and `autoResetAll` are not ported. Nothing recomputes
behind your back, so collapse rows in the same `update` branch that changes
the data or the grouping, if that is what you want.

Pinning and sorting expanded rows need nothing extra: they behave exactly as
described in [Row Pinning](/guide/row-pinning) and [Sorting](/guide/sorting).

## Example

[Expanding](https://elm-table-examples.pages.dev/expanding/), ported from
TanStack's Expanding example. For the detail-panel use, see
[Expanding Sub Components](https://elm-table-examples.pages.dev/sub-components/).

<iframe src="https://elm-table-examples.pages.dev/expanding/" title="Expanding example" loading="lazy"></iframe>
