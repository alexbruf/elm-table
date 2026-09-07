# Port notes

Running log for the Elm port of TanStack Table core. See `SPEC.md` for the plan.

## Reference

- Repo: https://github.com/TanStack/table, branch `main`
- Commit: `36733a38b6a77878eea616b25012c47a0f93d4da` (shallow clone, 2026-09-06)
- Local path: `reference/tanstack-table` (gitignored)
- Scope: `packages/table-core/src` and `packages/table-core/tests/{unit,implementation}`

## Design decisions

1. **`Value` has a `List` constructor.** The spec lists five constructors
   (`String`, `Number`, `Bool`, `Date`, `Null`). A sixth, `List (List Value)`,
   was added so array cell values exist: `arrIncludes`, `arrIncludesAll`,
   `arrIncludesSome`, the `extent` and `unique` aggregations, and range filter
   values (`[min, max]`) all need one. `Null` stands in for both `null` and
   `undefined`.
2. **Built-in filter fns carry their resolvers.** TanStack v9 filter fns are
   records of `filter`, `resolveFilterValue`, `resolveDataValue`, `autoRemove`.
   The Elm `FilterFn` is an opaque record with the same four parts so the
   `constructFilterFn` tests can be ported.

## Phase reports

### Phase 0: Setup

- Package skeleton, `make check` (elm-format, elm-review package template,
  elm-test), fixtures, placeholder test.
- Tests: 4 ported (fixture shape only) / 4 passing / 0 excluded.
- Biggest risk for phase 1: JavaScript coercion cases in `filterFns.test.ts`
  (`"1" == 1`, `String(null)`, `NaN`) that have no direct Elm counterpart.

### Phase 1: Built-in functions

- Commit `d7a0fd7`. Tests: 178 ported / 178 passing / 6 excluded of 184.
- Contract additions: `Value.toNumber`, `SortFn.splitAlphaNumeric`,
  `FilterFn.toDateTimestamp`.
- Biggest risk for phase 3: `FilterFn.filter` resolves only the cell value;
  the row model must call `resolveFilterValue` once per filter and
  `autoRemove` first.

### Phase 2: Core row model and columns

- Commit `3b78bf4`. Tests: 69 ported / 69 passing / 46 excluded of 115. The
  46 are instance identity and memoization (7), feature-registry and
  `setOptions` mechanics including all of `constructTable` and
  `rowModelSlots` (29), rendering (7), and later phases (3).
- Bench (`make bench`, node 24, `--optimize`): `coreRowModel` on 10,000 flat
  rows 9.7 ms min / 14.7 ms median; 2,500 parents × 3 children 10.8 ms min /
  12.9 ms median. Target was under 100 ms.
- Biggest risk for phase 3: `Nothing` filter fn means `'auto'`; auto-detection
  and resolve-once placement are phase 3's job.

### Phase 3: Filtering, faceting, sorting, pagination

- Commit `19d6dfe`. Tests: 231 ported / 231 passing / 25 excluded of 256
  (9.8%). Side effect: `filterFns.test.ts` rises to 133 ported (2 excluded)
  and `coreRowModelsFeature.utils.test.ts` to 10 ported (7 excluded).
- Contract changes: `Column.sortUndefined`, `enableMultiSort`,
  `enableGlobalFilter` and `Config.sortDescFirst` became `Maybe` (TanStack
  distinguishes unset from `false`); `Config` gained `enableFilters`,
  `getColumnCanGlobalFilter`, `pageCount`, `rowCount`; new abstract `SortDir`
  (`sortAsc` / `sortDesc`).
- API notes: `getIsSorted` returns `Maybe SortDir`; `setColumnFilter` and
  `toggleSort` take a `RowModel row` because `autoRemove` and the automatic
  first sort direction are data-derived, as in TanStack.
- Bench: full pipeline (10,000 rows, one `includesString` filter, one sort,
  page size 50) 86.2 ms min / 94.7 ms median, down from 242 / 336 ms after
  resolving the column reader once per stage instead of per row.
- Biggest risk for phase 4: group rows feed `aggregatedValues` to filtering
  and sorting via `getValue`; `Pagination.elm` carries its own `expandRows`
  that must be unified with the expanded row model.

### Phase 5: Selection, pinning, ordering, visibility, sizing

- Commit `22181af` (merge). Tests: 297 ported / 287 passing / 20 excluded of
  317 (6.3%); 10 cases are written but held back in `pendingIntegration`
  lists until phase 4 lands (they need grouped or expanded rows).
- Contract changes: `Config.enableRowSelection`, `enableMultiRowSelection`,
  `enableSubRowSelection`, `enableRowPinning` are `Row row -> Bool`;
  `withRowSelection` keeps its name. Column ordering composes in one place,
  `Column.orderColumns` (`allColumns → columnOrder → groupedColumnMode →
  visibility → pin split`). `visibleLeafColumns` is not pin-ordered, matching
  TanStack; the pin partition lives in the header seam and `visibleCells`.
- Merge fix: `selectRange` / `canSelectRange` walk the pre-pagination rows in
  display order (`rowsInDisplayOrder`), as TanStack's `getRowsInDisplayOrder`,
  so a shift-click range can span pages; `canSelectRange` gained a `State`
  argument.
- Biggest risk for phase 4's merge: grouped-column reordering must stay in
  `orderGroupedColumns` only.

### Phase 4: Grouping, aggregation, expansion

- Commit `HEAD` of the phase 4 merge. Tests: 113 ported / 113 passing / 11
  excluded of 124 (8.9%); `createPaginatedRowModel.test.ts` rises to 16 / 0
  excluded. The 10 held-back phase 5 integration cases are wired in and pass.
- Contract changes: `Config.getRowCanExpand`, `Config.getIsRowExpanded`,
  `Column.maxAggregationDepth` added; `Column.getGroupingValue` is
  `row -> Int -> Value`; `Column.aggregationFn = Nothing` means `'auto'`
  (`sum` for numbers, `extent` for dates). `Pagination.elm` reuses
  `Expanding.expandList`, removing the duplicate `expandRows`.
- Load-bearing decisions: group rows carry an explicit `aggregatedValues`
  entry for every leaf column (`Null` included) so `getValue` never falls
  through to the first leaf's accessor; `Null` grouping keys land under the
  key `"null"`, so TanStack's `null` and `undefined` buckets merge; group ids
  are `columnId:value` chained with `>`.
- Bench: pipeline with grouping (10,000 rows, one filter, 20 groups, `sum` and
  `mean`, `expandAll`, one sort, page 50) 149.4 ms min / 156.3 ms median
  against a 500 ms target.

### Phase 6: Cell selection and cell spanning

- Merged. Tests: 129 ported / 129 passing / 14 excluded of 143 (9.8%): 7
  DOM and drag-session handler cases, 5 `autoResetCellSelection`, 2
  memoization. The two cases that needed grouped and expanded rows pass
  after the merge.
- Contract additions: `State.cellSelection`; `Config.enableCellSpanning`,
  `enableCellSelection`, `cellSelectionFilter`, `enableCellRangeSelection`,
  `enableMultiCellRangeSelection`; `Column.enableCellSpanning`, `spanColumns`,
  `spanRows`, `enableCellSelection`. `CellSpanIndex` is an explicit value
  (`cellSpanIndex cfg state model`) because there is no memoisation.
  Selection reads take `SelectionRows { prePaginated, current }`.

## Coverage table

Filled in per phase. Cases are counted as `it(` / `test(` calls in the vitest
file. Full per-case exclusion lists live in `reports/phase-N.md`.

| vitest file | cases | ported | passing | excluded |
| --- | --- | --- | --- | --- |
| `unit/fns/sortFns.test.ts` | 41 | 41 | 41 | 0 |
| `unit/fns/filterFns.test.ts` | 135 | 133 | 133 | 2 |
| `unit/fns/aggregationFns.test.ts` | 8 | 8 | 8 | 0 |
| `implementation/core/row-models/createCoreRowModel.test.ts` | 18 | 18 | 18 | 0 |
| `implementation/core/row-models/rowModelFlatRowsOrder.test.ts` | 1 | 1 | 1 | 0 |
| `unit/core/columns/constructColumn.test.ts` | 2 | 1 | 1 | 1 |
| `unit/core/columns/coreColumnsFeature.utils.test.ts` | 13 | 11 | 11 | 2 |
| `unit/core/headers/constructHeader.test.ts` | 3 | 1 | 1 | 2 |
| `unit/core/headers/coreHeadersFeature.utils.test.ts` | 13 | 13 | 13 | 0 |
| `unit/core/rows/constructRow.test.ts` | 2 | 2 | 2 | 0 |
| `unit/core/rows/coreRowsFeature.utils.test.ts` | 21 | 19 | 19 | 2 |
| `unit/core/row-models/coreRowModelsFeature.utils.test.ts` | 17 | 17 | 17 | 0 |
| `unit/core/cells/constructCell.test.ts` | 2 | 1 | 1 | 1 |
| `unit/core/cells/coreCellsFeature.utils.test.ts` | 4 | 2 | 2 | 2 |
| `unit/core/table/constructTable.test.ts` | 7 | 0 | 0 | 7 |
| `unit/core/table/rowModelSlots.test.ts` | 11 | 0 | 0 | 11 |
| `unit/core/table/stockFeaturesInitialState.test.ts` | 1 | 1 | 1 | 0 |
| `implementation/features/column-filtering/createFilteredRowModel.test.ts` | 38 | 32 | 32 | 6 |
| `unit/features/column-filtering/columnFilteringFeature.utils.test.ts` | 28 | 26 | 26 | 2 |
| `implementation/features/column-faceting/createFacetedRowModels.test.ts` | 22 | 21 | 21 | 1 |
| `unit/features/column-faceting/columnFacetingFeature.test.ts` | 4 | 4 | 4 | 0 |
| `unit/features/global-filtering/globalFilteringFeature.utils.test.ts` | 20 | 19 | 19 | 1 |
| `implementation/features/row-sorting/createSortedRowModel.test.ts` | 25 | 25 | 25 | 0 |
| `unit/features/row-sorting/rowSortingFeature.utils.test.ts` | 52 | 50 | 50 | 2 |
| `implementation/features/row-pagination/createPaginatedRowModel.test.ts` | 16 | 16 | 16 | 0 |
| `unit/features/row-pagination/rowPaginationFeature.utils.test.ts` | 51 | 49 | 49 | 2 |
| `unit/features/column-visibility/columnVisibilityFeature.utils.test.ts` | 27 | 27 | 27 | 0 |
| `unit/features/column-ordering/columnOrderingFeature.utils.test.ts` | 22 | 22 | 22 | 0 |
| `unit/features/column-pinning/columnPinningFeature.utils.test.ts` | 56 | 56 | 56 | 0 |
| `unit/features/column-sizing/columnSizingFeature.utils.test.ts` | 38 | 38 | 38 | 0 |
| `implementation/features/row-selection/rowSelectionFeature.test.ts` | 34 | 34 | 34 | 0 |
| `implementation/features/row-selection/rowSelectionRange.test.ts` | 23 | 22 | 22 | 1 |
| `unit/features/row-selection/rowSelectionFeature.utils.test.ts` | 58 | 58 | 58 | 0 |
| `unit/features/row-pinning/rowPinningFeature.utils.test.ts` | 37 | 37 | 37 | 0 |
| `implementation/features/row-pinning/rowPinningFeature.test.ts` | 20 | 20 | 20 | 0 |
| `implementation/features/column-grouping/createGroupedRowModel.test.ts` | 15 | 15 | 15 | 0 |
| `implementation/features/column-grouping/columnGroupingFeature.test.ts` | 1 | 1 | 1 | 0 |
| `unit/features/column-grouping/columnGroupingFeature.utils.test.ts` | 24 | 24 | 24 | 0 |
| `implementation/features/row-aggregation/rowAggregationFeature.test.ts` | 18 | 13 | 13 | 5 |
| `implementation/features/row-expanding/createExpandedRowModel.test.ts` | 13 | 13 | 13 | 0 |
| `implementation/features/row-expanding/rowExpandingFeature.test.ts` | 2 | 2 | 2 | 0 |
| `unit/features/row-expanding/rowExpandingFeature.utils.test.ts` | 51 | 50 | 50 | 1 |
| `unit/features/cell-spanning/cellSpanningFeature.utils.test.ts` | 13 | 13 | 13 | 0 |
| `implementation/features/cell-spanning/cellSpanningFeature.test.ts` | 14 | 14 | 14 | 0 |
| `implementation/features/cell-selection/cellSelectionFeature.test.ts` | 66 | 62 | 62 | 4 |
| `implementation/features/cell-selection/cellSelectionGeometry.test.ts` | 11 | 11 | 11 | 0 |
| `implementation/features/cell-selection/cellSelectionRange.test.ts` | 23 | 23 | 23 | 0 |
| `implementation/features/cell-selection/cellSelectionSpanAware.test.ts` | 16 | 16 | 16 | 0 |

### Re-homing pass

Every excluded case whose vitest body still held a data-level assertion Elm can
express was ported as an adapted test (the `it` name verbatim plus a one-line
`-- adapted:` comment). 60 cases moved from excluded to ported, taking the
totals to 1,082 ported and 55 excluded of 1,137 (4.8%), which meets `SPEC.md`
"Definition of done" item 3. The per-case list, the adaptations, the remaining
exclusions grouped by reason and the "needs API" list are in
`reports/rehoming.md`.

## Semantic differences

See `reports/phase-1.md` (9 items: `Null` covers `null` and `undefined`,
`toString Null == ""`, invalid dates as `Number NaN`, ISO-only date strings,
exact numeric chunk comparison above 15 digits, structural `weakEquals`,
`toNumber` via `String.toFloat`, NaN written `sqrt -1`) and
`reports/phase-2.md` (pipeline order is core → filtered → grouped → sorted →
expanded → paginated, matching TanStack's `preSorted = grouped`; abstract
`Expanded` / `SortUndefined` / `GroupedColumnMode` with one function per
variant; no memoization or instance identity) and `reports/phase-3.md` (10
items: no fn registries so `getSortFn` / `getFilterFn` return functions and
"registered name" cases collapse; `resetX` returns to the feature default,
not a caller's `initialState`; no per-row `columnFiltersMeta`; `Infinity`
page size is `unlimitedPageSize`; custom filters receive the raw filter
value; sorted and paginated `rowsById` are the pre-stage maps as in TanStack)
and `reports/phase-5.md` (10 items: `ColumnRegion` type instead of an
optional position argument; `left` / `right` state names with TanStack's
`start` / `end` only in header ids; the shift-click anchor is caller state;
pinned row lists take both the pre-pagination model and the page; no
`position` field mutated onto rows or cells) and `reports/phase-4.md` (11
items, chiefly: explicit `Null` aggregated values on group rows; `"null"`
grouping key; group `original` is the first leaf's; keyed
`aggregationFn: [...]` and `getAggregationValue` overrides have no
counterpart).

## Renames

- `sortingFn` → `withSortFn` / `withCustomSort`; `filterFn` → `withFilterFn` /
  `withCustomFilter`; `aggregationFn` → `withAggregationFn`.
- `sortUndefined: 'first' | 'last' | -1 | 1` → `sortNullsFirst`,
  `sortNullsLast`, `sortNullsAsMinusOne`, `sortNullsAsPlusOne`.
- `expanded: true` → `expandAll`; `expanded: Record<string, boolean>` →
  `expandedIds (Set String)`.
- `reSplitAlphaNumeric` → `Table.SortFn.splitAlphaNumeric`.
- `column.toggleSorting` → `toggleSort`; `setPageIndex` → `setPage`;
  `getIsSorted` returns `Maybe SortDir` rather than `false | 'asc' | 'desc'`.
