---
title: Row Pinning
id: guide/row-pinning
---

Row pinning keeps chosen rows in a top or a bottom region while the rest of
the rows render in the center. It is the port of TanStack Table's **Row
Pinning** guide and its `rowPinningFeature`. Nothing has to be registered:
the state slice and the functions are always there.

Pinning is a rendering split, not a pipeline stage. It does not filter or
sort anything; it decides which of three lists a row is drawn in.

## State

Row pinning stores row ids in two lists.

```elm
-- in Table.State
, rowPinning : RowPinning


type alias RowPinning =
    { top : List String
    , bottom : List String
    }


-- in Table.initialState
, rowPinning = { top = [], bottom = [] }
```

The order inside each list is the order the pinned rows render in, so
pinning is also a small ordering of its own. To pin rows from the start, put
the ids in the state you build your model with rather than in an
`initialState` table option.

## Config options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableRowPinning` | `Row row -> Bool` | `always True` | Can this row be pinned. |
| `keepPinnedRows` | `Bool` | `True` | Keep a pinned row visible even when filtering or pagination removed it from the current page. |

Both are set with a record update; `Config` is a plain record and neither has
a `with*` builder.

```elm snippet=RowPinning.elm#activeRowsOnly
```

```elm snippet=RowPinning.elm#dropFilteredOutPins
```

TanStack's `enableRowPinning` takes `boolean | ((row) => boolean)`; here the
function form covers both, and `always False` is the boolean.

## Column options

None. Row pinning is decided per row, so no column builder affects it. The
column-level counterpart is [Column Pinning](/guide/column-pinning).

## Transitions

| Transition | Type | What it does |
| --- | --- | --- |
| [`pinRow`](/reference/module/Table#pinRow) | `RowPinPosition -> Row row -> State -> State` | Pin one row to an edge, or unpin it. |
| [`pinRowWith`](/reference/module/Table#pinRowWith) | `RowPinPosition -> PinRowOptions -> RowModel row -> Row row -> State -> State` | The same, pinning the row's leaf rows or its ancestors along with it. |
| [`setRowPinning`](/reference/module/Table#setRowPinning) | `RowPinning -> State -> State` | Replace both lists. |
| [`resetRowPinning`](/reference/module/Table#resetRowPinning) | `State -> State` | Unpin everything. |

`RowPinPosition` is an abstract type with one value per case:
`Table.pinnedTop`, `Table.pinnedBottom`, and `Table.rowUnpinned`. Unpinning
is `pinRow Table.rowUnpinned`, which is TanStack's `row.pin(false)`.

```elm snippet=RowPinning.elm#update
```

`PinRowOptions` decides how much of a row's family moves with it, which
matters for grouped and expanded tables. `pinRow` uses the default, both
`False`.

```elm
type alias PinRowOptions =
    { includeLeafRows : Bool
    , includeParentRows : Bool
    }


-- Table.defaultPinRowOptions
{ includeLeafRows = False, includeParentRows = False }
```

`pinRowWith` takes a row model because that is where the ancestors and leaf
rows are looked up.

```elm snippet=RowPinning.elm#pinWithLeafRows
```

## Queries

| Query | Type | Answers |
| --- | --- | --- |
| [`getIsRowPinned`](/reference/module/Table#getIsRowPinned) | `State -> Row row -> RowPinPosition` | Where is this row pinned? |
| [`getCanPinRow`](/reference/module/Table#getCanPinRow) | `Config row -> Row row -> Bool` | Can it be pinned? |
| [`getRowPinnedIndex`](/reference/module/Table#getRowPinnedIndex) | `Config row -> State -> PinnedRowsSource row -> Row row -> Int` | Its position among the pinned rows that actually render, or `-1`. |
| [`isSomeRowsPinned`](/reference/module/Table#isSomeRowsPinned) | `State -> Bool` | Is anything pinned at either edge? |
| [`isSomeRowsPinnedTop`](/reference/module/Table#isSomeRowsPinnedTop) | `State -> Bool` | Anything pinned to the top? |
| [`isSomeRowsPinnedBottom`](/reference/module/Table#isSomeRowsPinnedBottom) | `State -> Bool` | Anything pinned to the bottom? |
| [`topRows`](/reference/module/Table#topRows) | `Config row -> State -> PinnedRowsSource row -> List (Row row)` | The rows pinned to the top, in pinning order. |
| [`bottomRows`](/reference/module/Table#bottomRows) | `Config row -> State -> PinnedRowsSource row -> List (Row row)` | The rows pinned to the bottom. |
| [`centerRows`](/reference/module/Table#centerRows) | `State -> RowModel row -> List (Row row)` | The rows of the current page that are not pinned. |

### Why the pinned lists take two row models

`PinnedRowsSource` carries both the model before the page slice and the model
of the current page.

```elm
type alias PinnedRowsSource row =
    { prePaginated : RowModel row
    , current : RowModel row
    }
```

`keepPinnedRows` is what picks between them. With it on, the default, a
pinned row is looked up by id in `prePaginated`, so it keeps rendering in its
region even when a filter or the current page would have dropped it. Its
ancestors still have to be expanded for it to show. With it off, only rows
present in `current.rows` are drawn.

`centerRows` only ever reads the current page, so it takes the page model
directly.

Build both models once per `update` and pass the pair around.

```elm snippet=RowPinning.elm#pinnedSource
```

### Rendering the three regions

The rendered order is top, then center, then bottom. There is no single
function that concatenates them, because a table that gives each region its
own `tbody` needs them apart.

```elm snippet=RowPinning.elm#displayRows
```

`getRowPinnedIndex` is a position within the region a row is pinned to, and
`-1` when the row is not pinned or is not being rendered.

```elm snippet=RowPinning.elm#pinnedRowLabel
```

### Pinning controls

`getCanPinRow` decides whether the controls appear at all, and
`getIsRowPinned` compares against a position to disable the button for the
region the row is already in.

```elm snippet=RowPinning.elm#viewPinControls
```

```elm snippet=RowPinning.elm#pinButton
```

## Not ported

- **`onRowPinningChange` and `atoms`.** Transitions return a new `State`; you
  store it.
- **`row.position`.** TanStack writes a `position` field onto the rows that
  `getTopRows` and `getBottomRows` return. The lists here hand back the rows
  unchanged, and you know the region from the function you called.
- **`resetRowPinning()` restoring an initial slice.** There is no
  `table.initialState`, so `resetRowPinning` clears both lists, matching
  TanStack's `resetRowPinning(true)`. To go back to a remembered slice, call
  `setRowPinning` with it.

## Example

[Row Pinning](https://elm-table-examples.pages.dev/row-pinning/), ported from
TanStack's Row Pinning example.

<iframe src="https://elm-table-examples.pages.dev/row-pinning/" title="Row Pinning example" loading="lazy"></iframe>
