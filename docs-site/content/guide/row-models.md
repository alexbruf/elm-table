---
title: Row Models
id: guide/row-models
---

A row model is the result of running your data through one processing stage.
TanStack Table builds them from row model factories you register as slots on
a features object. `elm-table` has no features object and no slots: the six
stages are fixed, always present, and each one is an ordinary exposed
function you can call yourself.

This page is the port of TanStack's Row Models guide.

## What are row models?

Row models transform the data you passed in so the table can filter, group,
sort, expand, and paginate it. The rows you end up rendering are not a 1:1
mapping of your original data: they may be a page of a filtered and sorted
set, with group rows inserted and collapsed branches removed.

Every stage takes a `RowModel row` and returns a `RowModel row`, so the
stages compose in a plain pipeline.

## The pipeline

```text
core -> filtered -> grouped -> sorted -> expanded -> paginated
```

| Stage | Function | What it does | Skipped when |
| --- | --- | --- | --- |
| core | [`coreRowModel`](/reference/module/Table#coreRowModel), [`coreRowModelFromList`](/reference/module/Table#coreRowModelFromList) | One row per datum, sub-rows resolved, ids assigned | never |
| filtered | [`filteredRowModel`](/reference/module/Table#filteredRowModel) | Drops the rows that fail the column filters and the global filter | `Config.manualFiltering = True` |
| grouped | [`groupedRowModel`](/reference/module/Table#groupedRowModel) | Replaces the rows with group rows and computes aggregated values | `Config.manualGrouping = True` |
| sorted | [`sortedRowModel`](/reference/module/Table#sortedRowModel) | Sorts every level of the row tree | `Config.manualSorting = True` |
| expanded | [`expandedRowModel`](/reference/module/Table#expandedRowModel) | Flattens the expanded branches into the row list | `Config.manualExpanding = True` |
| paginated | [`paginatedRowModel`](/reference/module/Table#paginatedRowModel) | Keeps only the rows of the current page | `Config.manualPagination = True` |

All five `manual*` flags default to `False`, so the whole pipeline runs
unless you turn a stage off. A skipped stage returns its input unchanged.
See [Client-Side vs Server-Side](/guide/client-side-vs-server-side) for when
to set them.

There is nothing to configure and nothing to import per feature. Sorting
works because the sorting stage is in the pipeline, not because you
registered `createSortedRowModel()`.

## Running the pipeline

[`Table.rows`](/reference/module/Table#rows) runs all six stages over an
`Array`:

```elm snippet=RowModels.elm#wholePipelineFromArray
```

[`Table.rowsFromList`](/reference/module/Table#rowsFromList) is the same
thing for a `List`, which is what most Elm code has on hand:

```elm snippet=RowModels.elm#wholePipeline
```

Both are equivalent to writing the six stages out:

```elm snippet=RowModels.elm#byHand
```

## Running one stage at a time

Because each stage is its own function, you can stop wherever you like. This
counts the rows that survive filtering, without grouping, sorting, or paging
them:

```elm snippet=RowModels.elm#matchCount
```

A stage always takes the previous stage's `RowModel`, so the order above is
the only valid order. Handing `sortedRowModel` a core row model compiles, but
it sorts rows that were never filtered or grouped.

## Available row models

TanStack exposes both the stage output (`getSortedRowModel()`) and the input
to that stage (`getPreSortedRowModel()`). Here the input to a stage is just
whatever you passed in, so the "pre" accessors are thin aliases that exist to
make the intent readable at the call site.

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `getRowModel()` | [`rows`](/reference/module/Table#rows), [`rowsFromList`](/reference/module/Table#rowsFromList) | All six stages |
| `getCoreRowModel()` | [`coreRowModel`](/reference/module/Table#coreRowModel), [`coreRowModelFromList`](/reference/module/Table#coreRowModelFromList) | |
| `getPreFilteredRowModel()` | none | It is the core row model you already hold |
| `getFilteredRowModel()` | [`filteredRowModel`](/reference/module/Table#filteredRowModel) | |
| `getPreGroupedRowModel()` | [`preGroupedRowModel`](/reference/module/Table#preGroupedRowModel) | Another name for `filteredRowModel` |
| `getGroupedRowModel()` | [`groupedRowModel`](/reference/module/Table#groupedRowModel) | |
| `getPreSortedRowModel()` | none | It is `groupedRowModel`, as in TanStack |
| `getSortedRowModel()` | [`sortedRowModel`](/reference/module/Table#sortedRowModel) | |
| `getPreExpandedRowModel()` | [`preExpandedRowModel`](/reference/module/Table#preExpandedRowModel) | Another name for `sortedRowModel` |
| `getExpandedRowModel()` | [`expandedRowModel`](/reference/module/Table#expandedRowModel) | |
| `getPrePaginationRowModel()` | [`prePaginationRowModel`](/reference/module/Table#prePaginationRowModel) | Another name for `expandedRowModel` |
| `getPaginatedRowModel()` | [`paginatedRowModel`](/reference/module/Table#paginatedRowModel) | |
| `getSelectedRowModel()` | [`selectedRowModel`](/reference/module/Table#selectedRowModel) | Takes any stage's row model and keeps the selected rows |

Each "pre" function takes the row model one stage further back and applies
the stage in between, because that is what the name means. `preGroupedRowModel`
is "the row model grouping runs on", so you hand it the core row model and it
gives you the filtered one:

```elm snippet=RowModels.elm#preGrouped
```

There is no `preSortedRowModel`. TanStack's `getPreSortedRowModel()` is the
grouped row model, and here that is `groupedRowModel` under its own name:

```elm snippet=RowModels.elm#preSorted
```

TanStack's `getFilteredSelectedRowModel()` and
`getGroupedSelectedRowModel()` have no separate counterpart either. Apply
[`selectedRowModel`](/reference/module/Table#selectedRowModel) to whichever
stage output you want the selection of. See
[Row Selection](/guide/row-selection).

## The order of row model execution

```text
coreRowModel
  -> filteredRowModel
  -> groupedRowModel
  -> sortedRowModel
  -> expandedRowModel
  -> paginatedRowModel
```

This is TanStack's order, including the part that surprises people: grouping
runs before sorting, which is why TanStack's `getPreSortedRowModel()` is the
grouped model and not the filtered one. Rows are filtered, then grouped, then
sorted, then expanded, and paged last.

## Row model data structure

`RowModel row` is a plain record with three views of the same rows:

```elm
type alias RowModel row =
    { rows : List (Row row)
    , flatRows : List (Row row)
    , rowsById : Dict String (Row row)
    }
```

- `rows` is the tree: root rows only, each carrying its children in
  `rowSubRows`. This is the list you render from.
- `flatRows` has every row at the top level, sub-rows included. Use it to
  count or scan without walking the tree.
- `rowsById` is the lookup by row id.
  [`Table.findRow`](/reference/module/Table#findRow) reads it for you.

The record is not opaque, so `model.rows` works and so does record update.
The rows inside it are opaque; read them with the functions on
[Rows](/guide/rows).

Two stages hand back the row map of the stage before them rather than
rebuilding it, matching TanStack: the sorted and paginated models carry the
pre-stage `rowsById`.

## The rows you render

`paginatedRowModel.rows` is the current page, but it is not always the exact
list to draw. [`Table.rowsInDisplayOrder`](/reference/module/Table#rowsInDisplayOrder)
is:

```elm snippet=RowModels.elm#displayRows
```

With the default `Config.paginateExpandedRows = True` it returns
`model.rows` unchanged. With `paginateExpandedRows = False` the page counts
only root rows, and the expanded descendants that pagination did not carry
are inserted here. See [Expanding](/guide/expanding).

Row pinning is applied separately, not by `rowsInDisplayOrder`. Pinned rows
come from [`topRows`](/reference/module/Table#topRows) and
[`bottomRows`](/reference/module/Table#bottomRows), the rest from
[`centerRows`](/reference/module/Table#centerRows). See
[Row Pinning](/guide/row-pinning).

## Nothing is memoized

TanStack caches each row model and recomputes it only when its inputs change.
This package has no table instance to hang a cache on, so every call
recomputes from the `Config`, the `State`, and your data.

That makes the calling pattern important: compute the row model once per
`update` and store it in your model, rather than calling `Table.rowsFromList`
from several places in `view`.

```elm
type alias Model =
    { state : Table.State
    , data : List Person
    , rowModel : Table.RowModel Person
    }
```

```elm snippet=RowModels.elm#refresh
```

Every transition then reads the stored row model and refreshes it once:

```elm snippet=RowModels.elm#update
```

[Table State](/guide/table-state) covers this pattern in full, including
which transitions want which stage's row model.

## Customize/fork row models

TanStack tells you to copy a row model factory's source and modify it. Here
you do not have to fork anything: call the stages yourself and put your own
step between two of them.

A stage is just `RowModel row -> RowModel row`. This one drops inactive
people after filtering and before grouping:

```elm snippet=RowModels.elm#isActive
```

```elm snippet=RowModels.elm#rowModelOf
```

```elm snippet=RowModels.elm#withOwnStage
```

`rowModelOf` rebuilds all three fields of the record. That is the part to get
right: a step that changes `rows` must also narrow `flatRows` and `rowsById`,
or the later stages and every `findRow` lookup will disagree with what you
render. The version above is correct for a flat row model; with sub-rows,
build `flatRows` by walking `rowSubRows`.

## Faceted row models

Faceting answers "what values could the user pick here", so a column's facet
list has to ignore that column's own filter while respecting the others.
[`Table.facetedRowModel`](/reference/module/Table#facetedRowModel) takes the
pre-filtered row model, which is the core row model you handed to
`filteredRowModel`, and a column id:

```elm snippet=RowModels.elm#departmentOptions
```

```elm snippet=RowModels.elm#salaryRange
```

TanStack's three faceting slots map to three functions:

| TanStack | elm-table |
| --- | --- |
| `createFacetedRowModel()` | [`facetedRowModel`](/reference/module/Table#facetedRowModel) |
| `createFacetedUniqueValues()` | [`facetedUniqueValues`](/reference/module/Table#facetedUniqueValues) |
| `createFacetedMinMaxValues()` | [`facetedMinMax`](/reference/module/Table#facetedMinMax) |

Passing [`globalFacetKey`](/reference/module/Table#globalFacetKey) as the
column id excludes the global filter instead of a column filter. Full details
are in [Faceting](/guide/column-faceting).

## Manual stages

Setting a `manual*` flag makes that stage a pass-through, which is how you
hand the work to a server:

```elm snippet=RowModels.elm#serverSideConfig
```

The state slices still work the same way. Your `update` reads
`State.sorting` and `State.pagination`, sends a request, and puts the rows
the server returned into the model. `Config.pageCount` and `Config.rowCount`
let you report totals the client cannot count. See
[Client-Side vs Server-Side](/guide/client-side-vs-server-side).

## Not ported

**Function registries.** TanStack's `filterFns`, `sortFns`, and
`aggregationFns` slots register functions under string names so a column def
can say `filterFn: 'fuzzy'`. There are no registries here: you pass the
function value itself to `Table.withFilterFn`, `Table.withSortFn`, or
`Table.withAggregationFn`, and `getFilterFn` / `getSortFn` hand the function
back. The `'auto'` string has a counterpart in
[`getAutoFilterFn`](/reference/module/Table#getAutoFilterFn),
[`getAutoSortFn`](/reference/module/Table#getAutoSortFn), and
[`getAutoAggregationFn`](/reference/module/Table#getAutoAggregationFn), which
sample the data and return a real function.

**Row model slots.** There is no `tableFeatures()` call, so nothing to
register and no bundle-size reason to leave a stage out.
