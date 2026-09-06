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

## Coverage table

Filled in per phase. Cases are counted as `it(` / `test(` calls in the vitest
file. Full per-case exclusion lists live in `reports/phase-N.md`.

| vitest file | cases | ported | passing | excluded |
| --- | --- | --- | --- | --- |
| `unit/fns/sortFns.test.ts` | 41 | 41 | 41 | 0 |
| `unit/fns/filterFns.test.ts` | 135 | 130 | 130 | 5 |
| `unit/fns/aggregationFns.test.ts` | 8 | 7 | 7 | 1 |
| `implementation/core/row-models/createCoreRowModel.test.ts` | 18 | 14 | 14 | 4 |
| `implementation/core/row-models/rowModelFlatRowsOrder.test.ts` | 1 | 1 | 1 | 0 |
| `unit/core/columns/constructColumn.test.ts` | 2 | 1 | 1 | 1 |
| `unit/core/columns/coreColumnsFeature.utils.test.ts` | 13 | 11 | 11 | 2 |
| `unit/core/headers/constructHeader.test.ts` | 3 | 1 | 1 | 2 |
| `unit/core/headers/coreHeadersFeature.utils.test.ts` | 13 | 10 | 10 | 3 |
| `unit/core/rows/constructRow.test.ts` | 2 | 1 | 1 | 1 |
| `unit/core/rows/coreRowsFeature.utils.test.ts` | 21 | 18 | 18 | 3 |
| `unit/core/row-models/coreRowModelsFeature.utils.test.ts` | 17 | 9 | 9 | 8 |
| `unit/core/cells/constructCell.test.ts` | 2 | 1 | 1 | 1 |
| `unit/core/cells/coreCellsFeature.utils.test.ts` | 4 | 1 | 1 | 3 |
| `unit/core/table/constructTable.test.ts` | 7 | 0 | 0 | 7 |
| `unit/core/table/rowModelSlots.test.ts` | 11 | 0 | 0 | 11 |
| `unit/core/table/stockFeaturesInitialState.test.ts` | 1 | 1 | 1 | 0 |

## Semantic differences

See `reports/phase-1.md` (9 items: `Null` covers `null` and `undefined`,
`toString Null == ""`, invalid dates as `Number NaN`, ISO-only date strings,
exact numeric chunk comparison above 15 digits, structural `weakEquals`,
`toNumber` via `String.toFloat`, NaN written `sqrt -1`) and
`reports/phase-2.md` (pipeline order is core → filtered → grouped → sorted →
expanded → paginated, matching TanStack's `preSorted = grouped`; abstract
`Expanded` / `SortUndefined` / `GroupedColumnMode` with one function per
variant; no memoization or instance identity).

## Renames

- `sortingFn` → `withSortFn` / `withCustomSort`; `filterFn` → `withFilterFn` /
  `withCustomFilter`; `aggregationFn` → `withAggregationFn`.
- `sortUndefined: 'first' | 'last' | -1 | 1` → `sortNullsFirst`,
  `sortNullsLast`, `sortNullsAsMinusOne`, `sortNullsAsPlusOne`.
- `expanded: true` → `expandAll`; `expanded: Record<string, boolean>` →
  `expandedIds (Set String)`.
- `reSplitAlphaNumeric` → `Table.SortFn.splitAlphaNumeric`.
