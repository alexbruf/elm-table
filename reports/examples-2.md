# Examples port, batch 2

Fourteen TanStack Table React examples ported to Elm for `examples-site`.
Every feature runs through the package; nothing the package provides is
recomputed by hand.

## Examples

| slug | TanStack source | status | notes |
| --- | --- | --- | --- |
| column-ordering | `examples/react/column-ordering/src/main.tsx` | done | `faker.helpers.shuffle` becomes an `elm/random` shuffle over a seed in the model, so the page stays a `Browser.sandbox`. Order written with `setColumnOrder`. |
| column-dnd | `examples/react/column-dnd/src/main.tsx` | done | `dnd-kit` replaced by HTML5 drag and drop (`Shared/Drag.elm`), drop calls `setColumnOrder` with `arrayMove`. Elm cannot reach `event.dataTransfer.setData`, so Firefox will not start a drag; Chrome and Safari do. Noted in the module and in `Shared.Drag`'s doc. |
| column-pinning | `examples/react/column-pinning/src/main.tsx` | done | The React example has no "split mode" checkbox — split is its own example — so there is none here. Stress test is 10,000 rows instead of 1,000,000: `elm/random` generates rows one at a time and a million would hang the page. |
| column-pinning-split | `examples/react/column-pinning-split/src/main.tsx` | done | Three tables from `leftHeaderGroups`/`centerHeaderGroups`/`rightHeaderGroups` and `leftVisibleCells`/`centerVisibleCells`/`rightVisibleCells`. Stress test 10,000 instead of 1,000,000 (same reason). Own CSS for `.split-tables`. |
| column-pinning-sticky | `examples/react/column-pinning-sticky/src/main.tsx` | done | `position: sticky` offsets from `getColumnStart`/`getColumnAfter`, shadow on last-left / first-right via `columnIsLast`/`columnIsFirst`, `columnIndex` printed in each header like the React `getIndex` demo. The React page also has drag resize handles (`columnResizingFeature`); drag resizing is outside the package, so they are left out (noted in the module). |
| column-sizing | `examples/react/column-sizing/src/main.tsx` | done | The React example is already the non-resizing one: number inputs per column writing `setColumnSizing`. Ported as is (`setColumnSize`), including all three renderings — `<table>` at `centerTotalSize`, flex `<div>` at `totalSize`, and absolute `<div>` laid out with `getHeaderStart`/`getColumnStart`. |
| column-visibility | `examples/react/column-visibility/src/main.tsx` | done | Straight port: toggle-all + per column checkboxes, grouped headers and footers. |
| row-selection | `examples/react/row-selection/src/main.tsx` | done | Indeterminate header and per-row checkboxes via `Html.Attributes.property "indeterminate"`, shift-click range through `selectRange` on the pre-pagination row model, page-rows checkbox in the footer, count and selection dump. The React "Log `getSelectedRowModel().flatRows`" button becomes a `<details>` dump (Elm has no `console.info`). Stress test 10,000 instead of 1,000,000. |
| row-pinning | `examples/react/row-pinning/src/main.tsx` | done | `pinRowWith` with the example's `includeLeafRows`/`includeParentRows` checkboxes, `keepPinnedRows` set on the config from its checkbox, `topRows`/`centerRows`/`bottomRows`, sticky pinned rows positioned with `getRowPinnedIndex`. Data is `makeData 42 [2000, 2, 2]` and the stress button 5,000 × 2 × 2 instead of 200,000 × 2 × 2. |
| row-dnd | `examples/react/row-dnd/src/main.tsx` | done | HTML5 drag and drop; the drop reorders the data list (not the table state), `withGetRowId` keeps ids stable. Same Firefox caveat as column-dnd. |
| cell-selection | `examples/react/cell-selection/src/main.tsx` | done | Click / shift-click / ctrl-click / drag through `selectCell`, `extendCellSelectionTo`, `toggleCellSelection`; arrows and shift+arrows through `moveCellSelection` / `extendCellSelection`; Mod+A `selectAllCells`; Escape `clearCellSelection`; edges from `cellSelectionEdges`; summary from `selectedCellCount` / `cellSelectionRowIds` / `cellSelectionColumnIds`. Clipboard is unreachable from pure Elm, so "Copy Selection" becomes a TSV panel built from `selectedCellRangesData` with the React example's escaping rules, next to the same paste-test textarea. The extra `makeData.ts` fields (phone, city, country, department, salary) are derived deterministically from the generated person in `Shared/PersonExtra.elm` rather than adding fields to `Shared.People.Person`. |
| cell-spanning | `examples/react/cell-spanning/src/main.tsx` | done | `withSpanRows` on region/team, `withSpanRowsWhen` on shift (merges only while sorted by shift), `withSpanColumns` + `spanAllColumns` on the summary subtotal rows; `cellSpanIndex`/`cellRowSpan`/`cellColSpan` drive `rowspan`/`colspan` and covered cells are skipped. Data in `src/CellSpanning/Data.elm`, the Elm counterpart of the example's `makeData.ts`. |
| kitchen-sink | `examples/react/kitchen-sink/src/routes/index.tsx` | done | All of it on `makeData 42 [100, 5, 3]`: fuzzy global filter, text/range/select column filters with faceted values and min/max, sorting incl. a custom status order, grouping with median/sum/mean aggregation, expanding, row selection, row pinning, column visibility, sticky column pinning, column DnD, sizing, cell spanning on Status, cell selection with keyboard, pagination with "Show All". Three deliberate differences, all outside the package: `dnd-kit` → HTML5 DnD; `match-sorter`'s ranked fuzzy filter → a plain subsequence match (so its `fuzzySort` companion is not ported); the drag resize handles are dropped (sizes still come from `getColumnSize`/`getHeaderSize`/`totalSize`). |
| realtime-trading | `examples/react/realtime-trading` | done | `Browser.element` + `Time.every`; the web-worker feed becomes `RealtimeTrading/Feed.elm`, the same walk (row cursor striding by 97, same volatility formula) stepped from a `Random.Seed` in the model, with the per-tick move scaled up because Elm ticks a few times a second where the worker ticks thousands. Instrument universe is the first 100 rows of `market-instruments.ts` (`RealtimeTrading/Instruments.elm`). Column groups, headers and sizes match `trading-table-config.tsx`; the SVG sparkline becomes block characters. The React shell's benchmark/diagnostics panels, virtualizer and web worker are out of scope; the feed controls that remain are pause/start, instrument count, delivery interval, and the symbol filter. |

## Package bugs or gaps hit

None. Every function behaved as documented; no workaround was needed inside
the package's surface. The only things that could not be mirrored are
browser/library concerns listed above (dnd-kit, match-sorter ranking, drag
resizing, `navigator.clipboard`, web workers, virtualization) plus the
row-count reductions where `elm/random` cannot generate a million rows
interactively.

## Files added

- `examples-site/src/{ColumnOrdering,ColumnDnd,ColumnPinning,ColumnPinningSplit,ColumnPinningSticky,ColumnSizing,ColumnVisibility,RowSelection,RowPinning,RowDnd,CellSelection,CellSpanning,KitchenSink,RealtimeTrading}.elm`
- `examples-site/src/{ColumnPinningSplit,ColumnPinningSticky,ColumnSizing,RowPinning,CellSelection,CellSpanning,KitchenSink,RealtimeTrading}.css`
- `examples-site/src/CellSpanning/Data.elm`
- `examples-site/src/RealtimeTrading/{Feed,Instruments}.elm`
- `examples-site/src/Shared/{Drag,PersonExtra,StateJson}.elm`

`examples-site/src/Shared/People.elm` was touched only by `elm-format --yes`
(a three-line doc-comment reflow of the code block at the top); no code or
exposed value changed.

## Verified in a browser

Served `examples-site/dist` over `python3 -m http.server` and clicked through
these in Chrome (agent-browser and the Chrome extension tools):

- **column-dnd** — dragged the Age handle onto First Name; the column moved to
  the front and `columnOrder` in the state dump followed. Regenerate Data
  re-seeds the rows.
- **cell-selection** — click then shift-click gave "12 cells selected across 4
  rows and 3 columns" with a single continuous outline; ArrowDown collapsed the
  selection to one cell and moved it two rows.
- **kitchen-sink** — grouped by Status from the header 👊 button: three group
  rows with counts, median age / sum visits / mean progress aggregates, the
  `select` column stays pinned left, filters show faceted counts and bounds.
  Fixed here: a column with no aggregation used to render its expander on a
  group row; it now renders nothing, matching the React `aggregatedCell: () => null`.
- **column-pinning-sticky** — pinned First Name left, scrolled horizontally, the
  column stayed put with the inset shadow; header region indexes update.
- **row-selection** — clicked one checkbox (1 of 1000, header and footer
  checkboxes indeterminate), shift-clicked seven rows lower and got 8 selected.
- **row-pinning** — ⬆️ moved a row into the sticky top region and swapped its
  button for ❌.
- **cell-spanning** — North spans 9 rows, each team spans 3, the subtotal rows
  span the label columns. Fixed here: the three panels overlapped, so the
  per-example CSS now gives each panel `min-width: 0; overflow-x: auto`.
- **realtime-trading** — FEED LIVE, prices ticking with `up`/`down` colouring,
  pause/interval/instrument-count controls. Fixed here: the table went through
  `Table.rows`, so the default page size showed only 10 of the 100 instruments;
  the pipeline now stops at the sorted row model, as the React example does.
- **column-pinning** — pinned the Name group right; both leaves moved to the end.
- **column-pinning-split** — pinning moves columns between the three tables.
- **column-visibility** — unchecking `visits` drops the column and narrows the
  "More Info" group's colspan; footers render.
- **column-sizing** — editing a size input writes `columnSizing` in the state.
- **column-ordering** — Shuffle Columns rewrites `columnOrder` and the grouped
  headers regroup around the new order.

## Build

`cd examples-site && bun run build.ts`

```
14 built, 0 failed, 15 not yet written: basic, basic-external-state, basic-dynamic-columns, header-groups, filters, filters-faceted, filters-faceted-bucketed, filters-fuzzy, expanding, sub-components, grouping, aggregation, grouped-aggregation, pagination, sorting
```

The 15 "not yet written" are the other agent's half of the manifest.
`elm-format --validate examples-site/src` is clean.
