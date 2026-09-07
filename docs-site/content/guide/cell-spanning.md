---
title: Cell Spanning
id: guide/cell-spanning
---

Cell spanning merges adjacent body cells into one rendered cell, the way
`rowspan` and `colspan` merge cells in a plain HTML table or a spreadsheet.
Row spans come from the data: adjacent rows that share a value in an opted-in
column merge into one vertically spanning cell. Column spans are declared per
row, for things like a full-width summary row. It is the port of TanStack
Table's **Cell Spanning** guide and its `cellSpanningFeature`.

Spans are always computed from the rows you are about to render, so sorting,
filtering, pagination, and row pinning simply change which rows are adjacent
and the spans follow.

## State

None. Cell spanning stores nothing in `Table.State`, has no transitions, and
nothing to reset.

What it does have is an index. TanStack rebuilds `getCellSpanIndex()` behind
a memo; nothing here is memoized, and rebuilding the index once per cell
would be quadratic, so the index is a value you build and pass around.

```elm
cellSpanIndex : Config row -> State -> RowModel row -> CellSpanIndex
```

Build it once, from the row model you actually render, then read every cell's
spans out of it. Row pinning is read off the state, so a run never crosses a
pinned section boundary.

## Config options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableCellSpanning` | `Bool` | `True` | Allow spanning for the whole table. `False` makes every cell report a span of `1` and builds no index. |

Set it with
[`withCellSpanning`](/reference/module/Table#withCellSpanning).

```elm snippet=CellSpanning.elm#spanningOff
```

## Column options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableCellSpanning` | `Bool` | `True` | Take this column out of spanning even when the table allows it. |
| `spanRows` | `Maybe (SpanRows row)` | `Nothing` | How this column merges adjacent rows. |
| `spanColumns` | `Maybe (Row row -> Int)` | `Nothing` | How many columns this column's cell covers in a given row. |

| Builder | Sets | Notes |
| --- | --- | --- |
| [`withEnableCellSpanning`](/reference/module/Table#withEnableCellSpanning) | `enableCellSpanning` | A column opting out wins over the table option. |
| [`withSpanRows`](/reference/module/Table#withSpanRows) | `spanRows` | TanStack's `spanRows: true`: merge adjacent rows with equal values. |
| [`withSpanRowsWhen`](/reference/module/Table#withSpanRowsWhen) | `spanRows` | The predicate form. |
| [`withSpanColumns`](/reference/module/Table#withSpanColumns) | `spanColumns` | The count is resolved per row. |

### Row spanning per column

`withSpanRows` merges adjacent rows whose value for the column is equal.

```elm snippet=CellSpanning.elm#columns
```

`Null` never merges, since a merged block of blanks reads as a rendering bug
and joins rows that have nothing to do with each other. Two other differences
from TanStack follow from Elm's `==` rather than JavaScript's `Object.is`:
`NaN` never merges with itself, and `-0` merges with `0`.

`withSpanRowsWhen` takes control of where a run ends. The run is anchored:
every candidate row is tested against the run's first row, which keeps runs
transitive by construction.

```elm
type alias RowSpanContext row =
    { anchorRow : Row row
    , anchorValue : Value
    , previousRow : Row row
    , row : Row row
    , value : Value
    }
```

```elm snippet=CellSpanning.elm#salaryBandColumn
```

```elm snippet=CellSpanning.elm#sameSalaryBand
```

TanStack's context also carries `column` and `table`. Neither exists here:
there is no table instance, and the column is fixed by the call site that
installed the predicate.

### Column spanning and summary rows

`withSpanColumns` declares horizontal spans on the column that carries the
merged content. The count is measured in the order columns actually render,
so hidden columns are not counted and reordering is handled for you.

```elm snippet=CellSpanning.elm#summarySpan
```

[`spanAllColumns`](/reference/module/Table#spanAllColumns) is the stand-in
for TanStack's `Infinity`. A span larger than the room available is clamped
to the end of the cell's pinned region, so it never crosses the boundary
between left-pinned, center, and right-pinned columns.

When a cell spans rows and columns at once, the merged block is a rectangle:
the anchor cell reports both spans and every other cell in it reports `0` on
at least one axis. Cells only join a vertical run when their column spans
match, so a full-width summary row never merges into the data run above it.

## Transitions

None. Nothing about spanning is stored, so there is nothing to transition.
The one thing to recompute is the index, which you rebuild whenever the rows
you render change.

## Queries

| Query | Type | Answers |
| --- | --- | --- |
| [`cellSpanIndex`](/reference/module/Table#cellSpanIndex) | `Config row -> State -> RowModel row -> CellSpanIndex` | The spans of the rows you are rendering. |
| [`cellRowSpan`](/reference/module/Table#cellRowSpan) | `CellSpanIndex -> Cell -> Int` | How many rows this cell spans: `1` normally, `0` when covered. |
| [`cellColSpan`](/reference/module/Table#cellColSpan) | `CellSpanIndex -> Cell -> Int` | How many columns it spans, same convention. |
| [`cellIsCovered`](/reference/module/Table#cellIsCovered) | `CellSpanIndex -> Cell -> Bool` | Is it covered by another cell's span? |
| [`cellSpanIndexRowIds`](/reference/module/Table#cellSpanIndexRowIds) | `CellSpanIndex -> List String` | The row ids the index was built from, in render order. |
| [`cellSpanIndexRowSpans`](/reference/module/Table#cellSpanIndexRowSpans) | `CellSpanIndex -> Dict String (List Int)` | The vertical runs per column id, indexed by render-order row position. |
| [`columnCanSpan`](/reference/module/Table#columnCanSpan) | `Config row -> Column row -> Bool` | Does this column take part in spanning? |

Only columns with at least one run longer than one row appear in
`cellSpanIndexRowSpans`; a missing column means every cell in it spans one
row.

```elm snippet=CellSpanning.elm#spanningColumnIds
```

### Rendering spanned cells

A covered cell reports a span of `0` and must be skipped. Never render
`rowspan="0"`: in HTML that means "span to the end of the row group", which
merges the cell down the whole `tbody`. `cellIsCovered` is the check for both
axes at once.

```elm snippet=CellSpanning.elm#viewBody
```

```elm snippet=CellSpanning.elm#viewRow
```

```elm snippet=CellSpanning.elm#viewCell
```

A cell whose row is not in the index reports `1`. TanStack rejects a stale
row by object identity; the index here keys by row id, so a row that is no
longer rendered simply has no entry.

### Spanning, sorting, filtering, and pagination

Spans are derived from the row model you pass, never stored, so every change
to it recomputes them.

- Sorting changes adjacency. Sorting by the spanned column clusters equal
  values and gives the longest runs; sorting by another column usually breaks
  them apart.
- Filtering removes rows. When a filter takes out the middle of a run, the
  remaining neighbours become adjacent and merge.
- Pagination clips runs. A run never crosses a page boundary; the next page
  opens a fresh cell even when the value continues.
- Pinned rows render in their own sections, so a run never crosses a pinned
  section boundary either.

### Selecting merged cells

[Cell Selection](/guide/cell-selection) composes with spanning. A selection
rectangle grows to enclose every merged cell it touches, so a merge is always
entirely selected or entirely unselected, subtractions included. Arrow-key
navigation treats a merge as one stop,
[`selectedCellCount`](/reference/module/Table#selectedCellCount) counts it
once, and [`selectedCellIds`](/reference/module/Table#selectedCellIds)
returns only the cells that render.
[`selectedCellRangesData`](/reference/module/Table#selectedCellRangesData)
still returns the full row-major grid, because covered cells carry real
values.

The expansion happens when the bounds are derived, not when the selection is
stored, so stored corners stay put while sorting, paging, or turning spanning
off changes which cells merge.

## Known limitations

- Row virtualization needs care: if a run's anchor row is scrolled out of the
  rendered window, the covered rows render nothing. Read
  `cellSpanIndexRowSpans` to find the anchor and render a clamped span at the
  top of the window. See [Virtualization](/guide/virtualization).
- Grouped columns ignore `spanRows`, since [Grouping](/guide/grouping)
  already collapses repeated values into group rows, and a group row never
  joins a run in any column.
- Footer groups are unaffected by cell spanning.

## Not ported

Nothing from TanStack's page is missing, but two things are shaped
differently: `spanRows: true` is `withSpanRows` and its predicate form is
`withSpanRowsWhen`, and the memoized `table.getCellSpanIndex()` is the
explicit `cellSpanIndex` value described above.

## Example

[Cell Spanning](https://elm-table-examples.pages.dev/cell-spanning/), ported from
TanStack's Cell Spanning example.

<iframe src="https://elm-table-examples.pages.dev/cell-spanning/" title="Cell Spanning example" loading="lazy"></iframe>
