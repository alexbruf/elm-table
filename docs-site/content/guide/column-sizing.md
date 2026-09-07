---
title: Column Sizing
id: guide/column-sizing
---

## Column Sizing

Column sizing gives every column a width, a minimum, and a maximum, and lets
you override the width per column at runtime. The package computes numbers;
you decide what they mean in your markup, which is almost always pixels. This
page ports TanStack Table's *Column Sizing (React) Guide*.

If you want the user to drag a column edge to change a width, that is
[Column Resizing](/guide/column-resizing), which is a drag interaction built
on top of the state described here.

## State

Column sizing owns one state slice: the committed width of each column, keyed
by column id.

```elm
-- in Table.State
columnSizing : Dict String Float

-- in Table.initialState
columnSizing = Dict.empty
```

A column with no entry falls back to its own `size`, and then to the table's
`defaultColumn`. An entry is a raw number; the clamping between `minSize` and
`maxSize` happens on read, in
[`getColumnSize`](/reference/module/Table#getColumnSize), so a committed
width outside the bounds is stored as written and reported clamped.

## Config options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `defaultColumn` | `SizeDefaults` | `{ size = 150, minSize = 20, maxSize = 9007199254740991 }` | The sizing every column starts from. |

`SizeDefaults` is a plain record:

```elm
type alias SizeDefaults =
    { size : Float
    , minSize : Float
    , maxSize : Float
    }
```

`9007199254740991` is JavaScript's `Number.MAX_SAFE_INTEGER`, which is what
TanStack uses for "no maximum".

Set it with [`withDefaultColumn`](/reference/module/Table#withDefaultColumn),
which is TanStack's `tableOptions.defaultColumn`:

```elm snippet=ColumnSizing.elm#config
```

## Column options

| Builder | Type | Default | Description |
| --- | --- | --- | --- |
| [`withSize`](/reference/module/Table#withSize) | `Float -> Column row -> Column row` | `defaultColumn.size` | This column's starting width. |
| [`withMinSize`](/reference/module/Table#withMinSize) | `Float -> Column row -> Column row` | `defaultColumn.minSize` | The narrowest this column reports. |
| [`withMaxSize`](/reference/module/Table#withMaxSize) | `Float -> Column row -> Column row` | `defaultColumn.maxSize` | The widest this column reports. |

Read them back, with the config defaults already applied, using
[`columnSize`](/reference/module/Table#columnSize),
[`columnMinSize`](/reference/module/Table#columnMinSize), and
[`columnMaxSize`](/reference/module/Table#columnMaxSize). Those three are the
column definition's own numbers and ignore `State.columnSizing`;
[`getColumnSize`](/reference/module/Table#getColumnSize) is the state-aware
one and is what you render with.

A column whose `minSize` is larger than its `maxSize` reports `maxSize`. That
looks wrong and is deliberate: it is what TanStack's clamp does, and the
ported test asserts it.

## Transitions

| Function | Signature | Description |
| --- | --- | --- |
| [`setColumnSize`](/reference/module/Table#setColumnSize) | `String -> Float -> State -> State` | Commit one column's width. |
| [`setColumnSizing`](/reference/module/Table#setColumnSizing) | `Dict String Float -> State -> State` | Replace the whole map. |
| [`resetColumnSize`](/reference/module/Table#resetColumnSize) | `String -> State -> State` | Drop one column's committed width, leaving the others alone. |
| [`resetColumnSizing`](/reference/module/Table#resetColumnSizing) | `State -> State` | Drop every committed width. |

```elm snippet=ColumnSizing.elm#update
```

To start from widths you have persisted, write the map once:

```elm snippet=ColumnSizing.elm#startingWidths
```

## Queries

| Function | Signature | Description |
| --- | --- | --- |
| [`getColumnSize`](/reference/module/Table#getColumnSize) | `Config row -> State -> Column row -> Float` | The rendered width: the committed size when there is one, else the column's own size, else the default, clamped. |
| [`getColumnStart`](/reference/module/Table#getColumnStart) | `Config row -> State -> ColumnRegion -> Column row -> Float` | How far from the start of its region the column begins. |
| [`getColumnAfter`](/reference/module/Table#getColumnAfter) | `Config row -> State -> ColumnRegion -> Column row -> Float` | How far from the end of its region the column ends. |
| [`getHeaderSize`](/reference/module/Table#getHeaderSize) | `Config row -> State -> Header row -> Float` | A header's width: its column's size for a leaf header, the sum of its sub-headers for a parent header. |
| [`getHeaderStart`](/reference/module/Table#getHeaderStart) | `Config row -> State -> List (Header row) -> Header row -> Float` | How far from the start of its header row the header begins. |
| [`totalSize`](/reference/module/Table#totalSize) | `Config row -> State -> Float` | The width of the whole table: the sum of the top header row. |
| [`leftTotalSize`](/reference/module/Table#leftTotalSize) | `Config row -> State -> Float` | The width of the left-pinned region. |
| [`centerTotalSize`](/reference/module/Table#centerTotalSize) | `Config row -> State -> Float` | The width of the unpinned region. |
| [`rightTotalSize`](/reference/module/Table#rightTotalSize) | `Config row -> State -> Float` | The width of the right-pinned region. |

`getColumnStart` and `getColumnAfter` take a
[`ColumnRegion`](/guide/column-pinning#regions), which replaces TanStack's
optional `position` argument.

`getHeaderStart` takes the headers of the row the header belongs to, because a
`Header` does not point back at its header group. Pass
`group.headers` for the group you are rendering.

### Applying the widths

The numbers become inline `style "width"` attributes. Nothing in the package
writes CSS, so the unit is yours to choose:

```elm snippet=ColumnSizing.elm#px
```

```elm snippet=ColumnSizing.elm#viewHeaderCell
```

Give the table itself the total, and `table-layout: fixed` so the browser
honours the per-cell widths instead of computing its own:

```elm snippet=ColumnSizing.elm#viewTable
```

The offsets are what a [pinned](/guide/column-pinning) column needs for its
sticky position. A left-pinned column sits at `getColumnStart` from the left
edge of the left region, and a right-pinned column at `getColumnAfter` from
the right edge of the right region:

```elm snippet=ColumnSizing.elm#stickyLeft
```

```elm snippet=ColumnSizing.elm#stickyRight
```

## Not covered

TanStack's page also describes owning the `columnSizing` state through the
`atoms` option or `state.columnSizing` plus `onColumnSizingChange`. There is
nothing to port: `State.columnSizing` is always yours, held in your own
model.

`resetColumnSizing` here is TanStack's `resetColumnSizing(true)`: it empties
the map. There is no `table.initialState` to restore, so to go back to widths
you started with, call `setColumnSizing` with the map you remembered.

## Example

[Column Sizing](https://elm-table-examples.pages.dev/column-sizing/), ported
from TanStack's Column Sizing example.

<iframe src="https://elm-table-examples.pages.dev/column-sizing/" title="Column Sizing example" loading="lazy"></iframe>
