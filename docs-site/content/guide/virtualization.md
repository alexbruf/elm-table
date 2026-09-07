---
title: Virtualization
id: guide/virtualization
---

## Virtualization

Virtualization renders only the rows inside the scroll viewport, plus a small
buffer, so a table of fifty thousand rows keeps a few dozen elements in the
DOM. It is a rendering strategy, not a table feature, and this package does
none of it: it has no scroll position, no element heights, and no DOM. This
page ports TanStack Table's *Virtualization (React) Guide*.

TanStack pairs its table with TanStack Virtual. There is no single Elm
package that plays the same role for both axes. For a vertical list of rows,
[`FabienHenon/elm-infinite-list-view`](https://package.elm-lang.org/packages/FabienHenon/elm-infinite-list-view/latest/)
owns the scroll container, the item offsets, and the visible window; the
[Virtualized Rows](https://elm-table-examples.pages.dev/virtualized-rows/)
and
[Infinite Scrolling](https://elm-table-examples.pages.dev/virtualized-infinite-scrolling/)
examples use it. It has no horizontal mode, so the
[Virtualized Columns](https://elm-table-examples.pages.dev/virtualized-columns/)
example windows both axes by hand instead, from three numbers this package
already gives you: `getColumnStart`, `getColumnSize`, and `totalSize`. This
page describes the seam between this package and either approach; the
virtual list package's own documentation covers its side, and the hand-rolled
approach is shown in full below.

Virtualization is not a replacement for server-side paging. The rows still
have to be in the browser. If the dataset is too large to load, see
[Client-Side vs Server-Side](/guide/client-side-vs-server-side).

## State

Virtualization owns no state slice, no config option, no column option, no
transition, and no query. Everything below uses functions that belong to
other guides.

## Pagination runs by default

Every table built from this package runs the full six-stage pipeline unless
you turn a stage off, and the last stage is pagination, with a default page
size of 10. A virtual list handed a page of ten rows has nothing to
virtualize: it will render all ten, and the scroll bar will describe a page
rather than the table. Before wiring up a virtual list, decide how you are
going to stop pagination from cutting the row count a second time.

### Bypassing pagination

Two ways to get every row instead of one page:

Set the page size to
[`unlimitedPageSize`](/reference/module/Table#unlimitedPageSize), which is
what TanStack writes as `Infinity`. The pipeline still runs the paginated
stage, but that stage puts every row on page zero:

```elm snippet=VirtualizationGuide.elm#everyRowOnOnePage
```

Or stop the pipeline one stage earlier, at
[`prePaginationRowModel`](/reference/module/Table#prePaginationRowModel),
and never call
[`paginatedRowModel`](/reference/module/Table#paginatedRowModel) at all:

```elm snippet=VirtualizationGuide.elm#stopBeforePagination
```

Either way the point is the same: the virtual list has to see every row that
sorting, filtering, and grouping produced, or its scroll height is wrong.

## Feeding rows to the virtual list

[`rowsInDisplayOrder`](/reference/module/Table#rowsInDisplayOrder) runs the
whole pipeline up to `prePaginationRowModel` and hands back a plain
`List (Row row)`, in the order they display. That is exactly the input a
virtual list indexes into, with no adapter in between:

```elm snippet=VirtualizationGuide.elm#rowsToVirtualize
```

A virtual list keys its rendered items so the browser can reuse DOM elements
across scroll frames rather than tearing them down and rebuilding them. Give
rows real ids with
[`withGetRowId`](/reference/module/Table#withGetRowId), shown on `config`
above, then read them back with
[`rowId`](/reference/module/Table#rowId):

```elm snippet=VirtualizationGuide.elm#rowKeys
```

Without `withGetRowId` a row's id is its position in the data, so ids move
when the data reorders, and a virtual list keyed on them reuses the wrong
element for the wrong row.

## Keep the row model in your model, not in view

`view` runs on every scroll event, because scrolling is what changes which
rows a virtual list decides to render. Running the pipeline itself — sorting,
filtering, grouping fifty thousand rows — inside `view` would repeat that
work on every one of those events for no reason, since none of it depends on
the scroll position.

Run the pipeline once, in `update`, and store its result in your model. The
[Virtualized Rows](https://elm-table-examples.pages.dev/virtualized-rows/)
example calls this `recompute`, and runs it once after `init` and once after
every `Msg` that can change the rows, never from `view`:

```elm
type alias Model =
    { state : Table.State
    , rows : List (Table.Row Person)
    , list : InfiniteList.Model
    }
```

```elm snippet=VirtualizationGuide.elm#recompute
```

```elm snippet=VirtualizationGuide.elm#update
```

`view` then does one thing: hand the stored rows to the virtual list, and let
it decide the window.

```elm snippet=VirtualizationGuide.elm#viewRows
```

```elm snippet=VirtualizationGuide.elm#viewRow
```

Every column needs an explicit width from [Column Sizing](/guide/column-sizing)
rather than one the browser computes from whichever rows happen to be
mounted, since the header is rendered once, outside the part of the table
that scrolls, and nothing else keeps it lined up with the body. The same
reasoning applies to row height: a virtual list needs a height per row before
it renders the row, so a fixed row height, as `rowHeight` is above, is the
simple case, and a measured height is the complex one the virtual list
package's own documentation covers.

## Expanding rows with virtualization

[Expanding](/guide/expanding) inserts a row's sub-rows into the row list at
the `expandedRowModel` stage, which runs after sorting and before pagination.
A pipeline stopped at `sortedRowModel` never reaches that stage, so an
expandable table that virtualizes has to stop one stage later instead,
at `expandedRowModel`:

```elm snippet=VirtualizationGuide.elm#stopAfterExpanding
```

Everything else is unchanged: `rowsInDisplayOrder` already stops at this same
point, so code that goes through it, rather than assembling the pipeline by
hand, gets expanded rows for free. Toggling a row open or closed changes how
many rows there are, which changes the virtual list's total scroll height;
recompute before the next `view` the way sorting does.

## Column virtualization

TanStack also virtualizes columns horizontally, over
`table.getVisibleLeafColumns()`. The counterpart here is
[`visibleLeafColumns`](/reference/module/Table#visibleLeafColumns), which is
also a plain list, so the same seam applies: index into it for the columns to
render, and take each one's width from
[`getColumnSize`](/reference/module/Table#getColumnSize). Column
virtualization only pays off with dozens of columns or more; below that,
render them all.

`FabienHenon/elm-infinite-list-view` has no horizontal mode, so the
[Virtualized Columns](https://elm-table-examples.pages.dev/virtualized-columns/)
example windows columns with a running sum of their widths, computed once
per render rather than once per cell:

```elm snippet=VirtualizationGuide.elm#columnBounds
```

```elm snippet=VirtualizationGuide.elm#runningSum
```

Instead of positioning each column individually, the example leaves one
spacer cell to the left of the rendered columns and one to the right, each as
wide as the columns it stands in for. The left spacer is exactly
[`getColumnStart`](/reference/module/Table#getColumnStart) of the first
rendered column; the right one is whatever is left of
[`totalSize`](/reference/module/Table#totalSize) after the last rendered
column ends:

```elm snippet=VirtualizationGuide.elm#leftSpacerWidth
```

```elm snippet=VirtualizationGuide.elm#rightSpacerWidth
```

[`allColumnsRegion`](/reference/module/Table#allColumnsRegion) is the region
argument `getColumnStart` needs; it is TanStack's absent `position` argument,
present here because pinned columns have their own start-from-zero regions.
See [Column Pinning](/guide/column-pinning) if columns are pinned.

### Rows and columns together

The Virtualized Columns example windows both axes at once, from the same
scroll container: a vertical window over `rowsInDisplayOrder`, exactly as
above, and a horizontal window over `visibleLeafColumns`, exactly as above.
The two windows do not know about each other; each one only needs the scroll
position on its own axis and the sizes this package already reports.

## Infinite scrolling

The [Infinite Scrolling](https://elm-table-examples.pages.dev/virtualized-infinite-scrolling/)
example combines row virtualization with rows that arrive a page at a time as
the reader nears the bottom, rather than all fifty thousand up front. The
pattern:

1. Fetch a page of rows with a `Cmd` of your own; this package does no I/O.
2. Append the fetched rows to the data you hand the pipeline.
3. Keep virtualizing over `rowsInDisplayOrder`, which now returns more rows
   than it did a moment ago.
4. Ask for the next page once the reader is within some threshold of the
   bottom of what has loaded so far.

The threshold check is a function of numbers a scroll event already carries,
not a DOM measurement, so it needs nothing from this package beyond a row
count:

```elm snippet=VirtualizationGuide.elm#shouldFetchMore
```

If sorting runs on the server, use `manualSorting` so a re-sort re-fetches
from page zero instead of re-sorting whatever happens to be loaded already;
see [Client-Side vs Server-Side](/guide/client-side-vs-server-side). If
sorting runs on the client, as in the example, a re-sort re-runs the pipeline
over every row loaded so far, and should scroll back to the top: the row that
was under the reader before the sort is not the row that is there after it.

## Not covered

TanStack's page is mostly about TanStack Virtual and React:
`useVirtualizer`, `measureElement`, absolute positioning inside `tbody`, and
the experimental examples that write DOM styles outside React's render path.
All of that belongs to the virtual list package and to your own view code,
not to this one. Dynamic, measured row heights in particular are the virtual
list package's job end to end; nothing here changes between a fixed row
height and a measured one.

## Examples

- [Virtualized Rows](https://elm-table-examples.pages.dev/virtualized-rows/),
  ported from TanStack's Virtualized Rows example.
- [Virtualized Columns](https://elm-table-examples.pages.dev/virtualized-columns/),
  ported from TanStack's Virtualized Columns example.
- [Infinite Scrolling](https://elm-table-examples.pages.dev/virtualized-infinite-scrolling/),
  ported from TanStack's Virtualized Infinite Scrolling example.

<iframe src="https://elm-table-examples.pages.dev/virtualized-rows/" title="Virtualized Rows example" loading="lazy"></iframe>
