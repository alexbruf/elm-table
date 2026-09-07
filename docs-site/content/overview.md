---
title: Overview
id: overview
---

`elm-table` is a headless table library for Elm 0.19.1: an Elm port of
[TanStack Table](https://tanstack.com/table) core. It gives you the state,
the row processing, and the query functions for a table or datagrid, and it
gives you no markup at all. You write the `Html`.

The package renders nothing, holds no state of its own, uses no ports, and
calls no JavaScript. Every function has the shape `Config row -> State ->
...`, so two tables on one page never share anything by accident, and every
state change is a plain value you can inspect, log, store, or test.

## What is "headless" UI?

**Headless UI** is the name for a library that supplies the logic, the state,
and the data processing behind a piece of UI but no markup and no styles. The
hard parts of a table are sorting, filtering, grouping, pagination, and the
bookkeeping that ties them together. A headless library takes those and
leaves the rendering to you, so the look of the table is entirely yours.

With a prebuilt Elm table component you pass a record of options in and hope
its styling hooks reach the thing you want to change. With `elm-table` you
hold a `State`, run your data through the pipeline, and write the `Html.table`
yourself:

```elm snippet=QuickStart.elm#view
```

## The shape of the API

TanStack Table builds a *table instance*: an object that owns the options,
the state, the cached row models, and a few hundred methods. Elm has no good
place to put a mutable object like that, so this port has none. Three values
stand in for it.

| TanStack | elm-table | What it is |
| --- | --- | --- |
| `TableOptions` | `Config row` | The columns and every option, built once at the top level. |
| `TableState` | `State` | Every state slice, owned by your model. |
| `table.getRowModel()` | `Table.rows config state data` | The processed rows, recomputed when you ask for them. |

Everything else is a function that takes some of those three. There is no
`table.` prefix and nothing to construct.

## The pipeline

Rows go through six stages, always in this order:

```
core → filtered → grouped → sorted → expanded → paginated
```

`Table.rows` runs all six. Each stage is also exposed on its own
(`Table.filteredRowModel`, `Table.sortedRowModel`, and so on) so you can stop
early, look at an intermediate `RowModel`, or splice in a stage of your own.
See [Row Models](/guide/row-models).

## Features

Every feature of TanStack Table core is ported. Follow a link for the guide.

- [Cell Selection](/guide/cell-selection) — select spreadsheet-style rectangular ranges of cells
- [Cell Spanning](/guide/cell-spanning) — merge adjacent body cells across rows or columns
- [Column Filtering](/guide/column-filtering) — filter rows by a search value for one column
- [Column Grouping](/guide/grouping) — group rows by one or more column values
- [Column Ordering](/guide/column-ordering) — change the order of columns
- [Column Pinning](/guide/column-pinning) — freeze columns to the left or right of the table
- [Column Resizing](/guide/column-resizing) — the sizing state a drag handle writes to
- [Column Sizing](/guide/column-sizing) — change the width of columns
- [Column Visibility](/guide/column-visibility) — hide and show columns
- [Faceting](/guide/column-faceting) — list the unique values or the min and max of a column
- [Global Filtering](/guide/global-filtering) — filter rows by one search value across every column
- [Row Aggregation](/guide/aggregation) — roll up values for grouped rows
- [Row Expanding](/guide/expanding) — expand and collapse sub-rows
- [Row Pagination](/guide/pagination) — slice rows into pages
- [Row Pinning](/guide/row-pinning) — freeze rows to the top or bottom of the table
- [Row Selection](/guide/row-selection) — select and deselect rows
- [Row Sorting](/guide/sorting) — sort rows by column values

Three TanStack pages have no counterpart here and are listed on
[Features](/guide/features) with the reason: devtools, `flexRender`, and the
custom-feature plugin system.

## Composition

Because you own the markup, the messages, and the state, the package composes
with the rest of your app rather than boxing it in.

- **Your own state.** `State` is a plain record in your model. Put a slice of
  it in the URL, seed it from a flag, diff it, or write it back from a
  decoder. Nothing is hidden.
- **Your own stages.** Set `manualSorting`, `manualFiltering`,
  `manualGrouping`, `manualExpanding`, or `manualPagination` and that stage
  returns its input unchanged, so the server can do the work instead. See
  [Client-Side vs Server-Side](/guide/client-side-vs-server-side).
- **Your own rendering.** Pair it with
  [`dominikmayer/elm-virtual-list`](https://package.elm-lang.org/packages/dominikmayer/elm-virtual-list/latest/)
  for long lists, or with plain `Html.Lazy`. See
  [Virtualization](/guide/virtualization).

## Get started

- [Installation](/installation)
- [Quick Start](/quick-start)
- [Kitchen Sink example](https://elm-table-examples.pages.dev/kitchen-sink/) — every feature on one table
- [Migrating from TanStack](/migrating) if you already know the JavaScript API
