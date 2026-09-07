---
title: Examples
id: examples
---

Every example is a standalone Elm application, compiled and deployed at
[elm-table-examples.pages.dev](https://elm-table-examples.pages.dev/). Each one
ports the TanStack Table example of the same name, and each page shows the
running table above its full Elm source.

The feature guides embed the matching example at the bottom of the page, so you
can read the guide and watch the thing it describes in the same place.

## Basic Examples

| Example | What it shows | Guide |
| --- | --- | --- |
| [Basic](https://elm-table-examples.pages.dev/basic/) | The smallest possible table: four rows, six columns, no state. | [Quick Start](/quick-start) |
| [Basic (External State)](https://elm-table-examples.pages.dev/basic-external-state/) | The table state lives in your model and you can inspect, reset, and replace it. | [Table State](/guide/table-state) |
| [Basic (Dynamic Columns)](https://elm-table-examples.pages.dev/basic-dynamic-columns/) | Columns built at runtime from the data's own keys. | [Column Definitions](/guide/column-defs) |
| [Header Groups](https://elm-table-examples.pages.dev/header-groups/) | Nested column groups rendered as multi-row headers and footers. | [Header Groups](/guide/header-groups) |

## Feature Examples

| Example | What it shows | Guide |
| --- | --- | --- |
| [Kitchen Sink (All Features)](https://elm-table-examples.pages.dev/kitchen-sink/) | Every feature on one table: sorting, filtering, grouping, expanding, selection, pinning, visibility, ordering, sizing, pagination. | [Features](/guide/features) |
| [Cell Selection](https://elm-table-examples.pages.dev/cell-selection/) | Rectangular cell ranges with click, shift-click, ctrl-click, and keyboard movement. | [Cell Selection](/guide/cell-selection) |
| [Cell Spanning](https://elm-table-examples.pages.dev/cell-spanning/) | Merge adjacent cells with row and column spans. | [Cell Spanning](/guide/cell-spanning) |
| [Column Filters](https://elm-table-examples.pages.dev/filters/) | Per-column text and range filters plus a global filter. | [Column Filtering](/guide/column-filtering) |
| [Column Filters (Faceted)](https://elm-table-examples.pages.dev/filters-faceted/) | Filter inputs driven by faceted unique values and min/max. | [Faceting](/guide/column-faceting) |
| [Bucketed Faceted Filters](https://elm-table-examples.pages.dev/filters-faceted-bucketed/) | Faceted values grouped into buckets for numeric and date columns. | [Faceting](/guide/column-faceting) |
| [Fuzzy Search Filters](https://elm-table-examples.pages.dev/filters-fuzzy/) | A custom fuzzy filter function with match ranking. | [Fuzzy Filtering](/guide/fuzzy-filtering) |
| [Column Ordering](https://elm-table-examples.pages.dev/column-ordering/) | Reorder columns through state. | [Column Ordering](/guide/column-ordering) |
| [Column Ordering (DnD)](https://elm-table-examples.pages.dev/column-dnd/) | Drag headers to reorder columns using HTML5 drag events. | [Column Ordering](/guide/column-ordering) |
| [Column Pinning](https://elm-table-examples.pages.dev/column-pinning/) | Pin columns to the left or right edge. | [Column Pinning](/guide/column-pinning) |
| [Column Pinning (Split)](https://elm-table-examples.pages.dev/column-pinning-split/) | Pinned regions rendered as three separate tables. | [Column Pinning](/guide/column-pinning) |
| [Sticky Column Pinning](https://elm-table-examples.pages.dev/column-pinning-sticky/) | Pinned columns stay put with `position: sticky` while the rest scroll. | [Column Pinning](/guide/column-pinning) |
| [Column Sizing](https://elm-table-examples.pages.dev/column-sizing/) | Column widths from state with min and max clamping. | [Column Sizing](/guide/column-sizing) |
| [Column Resizing](https://elm-table-examples.pages.dev/column-resizing/) | Drag a header edge to resize a column, with onChange and onEnd modes and left-to-right or right-to-left direction. | [Column Resizing](/guide/column-resizing) |
| [Performant Column Resizing](https://elm-table-examples.pages.dev/column-resizing-performant/) | Resize with the body rendered from CSS variables so only the header re-renders while dragging. | [Column Resizing](/guide/column-resizing) |
| [Column Visibility](https://elm-table-examples.pages.dev/column-visibility/) | Show and hide columns with checkboxes. | [Column Visibility](/guide/column-visibility) |
| [Expanding](https://elm-table-examples.pages.dev/expanding/) | Nested sub-rows with expand and collapse. | [Expanding](/guide/expanding) |
| [Expanding Sub Components](https://elm-table-examples.pages.dev/sub-components/) | Expand a row to reveal arbitrary content instead of sub-rows. | [Expanding](/guide/expanding) |
| [Grouping](https://elm-table-examples.pages.dev/grouping/) | Group rows by one or more columns. | [Grouping](/guide/grouping) |
| [Aggregation](https://elm-table-examples.pages.dev/aggregation/) | Aggregated values on group rows and in footers. | [Aggregation](/guide/aggregation) |
| [Grouped Aggregation](https://elm-table-examples.pages.dev/grouped-aggregation/) | Nested groups with merged aggregates at every level. | [Aggregation](/guide/aggregation) |
| [Pagination](https://elm-table-examples.pages.dev/pagination/) | Client-side pages with page size, page jump, and counts. | [Pagination](/guide/pagination) |
| [Row DnD](https://elm-table-examples.pages.dev/row-dnd/) | Drag rows to reorder the underlying data using HTML5 drag events. | [Rows](/guide/rows) |
| [Row Pinning](https://elm-table-examples.pages.dev/row-pinning/) | Pin rows to the top or bottom of the table. | [Row Pinning](/guide/row-pinning) |
| [Row Selection](https://elm-table-examples.pages.dev/row-selection/) | Checkbox selection with all, some, and per-row state. | [Row Selection](/guide/row-selection) |
| [Sorting](https://elm-table-examples.pages.dev/sorting/) | Click and shift-click headers for single and multi-column sorting. | [Sorting](/guide/sorting) |

## Specialized Examples

| Example | What it shows | Guide |
| --- | --- | --- |
| [Virtualized Rows](https://elm-table-examples.pages.dev/virtualized-rows/) | 50,000 sorted and filtered rows rendered through an Elm virtual list. | [Virtualization](/guide/virtualization) |
| [Virtualized Columns](https://elm-table-examples.pages.dev/virtualized-columns/) | Wide tables: only the columns in view are rendered. | [Virtualization](/guide/virtualization) |
| [Infinite Scrolling](https://elm-table-examples.pages.dev/virtualized-infinite-scrolling/) | Pages of rows fetched as you scroll, appended to the data and re-run through the pipeline. | [Virtualization](/guide/virtualization) |
| [Realtime Trading](https://elm-table-examples.pages.dev/realtime-trading/) | Prices updating on a timer while sorting and filtering stay live. | [Data](/guide/data) |

## Not ported

Some TanStack examples exist only because of the JavaScript API and have no Elm
counterpart.

| TanStack example | Why not |
| --- | --- |
| Basic (useAppTable), Basic (useLegacyTable), Basic (Subscribe), Basic (External Atoms) | Four ways to construct a React table instance. There is one way here: build a `Config` and hold a `State`. |
| Composable Tables, Custom Plugin | Both extend the table instance. See [Features](/guide/features). |
| Experimental Web Workers Plugin, Experimental Spreadsheet | Experimental TanStack plugins. |
| With TanStack Form, Query, Router | Integrations with other JavaScript libraries. |
| Every component-library example (Shadcn, Material UI, Mantine, Chakra, Hero UI, React Aria) | React component libraries. You write the `Html` here. |

## Running them yourself

The sources live in `examples-site/src/` in the repository. Build the whole set
with `make examples-site` from the repository root, or one at a time with
`bun run build.ts <slug>` inside `examples-site/`.
