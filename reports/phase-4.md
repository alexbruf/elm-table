# Phase 4: grouping, aggregation, expansion

Reference commit: `36733a38b6a77878eea616b25012c47a0f93d4da`.

`make check` is green: `elm-format --validate src tests` reports `[]`,
`elm-review` reports `I found no errors!`, `elm-test` reports
`Passed: 603 / Failed: 0`. `elm make --docs=docs.json` succeeds. No `Debug` in
`src/`.

603 tests is 489 (phases 0 to 3) plus 114: 113 phase-4 cases and 1 phase-3
case re-homed here. The 5 "one manual option at a time" cases in
`tests/CoreRowModelsFeatureTest.elm` gained their grouping and expanding
halves in place, so they are still counted under phase 2.

## Coverage

Case counts are `grep -cE '^\s*(it|test)\(' <file>` against the vitest source.

| vitest file | cases | ported | passing | excluded |
| --- | --- | --- | --- | --- |
| `implementation/features/column-grouping/createGroupedRowModel.test.ts` | 15 | 15 | 15 | 0 |
| `implementation/features/column-grouping/columnGroupingFeature.test.ts` | 1 | 1 | 1 | 0 |
| `unit/features/column-grouping/columnGroupingFeature.utils.test.ts` | 24 | 24 | 24 | 0 |
| `implementation/features/row-aggregation/rowAggregationFeature.test.ts` | 18 | 11 | 11 | 7 |
| `implementation/features/row-expanding/createExpandedRowModel.test.ts` | 13 | 11 | 11 | 2 |
| `implementation/features/row-expanding/rowExpandingFeature.test.ts` | 2 | 2 | 2 | 0 |
| `unit/features/row-expanding/rowExpandingFeature.utils.test.ts` | 51 | 49 | 49 | 2 |
| **total** | **124** | **113** | **113** | **11** |

11 of 124 is 8.9%, inside the 10% budget.

One earlier file improves as a side effect:

| vitest file | cases | ported | passing | excluded | was |
| --- | --- | --- | --- | --- | --- |
| `implementation/features/row-pagination/createPaginatedRowModel.test.ts` | 16 | 16 | 16 | 0 | 15 / 1 excluded |

Elm test modules:

| elm-test module | tests | vitest file it ports |
| --- | --- | --- |
| `tests/GroupingRowModelTest.elm` | 16 | `createGroupedRowModel.test.ts`, `columnGroupingFeature.test.ts` |
| `tests/GroupingStateTest.elm` | 24 | `columnGroupingFeature.utils.test.ts` |
| `tests/AggregationTest.elm` | 11 | `rowAggregationFeature.test.ts` |
| `tests/ExpandingRowModelTest.elm` | 14 | `createExpandedRowModel.test.ts`, `rowExpandingFeature.test.ts`, plus the re-homed pagination case |
| `tests/ExpandingStateTest.elm` | 49 | `rowExpandingFeature.utils.test.ts` |

### Re-homed cases

1. `createPaginatedRowModel` > `manualPagination` > "should include expanded
   children when expanded rows bypass manual pagination" →
   `tests/ExpandingRowModelTest.elm`. `tests/PaginationRowModelTest.elm` keeps
   a `-- moved:` comment where it sat. With `manualPagination` on and
   `paginateExpandedRows` off it is `createExpandedRowModel` that splices the
   expanded children in, which is exactly the branch phase 4 wrote.
2. The 5 "one manual option at a time" cases in
   `tests/CoreRowModelsFeatureTest.elm` now assert both halves:
   `manualFiltering` checks the three grouped ids, `manualSorting` checks the
   seven expanded ids, `manualExpanding` checks that the page holds 2 group
   rows, and `manualPagination` checks that all 7 expanded rows survive. The
   phase-3 "waits for phase 4" comments are gone.

## Excluded cases

### `rowAggregationFeature.test.ts` (7)

`Table.AggregationFn` is one fold plus an optional merge. TanStack v9 also
takes `aggregationFn: ['sum', 'mean', { id, aggregationFn }]`, producing a
keyed object per cell, and `columnDef.getAggregationValue` /
`options.manualAggregation`, which hand the aggregation off to the caller.
Neither has a counterpart here.

1. "caches the default rows, invalidates with data, and recomputes explicit
   rows" — `_aggregationValueCache` plus `setOptions`.
2. "includes aggregation depth in the default-row cache key" — the same cache,
   keyed by `maxDepth`. The values it guards are asserted by "selects a unique
   depth frontier and keeps shorter ragged branches".
3. "uses handled column values and configurable local fallback" —
   `columnDef.getAggregationValue` and `manualAggregation`.
4. "supports a shared aggregation value provider through defaultColumn" — the
   same override, set through `defaultColumn`; `Config.defaultColumn` here is
   sizing only.
5. "warns and preserves undefined keys for invalid multi configurations" —
   keyed aggregation plus a `console.warn` spy.
6. "provides groupingRow only for grouped aggregation contexts" — the
   `AggregationContext` object (`subRows`, `groupingRow`, `source`, `table`).
   `AggregationFn.aggregate` takes `List Value`.
7. "lets aggregate choose immediate sub-rows instead of terminal rows" — the
   same context object, read from inside a custom aggregation.

Four further cases keep their scalar half with a comment in place rather than
being excluded: "aggregates scalar and keyed root values without grouping",
"preserves direct sub-row semantics for reaggregatable built-ins", "computes
nested scalar/keyed values and aggregates deeper grouping columns", and
"caches grouped values and merges sub-row results without rescanning parent
leaves".

### `createExpandedRowModel.test.ts` (2)

1. `memoization` > "should return the same reference on repeated calls".
2. `memoization` > "should not recompute when unrelated getters are called in
   between" — both are instance identity and memoization. The third
   memoization case is ported for the row list it guards.

### `rowExpandingFeature.utils.test.ts` (2)

1. `table_autoResetExpanded` > "should schedule a reset to the initial expanded
   state".
2. `table_autoResetExpanded` > "should not reset when manualExpanding is set" —
   `autoReset*` is out of scope per `SPEC.md`; nothing here reacts to a state
   change, and the caller decides when to reset.

### Adapted, not excluded

- "should reset to the initial grouping by default" and "should reset to the
  initial expanded map by default" are ported as the caller writing its own
  remembered value back with `setGrouping` / `setExpanded`, since there is no
  `initialState` (the phase-3 convention).
- "should return an empty array/map and a new instance each time" drops the
  `not.toBe` half: Elm lists and sets are values.
- Every `expect(onExpandedChange).not.toHaveBeenCalled()` becomes
  "the transition returned the state unchanged", and every
  `getUpdaterResult(onXChange, old)` becomes the state the transition
  produces.
- `column_getAutoAggregationFn`'s three `toBe(aggregationFns.sum)` cases
  compare a label recovered by running the function
  (`GroupingStateTest.aggregationFnLabel`), because Elm cannot compare
  functions. This follows `filterFnLabel` / `sortFnLabel` from phase 3.
- The two `_groupingValuesCache` call-count cases assert the value and that a
  repeated read gives the same value; `Table.rowGroupingValueFor` is pure.
- "caches grouped values and merges sub-row results without rescanning parent
  leaves" replaces the `merge` spy with a second column whose merge negates the
  total, so a group whose children are groups can only reach `-3` through the
  merge path.
- "rebuilds grouped aggregation values when column definitions change" uses two
  configs instead of `setOptions`, as phase 3 did for its runtime toggles.
- "keeps grouping structural when rowAggregationFeature is absent" has no
  feature registry to remove, so it is ported as the one column kind the
  automatic aggregation leaves alone: a string column with no
  `withAggregationFn` reads `Null` on a group row.
- "accepts rows from any row model or custom selection" drops the
  `getFilteredSelectedRowModel` line (row selection is phase 5) and keeps the
  four other row sources.
- "passes the original row, row index, and row instance to getGroupingValue"
  drops the `row.id` assertion: `withGetGroupingValue` takes `original` and
  `index`, and `row.index` / `row.original` equal those two arguments.
- The `aggregatedCell` assertion inside "computes nested scalar/keyed values"
  is rendering, which `SPEC.md` puts out of scope.
- `maxDepth: Infinity` is `9007199254740991`, as `pageSize: Infinity` was in
  phase 3.

## API this phase adds

Everything is exposed from `Table` inside the `-- Phase 4` region of the
exposing list and the `# Phase 4` `@docs` section, with the definitions in a
`-- PHASE 4` block after the `-- PHASE 3` block in `src/Table.elm`.

### Configuration

```elm
withRowCanExpand : (Row row -> Bool) -> Config row -> Config row
withIsRowExpanded : (Row row -> Bool) -> Config row -> Config row
withMaxAggregationDepth : Int -> Column row -> Column row
```

### Grouping state

```elm
getCanGroup : Config row -> String -> Bool
getIsGrouped : State -> String -> Bool
getGroupedIndex : State -> String -> Int
toggleGrouping : String -> State -> State
setGrouping : List String -> State -> State
resetGrouping : State -> State
rowIsGrouped : Row row -> Bool
rowGroupingValueFor : Config row -> Row row -> String -> Value
cellIsGrouped : State -> Row row -> String -> Bool
cellIsPlaceholder : State -> Row row -> String -> Bool
preGroupedRowModel : Config row -> State -> RowModel row -> RowModel row
```

`toggleGrouping` is `column_toggleGrouping`, which does not consult
`getCanGroup`; `column_getToggleGroupingHandler` is that guard in front of it,
and the ported handler cases write the guard themselves, as phase 3 did for
`toggleSort`. `Cell` is `{ id, columnId, rowId, value }` with no back
reference, so the two cell predicates take the row and the column id.

### Aggregation

```elm
getAutoAggregationFn : Config row -> RowModel row -> String -> Maybe AggregationFn
getAggregationFn : Config row -> RowModel row -> String -> Maybe AggregationFn
aggregationValue : Config row -> RowModel row -> String -> Value
aggregationValueOf :
    Config row -> RowModel row -> String
    -> { maxDepth : Int, rows : List (Row row) } -> Value
cellIsAggregated : Config row -> RowModel row -> State -> Row row -> String -> Bool
```

The `RowModel row` is what an `'auto'` aggregation function is sampled from,
the way phase 3's `'auto'` filter and sort readers take one. TanStack samples
the **core** row model for `column_getAutoAggregationFn` and aggregates the
**pre-grouped** one for `column_getAggregationValue()`; this port samples both
from the one model it is handed, so pass the core row model unless you mean
otherwise.

### Expanded state

```elm
preExpandedRowModel : Config row -> State -> RowModel row -> RowModel row
getCanExpand : Config row -> Row row -> Bool
getIsExpanded : Config row -> State -> Row row -> Bool
getIsAllParentsExpanded : Config row -> State -> RowModel row -> Row row -> Bool
getCanSomeRowsExpand : Config row -> RowModel row -> Bool
getIsSomeRowsExpanded : State -> Bool
getIsAllRowsExpanded : Config row -> State -> RowModel row -> Bool
getExpandedDepth : Config row -> State -> RowModel row -> Int
toggleExpanded : Config row -> RowModel row -> Row row -> Maybe Bool -> State -> State
toggleAllRowsExpanded : Config row -> RowModel row -> Maybe Bool -> State -> State
setExpanded : Expanded -> State -> State
resetExpanded : State -> State
```

TanStack reads a different row model in each of these: the pre-paginated one
in `table_getCanSomeRowsExpand`, the final one in `table_getIsAllRowsExpanded`,
`table_getExpandedDepth` and `row_toggleExpanded`'s materialisation step, and
`table.getRow` in `row_getIsAllParentsExpanded`. Each function takes its
`RowModel row` explicitly here.

`row_getToggleExpandedHandler` and `table_getToggleAllRowsExpandedHandler` are
DOM handlers; only their state halves exist, and the handler cases wrap
`toggleExpanded` in a `getCanExpand` guard themselves.

## Contract changes

Two `Config` fields and one `Column` field are new, and one `Column` field
changed type. Every change is in `src/Table/Internal/Types.elm`, with the
defaults in `src/Table/Internal/Config.elm` and
`src/Table/Internal/Column.elm`.

`Config`:

| field | was | now | why |
| --- | --- | --- | --- |
| `getRowCanExpand` | — | `Maybe (Row row -> Bool)` (default `Nothing`) | `row_getCanExpand` is `options.getRowCanExpand?.(row) ?? (enableExpanding && subRows.length)`; two ported cases drive that override. |
| `getIsRowExpanded` | — | `Maybe (Row row -> Bool)` (default `Nothing`) | `row_getIsExpanded` is `options.getIsRowExpanded?.(row) ?? …`; two ported cases drive it, one of them through the expanded row model. |

`Column`:

| field | was | now | why |
| --- | --- | --- | --- |
| `maxAggregationDepth` | — | `Int` (default `0`) | `columnDef.maxAggregationDepth` picks the frontier `aggregateColumnValue` folds over; `withMaxAggregationDepth` clamps it at `0`. |
| `getGroupingValue` | `Maybe (row -> Value)` | `Maybe (row -> Int -> Value)` | TanStack calls it `(originalRow, index, row)`, and `columnGroupingFeature.test.ts` asserts the index is passed. The `Row` argument is dropped; its `index` and `original` are the two arguments. `withGetGroupingValue` changed with it. |

`Column.aggregationFn` keeps its type, `Maybe AggregationFn`, but changes
meaning: `Nothing` is now `'auto'`, not "no aggregation", matching the
`rowAggregationFeature` default column definition (`aggregationFn: 'auto'`)
and the `Nothing`-means-`'auto'` rule already used for `filterFn` and
`sortFn`. `'auto'` resolves to `sum` for a numeric column and `extent` for a
date column, and to nothing for any other kind, so a string column still has
no aggregation.

## Semantic differences

1. **A group row's id is `"<columnId>:<groupKey>"`**, joined to its parent
   group's id with `>`: `status:a`, `a:a1>b:b1>c:c1`. This is
   `createGroupedRowModel.ts` verbatim, and it is why an id that contains `:`
   or `>` can in principle collide. TanStack has the same property.
2. **`Null` groups under the key `"null"`.** TanStack keys a bucket with
   `` `${groupingValue}` ``, so `null` gives `"null"` and `undefined` gives
   `"undefined"`. `Value.Null` stands for both here, so both land in
   `status:null`. `Value.toString Null` is `""`, which would make an unreadable
   id, so `Table.Internal.Grouping.groupKey` special-cases `Null`; every other
   constructor goes through `Value.toString`, which matches `String(x)`. The
   `1` / `"1"` collision case therefore ports unchanged.
3. **A group row's `original` is its first leaf row's `original`**, following
   `constructRow(table, id, leafRows[0].original, …)`. `leafRows` is
   `normalizeUniqueAggregationRows(members, Infinity)`, that is every terminal
   descendant of the bucket, so over tree data the first leaf is a grandchild,
   not the first member.
4. **`aggregatedValues` is filled for every leaf column, `Null` included.**
   TanStack replaces `getValue` on a group row, and that replacement returns
   `undefined` for a column that is neither an ancestor grouping column nor
   aggregatable. Elm rows have no method to replace, and `Row.getValue` falls
   back to the accessor on `original`, which for a group row is a real leaf's
   datum. Writing an explicit `Null` is what keeps a group row from reporting
   its first leaf's value. It also means `Dict.size (rowAggregatedValues row)`
   is the leaf column count on every group row.
5. **A grouping column on a group row reports the accessor value of the first
   member, not the grouping value.** `getValue(colId)` in
   `createGroupedRowModel.ts` returns `groupedRows[0].getValue(colId)` for the
   active grouping column and its ancestors. With a custom
   `withGetGroupingValue` those differ: the group *id* and
   `Table.rowGroupingValue` carry the grouping value, while
   `Table.getValue` carries the accessor value.
6. **Ungrouping needs no reset pass.** `_createGroupedRowModel` walks the row
   tree rewriting `depth` and `parentId` when the grouping is empty, because a
   previous grouped pass mutated the shared row objects. Elm rows are
   immutable, so the untouched model already carries its natural
   relationships and the stage returns its input. Both "ungrouping reset"
   cases pin that.
7. **Keyed aggregation does not exist.** `AggregationFn` is one fold plus an
   optional merge; TanStack's `aggregationFn: [...]` produces an object per
   cell. This costs 3 exclusions outright and trims 4 more cases to their
   scalar half.
8. **`merge` is used exactly where TanStack uses it**: only when the group has
   sub-rows, every one of them is a group row of a *different* column, and the
   aggregation carries a merge. Otherwise the values of the frontier at
   `maxAggregationDepth` are folded directly.
9. **`aggregationValueOf` deduplicates its rows, `aggregationValue` does
   not.** TanStack splits `normalizeAggregationRows` (a duplicate-id guard,
   for caller-supplied lists) from `normalizeUniqueAggregationRows` (no guard,
   for rows the pipeline produced). `aggregationValue` reads a row model, so
   it takes the unguarded path; `aggregationValueOf` takes a caller list, so
   it takes the guarded one. The "deduplicates overlapping row inputs" case
   pins the difference.
10. **`expandRows` has one implementation.** `Table.Internal.Expanding.expandList`
    is it; `Table.Internal.Pagination` calls it for both
    `paginateExpandedRows = False` paths (the page slice and
    `rowsInDisplayOrder`) instead of carrying its own copy, which is what
    `reports/phase-3.md` flagged. `Config.getIsRowExpanded` now applies on
    both paths.
11. **The expanded row model checks `manualPagination`.**
    `_createExpandedRowModel` returns its input when
    `!paginateExpandedRows && !manualPagination`, so with pagination manual the
    expansion happens in the expanded stage after all. That is the re-homed
    pagination case.

## Benchmarks

`make bench`, Node 24, `elm make --optimize`, 7 runs, clock around one port
round trip. The new `grouped` case is the `pipeline` case plus grouping: 10,000
flat rows, one column filter (`includesString` on `status`, which every row
passes), grouping by a 20-value `bucket` column with `sum` on `visits` and
`mean` on `progress`, `expanded = expandAll`, one sort (`lastName` ascending,
resolved to the automatic `text` sort fn) and `pageSize = 50`.

| case | rows | min | median |
| --- | --- | --- | --- |
| flat (`coreRowModel`) | 10,000 | 9.6 ms | 15.3 ms |
| nested (`coreRowModel`) | 2,500 × 3 | 10.6 ms | 12.7 ms |
| pipeline (`Table.rows`) | 10,000 | 86.5 ms | 103.8 ms |
| **grouped (`Table.rows`)** | **10,000** | **149.4 ms** | **156.3 ms** |

Target for the full pipeline was under 500 ms. No optimisation pass was
needed, because the grouped row model was written the way
`reports/phase-3.md` warned it had to be:

- one `Dict String` fold per level, keyed by the stringified grouping value,
  with first-seen order kept in a separate list;
- every leaf column resolved once per call into a `Resolved` record holding
  its group index, aggregation function, `maxAggregationDepth` and a
  `Row row -> Value` reader, so `Column.findColumn` never runs inside a loop
  and `Row.getValue` is never called per row;
- each column aggregated once per group, over the child groups' already
  computed values when the aggregation has a merge;
- `flatRows` built by one pre-order walk of the produced tree and `rowsById`
  by one `Dict` fold over that list.

The `grouped` answer line is `50 501 10020`: 20 group rows plus 10,000 leaves
in `rowsById`, and a page of 50 whose first row is a group carrying its 500
leaves.

## Not touched

`PORT_NOTES.md` is not in this phase's file list (a parallel phase-5 agent is
running), so its coverage table, semantic-difference list and phase-report
section still have to absorb both this report and `reports/phase-3.md`. The
rows to fold in are the two coverage tables above and the eleven semantic
differences.

One formatting note for the merge: `elm-format` pulls dangling comments at
the end of an exposing list down past the entries, so the phase markers there
are now a single trailing pair, `-- Phase 3 and Phase 4 are complete; phase 5
appends below.` followed by `-- Phase 5`. Phase 5 appends its entries above
that pair. The `-- PHASE 4` definition block sits after `-- PHASE 3` in
`src/Table.elm`; phase 5's goes after it.

`src/Table/Internal/Header.elm` and `groupedColumnMode` are untouched:
`groupedColumnMode` reorders or removes grouped columns from
`visibleLeafColumns`, which is phase 5's area, and it does not affect the row
model.

## Biggest risk for the merge with phase 5

**Every group row now carries an `aggregatedValues` entry for every leaf
column, and phase 5 changes which columns those are.** `Table.Internal.Grouping`
fills the dictionary from `Column.leafColumns cfg`, the definition-order leaf
list, not from `visibleLeafColumns`. Phase 5 owns `visibleLeafColumns`,
`columnOrder`, `columnVisibility` and `groupedColumnMode`, and the temptation
on merge will be to make grouping respect visibility so a hidden column is not
aggregated. It must not: TanStack aggregates lazily per `getValue` call and
never consults visibility, `row.getAllCells()` includes hidden columns, and a
column that is hidden and then shown again would otherwise read `Null` on
every group row until the model is rebuilt.

Two concrete seams:

1. **Selection over grouped rows.** `row_getIsSelected` walks `subRows`, and
   after grouping the top-level rows are group rows whose `subRows` are the
   leaves. Phase 5's `enableSubRowSelection` therefore decides whether
   selecting a group selects its members. It should run on the **grouped**
   model, not the core one, and `Row.leafRows` (terminal descendants) is not
   the same list as `Row.subRows` (direct children) on a group row.
2. **Header pinning and `groupedColumnMode`.** `groupedColumnMode: 'reorder'`
   moves grouped columns to the front of `visibleLeafColumns` and `'remove'`
   drops them, both before pinning partitions the list. `State.grouping` is
   now a live input to the column order as well as to the row model, so
   `Table.Internal.Header.visibleLeafColumnsToGroup` has to read it, and the
   two phase-2 header cases excluded for pinning come back with grouping in
   the mix.
