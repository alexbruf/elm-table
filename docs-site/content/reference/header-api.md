---
title: Header API
id: reference/header-api
---

TanStack's Header API Reference covers the header cell, the header row it sits in, and the helper that builds the header rows from a column tree. elm-table has the same two types, [`Header`](/reference/module/Table#Header) and [`HeaderGroup`](/reference/module/Table#HeaderGroup), and builds the rows with [`headerGroups`](/reference/module/Table#headerGroups) rather than a method on a table instance. This page maps TanStack's entries onto ours; full signatures and doc comments live on the generated [`Table` module page](/reference/module/Table). For prose, see [Headers](/guide/headers) and [Header Groups](/guide/header-groups).

## Types

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `Header` | [`Header`](/reference/module/Table#Header) | Opaque. Read it with the `header*` functions below. |
| `HeaderGroup` | [`HeaderGroup`](/reference/module/Table#HeaderGroup) | A plain record: `id`, `depth`, `headers`. One rendered header row. |
| `HeaderContext` | — | No render context. A header carries its ids and spans; the size reads take the `Config` and `State` they need. |
| `constructHeader` | [`headerGroups`](/reference/module/Table#headerGroups) | Headers are produced by the header-group builders, never one at a time. |
| `buildHeaderGroups` | [`headerGroups`](/reference/module/Table#headerGroups) | Also [`footerGroups`](/reference/module/Table#footerGroups), which is the same rows bottom row first. |
| `AppHeaderContext` | — | React-only. No render context here either. |

## Header rows

| Value | What it returns |
| --- | --- |
| [`headerGroups`](/reference/module/Table#headerGroups) | The header rows of a table, top row first. |
| [`footerGroups`](/reference/module/Table#footerGroups) | The footer rows: the header rows, bottom row first. |
| [`flatHeaders`](/reference/module/Table#flatHeaders) | Every header of every header row. |
| [`leafHeaders`](/reference/module/Table#leafHeaders) | The leaf headers reachable from the top header row. |
| [`getLeafHeaders`](/reference/module/Table#getLeafHeaders) | The descendants of one header, deepest first, with the header itself last. |

## Reading one header

| Reader | What it returns |
| --- | --- |
| [`headerId`](/reference/module/Table#headerId) | The header id. Placeholder headers get a compound id. |
| [`headerColumnId`](/reference/module/Table#headerColumnId) | The id of the column this header renders. |
| [`headerColSpan`](/reference/module/Table#headerColSpan) | How many leaf columns this header spans. |
| [`headerRowSpan`](/reference/module/Table#headerRowSpan) | How many header rows this header spans. `0` means a header above already covers this cell. |
| [`headerDepth`](/reference/module/Table#headerDepth) | Which header row this header belongs to, counted from `1` at the top. |
| [`headerIndex`](/reference/module/Table#headerIndex) | The header's position in its header row. |
| [`headerIsPlaceholder`](/reference/module/Table#headerIsPlaceholder) | Is this a filler header standing in for a column that has no group at this level? |
| [`headerPlaceholderId`](/reference/module/Table#headerPlaceholderId) | How many placeholders for the same column came before this one. |
| [`headerSubHeaders`](/reference/module/Table#headerSubHeaders) | The headers nested under this one. |

The header text itself lives on the column: [`columnHeader`](/reference/module/Table#columnHeader) and [`columnFooter`](/reference/module/Table#columnFooter), looked up with [`findColumn`](/reference/module/Table#findColumn) on `headerColumnId`. Both return a `Maybe String`, so a view usually falls back to the column id.

## Header sizes

| Value | What it returns |
| --- | --- |
| [`getHeaderSize`](/reference/module/Table#getHeaderSize) | The width of a header: its column's size for a leaf header, the sum of the sub-header widths for a parent header. |
| [`getHeaderStart`](/reference/module/Table#getHeaderStart) | How far from the start of its header row a header begins. Pass the headers of the row the header belongs to. |

## Pinned header variants

When columns are pinned, a table is rendered as three column regions. Each of the four header lists above has a per-region form, so a sticky left block and a sticky right block can be rendered as their own tables.

| Region | Header rows | Footer rows | All headers | Leaf headers |
| --- | --- | --- | --- | --- |
| Left | [`leftHeaderGroups`](/reference/module/Table#leftHeaderGroups) | [`leftFooterGroups`](/reference/module/Table#leftFooterGroups) | [`leftFlatHeaders`](/reference/module/Table#leftFlatHeaders) | [`leftLeafHeaders`](/reference/module/Table#leftLeafHeaders) |
| Center | [`centerHeaderGroups`](/reference/module/Table#centerHeaderGroups) | [`centerFooterGroups`](/reference/module/Table#centerFooterGroups) | [`centerFlatHeaders`](/reference/module/Table#centerFlatHeaders) | [`centerLeafHeaders`](/reference/module/Table#centerLeafHeaders) |
| Right | [`rightHeaderGroups`](/reference/module/Table#rightHeaderGroups) | [`rightFooterGroups`](/reference/module/Table#rightFooterGroups) | [`rightFlatHeaders`](/reference/module/Table#rightFlatHeaders) | [`rightLeafHeaders`](/reference/module/Table#rightLeafHeaders) |

TanStack names these regions `start` and `end`. The state field and these function names use `left` and `right`; only the generated header ids keep TanStack's `start` and `end` wording. See [Column Pinning](/guide/column-pinning).
