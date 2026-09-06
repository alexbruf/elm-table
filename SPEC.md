# Elm Headless Table: Port of TanStack Table Core

Handoff plan for an autonomous agent. Scope is `packages/table-core` only. No framework adapters, devtools, flexRender, or worker code.

## Goal

Publish an Elm 0.19.1 package `viewengine/elm-table` (working name) that reproduces TanStack Table's row-model pipeline and column state as pure functions, verified by ported tests from the TanStack repo.

## Source

- Repo: https://github.com/TanStack/table, branch `main`, clone with `--depth 1` and record the commit SHA in `PORT_NOTES.md`.
- Reference code: `packages/table-core/src`
- Reference tests: `packages/table-core/tests/unit/fns`, `packages/table-core/tests/implementation`, `packages/table-core/tests/unit/core`, fixtures in `packages/table-core/tests/fixtures`
- Prior art in Elm to read before designing: `evancz/elm-sortable-table` (sorting only), `dominikmayer/elm-virtual-list` (out of scope, but the intended pairing for large tables)

## Constraints

1. Pure Elm. No ports, no custom elements, no JS. Column resize by drag is out of scope; column sizing is state only.
2. Headless. The package exposes data and state; it renders nothing. A `Html`-free core module plus an optional thin `Table.View` helper module is acceptable, but tests must not depend on the view module.
3. User owns state. There is no instance object. Every function is `Config row -> State -> ...`.
4. One `Value` union for cell values: `String`, `Number Float`, `Bool`, `Date Time.Posix`, `Null`. Accessors return `Value`. Custom sort and filter functions take `row` directly so users are not forced through `Value`.
5. Match TanStack semantics wherever Elm can express them. Where JS quirks (undefined ordering, NaN, `-0`, prototype safety) drive a test, document the Elm behavior in `PORT_NOTES.md` and adjust the expected value, do not delete the test silently.
6. `elm-format` clean, `elm-review` with the default rule set clean, no `Debug` in shipped modules.

## Public API target

```elm
module Table exposing (..)

type alias Column row
type alias Config row          -- columns, getRowId, feature flags (manualSorting etc.)
type alias State               -- sorting, columnFilters, globalFilter, grouping, expanded,
                               -- rowSelection, pagination, columnOrder, columnVisibility,
                               -- columnPinning, columnSizing, rowPinning
type Row row                   -- id, index, depth, original, subRows, groupingColumnId, groupingValue
type alias RowModel row        -- rows (tree), flatRows, rowsById

initialState : State
rows : Config row -> State -> Array row -> RowModel row   -- full pipeline
coreRowModel, filteredRowModel, sortedRowModel, groupedRowModel,
expandedRowModel, paginatedRowModel : intermediate stages, each exposed

-- columns and headers
leafColumns, visibleLeafColumns, headerGroups, pinnedColumns
-- faceting
facetedUniqueValues, facetedMinMax
-- state transitions (pure)
toggleSort, setColumnFilter, toggleGrouping, toggleExpanded, toggleRowSelected,
toggleAllRowsSelected, setPage, setPageSize, ...
-- built-in fns
Table.SortFn: alphanumeric, alphanumericCaseSensitive, text, textCaseSensitive, datetime, basic
Table.FilterFn: includesString, includesStringSensitive, equalsString, arrIncludes,
                arrIncludesAll, arrIncludesSome, equals, weakEquals, inNumberRange
Table.AggregationFn: sum, min, max, extent, mean, median, unique, uniqueCount, count
```

Names may change during phase 1 if the ported tests make a better shape obvious. Record any rename in `PORT_NOTES.md`.

## Phases

Each phase ends with a commit, all tests green, and a short entry in `PORT_NOTES.md` listing tests skipped or altered and why.

### Phase 0: Setup

- Create package skeleton with `elm.json` (type `package`), `elm-test`, `elm-review`, `elm-format` wired into a `make check` target.
- Clone TanStack Table, record SHA.
- Write `tests/Fixtures.elm`: a typed `Person` record and generator matching `tests/fixtures/data` (firstName, lastName, age, visits, status, progress, plus the nested subRows shape used by expanding tests).

Done when: `make check` passes on an empty package with one placeholder test.

### Phase 1: Built-in functions

Port `unit/fns/sortFns.test.ts` (49 cases), `unit/fns/filterFns.test.ts` (135 cases), `unit/fns/aggregationFns.test.ts`.

- Implement `Table.SortFn`, `Table.FilterFn`, `Table.AggregationFn`, and the `Value` type.
- `reSplitAlphaNumeric` natural-sort chunking must match TanStack (`item2` before `item10`; string chunk sorts before number chunk).

Done when: every case in the three vitest files has a corresponding elm-test case, and the pass count equals the case count minus the documented JS-quirk exclusions (target: at most 10 exclusions across the three files).

### Phase 2: Core row model and columns

Port `implementation/core/row-models/createCoreRowModel.test.ts`, `rowModelFlatRowsOrder.test.ts`, and the assertion-level content of `unit/core/columns`, `unit/core/headers`, `unit/core/rows`.

- Implement `Column`, `Config`, `Row`, `RowModel`, `coreRowModel`, `leafColumns`, `headerGroups` (including grouped column headers and placeholder headers), `getRowId`, sub-row flattening with correct depth and `flatRows` order.

Done when: core row model and header group tests pass; a 10,000-row `coreRowModel` call completes under 100 ms in `elm-test` on the agent machine (record the number).

### Phase 3: Filtering, faceting, sorting, pagination

Port `column-filtering/createFilteredRowModel.test.ts`, `column-faceting/createFacetedRowModels.test.ts`, `column-filtering/columnFilteringFeature.utils.test.ts`, `global-filtering/globalFilteringFeature.utils.test.ts`, `row-sorting/createSortedRowModel.test.ts`, `row-sorting/rowSortingFeature.utils.test.ts`, `row-pagination/*`.

- Filtering must respect `filterFromLeafRows` and `maxLeafRowFilterDepth`.
- Sorting must support multi-sort, `sortDescFirst`, `invertSorting`, `sortUndefined` mapped onto `Null` placement, and stable ordering.
- Manual (server-side) flags skip the stage and return the input unchanged.

Done when: all listed test files are ported and green, exclusions documented.

### Phase 4: Grouping, aggregation, expansion

Port `column-grouping/createGroupedRowModel.test.ts`, `column-grouping/columnGroupingFeature.test.ts`, `row-aggregation/rowAggregationFeature.test.ts`, `row-expanding/createExpandedRowModel.test.ts`, `row-expanding/rowExpandingFeature.test.ts`.

- Group rows carry `groupingColumnId`, `groupingValue`, aggregated `Value`s per column, and `leafRows`.
- Expansion flattens the tree according to `State.expanded` (`ExpandAll` or `Set rowId`), with `paginateExpandedRows` honored in phase 3's paginator.

Done when: all listed test files are ported and green. This is the phase most likely to force a type change; if `Row` changes, re-run phases 1 to 3.

### Phase 5: Selection, pinning, ordering, visibility, sizing

Port `row-selection/rowSelectionFeature.test.ts`, `row-selection/rowSelectionRange.test.ts`, `row-pinning/*`, `column-pinning/*`, `column-ordering/*`, `column-visibility/*`, `column-sizing/*`.

- Row selection propagates to sub-rows and reports `isSomeSelected` / `isAllSelected` per parent.
- Column pinning returns left, center, right leaf column lists; no DOM.
- Column sizing is state plus `getSize` with min/max clamping; no resize handlers.

Done when: all listed test files are ported and green.

### Phase 6: Cell selection and cell spanning (optional, only if phases 0 to 5 are complete)

Port `cell-selection/*` and `cell-spanning/*`. Skip the `performance/` directory.

Done when: ported and green, or explicitly deferred in `PORT_NOTES.md` with the reason.

### Phase 7: Package hygiene

- Docs on every exposed value, `elm make --docs=docs.json` succeeds.
- `README.md` with one full example (sort + filter + paginate + group) rendering a plain `Html.table`.
- `examples/` folder with one `elm reactor`-runnable app using the README example on the fixture data.
- `PORT_NOTES.md` complete: SHA, test coverage table (per vitest file: cases, ported, passing, excluded), semantic differences list.

Done when: `elm publish --dry-run` style checks pass (`elm make --docs`, `elm diff` not applicable for 1.0.0), and the coverage table shows every in-scope file at 100% ported.

### Phase 8: Usable demo

Build `demo/` as a standalone `Browser.element` app that depends on the package via a local path, on a generated dataset. No live data sources.

Dataset:

- Generate deterministically in Elm from a fixed seed (`elm/random`), 5,000 rows, shape: SEO-style "keyword report" so the demo is recognizable: keyword, cluster (grouping key), intent (enum), search volume, difficulty, current position, previous position, change, URL, last crawled (date), plus 0 to 3 sub-rows per row for query variants.
- Expose a "Regenerate" control with a seed input so reviewers can vary data without a backend.

Required features, all wired to package state, none faked in the demo:

1. Click-to-sort headers with multi-sort on shift-click and a visible sort index.
2. Per-column filters: text (includesString), enum select (equals), numeric range (inNumberRange), date range.
3. Global search box.
4. Group by cluster and by intent, with sum/mean aggregates shown on group rows and expand/collapse of groups.
5. Expandable sub-rows for query variants.
6. Row selection with header checkbox (all / some indicator) and a selected-count readout.
7. Pagination with page size selector (10, 25, 50, 100).
8. Column visibility toggles and pin-left for the keyword column.
9. A footer showing pipeline timings for the last recompute (core, filtered, sorted, grouped, expanded, paginated) in milliseconds.

UI rules (from ViewEngine design preferences): whitespace-heavy, max 2 font weights, 1 accent color, hierarchy by size and spacing not borders, no settings inside modals, plain headlines, none of the banned words.

Build and deploy:

- `make demo` produces `demo/dist/index.html` plus one JS file, optimized with `elm make --optimize` and minified.
- Deploy to a static host (Cloudflare Pages preferred) and record the URL in `README.md` and `PORT_NOTES.md`.

Done when: the deployed URL loads, every feature in the list above works on the 5,000-row dataset, no interaction takes longer than 200 ms end to end in the footer timings on a laptop, and a reviewer can complete this script without help: filter to intent = commercial, group by cluster, sort by volume descending, expand the top group, select three rows, change page size to 50.

## Explicitly out of scope

- Framework adapters, devtools, `flexRender`, Web Worker serialization
- `autoReset`, `setStateSlice`, `readonlyOptions`, `prototypeSafeDictionaries`, `renderPhaseReactivity`, `tableAtoms` tests
- Drag-to-resize columns, any DOM measurement
- Virtualization (pair with `dominikmayer/elm-virtual-list` later); the demo paginates instead

## Definition of done (whole project)

1. Phases 0 to 5, 7 and 8 complete; phase 6 complete or deferred with reason.
2. `make check` green: elm-format, elm-review, elm-test.
3. `PORT_NOTES.md` coverage table: 100% of in-scope vitest files ported; total excluded cases under 5% of total in-scope cases, each with a one-line reason.
4. No exposed function takes or returns a value that depends on a DOM or JS runtime.
5. README example compiles and runs in `elm reactor`.
6. Demo deployed at a public URL and the phase 8 reviewer script passes.
7. Core row model on 10,000 rows under 100 ms; full pipeline (filter + sort + group + paginate) on 10,000 rows under 500 ms, both numbers recorded in `PORT_NOTES.md`.

## Reporting

At the end of each phase, report: phase number, commit SHA, test counts (ported / passing / excluded), any API rename, and the single biggest open risk for the next phase. Do not proceed past a phase with failing tests.
