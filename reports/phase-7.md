# Phase 7: package hygiene

`make check` is green: `elm-format --validate src tests` (and `examples`,
checked separately), `elm-review`, `elm-test` 903 tests (901 from phase 6
plus 2 re-homed in this phase). `elm make --docs=docs.json` succeeds.

## What changed

1. **`README.md` rewritten** as the package front page: a short intro
   (headless, pure, user-owned state, the six-stage pipeline order), an
   install line, one full example, an API map, an 8-bullet "Differences from
   TanStack" section, the `Demo: (see PORT_NOTES.md)` placeholder left for
   the orchestrator, and the Development section (`make check`, `make test`,
   `make docs`, `make bench`, `make demo`) with the existing env-file note
   for `make deploy` kept verbatim.
2. **`examples/` added**: `examples/elm.json` (application,
   `source-directories: ["src", "../src"]`, deps `elm/core` 1.0.5,
   `elm/html` 1.0.0, `elm/browser` 1.0.2, `elm/time` 1.0.0, `elm/json`
   1.1.3, plus the `elm/url`/`elm/virtual-dom` indirect deps `elm/browser`
   pulls in) and `examples/src/Main.elm`. `elm make src/Main.elm
   --output=/dev/null` succeeds; it is `elm reactor`-runnable. The data is
   20 inline `Person` records across 4 departments, written directly in the
   file (not copied from `tests/Fixtures.elm`).
3. **`Makefile`**: appended an `example` target
   (`cd examples && elm make src/Main.elm --output=/dev/null`) and added
   `example` to `.PHONY`. No existing target's recipe changed.
4. **`src/Table.elm` module doc reorganized.** The four `# Phase N` headings
   became the ten headings the task specified (`# Columns and headers`,
   `# Row models`, `# Filtering`, `# Sorting`, `# Grouping and aggregation`,
   `# Expanding`, `# Row selection`, `# Pinning`,
   `# Column ordering, visibility and sizing`, plus `# Pagination` folded
   into the flow after `# Sorting`), each with a one-line intro. Every
   `@docs` entry from the original four sections is still present exactly
   once; none was renamed. Two mixed-concern blocks were split by moving
   whole `@docs` lines (not reordering names inside a line): the old
   "Faceted row model" section merged into "Faceting" under `# Row models`,
   and the old "Phase 5 types" grab-bag (column-pinning, row-pinning, and
   row-selection types in one block) split into a "Selection types"
   subsection under `# Row selection` and a "Pinning types" subsection under
   `# Pinning`. The `-- Phase 2` / `-- Phase 6` comment markers inside the
   `exposing (...)` list were **not** touched, moved, or renamed.
   - **Side effect worth flagging**: `elm-format` reorders the items inside
     an `exposing (...)` list to match the order names first appear via
     `@docs` in the module doc. Reorganizing the doc therefore reordered the
     items *within* the phase 2–5 block of the exposing list (visible in
     `git diff src/Table.elm`), even though the two `-- Phase N` marker
     lines themselves stayed exactly where they were, at the top and just
     before the closing `)`. Since phase 6/8 agents only append lines after
     `-- Phase 6`, this should merge cleanly, but flagging it in case a
     3-way merge disagrees.
   - Renaming the "## Row selection" subheading to "## Selection state" was
     required: `elm-review`'s `Docs.ReviewLinksAndSections` rejects two
     headings (any level) that produce the same anchor id, and the new
     top-level `# Row selection` heading collided with the old subheading of
     the same name.
5. **`review/src/ReviewConfig.elm`**: `Simplify.rule Simplify.defaults` is
   now `Simplify.rule (Simplify.defaults |> Simplify.expectNaN)`
   (`jfmengels/elm-review-simplify` 2.1.15's actual function name, confirmed
   from the installed package source). The five `sqrt -1` NaN
   literals — `src/Table/Value.elm`, `src/Table/FilterFn.elm`,
   `tests/FilterFnTest.elm`, `tests/SortFnTest.elm`,
   `tests/AggregationFnTest.elm` — are now `0 / 0`. None of the five sites
   had an inline comment explaining the `sqrt -1` workaround, so there was
   nothing to reword there; `reports/phase-1.md` (point 9 of its "Semantic
   differences" list) and `PORT_NOTES.md` line 168 still describe the old
   convention as a historical record of that phase's decision — both are
   past-phase artifacts I did not edit (`PORT_NOTES.md` is explicitly the
   orchestrator's to consolidate; `reports/phase-1.md` is that phase's own
   report). The orchestrator may want a one-line update to `PORT_NOTES.md`
   noting the phase 7 change.

## Re-homed cases (task 5)

`reports/phase-2.md` excluded cases 37 and 38
(`coreColumnsFeature.utils`: "should render accessor keys as the default
header" and "should stringify values in the default cell renderer") are now
ported as data-only assertions in `tests/CoreColumnsTest.elm`, inside the
existing `table_getDefaultColumnDef` describe block:

- **37** checks that a column built without `withHeader` reports
  `columnHeader == Nothing` and that its `columnId` is the string a caller
  would fall back to (exactly what the README/example's `viewHeaderCell`
  does with `Maybe.withDefault columnId (Table.columnHeader col)`). Note the
  premise in the task ("if `columnHeader` defaults to the column id") does
  not literally hold — `columnHeader` returns `Nothing` by default, not
  `Just (columnId col)` — so the test asserts the actual data (`Nothing` +
  the id) with a comment explaining that falling back to the id is a view
  concern, not something `columnHeader` itself does.
- **38** checks that `Table.Value.toString` on `Table.getValue` for a
  `Value.Number 42` cell gives `"42"`, using a tiny local numeric config and
  a one-row `coreRowModelFromList` so the assertion goes through the real
  `getValue` path rather than calling `Value.toString` in isolation.

Items 39–42 (`row_renderValue` / `cell_renderValue`, 4 cases) stay excluded:
`Config` has no `renderFallbackValue` field, and there is no render layer to
attach the render half to, exactly as `reports/phase-2.md` already
anticipated. Confirmed by reading the reference vitest file directly
(`reference/tanstack-table/packages/table-core/tests/unit/core/rows/coreRowsFeature.utils.test.ts`,
`row_renderValue` describe block) — `renderFallbackValue` is a table-level
option this port never added, so `row_renderValue`'s only Elm-expressible
half (`getValue`) is already covered by the many other `getValue` cases in
`tests/CoreRowsTest.elm`.

## Publish dry-run checks

| Check | Result |
| --- | --- |
| `elm make --docs=docs.json` | succeeds |
| `elm-format --validate src tests examples` | clean |
| `elm-review` | no errors |
| `elm-test` | 903 passed, 0 failed |
| `elm bump` | not applicable — this is the first release at `1.0.0`, there is no prior published version to diff against |
| `elm.json` `exposed-modules` | `Table`, `Table.Value`, `Table.SortFn`, `Table.FilterFn`, `Table.AggregationFn` — matches the five modules under `src/` that have doc comments and are meant to be public |
| `elm.json` `summary` | 74 characters, under the 80-character limit |
| `elm.json` `license` | `MIT` |
| `grep -rn "Debug\." src` | no matches |

## API awkwardness noticed while writing the example

- **`Table.rows` takes an `Array row`, not a `List row`.** The README's
  `people` is a plain `List Person` (natural for ~20 literal records), which
  meant reaching for `Table.rowsFromList` instead of the more prominently
  documented `Table.rows`. A reader coming from the "Types" doc, where
  `rows` is listed first, will likely hit this same type error before
  finding `rowsFromList`. Worth considering whether `rows` should take a
  `List` and a separate `rowsFromArray` exist instead, since every other
  pipeline-adjacent helper (`coreRowModelFromList`, `rowsFromList`) is
  already list-first.
- **Three transitions need a `RowModel row` argument that isn't the one a
  caller is holding.** `toggleSort`, `setColumnFilter`, and
  `toggleExpanded` each take a `RowModel row` for auto-detection/expand-id
  materialization, but the "correct" stage per their own doc comments
  differs per function (pre-sort for `toggleSort`, core for
  `setColumnFilter`, pre-expand/sorted for `toggleExpanded`). The example
  sidesteps this by recomputing the full `Table.rows` pipeline result once
  per message and passing that everywhere, which is correct for this
  dataset (no manual flags, no multi-level grouping) but not obviously
  correct in general — a caller with `manualSorting` or a large dataset has
  to know which intermediate stage each function actually wants. A short
  "which row model do I pass here" table in the module doc, or accepting
  `Config row -> State -> Array row -> ...` directly for the common case,
  would remove a real "which one do I have lying around" question.
- **No exposed way to ask "does this row have an aggregated value for this
  column?" directly.** The example uses
  `Dict.member columnId (Table.rowAggregatedValues row)` to decide whether a
  group-row cell should render the aggregate or stay blank. That works, but
  `cellIsAggregated` (which exists) needs a `RowModel row` and a `State`
  that `cellIsGrouped`/`cellIsPlaceholder` don't need, so it wasn't the
  obvious first choice reading the doc top to bottom; a
  `rowHasAggregatedValue : Row row -> String -> Bool` alongside
  `rowAggregatedValues` would match the shape of `cellIsGrouped` more
  closely.
- **`columnHeader` returning `Maybe String` instead of defaulting to the
  column id** (see the re-homed test above) means every header-rendering
  caller repeats the same `Maybe.withDefault (columnId col) (columnHeader
  col)` one-liner. That's a deliberate headless design choice (no default
  header text baked into data), but it is exactly the kind of one-liner
  that shows up in every consumer's view code, so a documented convention
  or a small helper might be worth it before 1.0.0 locks the API.

## Not touched

`demo/` (phase 8, another worktree), `PORT_NOTES.md` (orchestrator's to
consolidate), the `-- Phase N` markers inside `Table.elm`'s `exposing (...)`
list, and `src/Table/Internal/CellSelection.elm` / phase 6 work.
