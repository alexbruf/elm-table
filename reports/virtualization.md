# Virtualization: examples and guide

## Approach

TanStack pairs the table with TanStack Virtual. There is no single Elm
package that does both axes, so this port uses two things, chosen by the
agent that built the examples (confirmed by reading `examples-site/elm.json`
and `examples-site/src/Shared/Virtual.elm` before touching anything):

- **`FabienHenon/elm-infinite-list-view` 3.3.1** for a vertical list of rows.
  It owns the scroll container, the item offsets, and the visible window.
  Used by **Virtualized Rows** and **Infinite Scrolling**.
- **A hand-written window helper, `Shared.Virtual`** (`examples-site/src/Shared/Virtual.elm`),
  for **Virtualized Columns**. `elm-infinite-list-view` has no horizontal
  mode and owns its own scroll container, so both axes of that table are
  windowed from three numbers this package already exposes:
  `getColumnStart`, `getColumnSize`, and `totalSize` (plus a fixed row
  height on the vertical axis). The module docs explain the choice in place.

This was already decided and half-built by the previous agent; nothing about
the approach needed to change, only finishing it: building, browser
verification, the docs guide, the README/SPEC line, and this report.

## Examples

| slug | TanStack source | status | notes |
| --- | --- | --- | --- |
| `virtualized-rows` | `examples/react/virtualized-rows` | done | 50,000 rows; pipeline stops at `sortedRowModel`, recomputed once per `update`; row window via `InfiniteList`. |
| `virtualized-columns` | `examples/react/virtualized-columns` | done | 200 rows × 1,000 columns; both axes windowed via `Shared.Virtual` (`fixed` for rows, `variable` for columns using a running sum of `getColumnSize`); spacer cells from `getColumnStart` / `totalSize`. |
| `virtualized-infinite-scrolling` | `examples/react/virtualized-infinite-scrolling` | done | 1,000-row fake backend, 50 rows/page, `Process.sleep 200` stand-in for latency; `InfiniteList` for the row window; sort is client-side and scrolls back to top. |

Build: `cd examples-site && bun run build.ts virtualized-rows virtualized-columns virtualized-infinite-scrolling` → `3 built, 0 failed, 0 not yet written`. `elm-format --validate examples-site/src` → clean (no changes needed).

## Browser verification

Chrome MCP tabs in this environment reported `document.hidden: true` and a
0×0 viewport even after `resize_window` (no attached display), so
verification used the `agent-browser` CLI against
`python3 -m http.server` in `examples-site/dist` instead. The server was
stopped afterward.

**Virtualized Rows** — DOM `tr` count in `.virtual-body tbody` at three scroll positions (container height 600px, scrollHeight 1,650,033px, 50,000 rows):

| Position | scrollTop | DOM `tr` count |
| --- | --- | --- |
| Top | 0 | 31 |
| Middle | 500,000 | 31 |
| Bottom | ~max (1,649,435) | 24 |

Sorting "First Name" re-sorted correctly (rows became `Alice, Alice, Alice, ...`) and the DOM row count stayed at 31 afterward.

**Virtualized Columns** — DOM `tr` count in `.virtual-grid tbody` (includes 2 spacer rows), at three scroll positions (200 rows × 1,000 columns, container 600×1000px):

| Position | scrollTop / scrollLeft | DOM `tr` count | Visible columns |
| --- | --- | --- | --- |
| Top-left | 0 / 0 | 25 (23 rows + 2 spacers) | 10 |
| Middle | 3,000 / 0 | 28 (26 rows + 2 spacers) | 10 |
| Bottom-right | 6,049 / 80,000 (max) | 22 (20 rows + 2 spacers) | 13 |

Sorting: a `ref`-based click on a sticky column header caused `agent-browser`'s scroll-into-view step to shift the horizontal scroll position before the click landed (an automation artifact of `position: sticky` headers in a table scrolling on both axes, not an app bug). A direct `MouseEvent` dispatched on the header element confirmed sorting works correctly — the clicked column showed the sort arrow and its values were in ascending order, with the small DOM window preserved (still ~20 rows / ~13 columns).

**Infinite Scrolling** — DOM `tr` count in `.virtual-body tbody` at three scroll positions, after scrolling to the bottom repeatedly to load all pages:

| Stage | Loaded rows | DOM `tr` count |
| --- | --- | --- |
| Initial load | 50 of 1,000 | 31 |
| After first scroll-to-bottom | 100 of 1,000 | 31 |
| Mid-way (several more scrolls) | 400 of 1,000 | 31 |
| Fully loaded, top | 1,000 of 1,000 | 31 |
| Fully loaded, middle (scrollTop 16,500) | 1,000 of 1,000 | 31 |
| Fully loaded, bottom (scrollTop 33,033, max) | 1,000 of 1,000 | 24 |

Scrolling near the bottom of what was loaded fetched the next page each time and the "X of 1,000 rows fetched" counter grew (50 → 100 → ... → 1,000), confirming infinite scroll works, while the DOM row count never exceeded 31. Sorting "First Name" after all 1,000 rows loaded scrolled back to the top and re-sorted correctly (`Alice, Alice, Alice, ...`), DOM count still 31.

No bugs found in the shipped code; the only issue encountered was an automation quirk with `agent-browser`'s ref-click auto-scroll on sticky headers, worked around with a direct DOM click.

## Docs guide

Replaced the stub at `docs-site/content/guide/virtualization.md` with a full
guide mirroring the TanStack React virtualization guide section for section,
adapted to what was actually built:

- Why the package paginates by default (default page size 10) and the two
  ways to bypass it: `unlimitedPageSize`, or stopping the pipeline at
  `prePaginationRowModel`.
- Feeding `rowsInDisplayOrder` to a virtual list, with stable row ids via
  `withGetRowId` / `rowId`.
- Keeping the row model in the model and slicing/rendering in `view` (the
  `recompute`-in-`update` pattern), not recomputing on every scroll event.
- Expanding rows with virtualization: stopping the pipeline one stage later,
  at `expandedRowModel`, instead of `sortedRowModel`.
- Column virtualization with `visibleLeafColumns`, `getColumnStart`,
  `getColumnSize`, `totalSize`, and the running-sum / spacer-cell technique,
  plus a short note on windowing both axes together.
- Infinite scrolling: the fetch-threshold pattern as a pure function, and the
  client-side vs. server-side sorting split (link to that guide).
- An iframe embed of `https://elm-table-examples.pages.dev/virtualized-rows/`
  (matching the convention in `pagination.md` / `column-sizing.md`), plus
  plain links to all three examples.

New snippet module `docs-site/snippets/src/VirtualizationGuide.elm`, all
declarations referenced from the guide via `elm snippet=` fences and
verified against the actual rendered HTML (no leaked comments, no stray
Elm keywords). Added `FabienHenon/elm-infinite-list-view` to
`docs-site/snippets/elm.json` via `elm install` so the row-list snippets
compile. Removed the now-superseded `docs-site/snippets/src/Virtualization.elm`
(the old stub's snippet source, which described `dominikmayer/elm-virtual-list`
— not what was actually built — and is no longer referenced anywhere).

Build: `cd docs-site && bun install && make dist` →
```
docs.json regenerated
34 snippet modules compile
49 pages written to dist/
309 snippet blocks inlined from 303 declarations
reference Table: 394/394 entries
reference Table.Value: 4/4 entries
reference Table.SortFn: 12/12 entries
reference Table.FilterFn: 32/32 entries
reference Table.AggregationFn: 16/16 entries
reference total: 458/458 entries
1684 internal links checked, 0 broken
note: 47 snippet declarations are not referenced
```
`./banned.sh` → `banned-word check: 0 hits`.

## README / SPEC line

`README.md` has no mention of virtualization anywhere (`grep -in virt README.md` returns nothing) — no "out of scope" or "paired later" line exists there to update. The line matching that description lives in **`SPEC.md`** instead, in "Explicitly out of scope":

> `- Virtualization (pair with \`dominikmayer/elm-virtual-list\` later); the demo paginates instead`

Since this is the one place in the repo making that claim, and it now names
the wrong package besides being stale, it was updated to:

> `- Virtualization is covered by a guide and three examples rather than a package feature; see https://elm-table-docs.pages.dev/guide/virtualization/ and https://elm-table-examples.pages.dev. The demo still paginates instead.`

`SPEC.md` was not named in the task, so flagging this substitution explicitly: if a README.md line was expected and one should be added there too (e.g. in the "Differences from TanStack" or a new scope note), that's a follow-up, not done here.

## Files touched

- `examples-site/src/VirtualizedRows.elm`, `VirtualizedColumns.elm`, `VirtualizedInfiniteScrolling.elm`, `examples-site/src/Shared/Virtual.elm` — built and verified (pre-existing from prior agent, unchanged by this pass).
- `docs-site/content/guide/virtualization.md` — rewritten.
- `docs-site/snippets/src/VirtualizationGuide.elm` — new.
- `docs-site/snippets/src/Virtualization.elm` — removed (superseded).
- `docs-site/snippets/elm.json` — added `FabienHenon/elm-infinite-list-view`.
- `SPEC.md` — updated the stale "out of scope" virtualization line.

No commits were made, per instructions.
