# Re-homing the excluded cases

Every excluded vitest case whose body still contains a data-level assertion the
Elm port can express has been ported as an **adapted** test: the vitest `it`
name is kept verbatim and a one-line `-- adapted: …` comment at the case says
what changed. The `-- excluded` comment blocks of the ported cases are gone.

Baseline (`PORT_NOTES.md` before this pass): 1,137 in-scope cases, 1,022
ported, 115 excluded (10.1%).

## Files touched

| vitest file | cases | ported before | ported after | excluded after |
| --- | --- | --- | --- | --- |
| `unit/fns/aggregationFns.test.ts` | 8 | 7 | 8 | 0 |
| `implementation/core/row-models/createCoreRowModel.test.ts` | 18 | 14 | 18 | 0 |
| `unit/core/headers/coreHeadersFeature.utils.test.ts` | 13 | 12 | 13 | 0 |
| `unit/core/rows/constructRow.test.ts` | 2 | 1 | 2 | 0 |
| `unit/core/rows/coreRowsFeature.utils.test.ts` | 21 | 18 | 19 | 2 |
| `unit/core/row-models/coreRowModelsFeature.utils.test.ts` | 17 | 10 | 17 | 0 |
| `unit/core/cells/coreCellsFeature.utils.test.ts` | 4 | 1 | 2 | 2 |
| `implementation/features/column-faceting/createFacetedRowModels.test.ts` | 22 | 19 | 21 | 1 |
| `unit/features/column-faceting/columnFacetingFeature.test.ts` | 4 | 3 | 4 | 0 |
| `unit/features/global-filtering/globalFilteringFeature.utils.test.ts` | 20 | 18 | 19 | 1 |
| `unit/features/row-sorting/rowSortingFeature.utils.test.ts` | 52 | 49 | 50 | 2 |
| `unit/features/row-pagination/rowPaginationFeature.utils.test.ts` | 51 | 44 | 49 | 2 |
| `unit/features/column-visibility/columnVisibilityFeature.utils.test.ts` | 27 | 25 | 27 | 0 |
| `implementation/features/row-selection/rowSelectionFeature.test.ts` | 34 | 29 | 34 | 0 |
| `implementation/features/row-selection/rowSelectionRange.test.ts` | 23 | 17 | 22 | 1 |
| `unit/features/row-selection/rowSelectionFeature.utils.test.ts` | 58 | 51 | 58 | 0 |
| `implementation/features/row-aggregation/rowAggregationFeature.test.ts` | 18 | 11 | 13 | 5 |
| `implementation/features/row-expanding/createExpandedRowModel.test.ts` | 13 | 11 | 13 | 0 |
| `unit/features/row-expanding/rowExpandingFeature.utils.test.ts` | 51 | 49 | 50 | 1 |
| `implementation/features/cell-spanning/cellSpanningFeature.test.ts` | 14 | 13 | 14 | 0 |
| `implementation/features/cell-selection/cellSelectionFeature.test.ts` | 66 | 54 | 62 | 4 |
| `implementation/features/cell-selection/cellSelectionRange.test.ts` | 23 | 22 | 23 | 0 |

60 cases re-homed. No `src/` change was needed for any of them.

## Re-homed cases and their adaptations

### `aggregationFns.test.ts` → `tests/AggregationFnTest.elm`

1. "preserves custom definition result inference" — an Elm aggregation sees
   values, not rows, so the custom fn joins the two values (`1,2`) where the
   vitest joins the two fake row ids (`0,1`); there is no type inference.

### `createCoreRowModel.test.ts` → `tests/CoreRowModelTest.elm`

2. "should call getSubRows with (originalRow, index)" — `Config.getSubRows` is
   `row -> List row` with no index and there is no spy, so the assertion is
   that the accessor ran on every original row.
3. "should return the same model object across repeated calls" — instance
   identity becomes equality of two builds (rows included).
4. "should build a new model when the data array identity changes" — a copied
   list is an equal value in Elm, so the second list really changes a row; the
   row count still matches.
5. "should preserve the cached model when setOptions keeps the same data
   reference" — `setOptions` becomes a second config differing only in an
   option the core row model does not read (`manualPagination`).

### `coreHeadersFeature.utils.test.ts` → `tests/CoreHeadersTest.elm`

6. "should expose the header, column, and table" — `getContext` builds a render
   context around the table instance; the parts it exposes are the header's own
   fields (`headerId`, `headerColumnId`).

### `constructRow.test.ts` → `tests/CoreRowsTest.elm`

7. "memoizes getLeafRows until subRows changes" — `getLeafRows` is a pure read,
   so the memo becomes "repeated reads agree", and the mutated `subRows`
   becomes a second config whose sub-row accessor reverses the children.

### `coreRowsFeature.utils.test.ts` → `tests/CoreRowsTest.elm`

8. "should reuse cell instances across calls" — cells are plain records built
   on demand, so instance reuse becomes structural equality across two calls.

### `coreRowModelsFeature.utils.test.ts` → `tests/CoreRowModelsFeatureTest.elm`

9. "should cache the core row model factory across calls" — nothing is cached
   in a pure port, so the assertion is that repeated builds from the same
   config and data are equal.
10. "should instantiate a registered factory even when its manual option
    bypasses the result" — there is no factory to instantiate, so only the
    observable half is asserted: the stage is bypassed while the manual option
    is on and applies as soon as it is off.
11–15. The five "runtime toggling via setOptions" cases (`manualFiltering`,
    `manualGrouping`, `manualSorting`, `manualExpanding`, `manualPagination`) —
    `setOptions` becomes two configs, one per side of the toggle (the phase 3
    convention). Both halves are kept: identity while manual, and the applied
    row ids / names / counts when it is off.

### `coreCellsFeature.utils.test.ts` → `tests/CoreCellsTest.elm`

16. "should expose the table, column, row, and cell with bound value helpers" —
    the context's parts are the cell record's own fields (`columnId`, `rowId`,
    `value`).

### `createFacetedRowModels.test.ts` → `tests/FacetingTest.elm`

17. "should keep the stock facetedUniqueValues reference stable until its
    inputs change" — reference stability becomes value equality; the filter
    that changes this column's faceted inputs is applied to the other column,
    as in the vitest case.
18. "should call a custom facetedUniqueValues factory live on every read" — the
    port's counterpart of a custom faceted values source is the column's own
    `withGetUniqueValues`, which the faceting functions consult on every read
    rather than caching.

### `columnFacetingFeature.test.ts` → `tests/FacetingTest.elm`

19. "caches faceted factory functions per column and global context" — there is
    no factory to cache, so the call counts become the observable half: a
    column context and the global context each keep their own value and
    repeated reads of either agree.

### `globalFilteringFeature.utils.test.ts` → `tests/GlobalFilterTest.elm`

20. "should reset to the initial global filter by default" — there is no
    `table.initialState`, so restoring a remembered initial filter is
    `setGlobalFilter` (the phase 3 convention for every "reset to the initial
    X" case).

### `rowSortingFeature.utils.test.ts` → `tests/SortingStateTest.elm`

21. "should consult isMultiSortEvent to decide on multi sorting" —
    `isMultiSortEvent` inspects a DOM event; `multi` is a plain argument of
    `Table.toggleSort`, so the shift event becomes `multi = True`.

### `rowPaginationFeature.utils.test.ts` → `tests/PaginationStateTest.elm`

22. "should reset the page index for client-side pagination" — the caller calls
    the reset (`Table.resetPageIndex`) the scheduler would.
23. "should reset to the first page instead of the initial page index" —
    `resetPageIndex` goes to the feature default, never to a caller's
    remembered initial page.
24. "should not invoke onPaginationChange when already on the default page" —
    no spy, so "not called" is "the state comes back unchanged".
25. "should invoke onPaginationChange when off the default page" — the
    resulting `Pagination` stands in for the updater.
26. "should reset even for manual pagination when autoResetPageIndex opts back
    in" — `manualPagination` gates TanStack's scheduler, not the reset; a
    caller that asks for the reset always gets it.

### `columnVisibilityFeature.utils.test.ts` → `tests/ColumnVisibilityTest.elm`

27. "should return handler that toggles visibility based on checkbox state" —
    the handler is the checkbox value plus `toggleColumnVisibility`; only the
    transition has a counterpart.
28. "should return handler that toggles all columns visibility based on
    checkbox state" — same, through `toggleAllColumnsVisible`.

### `rowSelectionFeature.test.ts` → `tests/RowSelectionFeatureTest.elm`

29. "should preserve row prototype methods on cloned parent rows" — Elm has no
    prototypes; the cloned parent still reads the same values as the original
    and is a different value.
30. "should not copy memoized row APIs from the original row to cloned parent
    rows" — nothing is memoized on a row, so the observable half is asserted:
    the clone carries its own sub-rows and its cells point back at it.
31. "memoizes getIsAllRowsSelected until selection or row model changes" — the
    call counts become "repeated reads agree" and "a changed selection
    recomputes".
32. "skips the enableRowSelection predicate for already-selected rows" — the
    `vi.fn` predicate becomes one that would answer `False`; the scan still
    reports all-selected, which is only possible when it never asks about a
    selected row.
33. "getGroupedSelectedRowModel falls back through the row-model chain when
    sorting is not registered" — no feature registry, so "without sorting
    registered" is the ordinary path with the sorting stage left out (the
    phase 6 convention).

### `rowSelectionRange.test.ts` → `tests/RowSelectionRangeTest.elm`

34. "detects direct and wrapped Shift events but ignores ordinary events" — the
    direct and wrapped shift forms collapse into the same `selectRange` call;
    the ordinary click is `toggleRowSelected`.
35. "supports custom range event detection" — range selection is opt-in at the
    call site here, so the caller *is* the detector: an ordinary click toggles
    and the caller's own "range" interaction calls `selectRange`.
36. "does not resolve display order for ordinary clicks but does for ranges" —
    the spy becomes an observable difference: the model is ordered by `kind`,
    so only a range that resolves display order selects exactly `0, 2, 4`.
37. "uses one selection change and never calls row.toggleSelected per interval
    row" — the spies become the one state the range returns.
38. "is not changed by direct row or table state APIs" — `_lastSelectedRowId`
    is instance data in TanStack; here the anchor is a caller-owned argument,
    so an ordinary toggle and a direct `setRowSelection` leave it usable and a
    later range still spans from it.

### `rowSelectionFeature.utils.test.ts` → `tests/RowSelectionTest.elm`

39. "should fire even for structural no-ops (row selection skips the no-op
    guard)" — no spy, so the write that skips the guard is asserted as the
    slice it returns when it rewrites the selection it already holds.
40. "table_getPreSelectedRowModel should return the core row model" — the
    selected row model takes the row model as an argument, so "the core row
    model" is what the caller passes in.
41. "should evaluate the enableSubRowSelection predicate once per unique
    parent" — the call-count half needs a spy; the 14-row result the per-pass
    subtree cache guards is asserted instead.
42. "row_getToggleSelectedHandler should read event.target.checked" — the
    handler is `toggleRowSelected` with the checkbox value.
43. "row_getToggleSelectedHandler should be a no-op when the row cannot be
    selected" — same, with `enableRowSelection` off.
44. "table_getToggleAllRowsSelectedHandler should select all rows from the
    checkbox state" — `toggleAllRowsSelected`.
45. "table_getToggleAllPageRowsSelectedHandler should select page rows from the
    checkbox state" — `toggleAllPageRowsSelected` over the page slice.

### `rowAggregationFeature.test.ts` → `tests/AggregationTest.elm`

46. "caches the default rows, invalidates with data, and recomputes explicit
    rows" — the call counts become "the same inputs give the same value" and
    the `setOptions` data swap becomes a second row model built from the new
    list.
47. "includes aggregation depth in the default-row cache key" — the cache key
    is not observable, so each depth keeping its own value across repeated
    reads is asserted.

### `createExpandedRowModel.test.ts` → `tests/ExpandingRowModelTest.elm`

48. "should return the same reference on repeated calls" — identity becomes
    equality across two builds.
49. "should not recompute when unrelated getters are called in between" — the
    unrelated getters are pure reads, so the assertion is that they leave the
    next build equal.

### `rowExpandingFeature.utils.test.ts` → `tests/ExpandingStateTest.elm`

50. "should schedule a reset to the initial expanded state" — the scheduling is
    out of scope; the reset it schedules is the caller writing its remembered
    initial slice back with `setExpanded`.

### `cellSpanningFeature.test.ts` → `tests/CellSpanningFeatureTest.elm`

51. "invalidates the memoized index when only the page changes" — no memo
    object, so identity becomes equality: two reads on one page agree and the
    next page differs.

### `cellSelectionFeature.test.ts` → `tests/CellSelectionFeatureTest.elm`

52. "clears ranges when data changes" — the reset a data change schedules is
    `clearCellSelection`.
53. "resets to initialState rather than to empty" — restoring a remembered
    initial slice is `setCellSelection`.
54. "does not clear an existing selection on first read" — building the row
    model is pure here, so "the first read" is the selection surviving a
    row-model build.
55. "can be disabled" — with no auto-reset the selection outlives the data
    change, which here is a second row model built from the new list.
56. "is overridden by autoResetAll" — option precedence has no counterpart; the
    asserted half is that one range survives.
57. "reads the modifier off a framework nativeEvent too" — no event object, so
    the shift path is asserted through `extendCellSelectionTo`.
58. "metaKey works for multi-range as well" — meta and ctrl reach the same pure
    transition, `toggleCellSelection`.
59. "does not open a drag without a document to close it" — no document and no
    drag flag, so only the selected-id assertion is kept.

### `cellSelectionRange.test.ts` → `tests/CellSelectionRangeTest.elm`

60. "is memoized between reads" — bounds are a value here, so the memo becomes
    two reads of the same selection agreeing.

## Remaining exclusions (55)

### Feature registry, `setOptions`, `constructTable`, `rowModelSlots` (30)

The true no-counterpart group: this port has no feature objects, no fn
registries and no table instance to reconfigure.

| count | cases |
| --- | --- |
| 11 | `rowModelSlots.test.ts` — row-model and fn-registry slots plus type-level assertions |
| 7 | `constructTable.test.ts` — instance construction, feature init order, `table_mergeOptions`, static options |
| 2 | `filterFns` "filter fn registry" (2) — JS object identity against a registry |
| 2 | `constructHeader` instance-specific header / header-group data |
| 2 | `rowSortingFeature.utils` "falls back to text when alphanumeric is not registered", "should fall back to basic for unknown sort fn names" |
| 1 | `constructColumn` instance-specific column data |
| 1 | `constructCell` instance-specific cell data |
| 1 | `createFilteredRowModel` "unresolvable global filter fn" (a name that fails to resolve, plus a `console.warn` spy) |
| 1 | `columnFilteringFeature.utils` `column_getFilterFn` "should return undefined for unknown filter fn names" |
| 1 | `globalFilteringFeature.utils` `table_getGlobalFilterFn` "should return undefined for unknown filter fn names" |
| 1 | `createFacetedRowModels` "no-factory fallbacks" — faceting is not a registered factory here |

### Rendering, out of scope per `SPEC.md` (6)

Owned by the phase 7 agent (`reports/phase-2.md` exclusion items 37–42), left
untouched by this pass: `coreColumnsFeature.utils` default header / default
cell renderer (2), `coreRowsFeature.utils` `row_renderValue` (2),
`coreCellsFeature.utils` `cell_renderValue` (2).

### Needs API (10)

Listed with the exact addition each one wants; see "Needs API" below.

| count | cases |
| --- | --- |
| 5 | `createFilteredRowModel` `columnFiltersMeta` (3, one `it(` generating two) and `row.columnFilters flags` (2) |
| 5 | `rowAggregationFeature` "uses handled column values and configurable local fallback", "supports a shared aggregation value provider through defaultColumn", "warns and preserves undefined keys for invalid multi configurations", "provides groupingRow only for grouped aggregation contexts", "lets aggregate choose immediate sub-rows instead of terminal rows" |

### JavaScript-only values (2)

1. `columnFilteringFeature.utils` "should always remove undefined even when
   autoRemove would keep it" — `Value.Null` is both `null` and `undefined`.
2. `rowPaginationFeature.utils` `table_getCanLastPage` "should return false when
   the page count is non-finite" — `Config.pageCount` is a `Maybe Int`; there
   is no `Infinity`.

### Assertions a pure port contradicts (7)

Every one of these asserts that *nothing* happened because of a scheduler or an
instance flag that does not exist here; porting them would assert the opposite
of what the port does.

1. `rowPaginationFeature.utils` "should not reset when manualPagination is set"
   — the reset is the caller's own call, so there is no scheduler to gate.
2. `rowExpandingFeature.utils` "should not reset when manualExpanding is set" —
   same.
3. `rowSelectionRange` "clears through every selection reset and select-all
   path" — the anchor is caller state; the port has nothing to clear.
4. `cellSelectionFeature` "document mouseup ends the drag and removes its
   listener" — asserts a document listener is attached and removed.
5. `cellSelectionFeature` "a rehydrated selection cannot resume a drag it never
   started" — asserts `_isSelectingCells` after rehydration.
6. `cellSelectionFeature` "mouseenter is a no-op when no drag is in progress" —
   the guard is the drag flag.
7. `cellSelectionFeature` "skips drag bookkeeping when drag is disabled" —
   `enableCellSelectionDrag` only ever touches the drag flag.

## Totals

| | cases | ported | excluded | excluded % |
| --- | --- | --- | --- | --- |
| before | 1137 | 1022 | 115 | 10.1% |
| after | 1137 | 1082 | 55 | 4.8% |

`SPEC.md` "Definition of done" item 3 (under 5% excluded) is met: 55 of 1,137
is 4.84%. The 6 rendering cases counted above are the phase 7 agent's; if they
land the figure drops to 49 (4.3%).

## Needs API

These cases have a data-level assertion but no function to make it against.
Each entry is the exact addition that would let it be ported.

1. **Per-row filter bookkeeping** — 5 `createFilteredRowModel` cases.
   - `Table.rowColumnFilters : Row row -> Dict String Bool` and
     `Table.rowColumnFiltersMeta : Row row -> Dict String Value`, both written
     by `Table.filteredRowModel` (pass/fail per column id plus the
     `__global__` entry), and cleared when no filters are active.
   - `Table.FilterFn.withAddMeta : (Value -> Value) -> FilterFn -> FilterFn`,
     the callback TanStack's `addMeta` fills that map with.
2. **Caller-supplied aggregation values** — 2 cases ("uses handled column
   values and configurable local fallback", "supports a shared aggregation
   value provider through defaultColumn").
   - `Table.withGetAggregationValue : (List (Row row) -> Value) -> Column row -> Column row`
     and `Config.manualAggregation : Bool`, plus letting
     `Config.defaultColumn` carry that accessor (today it is sizing only).
3. **Keyed aggregations** — 1 case ("warns and preserves undefined keys for
   invalid multi configurations").
   - `Table.withAggregationFns : List ( String, AggregationFn ) -> Column row -> Column row`,
     producing a keyed value per cell instead of one scalar.
4. **Aggregation context** — 2 cases ("provides groupingRow only for grouped
   aggregation contexts", "lets aggregate choose immediate sub-rows instead of
   terminal rows").
   - `Table.AggregationFn.customWithContext : ({ values : List Value, subRows : List Value, isGroupingRow : Bool } -> Value) -> AggregationFn`,
     the shape TanStack's `AggregationContext` gives a custom `aggregate`.
