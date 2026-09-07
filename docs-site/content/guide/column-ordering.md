---
title: Column Ordering
id: guide/column-ordering
---

## Column Ordering

Columns render in the order you defined them in `Table.config`.
`State.columnOrder` overrides that with an explicit list of column ids, which
is what a "move this column left" button or a drag-and-drop header row writes.
This page ports TanStack Table's *Column Ordering (React) Guide*.

Column order is not only yours to set. [Grouping](/guide/grouping) can move a
grouped column to the front, [Column Visibility](/guide/column-visibility)
drops hidden columns, and [Column Pinning](/guide/column-pinning) splits the
result into three regions. All of that happens in a fixed sequence, described
next.

### What affects column order

One function, [`orderColumns`](/reference/module/Table#orderColumns), applies
the ordering rules, and every leaf column list, header list, and cell list in
the package goes through it. The sequence is:

```text
allColumns -> State.columnOrder -> Config.groupedColumnMode -> visibility -> pin split
```

Reading that left to right:

1. **`allColumns`** is the columns as defined, each group column before its
   children.
2. **`State.columnOrder`** reorders them. Ids you list come first, in your
   order; columns you leave out keep their definition order behind the listed
   ones.
3. **`Config.groupedColumnMode`** moves grouped columns to the front, removes
   them, or leaves them alone. This is the only place that rule lives, in
   [`orderGroupedColumns`](/reference/module/Table#orderGroupedColumns), so a
   grouped column is never moved twice.
4. **Visibility** drops the hidden columns, giving
   [`visibleLeafColumns`](/reference/module/Table#visibleLeafColumns).
5. **The pin split** partitions that list into left, center, and right. It
   happens in the header builder and in
   [`visibleCells`](/reference/module/Table#visibleCells), not inside
   `orderColumns`.

TanStack's page lists pinning first. The rendered result is the same: because
left and right columns are ordered by `State.columnPinning` itself, your
`columnOrder` only decides the order of the unpinned ("center") columns.

Ordering composing in one place is the reason headers, columns, and cells
never disagree. If you write your own column list, run it through
`orderColumns` and you get the same order the package uses everywhere else.

## State

Column ordering owns one state slice: the column ids you want, in the order
you want them.

```elm
-- in Table.State
columnOrder : List String

-- in Table.initialState
columnOrder = []
```

An empty list means definition order. The list is a preference, not a
constraint: ids that match no column are ignored, duplicates are dropped, and
columns you leave out are appended behind the ones you listed. So
`[ "age" ]` on a three-column table means "age first, then the rest as
defined".

## Config options

Column ordering adds no `Config` field of its own. One field of
[Grouping](/guide/grouping) is applied by `orderColumns`, so it belongs here
too:

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `groupedColumnMode` | `GroupedColumnMode` | `groupedColumnsReorder` | What the leaf column list does with a grouped column: move it to the front, drop it, or leave it. |

`Config` is a plain record, so you set it with a record update:
`{ config | groupedColumnMode = Table.groupedColumnsIgnore }`.

## Column options

None. There is no per-column builder for ordering; a column's position comes
entirely from `State.columnOrder` and the rules above.

## Transitions

| Function | Signature | Description |
| --- | --- | --- |
| [`setColumnOrder`](/reference/module/Table#setColumnOrder) | `List String -> State -> State` | Replace `State.columnOrder`. |
| [`resetColumnOrder`](/reference/module/Table#resetColumnOrder) | `State -> State` | Empty `State.columnOrder`, restoring definition order. |

Both are the whole API for changing the order. A "move one column earlier"
button reads the current rendered order, swaps two ids, and writes the result
back:

```elm snippet=ColumnOrdering.elm#update
```

The current order is whatever `orderColumns` produces, which is the right
starting point even when `State.columnOrder` is still empty:

```elm snippet=ColumnOrdering.elm#renderedOrder
```

`swapEarlier` is ordinary list code with nothing table-specific in it:

```elm snippet=ColumnOrdering.elm#swapEarlier
```

## Queries

| Function | Signature | Description |
| --- | --- | --- |
| [`orderColumns`](/reference/module/Table#orderColumns) | `Config row -> State -> List (Column row) -> List (Column row)` | Put a column list in table order: `State.columnOrder`, then the grouped-column rules. TanStack's `getOrderColumnsFn`. |
| [`orderGroupedColumns`](/reference/module/Table#orderGroupedColumns) | `Config row -> State -> List (Column row) -> List (Column row)` | Apply `Config.groupedColumnMode` alone. TanStack's `orderColumns`. |
| [`columnIndex`](/reference/module/Table#columnIndex) | `Config row -> State -> ColumnRegion -> Column row -> Int` | The column's position in one region of the visible leaf columns, or `-1`. |
| [`columnIsFirst`](/reference/module/Table#columnIsFirst) | `Config row -> State -> ColumnRegion -> Column row -> Bool` | Is it the first visible column of that region? |
| [`columnIsLast`](/reference/module/Table#columnIsLast) | `Config row -> State -> ColumnRegion -> Column row -> Bool` | Is it the last visible column of that region? |

The last three take a `ColumnRegion`, which replaces TanStack's optional
`position` argument. Pass
[`allColumnsRegion`](/reference/module/Table#allColumnsRegion) where TanStack
would pass nothing, or
[`leftColumnsRegion`](/reference/module/Table#leftColumnsRegion),
[`centerColumnsRegion`](/reference/module/Table#centerColumnsRegion), or
[`rightColumnsRegion`](/reference/module/Table#rightColumnsRegion) to ask
about one pinned region. See [Column Pinning](/guide/column-pinning).

`columnIsFirst` and `columnIsLast` are what you want for the border or shadow
on the edge of a region:

```elm snippet=ColumnOrdering.elm#viewHeaderCell
```

`columnIndex` answers the same question as a number, which is what a drop
target needs:

```elm snippet=ColumnOrdering.elm#positionLabel
```

## Drag and drop reordering

The package has no drag-and-drop code, and no opinion about which approach you
use: a drag ends in one `setColumnOrder` call, and everything before that is
your own `Html.Events` wiring or a port to a JavaScript drag library. The
[Column DnD example](https://elm-table-examples.pages.dev/column-dnd/) does it
with native HTML5 drag events and no dependencies.

## Not covered

TanStack's page also describes owning the `columnOrder` state through the
`atoms` option or `state.columnOrder` plus `onColumnOrderChange`. There is
nothing to port: `State.columnOrder` is always yours, held in your own model.

`resetColumnOrder` here is TanStack's `resetColumnOrder(true)`: it clears the
slice. There is no `table.initialState` to restore, so to go back to an order
you started with, call `setColumnOrder` with the list you remembered.

## Example

[Column Ordering](https://elm-table-examples.pages.dev/column-ordering/),
ported from TanStack's Column Ordering example.

<iframe src="https://elm-table-examples.pages.dev/column-ordering/" title="Column Ordering example" loading="lazy"></iframe>
