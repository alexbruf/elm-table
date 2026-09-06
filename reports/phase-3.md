# Phase 3: filtering, faceting, sorting, pagination

Reference commit: `36733a38b6a77878eea616b25012c47a0f93d4da`.

`make check` is green: `elm-format --validate src tests` reports `[]`,
`elm-review` reports `I found no errors!`, `elm-test` reports
`Passed: 489 / Failed: 0`. `elm make --docs=docs.json` succeeds. No `Debug` in
`src/`.

489 tests is 252 (phases 0 to 2) plus 237: 231 phase-3 cases, 3 phase-1 cases
re-homed here, 1 phase-2 case that needed the filtered row model, and 2 extra
variants of a vitest `it.each` (which the `it(` case count does not see).

## Coverage

Case counts are `grep -cE '^\s*(it|test)\(' <file>` against the vitest source.

| vitest file | cases | ported | passing | excluded |
| --- | --- | --- | --- | --- |
| `implementation/features/column-filtering/createFilteredRowModel.test.ts` | 38 | 32 | 32 | 6 |
| `unit/features/column-filtering/columnFilteringFeature.utils.test.ts` | 28 | 26 | 26 | 2 |
| `implementation/features/column-faceting/createFacetedRowModels.test.ts` | 22 | 19 | 19 | 3 |
| `unit/features/column-faceting/columnFacetingFeature.test.ts` | 4 | 3 | 3 | 1 |
| `unit/features/global-filtering/globalFilteringFeature.utils.test.ts` | 20 | 18 | 18 | 2 |
| `implementation/features/row-sorting/createSortedRowModel.test.ts` | 25 | 25 | 25 | 0 |
| `unit/features/row-sorting/rowSortingFeature.utils.test.ts` | 52 | 49 | 49 | 3 |
| `implementation/features/row-pagination/createPaginatedRowModel.test.ts` | 16 | 15 | 15 | 1 |
| `unit/features/row-pagination/rowPaginationFeature.utils.test.ts` | 51 | 44 | 44 | 7 |
| **total** | **256** | **231** | **231** | **25** |

25 of 256 is 9.8%, inside the 10% budget.

Two earlier files improve as a side effect:

| vitest file | cases | ported | passing | excluded | was |
| --- | --- | --- | --- | --- | --- |
| `unit/fns/filterFns.test.ts` | 135 | 133 | 133 | 2 | 130 / 5 excluded |
| `unit/core/row-models/coreRowModelsFeature.utils.test.ts` | 17 | 10 | 10 | 7 | 9 / 8 excluded |

Elm test modules:

| elm-test module | tests | vitest file it ports |
| --- | --- | --- |
| `tests/FilteringRowModelTest.elm` | 35 | `createFilteredRowModel.test.ts` plus the 3 re-homed `filterFns.test.ts` cases |
| `tests/FilteringStateTest.elm` | 26 | `columnFilteringFeature.utils.test.ts` |
| `tests/GlobalFilterTest.elm` | 18 | `globalFilteringFeature.utils.test.ts` |
| `tests/FacetingTest.elm` | 22 | `createFacetedRowModels.test.ts`, `columnFacetingFeature.test.ts` |
| `tests/SortingRowModelTest.elm` | 25 | `createSortedRowModel.test.ts` |
| `tests/SortingStateTest.elm` | 49 | `rowSortingFeature.utils.test.ts` |
| `tests/PaginationRowModelTest.elm` | 15 | `createPaginatedRowModel.test.ts` |
| `tests/PaginationStateTest.elm` | 46 | `rowPaginationFeature.utils.test.ts` |

### Re-homed cases

`tests/FilterFnTest.elm` keeps a `-- moved:` comment where each of these sat.

1. `filterFns` > `constructFilterFn` > "applies both resolvers when filtering
   through the table row model" → `tests/FilteringRowModelTest.elm`.
2. `filterFns` > `auto filter fn for date columns` > "resolves inDateRange for
   Date-valued columns" → same module.
3. `filterFns` > `auto filter fn for date columns` > "filters date rows through
   the table row model" → same module.
4. `coreRowModelsFeature.utils` > "registered factories should apply when
   manual options are off" → `tests/CoreRowModelsFeatureTest.elm`.

The 5 "one manual option at a time" cases in `tests/CoreRowModelsFeatureTest.elm`
gained their downstream halves for filtering, sorting and pagination. The
grouping half of the `manualFiltering` case and the expanding half of the
`manualSorting` case are marked in place with a comment and wait for phase 4;
the `manualExpanding` and `manualPagination` cases assert row counts that phase
4 will raise once group rows and expanded rows exist.

## Excluded cases

### `createFilteredRowModel.test.ts` (6)

Per-row filter bookkeeping — a `Row` here carries no `columnFilters` /
`columnFiltersMeta` map, and a `FilterFn` has no `addMeta` callback:

1. `columnFiltersMeta` > "should populate row.columnFiltersMeta via the addMeta
   callback of a column filterFn".
2. `columnFiltersMeta` > "should populate row.columnFiltersMeta via the addMeta
   callback of a custom global filter".
3. `columnFiltersMeta` > "should preserve filter flags and metadata on nested
   ${leaf-first|root-first} clones" (one `it(` generating two cases).
4. `row.columnFilters flags` > "should tag flat rows with per-column pass/fail
   and the \_\_global\_\_ flag".
5. `row.columnFilters flags` > "should reset columnFilters and columnFiltersMeta
   on rows after all filters are removed".

Filter fn registry:

6. `unresolvable global filter fn` > "should apply no global filtering and warn
   in dev when the globalFilterFn name is not registered" —
   `Config.globalFilterFn` is a `Maybe FilterFn`, so there is no unregistered
   name and no `console.warn` to spy on.

### `columnFilteringFeature.utils.test.ts` (2)

1. `column_getFilterFn` > "should return undefined for unknown filter fn names"
   — `Column.filterFn` is a `Maybe FilterFn`, not a registry name.
2. `shouldAutoRemoveFilter` > "should always remove undefined even when
   autoRemove would keep it" — `undefined` is the one value TanStack drops
   before consulting `autoRemove`, and `Value.Null` stands for both `null` and
   `undefined`, so the two cannot be told apart.

### `createFacetedRowModels.test.ts` (3)

1. `no-factory fallbacks` > "should fall back to the pre-filtered model, empty
   Map, and undefined" — faceting is not a registered factory here.
2. `custom faceted row-model factories` > "should call a custom
   facetedUniqueValues factory live on every read".
3. `custom faceted row-model factories` > "should keep the stock
   facetedUniqueValues reference stable until its inputs change" — both are
   about the feature registry and its memoization.

### `columnFacetingFeature.test.ts` (1)

1. "caches faceted factory functions per column and global context" — factory
   caching and `vi.fn` call counts.

### `globalFilteringFeature.utils.test.ts` (2)

1. `table_getGlobalFilterFn` > "should return undefined for unknown filter fn
   names" — registry names again.
2. `table_resetGlobalFilter` > "should reset to the initial global filter by
   default" — this port has no `initialState`; the ported companion case
   asserts the `defaultState: true` half, and a caller that wants a starting
   filter back writes it with `setGlobalFilter`.

### `rowSortingFeature.utils.test.ts` (3)

1. `column_getAutoSortFn` > "falls back to text when alphanumeric is not
   registered" — registry.
2. `column_getSortFn` > "should fall back to basic for unknown sort fn names" —
   registry.
3. `column_getToggleSortingHandler` > "should consult isMultiSortEvent to decide
   on multi sorting" — `isMultiSortEvent` inspects a DOM event; `multi` is a
   plain argument of `Table.toggleSort`. The other two handler cases are ported
   against `toggleSort` behind a `getCanSort` guard, which is all the handler
   is.

### `createPaginatedRowModel.test.ts` (1)

1. `manualPagination` > "should include expanded children when expanded rows
   bypass manual pagination" — the assertion is on the full row model, and with
   `manualPagination` on it is `createExpandedRowModel` that splices the
   expanded children in. Phase 4.

### `rowPaginationFeature.utils.test.ts` (7)

1. `table_getCanLastPage` > "should return false when the page count is
   non-finite" — `Config.pageCount` is a `Maybe Int`; there is no `Infinity`.
2–7. `table_autoResetPageIndex` (6 cases) — `autoReset*` is out of scope per
   `SPEC.md`. Nothing here reacts to a state change; the caller decides when to
   reset the page.

### Adapted, not excluded

- Every "should reset to the initial X by default" case (column filters,
  sorting, pagination, page index, page size) is ported as the caller writing
  its own remembered value back, since there is no `initialState`.
- Identity assertions (`toBe`) become structural equality. "should clone
  matching parents that have subRows" asserts instead that the filtered row has
  the same id and datum with a different sub-row list; "keeps branch row
  identity when sorted subRows are unchanged" asserts plain value equality.
- `pageSize: Infinity` and `getDefaultPaginationState`'s "new instance" case use
  `Table.unlimitedPageSize` and an immutability assertion respectively.
- Cases asserting *which* built-in fn was picked (`toBe(sortFn_text)`) compare a
  label recovered by probing the function, because Elm cannot compare functions.
  `FilteringStateTest.filterFnLabel` and `SortingStateTest.sortFnLabel` are
  those probes, each documented at its definition.
- `createFilteredRowModel` > "should skip the parent predicate when matching
  descendants retain it" keeps the row assertion and drops the `vi.fn` call
  order; the short circuit the spy proves is the `subRows || predicate` branch
  in `Table.Internal.Filtering.keepFromLeafs`.
- `column_getAutoFilterFn` > "selects equals for non-array object values" uses a
  `Bool` column: `Value` has no object constructor, and JavaScript objects and
  booleans both select `equals`.
- `createSortedRowModel` > "does not copy memoized row APIs…" asserts that the
  cells of the sorted branch row point back at it; nothing is memoized here.
- `manualSorting` "runtime toggle" uses two configs rather than `setOptions`.

## API this phase adds

Everything is exposed from `Table` inside the `-- Phase 3` region of the
exposing list and the `# Phase 3` `@docs` section, with the definitions in the
`-- PHASE 3` block at the end of `src/Table.elm`.

Functions that have to guess something from the data (`'auto'` filter and sort
functions, the default global-filter predicate, the automatic first sort
direction) take a `RowModel row` to sample, exactly as TanStack samples the core
or filtered row model for the same job.

### Sort direction

```elm
type alias SortDir = Types.SortDir   -- abstract, like Expanded and SortUndefined
sortAsc : SortDir
sortDesc : SortDir
```

### Column filter state

```elm
getCanFilter : Config row -> String -> Bool
getIsFiltered : State -> String -> Bool
getFilterValue : State -> String -> Maybe Value
getFilterIndex : State -> String -> Int
getFilterFn : Config row -> RowModel row -> String -> Maybe FilterFn
getAutoFilterFn : Config row -> RowModel row -> String -> FilterFn
shouldAutoRemoveFilter : Maybe FilterFn -> Value -> Bool
setColumnFilter : Config row -> RowModel row -> String -> Value -> State -> State
setColumnFilters : Config row -> RowModel row -> List ColumnFilter -> State -> State
resetColumnFilters : State -> State
```

`SPEC.md` names `setColumnFilter : Config row -> String -> Value -> State -> State`;
the extra `RowModel row` is needed because `autoRemove` comes from the column's
filter fn, and an `'auto'` filter fn is chosen by looking at the data.

### Global filter state

```elm
getCanGlobalFilter : Config row -> RowModel row -> String -> Bool
getGlobalFilterFn : Config row -> FilterFn
globalAutoFilterFn : FilterFn
setGlobalFilter : Value -> State -> State
resetGlobalFilter : State -> State
```

### Faceting

```elm
facetedRowModel : Config row -> State -> RowModel row -> String -> RowModel row
globalFacetKey : String                          -- "__global__"
```

`facetedUniqueValues` and `facetedMinMax` keep their phase-2 signatures. All
three take the **pre-filtered** row model, that is whatever was handed to
`filteredRowModel`, and all three accept `globalFacetKey` as the column id for
the global filter's own facet context.

### Sorting state

```elm
getCanSort : Config row -> String -> Bool
getCanMultiSort : Config row -> String -> Bool
getIsSorted : State -> String -> Maybe SortDir
getSortIndex : State -> String -> Int
getAutoSortFn : Config row -> RowModel row -> String -> SortFn
getSortFn : Config row -> RowModel row -> String -> SortFn
getAutoSortDir : Config row -> RowModel row -> String -> SortDir
getFirstSortDir : Config row -> RowModel row -> String -> SortDir
getNextSortingOrder : Config row -> RowModel row -> State -> String -> Bool -> Maybe SortDir
toggleSort : Config row -> RowModel row -> String -> { desc : Maybe Bool, multi : Bool } -> State -> State
setSorting : List SortColumn -> State -> State
clearSorting : String -> State -> State
resetSorting : State -> State
```

`getIsSorted` returns `Maybe SortDir` rather than the `Maybe { desc : Bool }`
the brief suggested, so that it, `getFirstSortDir`, `getAutoSortDir` and
`getNextSortingOrder` all speak the same type. The last `Bool` of
`getNextSortingOrder` is TanStack's `multi`.

### Pagination state

```elm
prePaginationRowModel : Config row -> State -> RowModel row -> RowModel row   -- = expandedRowModel
rowsInDisplayOrder : Config row -> State -> RowModel row -> List (Row row)
displayIndex : Config row -> State -> RowModel row -> Row row -> Int
setPage : Config row -> Int -> State -> State
setPageSize : Int -> State -> State
setPagination : Pagination -> State -> State
resetPageIndex : Config row -> State -> State
resetPageSize : State -> State
resetPagination : State -> State
getPageCount : Config row -> State -> RowModel row -> Int
getPageOptions : Config row -> State -> RowModel row -> List Int
getRowCount : Config row -> RowModel row -> Int
getCanPreviousPage : State -> Bool
getCanNextPage : Config row -> State -> RowModel row -> Bool
getCanLastPage : Config row -> State -> RowModel row -> Bool
previousPage : Config row -> State -> State
nextPage : Config row -> State -> State
firstPage : Config row -> State -> State
lastPage : Config row -> State -> RowModel row -> State
unlimitedPageSize : Int
```

`rowsInDisplayOrder` and `displayIndex` port `table_getRowsInDisplayOrder` and
`row_getDisplayIndex` from `core/rows/coreRowsFeature.utils.ts`; three ported
cases (one each in filtering, sorting and pagination) assert display indexes, so
they land here rather than waiting for phase 5's cell selection.

## Contract changes

Five fields changed type and five were added. Every change is in
`src/Table/Internal/Types.elm`, with the defaults in
`src/Table/Internal/Config.elm` and `src/Table/Internal/Column.elm`.

`Column`:

| field | was | now | why |
| --- | --- | --- | --- |
| `sortUndefined` | `SortUndefined` (default `SortNullsLast`) | `Maybe SortUndefined` (default `Nothing`) | TanStack's default is `undefined`, which means "let the sort fn see the nulls". `Nothing` covers both `undefined` and `sortUndefined: false`; `createSortedRowModel.test.ts` tests that branch directly. |
| `enableMultiSort` | `Bool` (default `True`) | `Maybe Bool` (default `Nothing`) | `column_getCanMultiSort` is `columnDef ?? table ?? !!accessorFn`, so "not set" has to be distinguishable. |
| `enableGlobalFilter` | `Bool` (default `True`) | `Maybe Bool` (default `Nothing`) | the default `getColumnCanGlobalFilter` treats an *explicit* `true` as an opt-in for non string/number columns. |

`Config`:

| field | was | now | why |
| --- | --- | --- | --- |
| `sortDescFirst` | `Bool` (default `False`) | `Maybe Bool` (default `Nothing`) | `column_getFirstSortDir` falls through to `column_getAutoSortDir` only when neither level is set. |
| `enableFilters` | — | `Bool` (default `True`) | gates both `getCanFilter` and `getCanGlobalFilter`; it was missing. |
| `getColumnCanGlobalFilter` | — | `Maybe (Column row -> Bool)` (default `Nothing`) | the table option of the same name; `Nothing` is the stock predicate. |
| `pageCount` | — | `Maybe Int` (default `Nothing`) | manual pagination; `Just -1` is TanStack's "unknown". |
| `rowCount` | — | `Maybe Int` (default `Nothing`) | manual pagination. |

`Types.SortDir` (`Asc` / `Desc`) is new, abstract in `Table` with `sortAsc` and
`sortDesc`, following the phase-2 convention for `Expanded` and `SortUndefined`.

The builders keep their signatures: `withSortUndefined`, `withEnableMultiSort`
and `withEnableGlobalFilter` now write `Just`.

## Semantic differences

1. **`Null` is both `null` and `undefined`, again.** It costs one filtering
   case (`shouldAutoRemoveFilter` "should always remove undefined…") and one
   assertion in another (`null` is kept by TanStack, dropped here). It is also
   why `sortUndefined` places `Null` cells: there is nothing else to place.
2. **Elm cannot compare functions.** Every `expect(fn).toBe(builtInFn)` case is
   ported as a behavioural probe (`filterFnLabel` / `sortFnLabel`). `getSortFn`
   and `getFilterFn` return the function, not a name.
3. **No filter fn or sort fn registry.** `Column.filterFn`, `Column.sortFn` and
   `Config.globalFilterFn` hold values, so "unregistered name" cases have no
   counterpart (4 exclusions) and "look up registered names" cases collapse onto
   "function-valued fn wins".
4. **No `initialState`.** `resetX` is TanStack's `resetX(table, true)`: back to
   the feature default. Restoring a caller's own starting value is a plain
   `setX`.
5. **No per-row filter flags.** TanStack writes `row.columnFilters` and
   `row.columnFiltersMeta` onto the pre-filtered rows and the predicate then
   reads them. Here the predicate evaluates the resolved filters directly, which
   gives the same rows; `addMeta` has no counterpart (5 exclusions).
6. **`Infinity` is `Table.unlimitedPageSize`** (`Number.MAX_SAFE_INTEGER`), an
   `Int`. Every ported `pageSize: Infinity` case behaves identically; a
   `pageCount` of `Infinity` does not, which costs one case.
7. **A custom filter takes the row, a built-in takes the value.** TanStack's
   `filterFn(row, columnId, filterValue, addMeta)` splits here into
   `withFilterFn` (a `FilterFn` on `Value`) and `withCustomFilter`
   (`Row row -> Value -> Bool`). A custom filter receives the *raw* filter value,
   matching TanStack, which only applies `resolveFilterValue` when the filter fn
   carries one. When a column has both, the custom filter wins.
8. **Sorted `rowsById` is the pre-sorted map**, exactly as
   `createSortedRowModel.ts` leaves it, so its rows carry unsorted sub-rows.
   Same for the paginated model, whose `rowsById` is the whole pre-pagination
   map rather than just the page. Both are pinned by ported cases.
9. **`filterRows` rebuilds `flatRows` by walking the result tree.** TanStack
   pushes rows during the recursion and, in the from-root path, appends whole
   sub-trees when `maxLeafRowFilterDepth` stops the descent. A pre-order walk of
   the produced tree gives the identical list, which the pre-order cases pin.
10. **`Table.paginatedRowModel` does the expanding when
    `paginateExpandedRows = False`,** since that is where `expandRows` runs in
    TanStack too. It reads `State.expanded` directly rather than going through
    phase 4's `Table.Internal.Expanding`; phase 4 should factor the shared
    `expandRows` out of `Table.Internal.Pagination`.

## Benchmarks

`make bench`, Node 24, `elm make --optimize`, 7 runs, clock around one port
round trip. The new `pipeline` case is 10,000 flat rows with one column filter
(`includesString` on `status`, which every row passes so the sort sees all
10,000), one sort (`lastName`, ascending, resolved to the automatic `text` sort
fn) and `pageSize = 50`.

| case | rows | min | median |
| --- | --- | --- | --- |
| flat (`coreRowModel`) | 10,000 | 11.7 ms | 18.3 ms |
| nested (`coreRowModel`) | 2,500 × 3 | 12.1 ms | 13.3 ms |
| **pipeline (`Table.rows`)** | **10,000** | **86.2 ms** | **94.7 ms** |

Target was under 500 ms. Grouping and expanding are still identity stages, so
phase 4 will add to this number.

The first measurement was 242 ms min / 336 ms median. Both hot loops were
calling `Table.Internal.Row.getValue`, which calls `Column.findColumn`, which
rebuilds the whole column index (`Dict` fold over `flatColumns`) on **every**
call — once per row per filter, and twice per comparison in the sort. Both
modules now resolve the column once and keep a `Row row -> Value` reader
(`valueReader` in `Filtering.elm` and in `Sorting.elm`), which is the 2.6x. The
same trap is waiting for phase 4: `Grouping` and `Expanding` must not call
`Row.getValue` inside a loop either. Memoizing `columnsById` on the `Config`
would fix it everywhere but changes the phase-2 contract, so it was left alone.

## Not touched

`PORT_NOTES.md` is not in this phase's file list (a parallel phase-5 agent is
running), so its coverage table, semantic-difference list and phase-report
section still have to absorb this report. The rows and items to fold in are the
two coverage tables and the ten semantic differences above.

## Biggest risk for phase 4

**The grouped row model changes what a `Row` *is*, and three phase-3 behaviours
read those fields.** `createGroupedRowModel` produces rows whose id is
`"<columnId>:<value>"`, whose `aggregatedValues` shadow the accessor, and whose
`leafRows` hold the originals. Phase 3 already routes every cell read through
`aggregatedValues` first (`valueReader` in `Filtering.elm` and `Sorting.elm`
mirror `Row.getValue`), so grouping will silently start feeding aggregated
values to filters, sorts and facets. That is correct — TanStack sorts group rows
by their aggregate — but it means any change to how `aggregatedValues` is keyed
or when it is filled changes filtering and sorting results without touching
either module. The two concrete traps:

1. **Pipeline order.** `preSorted = grouped`, so the sorted row model sorts
   *group* rows using the automatic sort fn chosen from the **filtered** row
   model's values. If phase 4 fills `aggregatedValues` with a different `Value`
   constructor than the accessor returns (a `Number` mean for a `String`
   column, say), `getAutoSortFn` and the comparison will disagree.
2. **`expandRows` lives in two places.** `Table.Internal.Pagination` carries its
   own copy of `expandRows` / `row_getIsExpanded` because
   `paginateExpandedRows = False` needs it and `Table.Internal.Expanding` was a
   stub. Phase 4 must make the expanded row model and the paginator share one
   implementation, or the two will drift apart on `getIsRowExpanded` and on
   `enableExpanding`.
