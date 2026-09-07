---
title: Column Visibility
id: guide/column-visibility
---

## Column Visibility

Column visibility hides and shows columns at runtime, which is what a "choose
columns" menu writes. Hidden columns disappear from the column lists, the
header groups, and the cells of every row, so a table rendered through the
"visible" functions needs no other change. This page ports TanStack Table's
*Column Visibility (React) Guide*.

## State

Column visibility owns one state slice: a map from column id to whether that
column shows.

```elm
-- in Table.State
columnVisibility : Dict String Bool

-- in Table.initialState
columnVisibility = Dict.empty
```

The map is sparse. A column is hidden only when its id is in the map with the
value `False`. An id that is absent, or present with `True`, shows. An empty
map therefore means everything shows, which is why `initialState` starts
there.

Keys are leaf column ids. A group column has no entry of its own; hiding a
group column writes an entry for every hideable leaf below it.

## Config options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableHiding` | `Bool` | `True` | Turns hiding off for the whole table. With it `False`, [`columnCanHide`](/reference/module/Table#columnCanHide) is `False` for every column. |

`Config` is a plain record, so you set it with a record update:
`{ config | enableHiding = False }`.

## Column options

| Builder | Type | Default | Description |
| --- | --- | --- | --- |
| [`withEnableHiding`](/reference/module/Table#withEnableHiding) | `Bool -> Column row -> Column row` | `True` | Allow or forbid hiding this column. |

An id column or a row-selection checkbox column is the usual case for
`withEnableHiding False`:

```elm snippet=ColumnVisibility.elm#config
```

## Transitions

| Function | Signature | Description |
| --- | --- | --- |
| [`toggleColumnVisibility`](/reference/module/Table#toggleColumnVisibility) | `Config row -> Column row -> Maybe Bool -> State -> State` | Show or hide one column. `Nothing` flips it. |
| [`setColumnVisibility`](/reference/module/Table#setColumnVisibility) | `Dict String Bool -> State -> State` | Replace the whole map. |
| [`resetColumnVisibility`](/reference/module/Table#resetColumnVisibility) | `State -> State` | Empty the map, showing every column again. |
| [`toggleAllColumnsVisible`](/reference/module/Table#toggleAllColumnsVisible) | `Config row -> Maybe Bool -> State -> State` | Show or hide every leaf column. `Nothing` flips on the current state. Columns that cannot hide stay visible. |

The `Maybe Bool` is TanStack's optional `value` argument: `Just True` shows,
`Just False` hides, `Nothing` flips.

```elm snippet=ColumnVisibility.elm#update
```

To start with a column already hidden, write the map once:

```elm snippet=ColumnVisibility.elm#startHidden
```

## Queries

| Function | Signature | Description |
| --- | --- | --- |
| [`columnIsVisible`](/reference/module/Table#columnIsVisible) | `State -> Column row -> Bool` | Does this column show? |
| [`columnCanHide`](/reference/module/Table#columnCanHide) | `Config row -> Column row -> Bool` | May it be hidden? Both the table and the column have to allow it. |
| [`isAllColumnsVisible`](/reference/module/Table#isAllColumnsVisible) | `Config row -> State -> Bool` | Is every leaf column visible? |
| [`isSomeColumnsVisible`](/reference/module/Table#isSomeColumnsVisible) | `Config row -> State -> Bool` | Is at least one leaf column visible? |
| [`visibleLeafColumns`](/reference/module/Table#visibleLeafColumns) | `Config row -> State -> List (Column row)` | The leaf columns to render, in table order. |
| [`visibleFlatColumns`](/reference/module/Table#visibleFlatColumns) | `Config row -> State -> List (Column row)` | Every column, group columns included, minus the hidden ones. |
| [`visibleCells`](/reference/module/Table#visibleCells) | `Config row -> State -> Row row -> List Cell` | One row's cells whose column is visible, in render order. |
| [`visibleCellsByColumnId`](/reference/module/Table#visibleCellsByColumnId) | `Config row -> State -> Row row -> Dict String Cell` | The same cells keyed by column id. |

### A column menu

`columnIsVisible` sets the checkbox, `columnCanHide` disables it, and
`toggleColumnVisibility` is the message it sends:

```elm snippet=ColumnVisibility.elm#viewToggle
```

`isAllColumnsVisible` and `isSomeColumnsVisible` drive the "toggle all" box at
the top of the list:

```elm snippet=ColumnVisibility.elm#viewToggleAll
```

```elm snippet=ColumnVisibility.elm#viewToggles
```

### A visibility-aware body

[`allColumns`](/reference/module/Table#allColumns) and
[`getAllCells`](/reference/module/Table#getAllCells) ignore visibility, which
is what you want in a column menu and not what you want in a table body. Use
`visibleLeafColumns` for the columns and `visibleCells` for the cells:

```elm snippet=ColumnVisibility.elm#viewRow
```

[`headerGroups`](/reference/module/Table#headerGroups) and the per-region
header functions already account for visibility, so a header rendered from
them needs no filtering of its own. See
[Header Groups](/guide/header-groups).

`visibleCells` also applies the [pinning](/guide/column-pinning) split: left
cells, then unpinned cells, then right cells.

## Not covered

TanStack's page also describes owning the `columnVisibility` state through the
`atoms` option or `state.columnVisibility` plus `onColumnVisibilityChange`.
There is nothing to port: `State.columnVisibility` is always yours, held in
your own model.

`column.getToggleVisibilityHandler` has no counterpart, because the package
produces no event handlers. Write `onClick (ToggleColumn column)` yourself, as
above.

`resetColumnVisibility` here is TanStack's `resetColumnVisibility(true)`: it
empties the map. There is no `table.initialState` to restore, so to go back to
a visibility you started with, call `setColumnVisibility` with the map you
remembered.

## Example

[Column Visibility](https://elm-table-examples.pages.dev/column-visibility/),
ported from TanStack's Column Visibility example.

<iframe src="https://elm-table-examples.pages.dev/column-visibility/" title="Column Visibility example" loading="lazy"></iframe>
