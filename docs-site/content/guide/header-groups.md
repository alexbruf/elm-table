---
title: Header Groups
id: guide/header-groups
---

A header group is one row of header cells. This page is the port of
TanStack's Header Groups guide.

## What are header groups?

Header groups are the `<tr>` elements of your `<thead>`. Most tables have one
of them. You get more than one when your columns are nested, because each
level of nesting needs its own header row.

[`Table.group`](/reference/module/Table#group) is what nests columns. A group
column has no accessor and no cells; it exists to put a header above the
columns underneath it:

```elm snippet=HeaderGroups.elm#config
```

That config is three levels wide but two levels deep, so it produces two
header rows: `#` / `Name` / `Work` on top, then `First` / `Last` /
`Department` / `Salary`.

The `id` column is a leaf sitting at the top level, shallower than the
deepest leaf. To keep the grid rectangular, the header builder puts a
*placeholder* header above (or in the header rows alongside) each such
column. Placeholders are covered in [Headers](/guide/headers); the short
version is that you either render them as empty cells or merge them with
`rowSpan`.

## Where to get header groups from

| TanStack | elm-table |
| --- | --- |
| `table.getHeaderGroups()` | [`headerGroups`](/reference/module/Table#headerGroups) |
| `table.getFooterGroups()` | [`footerGroups`](/reference/module/Table#footerGroups) |
| `table.getStartHeaderGroups()` | [`leftHeaderGroups`](/reference/module/Table#leftHeaderGroups) |
| `table.getCenterHeaderGroups()` | [`centerHeaderGroups`](/reference/module/Table#centerHeaderGroups) |
| `table.getEndHeaderGroups()` | [`rightHeaderGroups`](/reference/module/Table#rightHeaderGroups) |
| `table.getStartFooterGroups()` | [`leftFooterGroups`](/reference/module/Table#leftFooterGroups) |
| `table.getCenterFooterGroups()` | [`centerFooterGroups`](/reference/module/Table#centerFooterGroups) |
| `table.getEndFooterGroups()` | [`rightFooterGroups`](/reference/module/Table#rightFooterGroups) |

Every one of them has the type `Config row -> State -> List (HeaderGroup
row)`. They need the `State` because column visibility, column order, and
column pinning all change which columns end up in which header row.

`headerGroups` already handles pinning: when any column is pinned it builds
the rows over the left-pinned columns, then the unpinned ones, then the
right-pinned ones, in that order. Reach for the three regional functions only
when you are laying the regions out as separate elements.

`footerGroups` is `headerGroups` reversed, bottom row first, matching
TanStack.

## Header group objects

`HeaderGroup row` is a plain record, not an opaque type:

```elm
type alias HeaderGroup row =
    { id : String
    , depth : Int
    , headers : List (Header row)
    }
```

- `id` is built from the depth: `"0"`, `"1"`, and so on. The pinned variants
  prefix it with their region, keeping TanStack's `start` / `center` / `end`
  wording, so the left-pinned top row is `"start_0"` and the right-pinned one
  is `"end_0"`.
- `depth` is the row index among the header rows, zero for the top row.
- `headers` are the [header](/guide/headers) cells of that row, left to
  right.

## Access header cells

Map over `headerGroup.headers`. This renders a `<thead>` with one `<tr>` per
header group, merging the placeholder chains vertically with `rowspan`:

```elm snippet=HeaderGroups.elm#viewHead
```

```elm snippet=HeaderGroups.elm#viewHeaderRow
```

```elm snippet=HeaderGroups.elm#viewHeaderCell
```

A header with a `rowSpan` of `0` is covered by a header above it and is
skipped, which is why `viewHeaderRow` uses `List.filterMap`. Everything else
is drawn with both `colspan` and `rowspan`.

A header carries no column, only `headerColumnId`, so the label comes from a
lookup:

```elm snippet=HeaderGroups.elm#headerLabel
```

## Footers

Footer rows come out bottom row first, which puts a spanning placeholder
below the cells it would have to cover. The `rowSpan` trick above does not
work there. In a `<tfoot>`, render placeholders as empty cells instead:

```elm snippet=HeaderGroups.elm#viewFoot
```

```elm snippet=HeaderGroups.elm#viewFooterRow
```

```elm snippet=HeaderGroups.elm#viewFooterCell
```

The footer text comes from
[`withFooter`](/reference/module/Table#withFooter), read back with
[`columnFooter`](/reference/module/Table#columnFooter):

```elm snippet=HeaderGroups.elm#footerLabel
```

## Pinned regions

If you are drawing the three pinned regions separately, the regional
functions return header rows of the same depth, so they zip together row by
row:

```elm snippet=HeaderGroups.elm#viewPinnedHead
```

See [Column Pinning](/guide/column-pinning) for the state that drives this.

## Nothing is memoized

Each call rebuilds the header rows from the `Config` and the `State`. Call
`headerGroups` once in your `view` and pass the result down, rather than
calling it inside a loop over rows.
