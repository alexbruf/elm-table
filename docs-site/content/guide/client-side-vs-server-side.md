---
title: Client-Side vs Server-Side
id: guide/client-side-vs-server-side
---

This package can filter, group, sort, expand, and paginate rows in the browser,
or it can hold the state for those features while your server does the work.
This page is the Elm counterpart of TanStack Table's **Client-Side vs
Server-Side Guide**, and the decision is the same one: how much data reaches
the browser, what it costs to transfer and process, and how fast an interaction
should feel.

As in TanStack, this is close to an all-or-nothing choice. Mixing client-side
and server-side processing across features usually produces answers that
describe only the rows you happen to have.

## Start With the Simplest Approach That Fits

Client-side processing is the smaller data flow. Fetch the whole dataset, hand
it to [`Table.rowsFromList`](/reference/module/Table#rowsFromList), and every
filter, sort, and page change is a state update with no request behind it.

A few thousand rows is comfortable. The package's benchmark runs the whole
pipeline over 10,000 rows with a filter, a sort, and pagination in about 94 ms
median with `elm make --optimize`; see [Data](/guide/data) for the full table.
What that costs in your application depends on the number of columns and the
work your accessors do, so measure with your own data.

Server-side processing fits better when:

- fetching the whole dataset would be slow, expensive, or large in memory;
- the browser receives one page or another subset of the rows;
- queries, permissions, or business rules have to be enforced by the backend;
- the data changes often enough that a full download goes stale; or
- the backend can search, sort, group, or aggregate with an index.

If both fit today, start on the client. The `State` you own is the same either
way, which is what makes moving the work to the server later a change to your
`update` function rather than a rewrite.

## Keep Dataset-Wide Operations Consistent

Filtering, grouping, sorting, and pagination describe one pipeline over one
dataset. When the server sends part of that dataset, a client-side stage can
only process the rows it was given.

Sorting after server-side pagination sorts the current page, not the whole
result. Filtering after server-side pagination hides rows on this page while
missing matches on every other page. Both look like bugs to the person using
the table.

The rule: when the server owns pagination, it should also own the filtering,
grouping, sorting, and aggregation that have to apply to the whole result.
Narrower scope is fine when you meant it, for example ranking rows within a
group the server already chose. Say so in the interface.

Faceting needs the same care. [Faceting](/guide/column-faceting) counts values
in whatever `RowModel` you pass it, so counts taken from one page describe that
page.

## What "Manual" Means

A `manual*` flag does not fetch anything and does not transform anything. It
tells the pipeline that the rows you passed in are already processed for that
feature, so the stage is skipped and the row model passes through unchanged.

| Operation | Manual flag | Stage skipped |
| --- | --- | --- |
| Column and global filtering | `manualFiltering` | [`filteredRowModel`](/reference/module/Table#filteredRowModel) |
| Grouping | `manualGrouping` | [`groupedRowModel`](/reference/module/Table#groupedRowModel) |
| Sorting | `manualSorting` | [`sortedRowModel`](/reference/module/Table#sortedRowModel) |
| Expanding | `manualExpanding` | [`expandedRowModel`](/reference/module/Table#expandedRowModel) |
| Pagination | `manualPagination` | [`paginatedRowModel`](/reference/module/Table#paginatedRowModel) |

All five default to `False`. They are plain `Bool` fields on `Table.Config`
with no builder, so set them with a record update, as in the example below.

Two differences from TanStack:

- There is no `manualAggregation`. Aggregated values are computed by the
  grouped stage, so `manualGrouping` covers them: with it set, the group rows
  you supply carry whatever values you put in them.
- Faceting has no manual flag and no factory to swap. `facetedRowModel`,
  `facetedUniqueValues`, and `facetedMinMax` read the row model you hand them,
  so a facet list that came from the server is data in your own model, and you
  render your filter controls from it directly.

Skipping a stage costs nothing else. The feature's state slice, its
transitions, and its query functions all keep working, which is the point:
`Table.toggleSort` still records what the user clicked, you just send that to
the server instead of sorting locally.

## A Typical Server-Side Data Flow

Start from the columns and a `Config` with the manual flags set. `rowCount` is
the total number of rows matching the current filters, which the server
reports; leave it `Nothing` until the first response arrives.

```elm snippet=ServerSide.elm#serverConfig
```

`Table.Config` is a plain record, so `{ base | manualSorting = True }` reaches
any field that has no builder. See
[Config and State](/guide/config-and-state) for the full option table.

Your model holds the state, the page of rows the server sent, and the total:

```elm
type alias Model =
    { state : Table.State
    , page : List Person
    , totalRows : Maybe Int
    , loading : Bool
    }
```

Each message that changes a server-owned slice does two things: it stores the
new `State`, and it asks for the matching page.

```elm snippet=ServerSide.elm#update
```

The parts worth naming:

- **A state change triggers a request.** Each transition produces a new
  `State`, and the same value is both stored and handed to the fetch. Nothing
  fires on its own.
- **Nothing resets itself.** TanStack's `autoResetPageIndex` has no
  counterpart, in either direction: no state slice resets when the rows change.
  Reset the page index yourself with
  [`Table.resetPageIndex`](/reference/module/Table#resetPageIndex) wherever
  filters, grouping, sorting, or page size change, as `SortBy` does above.
- **`toggleSort` still wants a row model.** The direction an unsorted column
  starts in depends on the data, so the transition reads it. With
  `manualSorting` set, the core row model over the current page is the right
  thing to pass: it is what the local rows can tell you.
- **The fetch is yours.** This package sends no requests. `fetchPage` above is
  a stub standing in for whatever your application uses, and its `Cmd Msg` is
  where an HTTP request, a port, or a GraphQL query goes.

```elm snippet=ServerSide.elm#fetchPage
```

Rendering is unchanged. Run the pipeline as usual: with the manual flags set,
the stages that would have re-processed the server's rows step aside, and what
comes back is the page you were sent, wrapped in `Table.Row` values with ids,
cells, and everything the view functions want.

```elm snippet=ServerSide.elm#currentRows
```

Use [`Table.withGetRowId`](/reference/module/Table#withGetRowId) with a real
backend key. Selection, expansion, and pinning store row ids, and a positional
id points at a different record after the next response. See
[Data](/guide/data#stable-row-ids).

### Telling the Table How Many Rows There Are

With `manualPagination` set, the row model only ever holds one page, so the
pipeline cannot count the rest. Two `Config` fields stand in for the count the
server reports:

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `rowCount` | `Maybe Int` | `Nothing` | Total rows matching the current filters. `getRowCount` returns it when set, otherwise the length of the row model it is given. |
| `pageCount` | `Maybe Int` | `Nothing` | Total pages. `getPageCount` returns it when set, otherwise `rowCount` divided by the page size, rounded up. |

Set `rowCount` when the server can report a total; `pageCount` follows from it.
Set `pageCount` directly only when the server reports pages rather than rows.

`Just -1` is the "unknown total" case, which is what a cursor-based API gives
you. [`Table.getCanNextPage`](/reference/module/Table#getCanNextPage) then
always returns `True`, so decide the Next button from whether the server said
another page exists.
[`Table.getCanLastPage`](/reference/module/Table#getCanLastPage) returns
`False`, because there is no known last page to jump to.

Each of these queries takes the row model, so pass the pre-pagination one:
`Table.getPageCount config state model` and
`Table.getRowCount config model`. With `manualPagination` set, the model you
have is that model.

### Why There Is No Built-In Server Row Model

This package is synchronous and pure. Every function takes a `Config`, a
`State`, and data already in memory, and returns a value. Fetching is effectful
and belongs in your `update`, where Elm already has a place for it.

There are also too many ways to shape the contract between a frontend and a
backend, REST parameters, GraphQL inputs, RPC calls, SQL builders, to pick one.
Leaving that boundary alone is what keeps the package working with any of them.

## Rendering Is a Separate Decision

Pagination and virtualization solve different problems, and choosing one does
not answer the other.

Pagination limits how many rows exist in the row model, on the client or the
server. Virtualization limits how many rows you draw, out of the ones already
loaded. Virtualization makes a large loaded dataset cheap to render, but it
does not reduce what you fetched or what the pipeline processed.

If the whole dataset is too large to load, move the processing to the server
first. Add [virtualization](/guide/virtualization) afterwards if the rows you
do load are still too many to draw.

## Choosing an Approach

Use client-side processing when the browser can reasonably hold the whole
dataset and immediate local interaction is worth having. Use server-side
processing when it cannot, or when the backend has to define the authoritative
answer.

Going server-side means writing the query yourself. This package gives you the
state that describes what the user asked for and the queries to render the
result; the SQL, the request, and the response handling are your application's.
That is the same separation TanStack draws, and for the same reason.

Whichever you choose, measure the whole path. Transfer size, memory, pipeline
time, and rendering are separate costs, and the right boundary is the one that
keeps all of them acceptable.
