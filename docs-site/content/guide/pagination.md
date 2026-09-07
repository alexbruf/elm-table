---
title: Pagination
id: guide/pagination
---

## Pagination

Pagination slices the rows into pages and hands you one page at a time. It is
the last stage of the [row model pipeline](/guide/row-models), so it sees
rows that are already filtered, grouped, sorted, and expanded. This page ports
TanStack Table's *Pagination (React) Guide*.

The same state slice and the same transitions work whether the slicing is
done here or by your server. Client-side pagination runs
[`paginatedRowModel`](/reference/module/Table#paginatedRowModel);
server-side pagination sets `manualPagination = True`, which turns that stage
into a pass-through, and tells the table how many rows there are with
`rowCount` or `pageCount`.

### Client-side or server-side

Client-side pagination is the simpler option whenever the browser can hold
the whole dataset. Move to server-side pagination when querying,
transferring, or holding all the rows is too expensive. Row count alone does
not decide it; see [Client-Side vs
Server-Side](/guide/client-side-vs-server-side).

Virtualization is a different thing again: it renders fewer rows without
reducing how many rows the browser holds, so it complements pagination rather
than replacing it. See [Virtualization](/guide/virtualization).

## State

Pagination owns one state slice, a record of two `Int`s:

```elm
-- in Table.State
pagination : Pagination

type alias Pagination =
    { pageIndex : Int
    , pageSize : Int
    }

-- in Table.initialState
pagination = { pageIndex = 0, pageSize = 10 }
```

`pageIndex` is zero-based, so the first page is `0`. To start somewhere else,
write the slice before you store the state:

```elm snippet=Pagination.elm#startOnPageThree
```

[`unlimitedPageSize`](/reference/module/Table#unlimitedPageSize) is the page
size that puts every row on one page. Elm has no `Infinity` for `Int`, so it
is `Number.MAX_SAFE_INTEGER` where TanStack writes `pageSize: Infinity`:

```elm snippet=Pagination.elm#showEveryRow
```

## Config options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `manualPagination` | `Bool` | `False` | Skip the paginated stage. The data you pass in is assumed to be one page already. |
| `pageCount` | `Maybe Int` | `Nothing` | How many pages there are in total. `Just -1` means the count is unknown. |
| `rowCount` | `Maybe Int` | `Nothing` | How many rows there are in total. The page count is derived from it and the page size when `pageCount` is not set. |
| `paginateExpandedRows` | `Bool` | `True` | With it `False`, expanded sub-rows always render on their parent's page, so a page can hold more rows than the page size. See [Expanding](/guide/expanding). |

`Config` is a plain record, so a server-side table sets these with a record
update:

```elm snippet=Pagination.elm#serverConfig
```

With an unknown page count (`pageCount = Just -1`),
[`getCanNextPage`](/reference/module/Table#getCanNextPage) is always `True`
because the end cannot be detected,
[`getCanPreviousPage`](/reference/module/Table#getCanPreviousPage) still
depends on the page index, and
[`getCanLastPage`](/reference/module/Table#getCanLastPage) is `False` because
there is no finite last page to jump to.

## Column options

Pagination has no column builders. It is a whole-table feature.

## Transitions

| Function | Signature | Description |
| --- | --- | --- |
| [`setPage`](/reference/module/Table#setPage) | `Config row -> Int -> State -> State` | Go to a page. TanStack's `setPageIndex`. Clamped to `[0, pageCount - 1]` when `Config.pageCount` is set; a `pageCount` of `Just -1` clamps nothing. |
| [`setPageSize`](/reference/module/Table#setPageSize) | `Int -> State -> State` | Change the page size, at least `1`. The page index moves so the row that was at the top of the page stays in view. |
| [`setPagination`](/reference/module/Table#setPagination) | `Pagination -> State -> State` | Replace the whole slice. |
| [`previousPage`](/reference/module/Table#previousPage) | `Config row -> State -> State` | Back one page, clamped at `0`. |
| [`nextPage`](/reference/module/Table#nextPage) | `Config row -> State -> State` | Forward one page. |
| [`firstPage`](/reference/module/Table#firstPage) | `Config row -> State -> State` | Go to page `0`. |
| [`lastPage`](/reference/module/Table#lastPage) | `Config row -> State -> RowModel row -> State` | Go to the last page. A no-op when the page count is unknown or empty. |
| [`resetPageIndex`](/reference/module/Table#resetPageIndex) | `Config row -> State -> State` | Back to page `0`. |
| [`resetPageSize`](/reference/module/Table#resetPageSize) | `State -> State` | Back to a page size of `10`. |
| [`resetPagination`](/reference/module/Table#resetPagination) | `State -> State` | Back to page `0` with a page size of `10`. |

[`lastPage`](/reference/module/Table#lastPage) is the only transition that
needs a row model, because it has to know the page count. Every other one
works from the `Config` and the `State` alone.

```elm snippet=Pagination.elm#update
```

## Queries

| Function | Signature | Description |
| --- | --- | --- |
| [`getPageCount`](/reference/module/Table#getPageCount) | `Config row -> State -> RowModel row -> Int` | `Config.pageCount` when set, otherwise the row count divided by the page size, rounded up. |
| [`getPageOptions`](/reference/module/Table#getPageOptions) | `Config row -> State -> RowModel row -> List Int` | Every page index, `[0, 1, ...]`. Empty when there are no pages. |
| [`getRowCount`](/reference/module/Table#getRowCount) | `Config row -> RowModel row -> Int` | `Config.rowCount` when set, otherwise the rows of the model handed in. |
| [`getCanPreviousPage`](/reference/module/Table#getCanPreviousPage) | `State -> Bool` | Is there a page before this one? |
| [`getCanNextPage`](/reference/module/Table#getCanNextPage) | `Config row -> State -> RowModel row -> Bool` | Is there a page after this one? An unknown page count always says yes. |
| [`getCanLastPage`](/reference/module/Table#getCanLastPage) | `Config row -> State -> RowModel row -> Bool` | Is there a known last page after this one? |
| [`prePaginationRowModel`](/reference/module/Table#prePaginationRowModel) | `Config row -> State -> RowModel row -> RowModel row` | The model pagination slices, which is the expanded one. |
| [`rowsInDisplayOrder`](/reference/module/Table#rowsInDisplayOrder) | `Config row -> State -> RowModel row -> List (Row row)` | The rows to render, in order. |
| [`displayIndex`](/reference/module/Table#displayIndex) | `Config row -> State -> RowModel row -> Row row -> Int` | A row's zero-based position in that list, or `-1`. |

### Give the counts the pre-pagination model

[`getRowCount`](/reference/module/Table#getRowCount),
[`getPageCount`](/reference/module/Table#getPageCount),
[`getPageOptions`](/reference/module/Table#getPageOptions),
[`getCanNextPage`](/reference/module/Table#getCanNextPage), and
[`getCanLastPage`](/reference/module/Table#getCanLastPage) all count rows.
Pass them the **pre-pagination** row model, not the page. Passing the page
gives you a row count of at most one page and a page count of `1`, and the
Next button will be disabled on every page.

```elm snippet=Pagination.elm#prePagination
```

The page itself is one more call on top of that:

```elm snippet=Pagination.elm#page
```

Rows come out of the page through
[`rowsInDisplayOrder`](/reference/module/Table#rowsInDisplayOrder). With
`paginateExpandedRows = False` that function is where the expanded
descendants missing from the page slice are put back, so use it rather than
reading `.rows` directly.

### A pagination control bar

Everything above together: first, previous, next, last, a page readout, a
"go to page" input, a page size select, and a total row count.

```elm snippet=Pagination.elm#viewPager
```

```elm snippet=Pagination.elm#viewPageSizeOption
```

For a page-number dropdown rather than a number input, build it from
[`getPageOptions`](/reference/module/Table#getPageOptions):

```elm snippet=Pagination.elm#viewPageJump
```

## Not covered

Controlled state through the `atoms` option or `state.pagination` plus
`onPaginationChange` has nothing to port: `State.pagination` is always yours,
so it can go straight into a query key. Nor is there an `initialState` option
to set a starting page; write the slice on
[`initialState`](/reference/module/Table#initialState) instead, as shown
above.

`autoResetPageIndex` and `autoResetAll` are not ported. Nothing recomputes
behind your back here, so call
[`resetPageIndex`](/reference/module/Table#resetPageIndex) in the same
`update` branch that changes a filter, the sorting, the grouping, or the
data.

TanStack's page also walks through two TanStack Query integrations,
page-index and cursor-based. The table-side settings they describe are the
`manualPagination`, `rowCount`, and `pageCount` options above; the request
lifecycle is your own `Cmd`.

## Example

[Pagination](https://elm-table-examples.pages.dev/pagination/), ported from
TanStack's Pagination example.

<iframe src="https://elm-table-examples.pages.dev/pagination/" title="Pagination example" loading="lazy"></iframe>
