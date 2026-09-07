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

TanStack pairs its table with TanStack Virtual. The Elm counterpart is
[`dominikmayer/elm-virtual-list`](https://package.elm-lang.org/packages/dominikmayer/elm-virtual-list/latest/),
which owns the scroll container, the item offsets, and the visible window.
This page describes the seam between the two: what this package hands a
virtual list, and what you have to set up so the hand-off is correct. The
virtual list package's own documentation covers its side.

Virtualization is not a replacement for server-side paging. The rows still
have to be in the browser. If the dataset is too large to load, see
[Client-Side vs Server-Side](/guide/client-side-vs-server-side).

## State

Virtualization owns no state slice, no config option, no column option, no
transition, and no query. Everything below uses functions that belong to other
guides.

## The seam

A virtual list wants three things: a list of items, a stable key per item, and
a height per item. The first two come from here.

### 1. A plain list of rows

[`rowsInDisplayOrder`](/reference/module/Table#rowsInDisplayOrder) returns
`List (Row row)`, already filtered, sorted, grouped, and expanded. That is
exactly the input a virtual list indexes into, with no adapter in between:

```elm snippet=Virtualization.elm#rowsToVirtualize
```

### 2. Every row, not one page

[Pagination](/guide/pagination) is always in the pipeline, and its default
page size is 10. A virtual list that only ever sees ten rows is not doing
anything. Turn pagination off for the render path by setting the page size to
[`unlimitedPageSize`](/reference/module/Table#unlimitedPageSize), which is
what TanStack writes as `Infinity`:

```elm snippet=Virtualization.elm#everyRow
```

The alternative is to keep pagination out of the render path entirely and stop
the pipeline one stage earlier, at
[`prePaginationRowModel`](/reference/module/Table#prePaginationRowModel).
Either way the point is the same: the virtual list has to see every row, or
its scroll height is wrong.

### 3. A stable id per row

A virtual list keys its items so the browser reuses elements across scroll
frames. Give rows real ids with
[`withGetRowId`](/reference/module/Table#withGetRowId), then read them back
with [`rowId`](/reference/module/Table#rowId):

```elm snippet=Virtualization.elm#config
```

```elm snippet=Virtualization.elm#rowKeys
```

Without `withGetRowId` a row's id is its position in the data, so ids move
when the data reorders, and a virtual list keyed on them reuses the wrong
element.

### 4. Fixed column widths

The header does not live inside the virtual viewport. It is rendered once,
above the scroll container, while the body rows come and go. Nothing lines the
two up unless the widths are decided in advance, which means every column
needs an explicit width from [Column Sizing](/guide/column-sizing) rather than
a width the browser computes from the content of whichever rows happen to be
mounted:

```elm snippet=Virtualization.elm#columnWidths
```

Apply the same number to the header cell and to the body cell, and give the
row a `table-layout: fixed` container or a flex layout. The same reasoning
applies to row height: a virtual list needs a height per row before it renders
the row, so a fixed row height is the simple case and a measured height is the
complex one.

## Virtualized columns

TanStack also virtualizes columns horizontally, over
`table.getVisibleLeafColumns()`. The counterpart here is
[`visibleLeafColumns`](/reference/module/Table#visibleLeafColumns), which is
also a plain list, so the same seam applies: index into it, and take each
column's width from
[`getColumnSize`](/reference/module/Table#getColumnSize). Column
virtualization only pays off with dozens of columns; below that, render them
all.

## Not covered

TanStack's page is mostly about TanStack Virtual and React: `useVirtualizer`,
`measureElement`, absolute positioning inside `tbody`, the spacer cells for
horizontal virtualization, infinite scrolling with TanStack Query, and the
experimental examples that write DOM styles outside React's render path. All
of that belongs to the virtual list package and to your own view code, not to
this one.

## Example

There is no virtualized example, because the virtualizing is done by another
package. The nearest one is
[Pagination](https://elm-table-examples.pages.dev/pagination/), which shows
the pagination stage that a virtualized table turns off.
