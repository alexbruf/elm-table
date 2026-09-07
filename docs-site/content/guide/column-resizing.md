---
title: Column Resizing
id: guide/column-resizing
---

## Column Resizing

Column resizing is dragging a column edge to a new width. The package holds
the transient state of the drag, does the arithmetic, and writes the widths it
computes into `State.columnSizing`; the handle, the pointer events, and the
subscription are yours, because nothing here touches the DOM. This page ports
TanStack Table's *Column Resizing (React) Guide*.

Resizing builds on [Column Sizing](/guide/column-sizing). If you only need
starting, minimum and maximum widths, that page is enough on its own.

## Enable column resizing

Every column can be resized by default. Turn it off for the whole table with
`Config.enableColumnResizing`, or per column with
[`withEnableResizing`](/reference/module/Table#withEnableResizing):

```elm snippet=ColumnResizingGuide.elm#config
```

Ask [`columnCanResize`](/reference/module/Table#columnCanResize) or, on a
header, [`headerCanResize`](/reference/module/Table#headerCanResize) before
rendering a handle. Both are `True` only when the column and the table allow
it.

## Column resize mode

`Config.columnResizeMode` decides when a drag writes to
`State.columnSizing`.

| Mode | What happens |
| --- | --- |
| [`resizeOnChange`](/reference/module/Table#resizeOnChange) | Every pointer move commits the new widths, so the table follows the pointer. The default here. |
| [`resizeOnEnd`](/reference/module/Table#resizeOnEnd) | Moves only track the drag in `State.columnResizing`; the widths are committed when the drag ends. Draw an indicator from `deltaOffset` while it runs. |

```elm snippet=ColumnResizingGuide.elm#onEndConfig
```

TanStack defaults to `"onEnd"` because an `"onChange"` drag re-renders a whole
React table on every frame. Elm's virtual DOM diff makes that much cheaper, so
the default here is `resizeOnChange`; switch to `resizeOnEnd` for a table with
expensive cells.

## Column resize direction

`Config.columnResizeDirection` is the sign of the drag.
[`resizeLtr`](/reference/module/Table#resizeLtr), the default, grows a column
when the pointer moves right; [`resizeRtl`](/reference/module/Table#resizeRtl)
grows it when the pointer moves left, which is what a right-to-left layout
needs:

```elm snippet=ColumnResizingGuide.elm#rtlConfig
```

## State

Resizing owns one state slice, and it is transient: it is empty between drags.

```elm
-- in Table.State
columnResizing : ColumnResizingState

-- in Table.initialState
columnResizing =
    { columnSizingStart = []
    , deltaOffset = Nothing
    , deltaPercentage = Nothing
    , isResizingColumn = Nothing
    , startOffset = Nothing
    , startSize = Nothing
    }
```

| Field | What it holds |
| --- | --- |
| `columnSizingStart` | The width every leaf header under the dragged header had when the drag began, as `( column id, width )`. |
| `deltaOffset` | How far the pointer has moved from `startOffset`, with the direction's sign. |
| `deltaPercentage` | That distance as a fraction of `startSize`, floored at `-0.999999`. |
| `isResizingColumn` | The column being dragged. TanStack's `false` is `Nothing` here. |
| `startOffset` | The pointer position the drag started at. |
| `startSize` | The width of the dragged header when the drag started. |

The committed widths live in `State.columnSizing`, not here. See
[Column Sizing](/guide/column-sizing#state).

## Transitions

TanStack does the whole drag inside the closure `header.getResizeHandler()`
returns, which installs its own document listeners. That closure is three
state transitions here, and you decide which events call them.

| Function | Signature | Call it on |
| --- | --- | --- |
| [`startColumnResize`](/reference/module/Table#startColumnResize) | `Config row -> State -> Header row -> Float -> State` | `mousedown` and `touchstart`, with the event's `clientX`. |
| [`updateColumnResize`](/reference/module/Table#updateColumnResize) | `Config row -> Float -> State -> State` | Every `mousemove` and `touchmove`, with the event's `clientX`. |
| [`endColumnResize`](/reference/module/Table#endColumnResize) | `Config row -> State -> State` | `mouseup`, `touchend`, and `touchcancel`. |

`startColumnResize` records `startOffset`, `startSize`, the leaf widths, and
the column id, and does nothing at all for a column that cannot be resized.
`updateColumnResize` writes `deltaOffset` and `deltaPercentage`, and in
`resizeOnChange` mode the new widths as well. `endColumnResize` commits the
widths the last move computed and then clears the slice, so pass the ending
position through `updateColumnResize` first when the event carries one, as a
`mouseup` does. A `touchend` carries no position, so calling `endColumnResize`
alone commits the last position a move reported.

Two more transitions cover the rest of TanStack's table API:
[`setColumnResizing`](/reference/module/Table#setColumnResizing) replaces the
slice, and [`resetColumnResizing`](/reference/module/Table#resetColumnResizing)
empties it, which is `table.resetHeaderSizeInfo(true)`.

```elm snippet=ColumnResizingGuide.elm#update
```

## Connecting the transitions to your UI

### Column size APIs

The widths a drag produces are read back with the column sizing queries, which
is where the numbers for your markup come from:

```elm
Table.getHeaderSize config state header
Table.getColumnSize config state column
```

### The resize handle

The handle is a small absolutely positioned element on the trailing edge of
the header cell. `mousedown` and `touchstart` both start the drag; the touch
decoder reads `touches[0].clientX` and rounds it, the way TanStack does:

```elm snippet=ColumnResizingGuide.elm#resizeHandle
```

```elm snippet=ColumnResizingGuide.elm#clientX
```

```elm snippet=ColumnResizingGuide.elm#touchClientX
```

A double click on the handle is the usual way to give a column its default
width back, which is
[`resetColumnSize`](/reference/module/Table#resetColumnSize).

The header cell itself takes its width from
[`getHeaderSize`](/reference/module/Table#getHeaderSize):

```elm snippet=ColumnResizingGuide.elm#viewHeaderCell
```

### Following the pointer

A mouse leaves the five-pixel handle on the first move, so the moves have to
be listened for on the document. `Browser.Events` does that, and the
subscription only exists while `isResizingColumn` is set:

```elm snippet=ColumnResizingGuide.elm#subscriptions
```

Touch events need no subscription: a touch gesture keeps firing at the element
its `touchstart` hit, so `touchmove`, `touchend` and `touchcancel` stay on the
handle, as they are in the snippet above.

### A resize indicator

In `resizeOnEnd` mode the widths do not move until the drag ends, so the
feedback during the drag is an indicator offset by `deltaOffset`:

```elm snippet=ColumnResizingGuide.elm#resizeIndicator
```

[`headerIsResizing`](/reference/module/Table#headerIsResizing) and
[`columnIsResizing`](/reference/module/Table#columnIsResizing) answer "is this
the column being dragged?", which is also what a highlighted handle keys off.

## Resizing performance

TanStack's advanced section is about keeping a drag off React's render path.
The same shape works here, and buys more than it costs on a large table:

1.  **Write the widths as CSS custom properties once.** Put
    `--header-<id>-size` and `--col-<id>-size` on the table element, and give
    every cell `width: calc(var(--col-firstName-size) * 1px)`. Only one
    attribute on one element changes per drag frame.
    `Html.Attributes.style` sets a style property, which a custom property is
    not, so write the whole attribute with `Html.Attributes.attribute`:

    ```elm snippet=ColumnResizingGuide.elm#sizeVariables
    ```

2.  **Keep the body out of the drag.** Once the cells read their widths from
    the variables, the body markup no longer mentions the state, so
    `Html.Lazy` skips rebuilding it entirely while a column is dragged:

    ```elm snippet=ColumnResizingGuide.elm#viewTable
    ```

Elm does not have React's problem in the first place: an unchanged subtree
diffs to no DOM patches, so a `resizeOnChange` drag on an ordinary table is
already smooth without any of this.

## Not covered

- `header.getResizeHandler()` itself, and everything it installs: the document
  listeners, their removal, the passive-listener check, the multi-touch guard,
  and the `requestAnimationFrame` coalescing of pointer moves. Those are the
  event plumbing above, and Elm's subscriptions already deliver at most one
  message per frame's worth of pointer moves.
- Owning `columnResizing` through the `atoms` option or through
  `state.columnResizing` plus `onColumnResizingChange`. The whole `State` is
  already yours, held in your own model.
- `table.resetHeaderSizeInfo()` with no argument, which restores
  `table.initialState`. There is no table instance to hold an initial state;
  keep the slice you want to go back to and pass it to `setColumnResizing`.

## Example

[Column Resizing](https://elm-table-examples.pages.dev/column-resizing/), with
both modes and both directions, and
[Performant Column Resizing](https://elm-table-examples.pages.dev/column-resizing-performant/),
which renders the body from the CSS variables above.

<iframe src="https://elm-table-examples.pages.dev/column-resizing/" title="Column Resizing example" loading="lazy"></iframe>
