---
title: Cell Selection
id: guide/cell-selection
---

Cell selection tracks spreadsheet-style rectangular selections: a cell, a
block dragged across, a Shift-extended range, and further rectangles added or
subtracted with Ctrl or Cmd. It is the port of TanStack Table's **Cell
Selection** guide and its `cellSelectionFeature`.

Selections are stored as ranges of ids, not as a set of cells, so a selection
of ten thousand cells is a few records. Everything else, including which
cells are actually inside the selection, is derived on read.

When a column merges cells, see [Cell Spanning](/guide/cell-spanning): a
selection rectangle grows to enclose any merged cell it touches, so a merge
is always entirely selected or entirely unselected.

```elm snippet=CellSelection.elm#config
```

Selection is keyed by row id and column id, so give rows stable ids with
`Table.withGetRowId` for the same reason as in
[Row Selection](/guide/row-selection).

## State

The slice is an ordered list of range operations.

```elm
-- in Table.State
, cellSelection : List CellSelectionRange


type alias CellSelectionRange =
    { anchorColumnId : String
    , anchorRowId : String
    , focusColumnId : String
    , focusRowId : String
    , operation : CellSelectionOperation
    }


-- in Table.initialState
, cellSelection = []
```

The anchor corner is where the selection started and stays put; the focus
corner is the one that moves while dragging or Shift-extending. Keeping both
corners, rather than a normalized rectangle, is what makes "extend from where
I started" possible.

Ranges apply in order. `Table.includeCells` adds its rectangle,
`Table.excludeCells` subtracts it, so "everything except these two cells" is
three small records rather than a list of every selected cell. TanStack's
`operation` field is optional and defaults to an inclusion; here it is
required, and [`cellRange`](/reference/module/Table#cellRange) builds an
inclusion.

Because ranges store ids, sorting, filtering, and column reordering keep the
corners pinned and recompute what falls between them. Hiding a column that a
corner sits on makes the range inert: nothing renders as selected, the range
stays in state, and it comes back when the column is shown again.

## Config options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableCellSelection` | `Bool` | `True` | Can cells be selected at all. |
| `cellSelectionFilter` | `Maybe (Cell -> Bool)` | `Nothing` | Decide per cell. When set, it replaces the boolean. |
| `enableCellRangeSelection` | `Bool` | `True` | Can a selection be extended into a range, which is what Shift-click and drag do. |
| `enableMultiCellRangeSelection` | `Bool` | `True` | Can further rectangles be added or subtracted, which is what Ctrl-click and Cmd-click do. |

TanStack's `enableCellSelection` takes `boolean | ((cell) => boolean)`. The
two are separate fields here, and the distinction is real:
`withCellSelection False` makes `selectAllCells` a no-op, while a predicate
that always answers `False` does not.

| Builder | Sets |
| --- | --- |
| [`withCellSelection`](/reference/module/Table#withCellSelection) | `enableCellSelection` |
| [`withCellSelectionWhen`](/reference/module/Table#withCellSelectionWhen) | `cellSelectionFilter` |
| [`withCellRangeSelection`](/reference/module/Table#withCellRangeSelection) | `enableCellRangeSelection` |
| [`withMultiCellRangeSelection`](/reference/module/Table#withMultiCellRangeSelection) | `enableMultiCellRangeSelection` |

```elm snippet=CellSelection.elm#salaryColumnOnly
```

## Column options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableCellSelection` | `Bool` | `True` | Can this column's cells be selected. `False` wins over the table option. |

Set it with
[`withEnableCellSelection`](/reference/module/Table#withEnableCellSelection).
This is the usual way to keep a checkbox or actions column out of a
selection.

```elm snippet=CellSelection.elm#columns
```

A cell that cannot be selected is skipped even when a rectangle is drawn
straight through it, and `moveCellSelection` steps over its column instead of
landing on it.

## Transitions

| Transition | Type | What it does |
| --- | --- | --- |
| [`selectCell`](/reference/module/Table#selectCell) | `Config row -> Cell -> State -> State` | Start a selection at one cell, replacing what was selected. |
| [`extendCellSelectionTo`](/reference/module/Table#extendCellSelectionTo) | `Config row -> Cell -> State -> State` | Move the active range's focus corner to this cell, keeping its anchor. |
| [`toggleCellSelection`](/reference/module/Table#toggleCellSelection) | `Config row -> SelectionRows row -> Cell -> State -> State` | Add a rectangle at this cell, or subtract one when the cell is already selected. |
| [`moveCellSelection`](/reference/module/Table#moveCellSelection) | `Config row -> SelectionRows row -> CellDirection -> State -> State` | Collapse the selection to a single cell one step away. |
| [`extendCellSelection`](/reference/module/Table#extendCellSelection) | `Config row -> SelectionRows row -> CellDirection -> State -> State` | Move the focus corner one step, keeping the anchor. |
| [`setFocusedCell`](/reference/module/Table#setFocusedCell) | `String -> String -> State -> State` | Collapse the selection to one named cell. |
| [`selectAllCells`](/reference/module/Table#selectAllCells) | `Config row -> SelectionRows row -> State -> State` | Select every selectable cell as one range. |
| [`selectCellRange`](/reference/module/Table#selectCellRange) | `CellSelectionRange -> State -> State` | Select a rectangle, replacing the selection. |
| [`selectCellRangeWith`](/reference/module/Table#selectCellRangeWith) | `CellSelectionMode -> CellSelectionRange -> State -> State` | The same with replace, include, or exclude semantics. |
| [`setCellSelection`](/reference/module/Table#setCellSelection) | `List CellSelectionRange -> State -> State` | Replace the whole slice. |
| [`clearCellSelection`](/reference/module/Table#clearCellSelection) | `State -> State` | Drop every range. |

`CellSelectionMode` is abstract, with `Table.replaceSelection`,
`Table.includeSelection`, and `Table.excludeSelection`. `CellDirection` is
abstract too: `Table.cellUp`, `Table.cellDown`, `Table.cellLeft`, and
`Table.cellRight`.

```elm snippet=CellSelection.elm#selectAllOfOneColumn
```

### The two row models

Most transitions and every query take a `SelectionRows`, which carries the
model before the page slice and the model of the current page.

```elm
type alias SelectionRows row =
    { prePaginated : RowModel row
    , current : RowModel row
    }
```

`prePaginated` fixes the display-order indexes a range resolves against, so a
range spans pages and lights up correctly on whichever page you are viewing.
`current` is the page you render, which bounds keyboard navigation and cell
spanning. Without pagination the two are the same model.

```elm snippet=CellSelection.elm#selectionRows
```

### Mouse interactions

TanStack has `cell.getSelectionStartHandler()` and
`cell.getSelectionExtendHandler()`, which attach their own document-level
`mouseup` listener and keep a drag flag on the table instance. None of that
exists here. You map your own `onMouseDown`, `onMouseEnter`, and `onKeyDown`
to the transitions above, and you own the "is the button still down" flag.

```elm snippet=CellSelection.elm#init
```

A `mousedown` picks one of three transitions from the modifier keys: plain is
`selectCell`, Shift is `extendCellSelectionTo`, and Ctrl or Cmd is
`toggleCellSelection`.

```elm snippet=CellSelection.elm#mouseDown
```

A `mouseenter` extends the active range, but only while a drag is in
progress; that guard is the flag in your model, since `extendCellSelectionTo`
itself does not know a drag from a click.

```elm snippet=CellSelection.elm#update
```

Shift and the platform modifier come off the event.

```elm snippet=CellSelection.elm#modifiersDecoder
```

`withCellRangeSelection False` makes `extendCellSelectionTo` select the cell
instead of extending, and `withMultiCellRangeSelection False` does the same
for `toggleCellSelection`, so the handlers above stay as they are when either
is switched off.

### Keyboard navigation

Arrow keys move, Shift and an arrow extend, and Escape clears. Nothing here
listens for keys on your behalf; decode them and send a `Msg`.

```elm snippet=CellSelection.elm#arrowKey
```

```elm snippet=CellSelection.elm#keyMsg
```

Bind the decoder to the table element rather than the document, or arrow keys
and Escape will take over inputs elsewhere on the page.

## Queries

| Query | Type | Answers |
| --- | --- | --- |
| [`cellCanSelect`](/reference/module/Table#cellCanSelect) | `Config row -> Cell -> Bool` | Can this cell be selected? |
| [`cellIsSelected`](/reference/module/Table#cellIsSelected) | `Config row -> State -> SelectionRows row -> Cell -> Bool` | Is it inside the final positive selection? |
| [`cellIsFocused`](/reference/module/Table#cellIsFocused) | `State -> Cell -> Bool` | Is it the active cell? |
| [`cellTabIndex`](/reference/module/Table#cellTabIndex) | `State -> Cell -> Int` | `0` for the focused cell, `-1` otherwise. |
| [`cellSelectionEdges`](/reference/module/Table#cellSelectionEdges) | `Config row -> State -> SelectionRows row -> Cell -> CellSelectionEdges` | Which of its sides sit on the selection boundary. |
| [`focusedCell`](/reference/module/Table#focusedCell) | `Config row -> State -> SelectionRows row -> Maybe Cell` | The active cell itself. |
| [`cellSelectionBounds`](/reference/module/Table#cellSelectionBounds) | `Config row -> State -> SelectionRows row -> List CellSelectionBounds` | The selection as disjoint index rectangles. |
| [`cellSelectionMergeBounds`](/reference/module/Table#cellSelectionMergeBounds) | `Config row -> State -> SelectionRows row -> List CellSelectionBounds` | The merged-cell rectangles in the same index space. |
| [`cellSelectionColumnIndexes`](/reference/module/Table#cellSelectionColumnIndexes) | `Config row -> State -> Dict String Int` | The render-order index of every visible column id. |
| [`selectedCellIds`](/reference/module/Table#selectedCellIds) | `Config row -> State -> SelectionRows row -> List String` | The ids of the selected cells, in row-major order. |
| [`selectedCellCount`](/reference/module/Table#selectedCellCount) | `Config row -> State -> SelectionRows row -> Int` | How many cells are selected; a merge counts once. |
| [`selectedCellRangesData`](/reference/module/Table#selectedCellRangesData) | `Config row -> State -> SelectionRows row -> List (List (List Value))` | Each positive region's values as a row-major grid. |
| [`cellSelectionRowIds`](/reference/module/Table#cellSelectionRowIds) | `Config row -> State -> SelectionRows row -> List String` | The rows the selection touches. |
| [`cellSelectionColumnIds`](/reference/module/Table#cellSelectionColumnIds) | `Config row -> State -> SelectionRows row -> List String` | The columns it touches. |

`CellSelectionBounds` is a rectangle of inclusive display-order indexes:
rows are positions in the pre-pagination display order, columns are positions
in the visible leaf columns in render order.

```elm
type alias CellSelectionBounds =
    { minRowIndex : Int
    , maxRowIndex : Int
    , minColumnIndex : Int
    , maxColumnIndex : Int
    }
```

Nothing is memoized, so a query costs what it computes. Call the cheap ones
per cell and the enumerating ones (`selectedCellIds`,
`selectedCellRangesData`) once, when you actually need the list.

```elm snippet=CellSelection.elm#selectionSummary
```

### Render cell selection UI

`cellSelectionEdges` gives `{ top, right, bottom, left }`, where a side is
`True` when the neighbour in that direction is not itself selected. That is
what draws one continuous outline around a selection, including around a
union of separate rectangles, without any cell inspecting its neighbours.

```elm snippet=CellSelection.elm#cellClass
```

```elm snippet=CellSelection.elm#edgeClasses
```

The cell element carries the class, the roving tab index, and the two mouse
handlers. `Table.Cell` is a plain record, so `cell.value` is the value to
render and `cell.columnId` and `cell.rowId` are its coordinates.

```elm snippet=CellSelection.elm#viewCell
```

Draw the outline with `box-shadow: inset ...` rather than `border`. On a
`border-collapse` table a thicker border widens the shared grid line, so rows
change height as cells become selected.

### Copying a selection

`selectedCellRangesData` returns raw values indexed as region, then row, then
column. A region is one of the final disjoint positive rectangles after every
include and exclude is applied. Turning that into clipboard text is your
decision, because the delimiter, the representation of `Null`, and any
quoting rules are yours.

```elm snippet=CellSelection.elm#selectionAsTsv
```

Elm cannot write to the clipboard on its own; send the string out through a
port.

### Geometry helpers

The rectangle algebra the feature uses is exposed, for building your own
selection tools on top of `CellSelectionBounds`.

| Function | Type |
| --- | --- |
| [`intersectCellSelectionBounds`](/reference/module/Table#intersectCellSelectionBounds) | `CellSelectionBounds -> CellSelectionBounds -> Maybe CellSelectionBounds` |
| [`subtractCellSelectionBounds`](/reference/module/Table#subtractCellSelectionBounds) | `CellSelectionBounds -> CellSelectionBounds -> List CellSelectionBounds` |
| [`addCellSelectionBounds`](/reference/module/Table#addCellSelectionBounds) | `List CellSelectionBounds -> CellSelectionBounds -> List CellSelectionBounds` |
| [`mergeAdjacentCellSelectionBounds`](/reference/module/Table#mergeAdjacentCellSelectionBounds) | `List CellSelectionBounds -> List CellSelectionBounds` |
| [`expandCellSelectionBounds`](/reference/module/Table#expandCellSelectionBounds) | `CellSelectionBounds -> List CellSelectionBounds -> CellSelectionBounds` |
| [`applyCellSelectionBoundsOperations`](/reference/module/Table#applyCellSelectionBoundsOperations) | `List ( CellSelectionOperation, CellSelectionBounds ) -> List CellSelectionBounds` |

`applyCellSelectionBoundsOperations` is the whole pipeline in one call: run
ordered includes and excludes and get back disjoint rectangles.
`expandCellSelectionBounds` is the step that grows a rectangle until it
contains every merged cell it touches.

## Not ported

- **Handlers and the drag session.** `getSelectionStartHandler`,
  `getSelectionExtendHandler`, the document `mouseup` listener,
  `enableCellSelectionDrag`, and the instance's `_isSelectingCells` flag have
  no counterpart. You wire the events and keep the flag.
- **`isCellRangeSelectionEvent` and `isMultiCellRangeSelectionEvent`.** Your
  own decoder decides which transition a click means, so there is no event
  predicate to override.
- **The deprecated `additive` option.** `selectCellRangeWith` with a
  `CellSelectionMode` is the only form.
- **`autoResetCellSelection`.** Nothing resets when the data changes. If new
  data can reuse row ids, call `clearCellSelection` when you replace it.
- **`resetCellSelection()` restoring an initial slice.** There is no
  `table.initialState`; `clearCellSelection` is TanStack's
  `resetCellSelection(table, true)`, and `setCellSelection` restores a slice
  you kept.
- **`table.Subscribe` and the render-performance section.** Elm's virtual DOM
  handles the re-render, and there are no getters hiding a state dependency.
  If a large table feels slow, compute the row models once per `update` and
  store them rather than rebuilding them per cell.

## Example

[Cell Selection](https://elm-table-examples.pages.dev/cell-selection/), ported from
TanStack's Cell Selection example.

<iframe src="https://elm-table-examples.pages.dev/cell-selection/" title="Cell Selection example" loading="lazy"></iframe>
