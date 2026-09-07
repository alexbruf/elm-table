---
title: Column Pinning
id: guide/column-pinning
---

## Column Pinning

Pinning holds a column against the left or right edge of the table while the
rest scroll. The state is a pair of column id lists, and the package hands you
the three column slices, the three header slices, and the three cell slices
that a pinned layout needs. This page ports TanStack Table's *Column Pinning
(React) Guide*.

There are two ways to render it, and the package supports both. Keep every
column in one table and use `position: sticky` CSS on the pinned cells, or
render the left, center, and right regions as three separate tables side by
side. The split layout is what the region functions below exist for.

### How pinning affects column order

Column order is decided in one place, and the pin split is its last step:

```text
allColumns -> State.columnOrder -> Config.groupedColumnMode -> visibility -> pin split
```

The order inside the left and right regions comes from `State.columnPinning`
itself, in the order those lists hold. `State.columnOrder` therefore only
decides the order of the unpinned ("center") columns. See [Column
Ordering](/guide/column-ordering).

## State

Column pinning owns one state slice: the ids pinned to each edge.

```elm
-- in Table.State
columnPinning : ColumnPinning

-- the type
type alias ColumnPinning =
    { left : List String
    , right : List String
    }

-- in Table.initialState
columnPinning = { left = [], right = [] }
```

TanStack calls these fields `start` and `end`, which are logical directions:
in a left-to-right layout `start` is the left edge, and in a right-to-left
layout it is the right edge. This port names them `left` and `right`, because
that is what a caller writing CSS is thinking about. The `start` / `end`
wording survives in one place only: the header ids of the per-region header
groups, which read `start_1_identity_firstName`, because the ported test
asserts those exact strings.

Ids in `left` and `right` are leaf column ids.
[`pinColumn`](/reference/module/Table#pinColumn) removes a column from both
lists before adding it to one, so it never lands in both. If you write the
record yourself and put an id in both, the left list wins.

## Config options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableColumnPinning` | `Bool` | `True` | Turns pinning off for the whole table. With it `False`, [`columnCanPin`](/reference/module/Table#columnCanPin) is `False` for every column. |

`Config` is a plain record, so you set it with a record update:
`{ config | enableColumnPinning = False }`.

## Column options

| Builder | Type | Default | Description |
| --- | --- | --- | --- |
| [`withEnablePinning`](/reference/module/Table#withEnablePinning) | `Bool -> Column row -> Column row` | `True` | Allow or forbid pinning this column. |

A group column can be pinned when at least one leaf below it allows it, and
pinning a group column pins every leaf below it.

```elm snippet=ColumnPinning.elm#config
```

## Transitions

| Function | Signature | Description |
| --- | --- | --- |
| [`pinColumn`](/reference/module/Table#pinColumn) | `ColumnPinPosition -> Column row -> State -> State` | Pin one column to an edge, or unpin it. |
| [`setColumnPinning`](/reference/module/Table#setColumnPinning) | `ColumnPinning -> State -> State` | Replace both lists at once. |
| [`resetColumnPinning`](/reference/module/Table#resetColumnPinning) | `State -> State` | Unpin every column. |

`ColumnPinPosition` is an abstract type with three values, standing in for
TanStack's `'start' | 'end' | false`:

| Value | Meaning |
| --- | --- |
| [`pinnedLeft`](/reference/module/Table#pinnedLeft) | Pinned to the left edge. TanStack's `'start'`. |
| [`pinnedRight`](/reference/module/Table#pinnedRight) | Pinned to the right edge. TanStack's `'end'`. |
| [`columnUnpinned`](/reference/module/Table#columnUnpinned) | Not pinned. TanStack's `false`. |

Wire `pinColumn` to a message that carries the position and the column:

```elm snippet=ColumnPinning.elm#update
```

To start with columns already pinned, write the state once:

```elm snippet=ColumnPinning.elm#pinnedByDefault
```

## Queries

### Regions

Most read functions come in four shapes: one per region, plus a general one
taking a `ColumnRegion`. `ColumnRegion` replaces TanStack's optional
`position` argument, which cannot be optional in Elm.

| Value | Meaning |
| --- | --- |
| [`allColumnsRegion`](/reference/module/Table#allColumnsRegion) | Every column. What TanStack means by leaving `position` out. |
| [`leftColumnsRegion`](/reference/module/Table#leftColumnsRegion) | The left-pinned columns. |
| [`centerColumnsRegion`](/reference/module/Table#centerColumnsRegion) | The unpinned columns. |
| [`rightColumnsRegion`](/reference/module/Table#rightColumnsRegion) | The right-pinned columns. |

### Per-column

| Function | Signature | Description |
| --- | --- | --- |
| [`columnCanPin`](/reference/module/Table#columnCanPin) | `Config row -> Column row -> Bool` | Can this column be pinned? |
| [`columnIsPinned`](/reference/module/Table#columnIsPinned) | `State -> Column row -> ColumnPinPosition` | Where is it pinned? A group column reports its first pinned leaf, left before right. |
| [`columnPinnedIndex`](/reference/module/Table#columnPinnedIndex) | `State -> Column row -> Int` | Its position inside its pinned region. An unpinned column gives `0`, matching TanStack. |

A pin control renders from those two:

```elm snippet=ColumnPinning.elm#pinControls
```

### Per-table

| Function | Signature | Description |
| --- | --- | --- |
| [`isSomeColumnsPinned`](/reference/module/Table#isSomeColumnsPinned) | `State -> Bool` | Is anything pinned to either edge? |
| [`isSomeColumnsPinnedLeft`](/reference/module/Table#isSomeColumnsPinnedLeft) | `State -> Bool` | Anything pinned left? |
| [`isSomeColumnsPinnedRight`](/reference/module/Table#isSomeColumnsPinnedRight) | `State -> Bool` | Anything pinned right? |

### Column lists

| Function | Signature | Description |
| --- | --- | --- |
| [`leftLeafColumns`](/reference/module/Table#leftLeafColumns) | `Config row -> State -> List (Column row)` | Left-pinned leaf columns, hidden ones included. |
| [`centerLeafColumns`](/reference/module/Table#centerLeafColumns) | `Config row -> State -> List (Column row)` | Unpinned leaf columns, in table order. |
| [`rightLeafColumns`](/reference/module/Table#rightLeafColumns) | `Config row -> State -> List (Column row)` | Right-pinned leaf columns. |
| [`pinnedLeafColumns`](/reference/module/Table#pinnedLeafColumns) | `Config row -> State -> ColumnRegion -> List (Column row)` | The same three by region. |
| [`leftVisibleLeafColumns`](/reference/module/Table#leftVisibleLeafColumns) | `Config row -> State -> List (Column row)` | Left-pinned leaf columns that are visible. |
| [`centerVisibleLeafColumns`](/reference/module/Table#centerVisibleLeafColumns) | `Config row -> State -> List (Column row)` | Visible unpinned leaf columns. |
| [`rightVisibleLeafColumns`](/reference/module/Table#rightVisibleLeafColumns) | `Config row -> State -> List (Column row)` | Right-pinned leaf columns that are visible. |
| [`pinnedVisibleLeafColumns`](/reference/module/Table#pinnedVisibleLeafColumns) | `Config row -> State -> ColumnRegion -> List (Column row)` | The same three by region. `allColumnsRegion` gives `visibleLeafColumns` unchanged. |
| [`pinnedColumns`](/reference/module/Table#pinnedColumns) | `Config row -> State -> PinnedColumns row` | All three visible slices at once, as `{ left, center, right }`. |

`PinnedColumns row` is a plain record:

```elm
type alias PinnedColumns row =
    { left : List (Column row)
    , center : List (Column row)
    , right : List (Column row)
    }
```

**[`visibleLeafColumns`](/reference/module/Table#visibleLeafColumns) is not
pin-ordered.** It keeps table order and ignores pinning entirely, exactly as
TanStack's `getVisibleLeafColumns` does. The pin partition lives in two other
places: the header seam, which is what the per-region header group functions
below build on, and
[`visibleCells`](/reference/module/Table#visibleCells), which returns the
left cells, then the center cells, then the right cells. So a one-table sticky
layout that renders headers with the header groups and cells with
`visibleCells` is already in pin order without asking for it.

### Header and footer lists

| Function | Signature |
| --- | --- |
| [`leftHeaderGroups`](/reference/module/Table#leftHeaderGroups) / [`centerHeaderGroups`](/reference/module/Table#centerHeaderGroups) / [`rightHeaderGroups`](/reference/module/Table#rightHeaderGroups) | `Config row -> State -> List (HeaderGroup row)` |
| [`leftFooterGroups`](/reference/module/Table#leftFooterGroups) / [`centerFooterGroups`](/reference/module/Table#centerFooterGroups) / [`rightFooterGroups`](/reference/module/Table#rightFooterGroups) | `Config row -> State -> List (HeaderGroup row)` |
| [`leftFlatHeaders`](/reference/module/Table#leftFlatHeaders) / [`centerFlatHeaders`](/reference/module/Table#centerFlatHeaders) / [`rightFlatHeaders`](/reference/module/Table#rightFlatHeaders) | `Config row -> State -> List (Header row)` |
| [`leftLeafHeaders`](/reference/module/Table#leftLeafHeaders) / [`centerLeafHeaders`](/reference/module/Table#centerLeafHeaders) / [`rightLeafHeaders`](/reference/module/Table#rightLeafHeaders) | `Config row -> State -> List (Header row)` |

A flat header list is every header of every row of that region; a leaf header
list is only the headers with no sub-headers. See
[Header Groups](/guide/header-groups) and [Headers](/guide/headers).

### Cell lists

| Function | Signature | Description |
| --- | --- | --- |
| [`leftVisibleCells`](/reference/module/Table#leftVisibleCells) | `Config row -> State -> Row row -> List Cell` | The row's visible cells whose column is pinned left. |
| [`centerVisibleCells`](/reference/module/Table#centerVisibleCells) | `Config row -> State -> Row row -> List Cell` | Its visible unpinned cells. |
| [`rightVisibleCells`](/reference/module/Table#rightVisibleCells) | `Config row -> State -> Row row -> List Cell` | Its visible cells pinned right. |

### Sticky layout

One table, one row, three groups of cells, each with its own class:

```elm snippet=ColumnPinning.elm#viewRow
```

The `left` and `right` CSS offsets a sticky column needs are widths, so they
come from [Column Sizing](/guide/column-sizing):
[`getColumnStart`](/reference/module/Table#getColumnStart) with
`leftColumnsRegion`, and
[`getColumnAfter`](/reference/module/Table#getColumnAfter) with
`rightColumnsRegion`.

### Split layout

Three tables, each built from one region's headers and one region's cells:

```elm snippet=ColumnPinning.elm#viewLeftTable
```

```elm snippet=ColumnPinning.elm#viewHeaderRow
```

## Not covered

TanStack's page also describes owning the `columnPinning` state through the
`atoms` option or `state.columnPinning` plus `onColumnPinningChange`. There is
nothing to port: `State.columnPinning` is always yours, held in your own
model.

`resetColumnPinning` here is TanStack's `resetColumnPinning(true)`: it clears
both lists. There is no `table.initialState` to restore, so to go back to a
pinning you started with, call `setColumnPinning` with the record you
remembered.

TanStack marks each returned cell with a `position` field. This port does not:
the lists carry the same cells unchanged, and you know the region from the
function you called.

## Example

[Column Pinning](https://elm-table-examples.pages.dev/column-pinning/),
ported from TanStack's Column Pinning example.

<iframe src="https://elm-table-examples.pages.dev/column-pinning/" title="Column Pinning example" loading="lazy"></iframe>

Two more layouts of the same feature:
[Column Pinning (Split)](https://elm-table-examples.pages.dev/column-pinning-split/)
renders the three regions as three separate tables, and
[Sticky Column Pinning](https://elm-table-examples.pages.dev/column-pinning-sticky/)
keeps them in one table with `position: sticky`.
