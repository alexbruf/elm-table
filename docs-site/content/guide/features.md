---
title: Features
id: guide/features
---

This page is the Elm counterpart of TanStack Table's **Features Guide**. In
TanStack v9 a table declares the capabilities it uses with a `tableFeatures({...})`
call, and each feature it registers adds its own state, options, and APIs to the
table instance. That page explains what to register and why.

There is nothing to register here. Every feature in this package is a set of
plain functions on `Table.Config`, `Table.State`, and the row model, and they are
all available the moment you `import Table`.

## Why There Is No `features` Option

TanStack's `features` option exists to keep bundles small. A plugin that is not
registered is not imported, so its code is not shipped, and its APIs do not
appear in the TypeScript types either.

Elm gets the same result from the compiler. `elm make --optimize` drops every
function your program never calls, so an unused feature costs nothing at
runtime and nothing in the build. That removes the registration step, and with
it the type errors TanStack raises when a row model is registered without its
feature.

One consequence is worth knowing. [`Table.rows`](/reference/module/Table#rows)
runs all six pipeline stages, so it references all six, and the compiler keeps
them. Calling only the stages you want keeps the rest out of the build:

```elm snippet=Features.elm#sortedOnly
```

See [Row Models](/guide/row-models) for the stages and what each one does.

## Features, Row Models, and Functions Are Separate

TanStack draws a line between three things: a feature (state and APIs), a row
model (the client-side work), and a function registry (named sort, filter, and
aggregation implementations). The same line exists here, drawn differently.

- **State and transitions.** Every feature owns one slice of `Table.State` and
  a set of `... -> State -> State` transitions. They work whether or not the
  matching pipeline stage runs.
- **Pipeline stages.** The six stages, in order, are core, filtered, grouped,
  sorted, expanded, paginated. Each is a function from a `RowModel` to a
  `RowModel`. A `manual*` flag on the `Config` skips its stage and passes the
  rows through untouched, which is how you hand the work to a server. See
  [Client-Side vs Server-Side](/guide/client-side-vs-server-side).
- **Functions.** A `SortFn`, `FilterFn`, or `AggregationFn` is a value you pass
  to a column builder, not a string looked up in a registry. There is no
  registry to include or tree-shake, and no name that can be spelled wrong.

Nothing is opt-in. Sorting works because the sorted stage is always part of the
pipeline, not because you registered `rowSortingFeature`:

```elm snippet=Features.elm#config
```

```elm snippet=Features.elm#rowModel
```

## The Feature List

These are TanStack's stock features and where each one lives here.

| TanStack feature | Guide | What it is |
| --- | --- | --- |
| `cellSelectionFeature` | [Cell Selection](/guide/cell-selection) | Rectangular cell ranges, keyboard navigation, and the focused cell. |
| `cellSpanningFeature` | [Cell Spanning](/guide/cell-spanning) | Cells that span rows or columns. |
| `columnFacetingFeature` | [Faceting](/guide/column-faceting) | Unique values, counts, and min/max ranges for building filter controls. |
| `columnFilteringFeature` | [Column Filtering](/guide/column-filtering) | Per-column filters and the filtered stage. |
| `columnGroupingFeature` | [Grouping](/guide/grouping) | Group rows by one or more column values. |
| `columnOrderingFeature` | [Column Ordering](/guide/column-ordering) | The order columns are drawn in. |
| `columnPinningFeature` | [Column Pinning](/guide/column-pinning) | Columns held to the left or right edge. |
| `columnResizingFeature` | [Column Resizing](/guide/column-resizing) | Turning a drag into a new column width. |
| `columnSizingFeature` | [Column Sizing](/guide/column-sizing) | Column widths, minimums, maximums, and offsets. |
| `columnVisibilityFeature` | [Column Visibility](/guide/column-visibility) | Showing and hiding columns. |
| `globalFilteringFeature` | [Global Filtering](/guide/global-filtering) | One filter value applied across columns. |
| `rowAggregationFeature` | [Aggregation](/guide/aggregation) | The values a group row reports for its children. |
| `rowExpandingFeature` | [Expanding](/guide/expanding) | Which rows show their sub-rows. |
| `rowPaginationFeature` | [Pagination](/guide/pagination) | Page index, page size, and the paginated stage. |
| `rowPinningFeature` | [Row Pinning](/guide/row-pinning) | Rows held at the top or bottom. |
| `rowSelectionFeature` | [Row Selection](/guide/row-selection) | Selected row ids, including sub-row rules. |
| `rowSortingFeature` | [Sorting](/guide/sorting) | Sort state, multi-sorting, and the sorted stage. |

Two more pages match TanStack's, and neither is a feature there either.
[Fuzzy Filtering](/guide/fuzzy-filtering) is a recipe built from filtering and
sorting. [Virtualization](/guide/virtualization) is a rendering technique that
lives outside the package.

TanStack's `stockFeatures` bundle, which registers all of the above at once,
has no counterpart: everything above is already available.

## What TanStack Has That This Package Does Not

Five parts of TanStack Table have no Elm counterpart. Each one exists because
of something that is not true here.

- **Devtools.** TanStack's devtools panel inspects a live table instance. There
  is no instance to inspect. `Config`, `State`, and `RowModel` are ordinary
  values, so you can print one, store it, or compare two.
- **`flexRender`.** In TanStack a `cell` or `header` option can be a string, a
  value, or a component, and `flexRender` decides how to render whichever one
  it was given. In Elm you write the `Html` yourself from the cell value, so
  there is nothing to dispatch on. See [Cells](/guide/cells).
- **Custom features and plugins.** A TanStack plugin attaches new state and new
  methods to the table instance. With no instance, there is nothing to attach
  to. A behaviour this package does not have is a function you write over the
  `RowModel` it returns.
- **Table and column meta.** `meta` is a place to hang your own typed data on a
  table or a column so a render function can read it back off the instance.
  Keep that data in your own model and read it there; column ids are strings you
  can key a `Dict` by.
- **Type helpers.** `createColumnHelper`, `createTableHook`, and the registry
  types exist to recover type information TypeScript cannot infer on its own.
  Elm infers the row type from your accessors, so `Table.column` needs no helper
  and no type parameters beyond `row`. See
  [Column Definitions](/guide/column-defs).

## Where to Go Next

[Config and State](/guide/config-and-state) covers the two values every feature
reads. [Table State](/guide/table-state) covers owning the `State` in your
model. Each feature guide above follows the same shape: the state slice, the
config and column options, the transitions, and the queries used while
rendering.
