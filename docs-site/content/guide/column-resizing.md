---
title: Column Resizing
id: guide/column-resizing
---

## Column Resizing

TanStack Table's *Column Resizing (React) Guide* is about `columnResizeMode`,
`columnResizeDirection`, `header.getResizeHandler()`, and the transient
`columnSizing` drag state. None of that is ported. Resizing a column by
dragging its edge is a DOM interaction: it needs mouse and touch events,
element positions, and a pointer capture, and this package touches no DOM. So
there is no resize feature here, no resize state slice, no config option, no
column option, and no query.

What is ported is everything a resize writes to. A column's width is state,
and that state is [Column Sizing](/guide/column-sizing). A drag is your own
`Html.Events` wiring that ends in one
[`setColumnSize`](/reference/module/Table#setColumnSize) call. This page shows
that wiring.

## Writing the drag yourself

A mouse-driven resize is three messages and one piece of your own model.

**Hold the drag in your model.** You need the column being resized, the
pointer position the drag started at, and the width it started at. Everything
else is arithmetic.

```elm
type alias Drag =
    { columnId : String
    , startX : Float
    , startWidth : Float
    }


type alias Model =
    { state : Table.State
    , drag : Maybe Drag
    }


type Msg
    = ResizeStarted String Float
    | ResizeMoved Float
    | ResizeEnded
```

**Start the drag on `mousedown`.** The handle is a small absolutely
positioned element on the trailing edge of the header cell. The decoder reads
`clientX` off the event:

```elm snippet=ColumnResizing.elm#resizeHandle
```

```elm snippet=ColumnResizing.elm#clientX
```

**Read the starting width from the table.**
[`getColumnSize`](/reference/module/Table#getColumnSize) is the width the
column is currently rendering at, whether it comes from `State.columnSizing`,
the column's own `size`, or the table default:

```elm snippet=ColumnResizing.elm#currentWidth
```

**Follow the pointer with a subscription.** Listening on the document rather
than on the handle is what keeps the drag alive when the pointer leaves the
5-pixel handle, which it does immediately:

```elm snippet=ColumnResizing.elm#subscriptions
```

**Commit the new width in `update`.** The whole interaction reduces to
`startWidth + (currentX - startX)`:

```elm snippet=ColumnResizing.elm#update
```

You do not have to clamp the result. `getColumnSize` clamps between the
column's `minSize` and `maxSize` on read, so a drag past either bound is
stored as written and rendered at the bound. Set those bounds with
[`withMinSize`](/reference/module/Table#withMinSize) and
[`withMaxSize`](/reference/module/Table#withMaxSize).

For touch support, add `Html.Events.on "touchstart"` and
`Html.Events.on "touchmove"` handlers reading `touches[0].clientX`, or use a
port to a `pointerdown` / `pointermove` listener, which handles mouse, touch,
and pen in one path.

## Resize mode

TanStack's `columnResizeMode` chooses when `column.getSize()` starts returning
the new width: `"onChange"` updates it on every drag frame, `"onEnd"` only
when the drag finishes. Here that is not an option, it is where you put the
`setColumnSize` call:

| TanStack mode | What you write |
| --- | --- |
| `"onChange"` | Call `setColumnSize` in the `ResizeMoved` branch, as above. The table re-renders at every frame. |
| `"onEnd"` | Keep the running delta in your `Drag` record, render a preview line from it, and call `setColumnSize` once in the `ResizeEnded` branch. |

`"onEnd"` exists in TanStack mainly to avoid re-rendering a large React table
on every frame. Elm's virtual DOM diff is cheap enough that `"onChange"` is a
reasonable default, but a table with expensive cells will still be smoother
with the `"onEnd"` shape.

## Resize direction

TanStack's `columnResizeDirection` flips the sign of the delta for
right-to-left layouts. There is no such option here; in an RTL layout,
subtract the delta instead of adding it.

## Not covered

Everything else on TanStack's page depends on the resize feature existing:

- `header.getResizeHandler()`, `column.getCanResize()`, and
  `column.getIsResizing()`. The package produces no event handlers and tracks
  no drag, so write the handler above and read "is this column being resized?"
  off your own `Drag`.
- The `columnResizing` state object (`deltaOffset`, `deltaPercentage`,
  `isResizingColumn`, `startOffset`, `startSize`, `columnSizingStart`) and
  `table.setColumnResizing`. Your `Drag` record is that state, holding only
  the fields you actually use.
- `enableColumnResizing` and the per-column `enableResizing`. Decide whether
  to render a handle in your own view code.
- The advanced performance section, which is about CSS variables, React
  memoization, and keeping a drag off React's render path. None of it
  transfers.

## Example

The column widths this page writes are the ones the
[Column Sizing example](https://elm-table-examples.pages.dev/column-sizing/)
renders, with min and max clamping visible. There is no drag example: the drag
is DOM code, not table code.
