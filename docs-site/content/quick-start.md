---
title: Quick Start
id: quick-start
---

`elm-table` manages a table's state and row processing — sorting, filtering,
grouping, pagination, selection, and the rest — while you keep full control of
the markup. This page gets you from `elm install` to a rendering table, then
adds the first feature.

## Installation

```bash
elm install alexbruf/elm-table
```

## Your first table

Six steps. Every block below is one declaration from a module that compiles
as written; the whole module is at the bottom of the page.

**1. Describe your data.** Any record type works. The package never inspects
it directly, only through the accessors you give it.

```elm
type alias Person =
    { id : String
    , firstName : String
    , lastName : String
    , age : Int
    }
```

**2. Define your columns.** `Table.column` takes an id and an accessor
turning a row into a [`Value`](/guide/values). `Table.withHeader` sets the
header text.

```elm snippet=QuickStart.elm#columns
```

**3. Build the `Config`.** This is TanStack's `TableOptions`. Build it once,
at the top level of your module, not inside `view` — it holds no state, so
there is nothing to recompute.

```elm snippet=QuickStart.elm#config
```

`withGetRowId` gives each row a stable id. Without it a row's id is its index
in the data, which is fine until the data reorders.

**4. Put the `State` in your model.** `Table.initialState` is every slice at
its default: no sorting, no filters, page 0, everything visible.

```elm snippet=QuickStart.elm#init
```

**5. Run the pipeline.** `Table.rowsFromList` takes the config, the state, and
your data, and returns a `RowModel` — the processed rows plus a lookup by id.
Nothing is memoized, so a real app computes this once in `update` and stores
it; this page recomputes it so each function stays a one-liner. See
[Table State](/guide/table-state) for the storing pattern.

```elm snippet=QuickStart.elm#rowModel
```

**6. Render.** `Table.visibleLeafColumns` gives the columns to draw,
`Table.rowsInDisplayOrder` gives the rows for the current page, and
`Table.getValue` reads one cell.

```elm snippet=QuickStart.elm#view
```

```elm snippet=QuickStart.elm#viewRow
```

```elm snippet=QuickStart.elm#viewCell
```

A few things to note:

- There is no table instance and nothing to construct. `config`, `state`, and
  your data are the three arguments every function wants.
- `Table.rowsInDisplayOrder` is the list to render. It is `rowModel.rows` plus
  the expanded descendants that pagination left out when
  `Config.paginateExpandedRows` is `False`. Row pinning is separate, and lives
  in [`topRows`, `centerRows`, and `bottomRows`](/guide/row-pinning).
- `Table.getValue` returns a `Value`, not a `String`. `Value.toString` gives
  you TanStack's `String(value)` coercion; pattern match on the `Value` when
  you want your own formatting.
- Nothing here is opt-in. Sorting works because the sorting stage is always in
  the pipeline, not because you registered a feature.

## Add a feature: sorting

Sorting needs one message and one state transition. `Table.toggleSort` cycles
a column through ascending, descending, and unsorted, exactly as clicking a
TanStack header does.

```elm snippet=QuickStart.elm#update
```

The `{ desc, multi }` record is TanStack's `toggleSorting(desc, isMulti)`.
Pass `desc = Just True` to force a direction; pass `multi = True` (from a
shift-click) to add the column to the sort instead of replacing it.

`toggleSort` takes a `RowModel` because the first direction a column sorts in
can depend on the data: an unsorted column of dates starts descending, a
column of strings starts ascending, the same rule TanStack uses.

The header then reads the direction back out with `Table.getIsSorted`, which
returns `Maybe SortDir`:

```elm snippet=QuickStart.elm#viewHeader
```

Every other feature follows this pattern: a transition function that returns a
new `State`, and query functions that read the state back for rendering. See
the [Sorting](/guide/sorting) guide for custom sort functions, multi-sorting,
and per-column options.

## Wiring it up

Nothing about the package needs a `Browser.element` or a subscription, so the
whole thing runs as a sandbox:

```elm snippet=QuickStart.elm#main
```

The complete file every block above came from is
`docs-site/snippets/src/QuickStart.elm` in the repository, and a runnable
version of the same table is the
[Basic example](https://elm-table-examples.pages.dev/basic/).

## Where to go next

**Config and State.** [Config and State](/guide/config-and-state) is the
page to read next: what goes in each, and why there is no third thing.

**Table State.** [Table State](/guide/table-state) covers owning the `State`
in your model, when to store the `RowModel` alongside it, and how to reset a
slice.

**Feature guides.** Each feature has its own page:
[Column Filtering](/guide/column-filtering), [Pagination](/guide/pagination),
[Row Selection](/guide/row-selection), [Grouping](/guide/grouping),
[Column Visibility](/guide/column-visibility), and the rest.

**Examples.** Every TanStack example ported to Elm, runnable, is at
[elm-table-examples.pages.dev](https://elm-table-examples.pages.dev/), listed
on the [Examples](/examples) page.
