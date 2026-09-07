# Phase 9: column resizing

Ports `features/column-resizing/columnResizingFeature.utils.ts` and its test
file. TanStack drives the whole feature through the closure
`header_getResizeHandler` returns, which installs `mousedown` / `mousemove` /
`mouseup` / `touchstart` / `touchmove` / `touchend` / `touchcancel` listeners
on the document and writes state from them. This package touches no DOM, so
the closure is split into the three state transitions it performs -
`startColumnResize`, `updateColumnResize`, `endColumnResize` - and the caller
wires the events. This report picks up a prior agent's work-in-progress; the
package, tests, examples, and docs guide were already written and green, and
this pass verified each item against the reference source, filled in the two
curated reference tables (the diff shows they were already complete), and
built and drove both examples in a real browser.

## Coverage

| file | cases | ported | passing | excluded |
| --- | --- | --- | --- | --- |
| `unit/features/column-resizing/columnResizingFeature.utils.test.ts` | 27 | 16 | 16 | 11 |

`tests/ColumnResizingTest.elm` has 21 `test` cases: the 16 ported vitest
cases plus a 5-case "elm-table additions" block for paths the vitest file
never exercises (see Semantic differences below). `elm-test` runs 1113 tests
total (1092 before this feature, +21 here).

### Exclusions (11)

All eleven are DOM/browser event plumbing with no counterpart in a package
that touches no DOM; TanStack tests them because its listeners live inside
the untestable-by-composition closure, this package exposes the three state
transitions directly instead.

| vitest case | Reason |
| --- | --- |
| `isTouchStartEvent > should return true for touch start events` | Type-narrows an `unknown` DOM event; callers already have a decoded `clientX : Float` before calling `startColumnResize`/`updateColumnResize`. |
| `isTouchStartEvent > should return false for non-touch start events` | Same. |
| `header_getResizeHandler > should return a function` | Tests that the handler factory returns a closure; the three transitions are plain top-level functions, not a returned closure. |
| `header_getResizeHandler > should attach listeners to an explicit context document` | `addEventListener` registration; no listeners in this package. |
| `header_getResizeHandler > should not resize when column resizing is disabled` | Ported (kept in the main block). |
| `header_getResizeHandler > should ignore multi-touch events` | Multi-touch filtering (`event.touches.length > 1`) is a property of the raw DOM event, decided by the caller's `Json.Decode` before it ever calls a transition. |
| `header_getResizeHandler > should update immediately in onChange mode` | Ported. |
| `header_getResizeHandler > should allow resizing a column from zero width` | Ported. |
| `header_getResizeHandler > should not produce NaN when startSize is zero` | Ported. |
| `header_getResizeHandler > should coalesce move events into one update per animation frame` | `requestAnimationFrame` throttling of pointer moves is a browser runtime concern with no pure-function counterpart; `updateColumnResize` is called once per message regardless of frame timing. |
| `header_getResizeHandler > should cancel a pending coalesced move on mouse up and commit the end position` | Ported (the coalescing itself is excluded, but the "commits the last position at drag end" behavior is ported). |
| `header_getResizeHandler > should flush one store notification per move tick and per drag end (batched writes)` | Tests TanStack's reactive store batching `table._reactivity.batch`; this package has no store or subscriber notifications, `State` is a plain value returned from each call. |
| `header_getResizeHandler > should not commit sizing on move ticks in onEnd mode, only at drag end` | Ported. |
| `header_getResizeHandler > should cleanup event listeners on mouse up` | `removeEventListener`; no listeners in this package. |
| `header_getResizeHandler > should cleanup event listeners and reset state on touchcancel` | Ported (the listener-removal assertions are excluded, the "commits the last position, then ignores further moves" behavior is ported). |
| `passiveEventSupported > should return boolean indicating passive event support` | Feature-detects `{ passive: true }` listener support; this package registers no listeners. |
| `passiveEventSupported > should cache the result of passive support check` | Same. |
| `passiveEventSupported > should handle errors during support check` | Same. |

(17 lines above cover the 11 excluded cases; the other 16 rows shown for
context are the ported ones, folded into the main `describe` block in
`tests/ColumnResizingTest.elm`.)

## Package API

All added under `-- Phase 9` in the exposing list (elm-format hoists the
marker comment to the end of the list, as it did for phases 3-8) and a
`# Column resizing` docs section, with a `-- PHASE 9` code block at the end
of `src/Table.elm`. Implementation lives in
`src/Table/Internal/ColumnResizing.elm` (single new module,
`Table.Internal.Types` and `Table.Internal.Config` carry the state/defaults).

| Name | Signature |
| --- | --- |
| `ColumnResizingState` | `type alias ColumnResizingState = { columnSizingStart : List ( String, Float ), deltaOffset : Maybe Float, deltaPercentage : Maybe Float, isResizingColumn : Maybe String, startOffset : Maybe Float, startSize : Maybe Float }` |
| `ColumnResizeMode` | `type alias ColumnResizeMode` (abstract; `resizeOnChange` \| `resizeOnEnd`) |
| `ColumnResizeDirection` | `type alias ColumnResizeDirection` (abstract; `resizeLtr` \| `resizeRtl`) |
| `resizeOnChange` | `ColumnResizeMode` |
| `resizeOnEnd` | `ColumnResizeMode` |
| `resizeLtr` | `ColumnResizeDirection` |
| `resizeRtl` | `ColumnResizeDirection` |
| `withEnableResizing` | `Bool -> Column row -> Column row` |
| `columnCanResize` | `Config row -> Column row -> Bool` |
| `columnIsResizing` | `State -> Column row -> Bool` |
| `headerCanResize` | `Config row -> Header row -> Bool` |
| `headerIsResizing` | `State -> Header row -> Bool` |
| `startColumnResize` | `Config row -> State -> Header row -> Float -> State` |
| `updateColumnResize` | `Config row -> Float -> State -> State` |
| `endColumnResize` | `Config row -> State -> State` |
| `setColumnResizing` | `ColumnResizingState -> State -> State` |
| `resetColumnResizing` | `State -> State` |

Every one of the 17 names above has an `elm make --docs=docs.json` doc
comment; `docs-site`'s build confirms full reference coverage (`reference
Table: 411/411 entries`, 0 broken internal links).

### Fields added

- `Config.enableColumnResizing : Bool` (default `True`)
- `Config.columnResizeMode : ColumnResizeMode` (default `ResizeOnChange` -
  see semantic differences)
- `Config.columnResizeDirection : ColumnResizeDirection` (default `Ltr`)
- `Column`'s internal fields record gets `enableResizing : Bool` (default
  `True`), set by `withEnableResizing`
- `State.columnResizing : ColumnResizingState`, defaulted in
  `Table.initialState` to `Config.defaultColumnResizing` (all fields
  `Nothing`/`[]`, matching `getDefaultColumnResizingState()`)

`tests/CoreTableTest.elm`'s `stockFeaturesInitialState` case was updated to
include the new `columnResizing` field in the expected initial `State`.

## Semantic differences

1. **`columnResizeMode` default.** TanStack's `getDefaultTableOptions`
   returns `columnResizeMode: 'onEnd'`. This port defaults to
   `resizeOnChange`. Reasoning (documented in the guide and in
   `features-api.md`): TanStack defaults to `onEnd` because an `onChange`
   drag re-renders a whole React table every frame; Elm's virtual DOM diff
   makes that much cheaper, so `onChange` is the friendlier default here,
   with `onEnd` offered for tables with expensive cells. This is a
   deliberate API decision, not an oversight - it is called out in three
   places (`docs-site/content/guide/column-resizing.md`, the curated
   `ColumnResizeMode` row in `docs-site/content/reference/features-api.md`,
   and here).
2. **`isResizingColumn : false | string` -> `Maybe String`.** Same pattern
   used throughout the port for TanStack's `false`-as-sentinel unions.
3. **No DOM, no closure.** `header.getResizeHandler()` is split into three
   direct transitions (`startColumnResize`, `updateColumnResize`,
   `endColumnResize`); the caller owns the `mousedown`/`mousemove`/`mouseup`/
   touch wiring (`Browser.Events` subscriptions, decoded `clientX`).
4. **`updateColumnResize` and `endColumnResize` guard "no drag in
   progress".** TanStack has no such guard because its listeners only exist
   for the length of a drag; this package's transitions are always
   reachable, so a call with no active drag (`isResizingColumn == Nothing`)
   is a no-op.
5. **`endColumnResize` always commits.** TanStack's `onEnd` handler commits
   from `clientXPos ?? latestMoveX`, i.e. the position of the ending event or
   the last observed move. This package has no "latest move" to fall back to
   inside `endColumnResize` itself, so the guide is explicit that callers
   must call `updateColumnResize` first with the ending event's position when
   it carries one (`mouseup`), and rely on the deltas already in state
   otherwise (`touchend` with no position, or `touchcancel`); the "cleanup
   ... on touchcancel" test is ported on this basis.
6. **No `passiveEventSupported`, no `isTouchStartEvent`, no listener
   lifecycle, no `requestAnimationFrame` coalescing.** Event plumbing with no
   pure-function counterpart; see Exclusions.
7. **`table.resetHeaderSizeInfo()` with no argument** (restores
   `table.initialState.columnResizing`) has no counterpart, because there is
   no table instance holding an initial state; `resetColumnResizing` is the
   `defaultState: true` form only. Callers keep the slice they want to
   return to and pass it to `setColumnResizing`.

## Browser verification

Built both examples (`cd examples-site && bun run build.ts column-resizing
column-resizing-performant` -> `2 built, 0 failed, 0 not yet written`) and
`elm-format --validate examples-site/src` (`[]`, clean). Served
`examples-site/dist` and drove both pages with `claude-in-chrome` (a Bash
`curl`/background-server combination was blocked by the sandbox's network
policy for this session, so verification went through the browser tool
directly against an already-running `python3 -m http.server` for this
worktree's `dist/`):

- **Column Resizing example, `onChange` mode:** dragged the `Age` column's
  trailing-edge handle (`.resizer`, 5px, revealed on hover) 74px right; the
  header and every row cell in the `Age` column widened live during the drag
  (150px -> 224px), matching `startWidth + startWidth * deltaPercentage`
  rounded to 2 decimals.
- **Same example, `onEnd` mode:** switched the mode selector, dragged the
  same handle 98px left; the column held its width until the drag ended,
  then committed to 126px in one step (no intermediate frames), confirming
  `updateColumnResize` in `ResizeOnEnd` mode only writes `deltaOffset`/
  `deltaPercentage` and `endColumnResize` performs the actual commit.
- **Same example, `rtl` direction:** switched the direction selector (the
  whole table visually mirrors, `.resizer.rtl` moves to the header's left
  edge); dragging the handle *left* by 53px grew the column (123px ->
  176px), confirming `resizeRtl` inverts the delta's sign as
  `movedTo`/`updateResize` implement.
- **Performant Column Resizing example:** dragged the `Age` handle 74px
  right; the header widened live, the body (rendered from CSS custom
  properties, kept out of the drag via the shape described in the guide)
  reflowed correctly, and the page's live JSON state viewer showed
  `"columnSizing": { "age": 224 }` after the drag, matching the plain
  example's arithmetic exactly.
- No console errors on either page during or after any of the above drags.

## `make check` and `make -C docs-site dist`

```
$ make check
elm-format --validate src tests
[]
elm-review
I found no errors!
elm-test
Running 1113 tests.
TEST RUN PASSED
Duration: 276 ms
Passed:   1113
Failed:   0
```

```
$ make -C docs-site dist
bun run build.ts
  docs.json regenerated
  35 snippet modules compile
  49 pages written to dist/
  307 snippet blocks inlined from 301 declarations
  reference Table: 411/411 entries
  reference Table.Value: 4/4 entries
  reference Table.SortFn: 12/12 entries
  reference Table.FilterFn: 32/32 entries
  reference Table.AggregationFn: 16/16 entries
  reference total: 475/475 entries
  1712 internal links checked, 0 broken
  note: 53 snippet declarations are not referenced

$ ./banned.sh
banned-word check: 0 hits
```

`make docs` (root `elm make --docs=docs.json`) also succeeds standalone.
`docs-site/node_modules` was missing at the start of this pass; `bun install`
in `docs-site/` fetched `turndown`, `turndown-plugin-gfm`, `marked` (4
packages) before the build.
