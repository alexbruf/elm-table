# Phase 2: core row model and columns

Reference commit: `36733a38b6a77878eea616b25012c47a0f93d4da`.

`make check` is green: `elm-format --validate src tests`, `elm-review` with the
package template config, `elm-test` 74 tests (69 phase-2 cases plus the 5
phase-0 fixture tests). `elm make --docs` succeeds. No `Debug` in `src/`.

## Coverage

| vitest file | cases | ported | passing | excluded |
| --- | --- | --- | --- | --- |
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
| **total** | **115** | **69** | **69** | **46** |

Elm test modules, one per source area:

| elm-test module | vitest files it ports |
| --- | --- |
| `tests/CoreRowModelTest.elm` | `createCoreRowModel.test.ts`, `rowModelFlatRowsOrder.test.ts` |
| `tests/CoreColumnsTest.elm` | `unit/core/columns/*` |
| `tests/CoreHeadersTest.elm` | `unit/core/headers/*` |
| `tests/CoreRowsTest.elm` | `unit/core/rows/*` |
| `tests/CoreRowModelsFeatureTest.elm` | `unit/core/row-models/coreRowModelsFeature.utils.test.ts` |
| `tests/CoreCellsTest.elm` | `unit/core/cells/*` |
| `tests/CoreTableTest.elm` | `unit/core/table/stockFeaturesInitialState.test.ts` |

## Excluded cases

Instance identity, memoization, and `setOptions`:

1. `createCoreRowModel` "should return the same model object across repeated calls" — memoization of a table instance; Elm values are recomputed and compared structurally.
2. `createCoreRowModel` "should build a new model when the data array identity changes" — same reason, plus `setOptions`.
3. `createCoreRowModel` "should preserve the cached model when setOptions keeps the same data reference" — `setOptions` has no counterpart.
4. `createCoreRowModel` "should call getSubRows with (originalRow, index)" — spy-only, and `Config.getSubRows` is `row -> List row` with no index parameter.
5. `constructRow` "memoizes getLeafRows until subRows changes" — memoization.
6. `coreRowsFeature.utils` "should reuse cell instances across calls" — cell instance identity; cells are plain records built on demand.
7. `coreHeadersFeature.utils` "should expose the header, column, and table" and `coreCellsFeature.utils` "should expose the table, column, row, and cell with bound value helpers" — `getContext` builds a render context around the table instance (2 cases).

Feature-registry and prototype hooks (this port has no feature objects):

8. `constructColumn` "should initialize instance-specific column data for every column".
9. `constructHeader` "should initialize instance-specific header data for every header".
10. `constructHeader` "should initialize instance-specific header group data for every header group".
11. `constructCell` "should initialize instance-specific cell data once per cell".
12. `coreRowModelsFeature.utils` "should cache the core row model factory across calls".
13. `coreRowModelsFeature.utils` "should instantiate a registered factory even when its manual option bypasses the result".
14–18. `coreRowModelsFeature.utils` "runtime toggling via setOptions" (5 cases) — `setOptions` has no counterpart; the flags are ordinary record fields the caller changes.
19–25. `constructTable.test.ts` (7 cases) — table instance construction, feature init order, `table_mergeOptions`, static options.
26–36. `rowModelSlots.test.ts` (11 cases) — row-model and fn-registry feature slots plus TypeScript type-level assertions.

Rendering (out of scope per SPEC):

37. `coreColumnsFeature.utils` "should render accessor keys as the default header".
38. `coreColumnsFeature.utils` "should stringify values in the default cell renderer".
39–40. `coreRowsFeature.utils` `row_renderValue` (2 cases) — `renderValue` and `renderFallbackValue` are render concerns.
41–42. `coreCellsFeature.utils` `cell_renderValue` (2 cases) — same.

Later phases:

43. `coreHeadersFeature.utils` "should order pinned columns first via the pin partitioning path" — column pinning is phase 5. The seam is `Table.Internal.Header.visibleLeafColumnsToGroup`.
44. `coreHeadersFeature.utils` "should keep rowSpans consistent through the pin partitioning path" — same.
45. `coreRowModelsFeature.utils` "registered factories should apply when manual options are off" — needs the phase 3 filtered row model.

That is 45 entries covering 46 excluded cases (entry 7 covers two).

### Adapted cases

- `createCoreRowModel` "should receive (originalRow, index, parentRow)…" is ported by encoding the arguments in the produced row ids; the `toHaveBeenCalledTimes` assertion is dropped.
- `coreColumnsFeature.utils` "should let options.defaultColumn win" is ported against `Config.defaultColumn` sizing instead of the default header template, because header templates are render code.
- `coreRowsFeature.utils` "should preserve cell identity across column order changes" asserts the new order and that the cell set is unchanged, not object identity.
- `coreRowsFeature.utils` "should throw for unknown row ids" asserts `Nothing`; Elm has no exceptions.
- `table_getRowId` / `row_getValue` "cache" cases assert the value, since caching is not observable in a pure API.
- The 5 "one manual option at a time" cases assert only the bypass half. **Phase 3 and 4 must extend them** with the downstream transform assertions (grouped ids, sorted names, expanded row ids, page slice) once those stages exist.

## API this phase defines

Everything below is exposed from `Table`. The exposing list and the `@docs`
blocks are split by `-- Phase 2` / `-- Phase 3` / `-- Phase 4` / `-- Phase 5`
markers so parallel phases append in different regions.

### Types

`Column row`, `Config row`, `State`, `Row row`, `RowModel row`, `Header row`,
`HeaderGroup row`, `Cell`, `Expanded`, `SortUndefined`, `GroupedColumnMode`,
`SortColumn`, `ColumnFilter`, `Pagination`, `ColumnPinning`, `RowPinning`,
`SizeDefaults`.

`Column`, `Row`, and `Header` are opaque. `Config`, `State`, `RowModel`,
`HeaderGroup`, `Cell`, and the small state records are transparent records.

Elm cannot re-export the variants of a type declared in another module, and the
types have to live in `Table.Internal.Types` so the internal modules can build
them. `Expanded`, `SortUndefined`, and `GroupedColumnMode` are therefore
abstract in `Table` with one function per variant:

- `expandAll : Expanded`, `expandedIds : Set String -> Expanded`, `expandedIdsOf : Expanded -> Maybe (Set String)`
- `sortNullsFirst`, `sortNullsLast`, `sortNullsAsMinusOne`, `sortNullsAsPlusOne : SortUndefined`
- `groupedColumnsReorder`, `groupedColumnsRemove`, `groupedColumnsIgnore : GroupedColumnMode`

Inside `src/Table/Internal/*` the constructors are ordinary constructors
(`Table.Internal.Types.ExpandAll` and so on), so phases 3 to 5 pattern match on
them directly.

### Configuration

- `config : List (Column row) -> Config row`
- `initialState : State`
- `withGetRowId : (row -> Int -> Maybe String -> String) -> Config row -> Config row`
- `withSubRows : (row -> List row) -> Config row -> Config row`
- `withDefaultColumn : SizeDefaults -> Config row -> Config row`
- `withGlobalFilterFn : FilterFn -> Config row -> Config row`
- `withRowSelection : (row -> Bool) -> Config row -> Config row`

Every other flag is a plain record field, set with record update. `Config` holds:
`columns`, `getRowId`, `getSubRows`, `manualSorting`, `manualFiltering`,
`manualGrouping`, `manualExpanding`, `manualPagination`, `enableSorting`,
`enableMultiSort`, `maxMultiSortColCount`, `enableSortingRemoval`,
`enableMultiRemove`, `sortDescFirst`, `enableColumnFilters`,
`enableGlobalFilter`, `filterFromLeafRows`, `maxLeafRowFilterDepth`,
`globalFilterFn`, `enableGrouping`, `groupedColumnMode`, `enableExpanding`,
`paginateExpandedRows`, `enableRowSelection`, `enableMultiRowSelection`,
`enableSubRowSelection`, `enableRowPinning`, `keepPinnedRows`,
`enableColumnPinning`, `enableHiding`, `defaultColumn`.

Defaults follow TanStack: every `manual*` flag `False`, every `enable*` flag
`True`, `maxMultiSortColCount = 9007199254740991`, `maxLeafRowFilterDepth =
100`, `filterFromLeafRows = False`, `sortDescFirst = False`, `globalFilterFn =
Nothing` (auto), `groupedColumnMode = groupedColumnsReorder`,
`paginateExpandedRows = True`, `keepPinnedRows = True`, `getSubRows` returns
`[]`, `getRowId = Nothing`, `defaultColumn = { size = 150, minSize = 20, maxSize
= 9007199254740991 }`.

`State` holds `sorting`, `columnFilters`, `globalFilter`, `grouping`,
`expanded`, `rowSelection`, `pagination`, `columnOrder`, `columnVisibility`,
`columnPinning`, `columnSizing`, `rowPinning`. `initialState` matches
`stockFeaturesInitialState.test.ts`: empty lists, empty `Set`/`Dict`,
`globalFilter = Value.Null`, `expanded = expandedIds Set.empty`,
`pagination = { pageIndex = 0, pageSize = 10 }`, `columnPinning = { left = [],
right = [] }`, `rowPinning = { top = [], bottom = [] }`.

Note: `columnPinning` uses `left` / `right`, not TanStack's `start` / `end`.

### Building columns

`column : String -> (row -> Value) -> Column row`,
`group : String -> List (Column row) -> Column row`,
`display : String -> Column row`.

Options, all `a -> Column row -> Column row`:
`withHeader`, `withFooter`, `withSortFn`, `withCustomSort`, `withSortDescFirst`,
`withInvertSorting`, `withSortUndefined`, `withEnableSorting`,
`withEnableMultiSort`, `withFilterFn`, `withCustomFilter`,
`withEnableColumnFilter`, `withEnableGlobalFilter`, `withAggregationFn`,
`withGetGroupingValue`, `withGetUniqueValues`, `withEnableGrouping`,
`withEnableHiding`, `withEnablePinning`, `withSize`, `withMinSize`,
`withMaxSize`.

`withCustomSort : (Row row -> Row row -> Order)` and
`withCustomFilter : (Row row -> Value -> Bool)` take rows, as SPEC requires.
Column ids are always explicit; `group` stamps `depth` and `parentId` onto its
whole subtree at build time, so no table instance is needed to read them.

### Reading columns

`columnId`, `columnHeader`, `columnFooter`, `columnDepth`, `columnColumns`,
`columnParentId`, `columnAccessor`, `columnSize`, `columnMinSize`,
`columnMaxSize`, `columnFlatColumns`, `columnLeafColumns`,
`allColumns : Config row -> List (Column row)` (flat, groups included, group
before children), `leafColumns : Config row -> List (Column row)` (definition
order), `visibleLeafColumns : Config row -> State -> List (Column row)`
(`columnOrder` applied, hidden columns dropped), `findColumn : Config row ->
String -> Maybe (Column row)`.

### Reading rows

`rowId`, `rowIndex`, `rowDepth`, `rowOriginal`, `rowSubRows`, `rowParentId`,
`rowOriginalSubRows`, `rowGroupingColumnId`, `rowGroupingValue`, `rowLeafRows`,
`rowAggregatedValues`.

`getValue : Config row -> Row row -> String -> Value` (aggregated values first,
then the accessor, `Null` for unknown or accessor-less columns),
`getUniqueValues : Config row -> Row row -> String -> List Value`,
`getLeafRows : Row row -> List (Row row)`,
`getParentRow : RowModel row -> Row row -> Maybe (Row row)`,
`getParentRows : RowModel row -> Row row -> List (Row row)`,
`getAllCells : Config row -> State -> Row row -> List Cell`,
`findRow : RowModel row -> String -> Maybe (Row row)`,
`maxSubRowDepth : RowModel row -> Int`.

`Cell = { id, columnId, rowId, value }` with `id = rowId ++ "_" ++ columnId`.

`Row` carries `groupingColumnId : Maybe String`, `groupingValue : Value`,
`leafRows : List (Row row)`, and `aggregatedValues : Dict String Value` already;
the core row model leaves them empty, phase 4 fills them.

### Headers

`headerGroups : Config row -> State -> List (HeaderGroup row)`, `footerGroups`
(reversed), `flatHeaders`, `leafHeaders`, `getLeafHeaders : Header row -> List
(Header row)`, and the accessors `headerId`, `headerColumnId`, `headerColSpan`,
`headerRowSpan`, `headerDepth`, `headerIndex`, `headerIsPlaceholder`,
`headerPlaceholderId`, `headerSubHeaders`.

`HeaderGroup row = { id : String, depth : Int, headers : List (Header row) }`.
Group ids are `"0"`, `"1"`, …, header depths run from `1` at the top, matching
`buildHeaderGroups`.

### The pipeline

- `rows : Config row -> State -> Array row -> RowModel row`, `rowsFromList` for `List`
- `coreRowModel : Config row -> State -> Array row -> RowModel row`, `coreRowModelFromList`
- `filteredRowModel`, `groupedRowModel`, `sortedRowModel`, `expandedRowModel`,
  `paginatedRowModel : Config row -> State -> RowModel row -> RowModel row`
- `facetedUniqueValues : Config row -> State -> RowModel row -> String -> List ( Value, Int )`
- `facetedMinMax : Config row -> State -> RowModel row -> String -> Maybe ( Float, Float )`

**Pipeline order deviates from the task brief and follows TanStack:** core →
filtered → **grouped** → **sorted** → expanded → paginated. `coreRowModelsFeature.utils.ts`
defines `preSorted = grouped` and `preGrouped = filtered`, and the ported matrix
case "manualGrouping should bypass grouping while sorting still sorts the
filtered leaf rows" only makes sense in that order.

Each stage function in `Table` checks its `manual*` flag and returns the input
unchanged when it is set; the body lives in
`src/Table/Internal/{Filtering,Grouping,Sorting,Expanding,Pagination}.elm` and
is an identity pass-through in phase 2. Faceting is stubbed in
`src/Table/Internal/Faceting.elm`. **Phases 3 to 5 fill those bodies and never
need to touch `Table.elm` for the pipeline.**

Stub bodies are written point-free (`always (always identity)`) because
`elm-review`'s `NoUnused.Parameters` rejects `_` parameters.

### Module layout

```
src/Table.elm                        facade, phase-sectioned exposing list
src/Table/Internal/Types.elm         every shared type
src/Table/Internal/Config.elm        config defaults, builders, rowIdFor
src/Table/Internal/Column.elm        column builders, accessors, column lists
src/Table/Internal/Row.elm           row accessors and row helpers
src/Table/Internal/Header.elm        header groups, spans, placeholders
src/Table/Internal/CoreRowModel.elm  createCoreRowModel
src/Table/Internal/Filtering.elm     phase 3
src/Table/Internal/Sorting.elm       phase 3
src/Table/Internal/Grouping.elm      phase 4
src/Table/Internal/Expanding.elm     phase 4
src/Table/Internal/Pagination.elm    phase 3
src/Table/Internal/Faceting.elm      phase 3
```

`tests/Fixtures.elm` gained `columns : List (Table.Column Person)` (one accessor
column per `Person` field, `subRows` excluded) and `config : Table.Config Person`
(`columns` plus `withSubRows`).

## Benchmarks

`make bench` builds `bench/src/Bench.elm` with `--optimize` and runs
`bench/run.js` under Node 24. The clock is `performance.now()` around one port
round trip; the Elm side builds the row model inside the port subscription
handler and answers with the row, flatRow, and `rowsById` counts so nothing is
left unevaluated. Seven runs per case.

| case | rows | min | median |
| --- | --- | --- | --- |
| flat | 10,000 rows, no children | 9.7 ms | 14.7 ms |
| nested | 2,500 parents x 3 children = 10,000 rows | 10.8 ms | 12.9 ms |

Target was under 100 ms; the numbers are 7 to 10 times inside it, so no
optimisation work was needed. `flatRows` is built with one preorder traversal
and `rowsById` with a single `Dict` fold over that list, so nothing is
re-flattened and no `List.append` runs inside a loop.

## Biggest risk for phase 3

Filter-value semantics. `State.columnFilters` carries `Value`, and TanStack
resolves each filter through `filterFn.resolveFilterValue` before any row is
tested, then picks a filter fn per column with `getFilterFn` (`'auto'` inspects
the first row's cell value). Phase 2 leaves `Column.filterFn` and
`Config.globalFilterFn` as `Maybe FilterFn` with `Nothing` meaning auto, so
phase 3 has to implement that auto-detection against
`columnFilteringFeature.utils.ts` and decide where `autoRemove` runs. Get the
resolve-once placement wrong and `createFilteredRowModel.test.ts` fails in ways
that look like filter-fn bugs. The second risk in the same area is
`filterFromLeafRows` plus `maxLeafRowFilterDepth`, which change which node of
the row tree is tested and are the only part of filtering that touches the tree
shape phase 2 built.
