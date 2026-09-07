---
title: Headers
id: guide/headers
---

A header is one `<th>`. Headers are to the `<thead>` what
[cells](/guide/cells) are to the `<tbody>`. This page is the port of
TanStack's Headers guide.

`Header row` is opaque, like `Row` and `Column`: you read it through
functions rather than fields.

## Where to get headers from

### Header group headers

Headers arrive in [header groups](/guide/header-groups), one group per header
row. `headerGroup.headers` is the list, left to right:

```elm snippet=HeaderGroups.elm#viewHeaderRow
```

### Header list functions

When you want a flat list rather than the rows, these return one:

| TanStack | elm-table |
| --- | --- |
| `table.getFlatHeaders()` | [`flatHeaders`](/reference/module/Table#flatHeaders) |
| `table.getLeafHeaders()` | [`leafHeaders`](/reference/module/Table#leafHeaders) |
| `header.getLeafHeaders()` | [`getLeafHeaders`](/reference/module/Table#getLeafHeaders) |
| `table.getStartFlatHeaders()` | [`leftFlatHeaders`](/reference/module/Table#leftFlatHeaders) |
| `table.getCenterFlatHeaders()` | [`centerFlatHeaders`](/reference/module/Table#centerFlatHeaders) |
| `table.getEndFlatHeaders()` | [`rightFlatHeaders`](/reference/module/Table#rightFlatHeaders) |
| `table.getStartLeafHeaders()` | [`leftLeafHeaders`](/reference/module/Table#leftLeafHeaders) |
| `table.getCenterLeafHeaders()` | [`centerLeafHeaders`](/reference/module/Table#centerLeafHeaders) |
| `table.getEndLeafHeaders()` | [`rightLeafHeaders`](/reference/module/Table#rightLeafHeaders) |

[`flatHeaders`](/reference/module/Table#flatHeaders) is every header of every
header row, group headers and placeholders included.
[`leafHeaders`](/reference/module/Table#leafHeaders) is only the headers with
no sub-headers, which is one per rendered column.

```elm snippet=Headers.elm#flatHeaderIds
```

```elm snippet=Headers.elm#leafHeaderIds
```

[`getLeafHeaders`](/reference/module/Table#getLeafHeaders) is the per-header
version: the columns one header actually covers, useful when a click on a
group header should act on everything below it.

```elm snippet=Headers.elm#coveredColumns
```

## Header objects

Every reader takes the header and nothing else.

| TanStack | elm-table |
| --- | --- |
| `header.id` | [`headerId`](/reference/module/Table#headerId) |
| `header.column.id` | [`headerColumnId`](/reference/module/Table#headerColumnId) |
| `header.colSpan` | [`headerColSpan`](/reference/module/Table#headerColSpan) |
| `header.rowSpan` | [`headerRowSpan`](/reference/module/Table#headerRowSpan) |
| `header.depth` | [`headerDepth`](/reference/module/Table#headerDepth) |
| `header.index` | [`headerIndex`](/reference/module/Table#headerIndex) |
| `header.isPlaceholder` | [`headerIsPlaceholder`](/reference/module/Table#headerIsPlaceholder) |
| `header.placeholderId` | [`headerPlaceholderId`](/reference/module/Table#headerPlaceholderId) |
| `header.subHeaders` | [`headerSubHeaders`](/reference/module/Table#headerSubHeaders) |
| `header.getSize()` | [`getHeaderSize`](/reference/module/Table#getHeaderSize) |
| `header.getStart()` | [`getHeaderStart`](/reference/module/Table#getHeaderStart) |
| `header.column` | none, use `headerColumnId` then `findColumn` |
| `header.headerGroup` | none |
| `header.getContext()` | none |

### Header ids

`headerId` is unique within the header rows. For a plain header it is the
column id. A group header, a placeholder, or a header in a pinned region gets
a compound id built from the region, the depth, the column id, and the id of
its first child, joined with underscores. Use it as the key of a keyed node,
not as something to parse.

### There is no header.column

A header carries the column's *id*, not the column. To get the column, look
it up:

```elm snippet=Headers.elm#headerColumn
```

That is the one extra step compared with TanStack. It comes up whenever you
want the header text, since the text lives on the column:

```elm snippet=Headers.elm#headerLabel
```

`Table.columnHeader` returns a `Maybe String`, because
[`withHeader`](/reference/module/Table#withHeader) is optional. Falling back
to the column id is the usual choice.

There is no `header.headerGroup` either. You have the header group in scope
when you map over its `headers`, so pass down what you need from it.

### Nested and grouped header properties

These matter once columns are nested with
[`Table.group`](/reference/module/Table#group):

- [`headerColSpan`](/reference/module/Table#headerColSpan): how many columns
  the header spans. Goes straight into the `colspan` attribute.
- [`headerRowSpan`](/reference/module/Table#headerRowSpan): how many header
  rows it spans. A leaf column shallower than the deepest leaf column
  produces a chain of placeholder headers above its real header. The
  placeholder at the top of the chain reports the whole chain's span, and
  every header it covers, including the real leaf header at the bottom,
  reports `0`.
- [`headerDepth`](/reference/module/Table#headerDepth): which header row the
  header is in, counting from `0` at the top.
- [`headerIndex`](/reference/module/Table#headerIndex): the header's position
  from left to right within its header row. Not the same as `headerDepth`.
- [`headerIsPlaceholder`](/reference/module/Table#headerIsPlaceholder): true
  for a filler header standing in for a column that has no group at this
  level.
- [`headerPlaceholderId`](/reference/module/Table#headerPlaceholderId): how
  many placeholders for the same column came before this one, as a string.
  `Nothing` on a real header.
- [`headerSubHeaders`](/reference/module/Table#headerSubHeaders): the headers
  nested directly under this one, empty on a leaf header.

```elm snippet=Headers.elm#childIds
```

```elm snippet=Headers.elm#placeholderReport
```

## Header row spanning

With an uneven column tree, merge each placeholder chain into one cell:
skip every header whose `headerRowSpan` is `0`, and render the rest with both
attributes. This replaces the usual `headerIsPlaceholder` check, because the
spanning placeholder is the cell that draws the column's header text.

```elm snippet=HeaderGroups.elm#viewHeaderCell
```

This recipe is for `<thead>` only. `footerGroups` returns the header rows in
reverse, which puts a spanning placeholder below the cells it would need to
cover, so keep the empty-cell placeholder pattern in `<tfoot>`. See
[Header Groups](/guide/header-groups).

The body-cell equivalent is [Cell Spanning](/guide/cell-spanning).

## Header rendering

TanStack renders a header with `flexRender(header.column.columnDef.header,
header.getContext())` because a `header` column option can be a string, JSX,
or a function. Here
[`withHeader`](/reference/module/Table#withHeader) takes a `String` and you
write the markup:

```elm snippet=Headers.elm#viewHeaderCell
```

For a sortable header, put the click handler and the direction arrow in that
same function. See [Sorting](/guide/sorting).

## Sizing

[`getHeaderSize`](/reference/module/Table#getHeaderSize) is a leaf header's
column width, or the sum of the sub-header widths for a parent header.
[`getHeaderStart`](/reference/module/Table#getHeaderStart) is how far from
the start of its header row the header begins, which is what a sticky pinned
header needs. It takes the headers of the row the header belongs to, because
there is no header group reference to walk back to. Pass
`headerGroup.headers`, not `flatHeaders`:

```elm snippet=Headers.elm#viewStickyHeaderRow
```

```elm snippet=Headers.elm#offsetPx
```

See [Column Sizing](/guide/column-sizing) and
[Column Resizing](/guide/column-resizing).
