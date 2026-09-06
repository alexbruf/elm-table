# Phase 5: selection, pinning, ordering, visibility, sizing

Reference commit: `36733a38b6a77878eea616b25012c47a0f93d4da`.

`make check` is green in this worktree: `elm-format --validate src tests`,
`elm-review` with the package template config, `elm-test` 539 tests (287 of
them phase 5). `elm make --docs` succeeds. No `Debug` in `src/`.

Phase 3 is being ported in parallel, so `filteredRowModel`, `sortedRowModel`,
`groupedRowModel`, `expandedRowModel`, and `paginatedRowModel` are still
identity stubs here. Cases that need one of those stages are written but kept
out of the exported `suite`; see "Pending integration".

## Coverage

| vitest file | cases | ported | passing | excluded |
| --- | --- | --- | --- | --- |
| `unit/features/column-visibility/columnVisibilityFeature.utils.test.ts` | 27 | 25 | 25 | 2 |
| `unit/features/column-ordering/columnOrderingFeature.utils.test.ts` | 22 | 22 | 22 | 0 |
| `unit/features/column-pinning/columnPinningFeature.utils.test.ts` | 56 | 56 | 56 | 0 |
| `unit/features/column-sizing/columnSizingFeature.utils.test.ts` | 38 | 38 | 38 | 0 |
| `implementation/features/row-selection/rowSelectionFeature.test.ts` | 34 | 29 | 26 | 5 |
| `implementation/features/row-selection/rowSelectionRange.test.ts` | 23 | 17 | 11 | 6 |
| `unit/features/row-selection/rowSelectionFeature.utils.test.ts` | 58 | 51 | 51 | 7 |
| `unit/features/row-pinning/rowPinningFeature.utils.test.ts` | 37 | 37 | 37 | 0 |
| `implementation/features/row-pinning/rowPinningFeature.test.ts` | 20 | 20 | 19 | 0 |
| `unit/core/headers/coreHeadersFeature.utils.test.ts` (re-homed) | 2 | 2 | 2 | 0 |
| **total** | **317** | **297** | **287** | **20** |

20 of 315 in-scope phase 5 cases are excluded, 6.3%.

Elm test modules, one per vitest file:

| elm-test module | vitest file it ports |
| --- | --- |
| `tests/ColumnVisibilityTest.elm` | `unit/features/column-visibility/columnVisibilityFeature.utils.test.ts` |
| `tests/ColumnOrderingTest.elm` | `unit/features/column-ordering/columnOrderingFeature.utils.test.ts` |
| `tests/ColumnPinningTest.elm` | `unit/features/column-pinning/columnPinningFeature.utils.test.ts` plus the two re-homed header cases |
| `tests/ColumnSizingTest.elm` | `unit/features/column-sizing/columnSizingFeature.utils.test.ts` |
| `tests/RowSelectionTest.elm` | `unit/features/row-selection/rowSelectionFeature.utils.test.ts` |
| `tests/RowSelectionFeatureTest.elm` | `implementation/features/row-selection/rowSelectionFeature.test.ts` |
| `tests/RowSelectionRangeTest.elm` | `implementation/features/row-selection/rowSelectionRange.test.ts` |
| `tests/RowPinningTest.elm` | `unit/features/row-pinning/rowPinningFeature.utils.test.ts` |
| `tests/RowPinningFeatureTest.elm` | `implementation/features/row-pinning/rowPinningFeature.test.ts` |

`tests/Fixtures.elm` is unchanged; the new modules build on `Fixtures.config`,
`Fixtures.makeData`, and two local fixtures (an `Item` record for the sizing
and header cases, a `TestRow` record with sub-rows for the range cases).

## Excluded cases

DOM handlers (8):

1. `columnVisibilityFeature.utils` "column_getToggleVisibilityHandler should
   return handler that toggles visibility based on checkbox state".
2. `columnVisibilityFeature.utils` "table_getToggleAllColumnsVisibilityHandler
   should return handler that toggles all columns visibility based on checkbox
   state".
3. `rowSelectionFeature.utils` "row_getToggleSelectedHandler should read
   event.target.checked".
4. `rowSelectionFeature.utils` "row_getToggleSelectedHandler should be a no-op
   when the row cannot be selected".
5. `rowSelectionFeature.utils` "table_getToggleAllRowsSelectedHandler should
   select all rows from the checkbox state".
6. `rowSelectionFeature.utils` "table_getToggleAllPageRowsSelectedHandler
   should select page rows from the checkbox state".
7. `rowSelectionRange` "detects direct and wrapped Shift events but ignores
   ordinary events" — the case is about the event shape (`shiftKey`,
   `nativeEvent.shiftKey`); the state half it drives is covered by the range
   cases that are ported.
8. `rowSelectionRange` "supports custom range event detection" — same, plus an
   `isRowRangeSelectionEvent` option that has no counterpart.

Spies and memoization (6):

9. `rowSelectionFeature.utils` "should fire even for structural no-ops (row
   selection skips the no-op guard)" — a call-count assertion on
   `onRowSelectionChange`.
10. `rowSelectionFeature.utils` "should evaluate the enableSubRowSelection
    predicate once per unique parent" — a call-count assertion on the
    predicate; the port has no per-pass subtree cache to observe.
11. `rowSelectionFeature` "should not copy memoized row APIs from the original
    row to cloned parent rows".
12. `rowSelectionFeature` "memoizes getIsAllRowsSelected until selection or row
    model changes".
13. `rowSelectionFeature` "skips the enableRowSelection predicate for
    already-selected rows".
14. `rowSelectionRange` "does not resolve display order for ordinary clicks but
    does for ranges" — a spy on `getRowsInDisplayOrder`.

Instance identity and feature registry (3):

15. `rowSelectionFeature` "should preserve row prototype methods on cloned
    parent rows" — prototype identity of a cloned row.
16. `rowSelectionFeature` "getGroupedSelectedRowModel falls back through the
    row-model chain when sorting is not registered" — feature-registry
    fallback; the caller picks the row model here.
17. `rowSelectionFeature.utils` "table_getPreSelectedRowModel should return the
    core row model" — no counterpart: the selected row model takes the row
    model as an argument.

Caller-owned UI state (3):

18. `rowSelectionRange` "uses one selection change and never calls
    row.toggleSelected per interval row" — spies on the instance API.
19. `rowSelectionRange` "is not changed by direct row or table state APIs" —
    `_lastSelectedRowId` is the anchor, which the caller owns in this port.
20. `rowSelectionRange` "clears through every selection reset and select-all
    path" — same reason.

### Adapted cases

- Every `onXChange` case is ported as an assertion on the returned `State`
  instead of on the spy.
- Every `reset...(table, false)` case ("reset to initial state") is ported as
  `setX initial state`, because a stateless API has no `table.initialState`;
  `resetX` is TanStack's `defaultState: true` behaviour.
- `toHaveBeenCalledTimes` assertions are dropped throughout.
- `getDefaultXState` "not.toBe" (new instance each call) assertions are
  dropped; the value assertion is kept.
- `row_getCenterVisibleCells` "should return the shared visible cells array
  when nothing is pinned" and `table_getCenterLeafColumns` "should return the
  shared leaf columns array when nothing is pinned" assert structural equality
  instead of reference identity.
- `table_getTopRows` "should return pinned rows with position property"
  asserts the rows themselves; TanStack mutates a `position` field onto the
  row, which this port does not.
- `row_pin` "should include leaf rows" / "should include parent rows" use real
  nested fixture rows instead of a mocked `getLeafRows` / `getParentRows`.
- The `keepPinnedRows` cases and every "current page" case build the page by
  slicing the core row model, because the paginated row model is a stub here
  and the pinned-row and page-selection APIs take the row model as an
  argument. After the merge these can be re-pointed at
  `Table.paginatedRowModel` without changing the expectations.
- `rowSelectionFeature` "should preserve three levels of selected row structure
  and prototypes" keeps the structure assertions and drops the three identity
  assertions.
- `rowSelectionRange` "can disable range selection" is ported as two ordinary
  toggles: range selection is opt-in at the call site here, so there is no
  `enableRowRangeSelection` flag to switch off.
- `rowSelectionRange` "falls back to an ordinary toggle for invalid and removed
  anchor ids" uses a row model built without the anchor row instead of applying
  a column filter.
- `column pinning table instance APIs` "should update center visible columns
  when column order changes" asserts the seven fixture columns; the TypeScript
  fixture has an eighth (`subRows`) column that this port's fixture does not.
- `isRowSelected` "row id exists / does not exist" cases build real rows with
  `withGetRowId` (ids `123`, `456`, `789`) because `Row` is opaque and cannot
  be faked.

## Pending integration

Written in full, kept out of the exported `suite` as a top-level
`pendingIntegration : List Test` in the same module. They compile and fail
only because the stage they exercise is an identity stub in this worktree.
Wire each one in with `describe "<name>" pendingIntegration` (or splice the
list into `suite`) after the phase 3 merge.

`tests/RowSelectionFeatureTest.elm` (3 cases, needs filtered / grouped /
sorted):

1. "getFilteredSelectedRowModel excludes selected rows that are filtered out"
2. "getGroupedSelectedRowModel returns a selected group row"
3. "getGroupedSelectedRowModel collects a selected leaf under an unselected
   group"

`tests/RowSelectionRangeTest.elm` (6 counted cases in 7 test values, needs
expanded / sorted / filtered / grouped / paginated):

4. "changes expanded descendants explicitly when child recursion is disabled"
5. "prunes ancestors of deselected range rows with deselectParents"
6. "uses the latest sorting order between interactions"
7. "uses the latest filtered order while a visible anchor remains valid"
8. "includes grouped rows in display order"
9. "selects across client-side pages"
10. "includes expanded rows when paginateExpandedRows is true or false" — the
    vitest `it.each([true, false])` case, which the `it(`-line count does not
    count.

`tests/RowPinningFeatureTest.elm` (1 case, needs grouped):

11. "does not throw when a pinned grouped row disappears after ungrouping"

`pendingIntegration` is typed `List Test` rather than `Test` on purpose:
elm-test runs every exposed `Test` value it finds, and `Test.skip` makes the
run exit with code 3, which would break `make check`. elm-test ignores values
of other types, and `NoUnused.Exports` is already configured to ignore
`tests/`.

## API this phase defines

Everything below is exposed from `Table`. `elm-format` moves comments in an
exposing list to its end, so the phase 5 entries sit directly after the phase
2 ones and the `-- Phase 3` / `-- Phase 4` / `-- Phase 5` markers now trail
the list; a comment there says so.

### Types

`ColumnPinPosition`, `ColumnRegion`, `RowPinPosition`, `SubRowSelection` are
abstract unions with one function per variant, following the phase 2
convention. `SelectOptions`, `PinRowOptions`, `PinnedRowsSource row`, and
`PinnedColumns row` are transparent records.

```elm
type alias SelectOptions = { selectChildren : Bool, deselectParents : Bool }
type alias PinRowOptions = { includeLeafRows : Bool, includeParentRows : Bool }
type alias PinnedRowsSource row = { prePaginated : RowModel row, current : RowModel row }
type alias PinnedColumns row = { left : List (Column row), center : List (Column row), right : List (Column row) }
```

Variant constructors and defaults:

```elm
pinnedLeft, pinnedRight, columnUnpinned : ColumnPinPosition
allColumnsRegion, leftColumnsRegion, centerColumnsRegion, rightColumnsRegion : ColumnRegion
pinnedTop, pinnedBottom, rowUnpinned : RowPinPosition
noSubRowsSelected, someSubRowsSelected, allSubRowsSelected : SubRowSelection
defaultSelectOptions : SelectOptions
defaultPinRowOptions : PinRowOptions
```

### Column visibility

```elm
columnIsVisible : State -> Column row -> Bool
columnCanHide : Config row -> Column row -> Bool
toggleColumnVisibility : Config row -> Column row -> Maybe Bool -> State -> State
setColumnVisibility : Dict String Bool -> State -> State
resetColumnVisibility : State -> State
toggleAllColumnsVisible : Config row -> Maybe Bool -> State -> State
isAllColumnsVisible : Config row -> State -> Bool
isSomeColumnsVisible : Config row -> State -> Bool
visibleFlatColumns : Config row -> State -> List (Column row)
visibleCells : Config row -> State -> Row row -> List Cell
visibleCellsByColumnId : Config row -> State -> Row row -> Dict String Cell
```

### Column order

```elm
setColumnOrder : List String -> State -> State
resetColumnOrder : State -> State
orderColumns : Config row -> State -> List (Column row) -> List (Column row)
orderGroupedColumns : Config row -> State -> List (Column row) -> List (Column row)
columnIndex : Config row -> State -> ColumnRegion -> Column row -> Int
columnIsFirst : Config row -> State -> ColumnRegion -> Column row -> Bool
columnIsLast : Config row -> State -> ColumnRegion -> Column row -> Bool
```

`orderColumns` is TanStack's `table_getOrderColumnsFn` (column order, then
grouped-column rules); `orderGroupedColumns` is TanStack's `orderColumns`.

### Column pinning

```elm
pinColumn : ColumnPinPosition -> Column row -> State -> State
setColumnPinning : ColumnPinning -> State -> State
resetColumnPinning : State -> State
columnCanPin : Config row -> Column row -> Bool
columnIsPinned : State -> Column row -> ColumnPinPosition
columnPinnedIndex : State -> Column row -> Int
isSomeColumnsPinned : State -> Bool
isSomeColumnsPinnedLeft : State -> Bool
isSomeColumnsPinnedRight : State -> Bool
leftLeafColumns, centerLeafColumns, rightLeafColumns : Config row -> State -> List (Column row)
pinnedLeafColumns : Config row -> State -> ColumnRegion -> List (Column row)
leftVisibleLeafColumns, centerVisibleLeafColumns, rightVisibleLeafColumns : Config row -> State -> List (Column row)
pinnedVisibleLeafColumns : Config row -> State -> ColumnRegion -> List (Column row)
pinnedColumns : Config row -> State -> PinnedColumns row
leftHeaderGroups, centerHeaderGroups, rightHeaderGroups : Config row -> State -> List (HeaderGroup row)
leftFooterGroups, centerFooterGroups, rightFooterGroups : Config row -> State -> List (HeaderGroup row)
leftFlatHeaders, centerFlatHeaders, rightFlatHeaders : Config row -> State -> List (Header row)
leftLeafHeaders, centerLeafHeaders, rightLeafHeaders : Config row -> State -> List (Header row)
leftVisibleCells, centerVisibleCells, rightVisibleCells : Config row -> State -> Row row -> List Cell
```

### Column sizing

```elm
getColumnSize : Config row -> State -> Column row -> Float
getColumnStart : Config row -> State -> ColumnRegion -> Column row -> Float
getColumnAfter : Config row -> State -> ColumnRegion -> Column row -> Float
setColumnSize : String -> Float -> State -> State
setColumnSizing : Dict String Float -> State -> State
resetColumnSize : String -> State -> State
resetColumnSizing : State -> State
getHeaderSize : Config row -> State -> Header row -> Float
getHeaderStart : Config row -> State -> List (Header row) -> Header row -> Float
totalSize, leftTotalSize, centerTotalSize, rightTotalSize : Config row -> State -> Float
```

`getColumnSize` is the state-aware size; phase 2's `columnSize` stays the
column definition's own clamped size. `getHeaderStart` takes the headers of
the row the header belongs to, because a `Header` does not point back at its
header group.

### Row selection

```elm
toggleRowSelected : Config row -> RowModel row -> Row row -> Maybe Bool -> State -> State
toggleRowSelectedWith : Config row -> SelectOptions -> RowModel row -> Row row -> Maybe Bool -> State -> State
toggleAllRowsSelected : Config row -> RowModel row -> Maybe Bool -> State -> State
toggleAllPageRowsSelected : Config row -> RowModel row -> Maybe Bool -> State -> State
deselectAllRows : State -> State
setRowSelection : Set String -> State -> State
resetRowSelection : State -> State
selectRange : Config row -> RowModel row -> String -> Row row -> Bool -> State -> State
selectRangeWith : Config row -> SelectOptions -> RowModel row -> String -> Row row -> Bool -> State -> State
canSelectRange : Config row -> RowModel row -> String -> Row row -> Bool
getIsRowSelected : State -> Row row -> Bool
getIsSomeRowsSelected : State -> Bool
getIsAllRowsSelected : Config row -> State -> RowModel row -> Bool
getIsAllPageRowsSelected : Config row -> State -> RowModel row -> Bool
getIsSomePageRowsSelected : Config row -> State -> RowModel row -> Bool
getCanSelect : Config row -> Row row -> Bool
getCanSelectSubRows : Config row -> Row row -> Bool
getCanMultiSelect : Config row -> Row row -> Bool
getIsSomeSelected : Config row -> State -> Row row -> Bool
getIsAllSubRowsSelected : Config row -> State -> Row row -> Bool
subRowSelection : Config row -> State -> Row row -> SubRowSelection
selectedRowIds : State -> List String
selectedRowModel : State -> RowModel row -> RowModel row
```

`selectedRowModel` is TanStack's `selectRowsFn`. Its three getters are this
function over three models: `getSelectedRowModel` is the core model,
`getFilteredSelectedRowModel` the filtered model, `getGroupedSelectedRowModel`
the sorted model. `deselectAllRows` is the `{ deselectAll: true }` option,
which only ever means "clear everything".

### Row pinning

```elm
pinRow : RowPinPosition -> Row row -> State -> State
pinRowWith : RowPinPosition -> PinRowOptions -> RowModel row -> Row row -> State -> State
setRowPinning : RowPinning -> State -> State
resetRowPinning : State -> State
getIsRowPinned : State -> Row row -> RowPinPosition
getRowPinnedIndex : Config row -> State -> PinnedRowsSource row -> Row row -> Int
getCanPinRow : Config row -> Row row -> Bool
isSomeRowsPinned : State -> Bool
isSomeRowsPinnedTop : State -> Bool
isSomeRowsPinnedBottom : State -> Bool
topRows : Config row -> State -> PinnedRowsSource row -> List (Row row)
bottomRows : Config row -> State -> PinnedRowsSource row -> List (Row row)
centerRows : State -> RowModel row -> List (Row row)
```

### New internal modules

```
src/Table/Internal/ColumnVisibility.elm
src/Table/Internal/ColumnOrdering.elm
src/Table/Internal/ColumnPinning.elm
src/Table/Internal/ColumnSizing.elm
src/Table/Internal/RowSelection.elm
src/Table/Internal/RowPinning.elm
```

Import order inside the package is `Column → ColumnVisibility →
ColumnPinning → Header → ColumnSizing`, with `ColumnOrdering` on top of
`ColumnPinning`. `ColumnVisibility` deliberately holds only the unordered
visible-cell list; the pin-ordered `visibleCells` lives in `ColumnPinning`,
which is what keeps the two modules acyclic.

## Contract changes

`Table.Internal.Types.Config`, four fields changed type. TanStack passes the
`Row` to each of these predicates (`row.id`, `row.index`), and several ported
cases depend on that, so the port follows:

| field | phase 2 | phase 5 |
| --- | --- | --- |
| `enableRowSelection` | `row -> Bool` | `Row row -> Bool` |
| `enableMultiRowSelection` | `Bool` | `Row row -> Bool` |
| `enableSubRowSelection` | `Bool` | `Row row -> Bool` |
| `enableRowPinning` | `Bool` | `Row row -> Bool` |

`Table.withRowSelection` therefore becomes
`(Row row -> Bool) -> Config row -> Config row`; the name and its place in
the phase 2 exposing list are unchanged. `always True` replaces the old
`\_ -> True` defaults, so `NoUnused.Parameters` stays quiet. Boolean options
are written `always False` at the call site.

New types in `Table.Internal.Types`: `ColumnPinPosition`, `ColumnRegion`,
`RowPinPosition`, `SubRowSelection`, `SelectOptions`, `PinRowOptions`,
`PinnedRowsSource`, `PinnedColumns`. No field was added to `Column`,
`Row`, or `State`; phase 2 had already provisioned `columnPinning`,
`columnSizing`, `columnVisibility`, `columnOrder`, `rowSelection`, and
`rowPinning`.

Three edits outside the new modules:

1. `Table.Internal.Column`: `orderColumns` now takes the `Config` and applies
   `Config.groupedColumnMode` after `State.columnOrder`, matching
   `table_getOrderColumnsFn`; `applyColumnOrder`, `orderGroupedColumns`, and
   `orderedLeafColumns` (TanStack's `table_getAllLeafColumns`) were added, and
   `visibleLeafColumns` now builds on `orderedLeafColumns`.
2. `Table.Internal.Row.getAllCells` calls `Column.orderedLeafColumns`, so
   cells follow the same order as headers and visible columns (the sizing
   file's "reorders visible leaf columns, headers, and cells in lockstep after
   setGrouping" case).
3. `Table.Internal.Header`: `visibleLeafColumnsToGroup` is now the pin
   partition (left, then center, then right) and `buildHeaderGroups` takes a
   header family that prefixes group and parent header ids
   (`start_1_identity_firstName`), which is what the per-region header group
   functions need.

## Semantic differences

1. **`visibleLeafColumns` is not pin-ordered.** TanStack's
   `table_getVisibleLeafColumns` keeps table order and only the header
   builder and `row_getVisibleCells` apply the pin partition. This port does
   the same: the partition lives in `Header.visibleLeafColumnsToGroup` and in
   `visibleCells`. `pinnedVisibleLeafColumns cfg state allColumnsRegion` is
   `visibleLeafColumns`, which is what
   `table_getPinnedVisibleLeafColumns(table)` with no position returns.
2. **Regions are a type, not an optional argument.** TanStack's
   `position?: 'start' | 'center' | 'end'` becomes `ColumnRegion` with
   `allColumnsRegion` standing in for the absent argument.
3. **`left` / `right`, not `start` / `end`.** Phase 2 named the state fields
   `left` and `right`; the API keeps those names. Only the header family in
   header ids uses TanStack's literal `start` / `center` / `end`, because the
   ported case asserts those id strings.
4. **The shift-click anchor is caller state.** `selectRange` takes the anchor
   row id; there is no `_lastSelectedRowId` and no
   `isRowRangeSelectionEvent`. `canSelectRange` exposes the guard so a caller
   can tell a range apart from a fallback toggle.
5. **Display order is the row model you pass.** `selectRange` walks
   `model.rows`, which is TanStack's `getRowsInDisplayOrder` for the default
   `paginateExpandedRows = True`. The `paginateExpandedRows = False` variant,
   which splices expanded descendants into the display order, is one of the
   pending-integration cases.
6. **`getRowPinnedIndex` and the pinned row lists take both row models.**
   `PinnedRowsSource` carries the pre-pagination model and the current page,
   because `keepPinnedRows` picks between them.
7. **No `position` field on rows or cells.** TanStack mutates
   `row.position = 'top'` and `cell.position = 'start'` onto the objects it
   returns; the lists here carry the same rows and cells unchanged, and the
   caller knows the region from the function it called.
8. **`resetX` means TanStack's `defaultState: true`.** There is no
   `table.initialState`, so restoring a remembered initial slice is a `setX`
   call.
9. **`column_getSize` clamping is written as `min (max minSize size) maxSize`**
   rather than Elm's `clamp`, so a column whose `minSize` exceeds its
   `maxSize` reports `maxSize`, exactly like TanStack.
10. **`getIsAllParentsExpanded` is re-implemented locally** in
    `RowPinning` (read straight off `State.expanded`), because
    `Table.Internal.Expanding` belongs to another phase. It is a private
    helper, not exposed.

## Biggest risk for the merge with phase 3

Ordering composition. Phase 5 moved the leaf-column ordering into
`Column.orderColumns` / `Column.orderedLeafColumns`, and every column, header,
and cell list now goes through it: `allColumns → columnOrder → groupedColumnMode
→ visibility → pin split`. Phase 3 owns `State.grouping` only indirectly (it is
phase 4's slice) but does touch the row-model pipeline that reads those column
lists, and phase 4 will add real group rows whose ids (`status:single`) the
selection and pinning functions look up by id. Two concrete failure modes to
check right after the merge:

1. If phase 3 or 4 adds its own column ordering for grouping, the grouped
   column will be moved to the front twice, or removed and then re-added.
   `orderGroupedColumns` is the single place that rule may live.
2. The ten pending-integration cases are the exact points where the merged
   pipeline meets phase 5. They are written against the public stage functions,
   so they should pass unchanged; if "includes grouped rows in display order"
   or "selects across client-side pages" fails, the disagreement is about what
   `RowModel.rows` means after grouping or pagination, not about selection.

A smaller merge risk: the phase 5 exposing entries sit between phase 2's and
the `-- Phase 3` marker because elm-format hoists comments to the end of the
list. If phase 3 appends its entries at the marker, the two blocks are
adjacent but distinct lines, and git should merge them cleanly; if it does
not, keeping both blocks and re-running `elm-format` is enough.
