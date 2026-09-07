---
title: Cell API
id: reference/cell-api
---

TanStack's Cell API Reference covers the cell object and the context a cell renderer is handed. elm-table has no renderers, so a cell is only data: [`Cell`](/reference/module/Table#Cell) is a four-field record of `id`, `columnId`, `rowId`, and `value`, computed on demand from a row. Everything a renderer would ask a cell about is a separate function that takes the cell. This page maps TanStack's entries onto ours; full signatures and doc comments live on the generated [`Table` module page](/reference/module/Table). For prose, see [Cells](/guide/cells).

## Types

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `Cell` | [`Cell`](/reference/module/Table#Cell) | A plain record: `id`, `columnId`, `rowId`, `value`. Build the list for a row with [`visibleCells`](/reference/module/Table#visibleCells). |
| `CellContext` | — | No render context. A `Cell` carries its own ids and value, and the queries below take the `Config`, `State`, or row model they need. |
| `CellData` | [`Value`](/reference/module/Table-Value#Value) | TanStack's cell data is `unknown`. Here every cell value is one of the `Value` constructors; see [Values](/guide/values). |
| `constructCell` | [`getAllCells`](/reference/module/Table#getAllCells) | Cells come from a row, one per leaf column. There is no single-cell constructor. |
| `AppCellContext` | — | React-only. No render context here either. |

## Building the cells of a row

| Value | What it returns |
| --- | --- |
| [`getAllCells`](/reference/module/Table#getAllCells) | One cell per leaf column, in leaf column order. Hidden columns are included. |
| [`visibleCells`](/reference/module/Table#visibleCells) | The cells whose column is visible: left-pinned first, then the unpinned cells in table order, then the right-pinned ones. |
| [`visibleCellsByColumnId`](/reference/module/Table#visibleCellsByColumnId) | The same cells keyed by column id, for a renderer that walks columns rather than cells. |
| [`leftVisibleCells`](/reference/module/Table#leftVisibleCells) | The visible cells pinned left, in pinning-state order. |
| [`centerVisibleCells`](/reference/module/Table#centerVisibleCells) | The visible cells whose column is not pinned. |
| [`rightVisibleCells`](/reference/module/Table#rightVisibleCells) | The visible cells pinned right, in pinning-state order. |

## Grouping and aggregation queries

These three decide what a cell of a group row renders. They take the row and the column id rather than a `Cell`, because that is all they need.

| Query | What it answers |
| --- | --- |
| [`cellIsGrouped`](/reference/module/Table#cellIsGrouped) | Is this the cell of the column its group row groups by? |
| [`cellIsAggregated`](/reference/module/Table#cellIsAggregated) | Is this cell an aggregated one? True on a group row for a column that is neither the row's own grouping column nor itself grouped, and that has an aggregation function. |
| [`cellIsPlaceholder`](/reference/module/Table#cellIsPlaceholder) | Is this the cell of a grouped column that is not this row's own grouping column? Those cells render as placeholders. |

See [Grouping](/guide/grouping) and [Aggregation](/guide/aggregation).

## Cell selection queries

Each takes a `Cell`. The reads that resolve a selection need a [`SelectionRows`](/reference/module/Table#SelectionRows), which is the pre-pagination row model together with the page you render, because a range can span pages.

| Query | What it answers |
| --- | --- |
| [`cellCanSelect`](/reference/module/Table#cellCanSelect) | Can this cell currently be selected? A column opting out wins over the table option. |
| [`cellIsSelected`](/reference/module/Table#cellIsSelected) | Does this cell fall inside the final positive selection? |
| [`cellIsFocused`](/reference/module/Table#cellIsFocused) | Is this the active cell, the anchor of the most recent range? |
| [`cellTabIndex`](/reference/module/Table#cellTabIndex) | `0` for the focused cell and `-1` otherwise, for a roving tabindex. |
| [`cellSelectionEdges`](/reference/module/Table#cellSelectionEdges) | Which sides of this cell sit on the outer boundary of the selection, so you can draw one border around a block. |

See [Cell Selection](/guide/cell-selection).

## Cell spanning queries

Each takes a [`CellSpanIndex`](/reference/module/Table#CellSpanIndex), built once per render with [`cellSpanIndex`](/reference/module/Table#cellSpanIndex), and a `Cell`.

| Query | What it answers |
| --- | --- |
| [`cellRowSpan`](/reference/module/Table#cellRowSpan) | How many rows this cell spans: `1` when it does not span, `0` when a spanning cell above covers it. |
| [`cellColSpan`](/reference/module/Table#cellColSpan) | How many columns this cell spans: `1` when it does not span, `0` when another cell's column span covers it. |
| [`cellIsCovered`](/reference/module/Table#cellIsCovered) | Does another cell's span cover this cell? Covered cells carry no content and must not be rendered. |

See [Cell Spanning](/guide/cell-spanning).
