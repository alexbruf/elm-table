# Documentation site

`docs-site/` is the documentation site for `viewengine/elm-table`, a static
site generated from Markdown by `docs-site/build.ts` (bun + `marked`) and
deployed to Cloudflare Pages.

**Deployed: <https://elm-table-docs.pages.dev>** (project `elm-table-docs`,
first deployment `92bd95d1`, 51 files).

It mirrors the TanStack Table docs site (`reference/tanstack-table/docs/`,
commit `36733a38`) in structure, page names, and section order, with every
page rewritten for the Elm API.

## Build

```
make -C docs-site dist      full build
make -C docs-site dev       skip the two elm make runs
make -C docs-site serve     build, then serve dist/ on :8099
make -C docs-site deploy    build, then deploy.sh
```

`make dist` runs, and fails on, five stages:

1. `elm make --docs=docs.json` in the repository root.
2. `elm make src/*.elm` in `docs-site/snippets/` (34 modules).
3. Markdown render, with `elm snippet=Module.elm#name` fences replaced by the
   named top-level declaration.
4. One generated page per exposed module from `docs.json`; fails if a `@docs`
   line names something `docs.json` does not expose, or if an exposed value
   appears in no `@docs` line.
5. Link check over every internal `href`; fails on a missing page or anchor.

Latest run:

```
docs.json regenerated
34 snippet modules compile
49 pages written to dist/
300 snippet blocks inlined from 294 declarations
reference Table: 394/394 entries
reference Table.Value: 4/4 entries
reference Table.SortFn: 12/12 entries
reference Table.FilterFn: 32/32 entries
reference Table.AggregationFn: 16/16 entries
reference total: 458/458 entries
1678 internal links checked, 0 broken
```

## Results

| Check | Result |
| --- | --- |
| `make -C docs-site dist` | passes end to end |
| Snippets | 34 Elm modules, 335 top-level declarations, 294 referenced by 300 fenced blocks; all compile against `../../src` |
| Generated reference | 458 of 458 `docs.json` entries rendered (394 + 4 + 12 + 32 + 16); the build fails if the two numbers ever differ |
| Link check | 1,678 internal links and anchors, 0 broken |
| Banned words | `docs-site/banned.sh` over `content/`, `dist/`, `shared/`, `README.md`: 0 hits |
| Browser check | Overview, Quick Start, Sorting guide, `Table` reference, Features API, and a 420px mobile viewport, all in Chrome against `dist/` and then against the deployed URL |
| Pages | 49 (43 hand-written Markdown, 5 generated module pages, 1 root redirect) |
| Content | 8,349 lines of Markdown |

## Page inventory

Every entry of TanStack's `docs/config.json` navigation is accounted for.
"Skipped" entries were named as out of scope in the task.

### Getting Started

| TanStack page | Our page | Status |
| --- | --- | --- |
| Overview | `overview` | ported |
| Installation | `installation` | ported |
| Devtools | — | skipped; no live table instance to inspect. Noted on `guide/features` |
| Agent Skills (TanStack Intent) | — | skipped |
| framework/react/quick-start | `quick-start` | ported, replaces all eleven per-framework quick starts |
| framework/react/guide/migrating | `migrating` | ported as "Migrating from TanStack": the renames and semantic differences from `PORT_NOTES.md` in TanStack's migrating-page style |
| framework/react/guide/use-legacy-table | — | skipped; v8 compatibility layer |
| (new) | `comparison` | new: comparison with `evancz/elm-sortable-table` |

### Core Guides

| TanStack page | Our page | Status |
| --- | --- | --- |
| guide/features | `guide/features` | ported |
| guide/data | `guide/data` | ported |
| guide/client-side-vs-server-side | `guide/client-side-vs-server-side` | ported; the `manual*` flags, `pageCount`, `rowCount` |
| guide/column-defs | `guide/column-defs` | ported |
| guide/tables ("Table Instance") | `guide/config-and-state` | ported and renamed: there is no instance, so the page is `Config row` + `State` + `initialState` |
| guide/row-models | `guide/row-models` | ported |
| guide/worker-row-models | — | skipped; experimental web-worker plugin |
| guide/rows | `guide/rows` | ported |
| guide/cells | `guide/cells` | ported |
| guide/header-groups | `guide/header-groups` | ported |
| guide/headers | `guide/headers` | ported |
| guide/columns | `guide/columns` | ported |
| guide/table-and-column-meta | — | merged into `guide/features` (one line: Elm's own types do that job) |
| guide/helpers ("Type Helpers") | — | merged into `guide/features` and `guide/column-defs` (one line each) |
| framework/react/guide/table-state | `guide/table-state` | ported |
| framework/react/guide/react-compiler | — | skipped |
| framework/react/guide/composable-tables | — | skipped; merged as one line into `guide/features` |
| framework/react/guide/table-context | — | skipped |
| framework/react/guide/flex-render | — | skipped; noted on `guide/features` and `guide/cells` |
| framework/react/guide/custom-features | — | skipped; noted on `guide/features` |
| (new) | `guide/values` | new: the `Value` union, `toString`, `toNumber`, `Null` semantics |

### Feature Guides

All under `framework/react/guide/`. Every one is ported.

| TanStack page | Our page | Status |
| --- | --- | --- |
| cell-selection | `guide/cell-selection` | ported |
| cell-spanning | `guide/cell-spanning` | ported |
| column-ordering | `guide/column-ordering` | ported |
| column-pinning | `guide/column-pinning` | ported |
| column-sizing | `guide/column-sizing` | ported |
| column-resizing | `guide/column-resizing` | ported as one page stating it is out of scope (sizing is state only) plus a compiling mouse-drag wiring that ends in `Table.setColumnSize` |
| column-visibility | `guide/column-visibility` | ported |
| column-filtering | `guide/column-filtering` | ported |
| global-filtering | `guide/global-filtering` | ported |
| fuzzy-filtering | `guide/fuzzy-filtering` | ported; `@tanstack/match-sorter-utils` replaced by a compiling subsequence matcher wired with `withCustomFilter`, pointing at the `filters-fuzzy` example |
| column-faceting | `guide/column-faceting` | ported as "Faceting" |
| aggregation | `guide/aggregation` | ported |
| grouping | `guide/grouping` | ported |
| expanding | `guide/expanding` | ported |
| pagination | `guide/pagination` | ported |
| row-pinning | `guide/row-pinning` | ported |
| row-selection | `guide/row-selection` | ported |
| sorting | `guide/sorting` | ported |
| virtualization | `guide/virtualization` | ported as one page pairing with `dominikmayer/elm-virtual-list` |

Each of the 17 feature guides with a matching example ends with an `<iframe>`
embed of `https://elm-table-examples.pages.dev/<slug>/`, as TanStack does.
`column-resizing` and `virtualization` link an example instead of embedding one.

### API Reference

| TanStack nav section | Our page | Status |
| --- | --- | --- |
| Core API Reference (`reference/index`) | `reference/module/Table` … `Table-AggregationFn` | ported, generated from `docs.json` |
| React API Reference | — | skipped; framework adapter |
| Table API Reference (24 entries) | `reference/table-api` | ported; every entry mapped, 8 React-only ones to `—` with a reason |
| Column API Reference (15) | `reference/column-api` | ported |
| Row API Reference (17) | `reference/row-api` | ported |
| Cell API Reference (5) | `reference/cell-api` | ported |
| Header API Reference (6) | `reference/header-api` | ported |
| Features API Reference (66) | `reference/features-api` | ported |
| Static Functions API Reference | — | skipped |
| Legacy API Reference | — | skipped |

The five generated module pages render every `@docs` section of each module
comment, in the module's own order, with each value's type signature and doc
comment, the way package.elm-lang.org does.

### Examples

| TanStack nav section | Our page | Status |
| --- | --- | --- |
| Basic Examples (8) | `examples` | ported; 4 of ours, the other 4 listed under "Not ported" with reasons |
| Feature Examples (26) | `examples` | ported; 24 of ours |
| Specialized Examples (12) | `examples` | 1 of ours (`realtime-trading`); the rest listed as not ported |
| Component Library Examples (16) | `examples` | listed as not ported (React component libraries) |

## Snippets

Every complete Elm declaration shown in the docs comes from
`docs-site/snippets/`, an Elm application whose `source-directories` are
`["src", "../../src"]`, so the snippets compile against the working tree.

- 34 snippet modules plus `Shared/People.elm`, the fixture they share.
- 335 extractable top-level declarations, 294 of them referenced by 300 fenced
  blocks (`elm snippet=Module.elm#name`).
- The 41 unreferenced declarations are each module's supporting `config`,
  `Model`, or `Msg`, kept so the module reads as a complete example.
- `elm make src/*.elm --output=/dev/null` in `snippets/`: exit 0.
- The build fails if the project does not compile or if a referenced
  declaration is missing.

Plain ` ```elm ` fences with no `snippet=` are used only for fragments that
cannot compile alone: bare type signatures, `State` record literals shown as
data, and `type alias` illustrations.

## Package doc-comment problems found

For the orchestrator to fix in `src/`. None of these break the build; they all
render on the generated reference pages.

1. **Stale port-plan text.** `Table.facetedUniqueValues` and
   `Table.facetedMinMax` both end their doc comment with "The body lands in
   phase 3." (`src/Table.elm` around lines 1423 and 1431). That is leftover
   planning text and is published verbatim on `/reference/module/Table`.
   Both also omit which row model to pass, which the sibling
   `facetedRowModel` comment does explain.

2. **`Config` and `State` render as empty aliases.** `Table.elm` exposes them
   as `type alias Config row = Table.Internal.Types.Config row`, so `docs.json`
   records only that reference. The generated module page therefore shows
   `type alias Config row = Table.Config row` and not one field. A reader
   looking up `manualSorting`, `pageCount`, or `State.pagination` in the
   reference finds nothing; the option tables on `guide/config-and-state` are
   currently the only place those fields are documented. Inlining the record
   types in `Table.elm`, or listing the fields in the two alias doc comments,
   would fix it.

3. **The `RowModel`-taking transitions still do not name their stage.** The
   doc comments for `toggleSort`, `setColumnFilter`, and `toggleExpanded` say
   *why* they need a row model but never which stage's model to pass. This is
   the open item from `reports/phase-7.md`. `setColumnFilters` has the same
   signature and the same gap, and is not on that list.

4. **`resetPageIndex` takes a `Config row`; every other `resetX` takes only
   `State`.** The odd signature in that family. Worth a line in its doc comment
   saying why.

5. **No `resetCellSelection`.** `cellSelection` is the only state slice without
   a `resetX`. `clearCellSelection` fills the role; its doc comment does not say
   so.

6. **Thin doc comments** (accurate, just short of a cross-reference):
   `maxSubRowDepth` does not say it is TanStack's `table.getMaxSubRowDepth()`;
   `aggregationValueOf` does not mention that it deduplicates its row list
   while `aggregationValue` does not; `getIsSomeRowsExpanded` taking only
   `State`, unlike its `getIsAllRowsExpanded` sibling, is unremarked;
   `pinRow` does not say that the leaf and parent options are unavailable in
   that form.

7. **Missing `Config` builders.** `enableMultiRowSelection`,
   `enableSubRowSelection`, `enableRowPinning`, `keepPinnedRows`,
   `enableColumnPinning`, `enableHiding`, and `groupedColumnMode` have no
   `with*` builder and can only be set by record update, while their siblings
   do. The pages say so explicitly, but it is an asymmetry a reader notices.

Every exposed value has a non-empty doc comment; nothing is undocumented.

## Report discrepancies found while writing

Corrections made against the phase reports, with `docs.json` treated as the
source of truth:

- `reports/phase-5.md` lists `canSelectRange : Config row -> RowModel row ->
  String -> Row row -> Bool`. The real signature has a `State` argument:
  `Config row -> State -> RowModel row -> String -> Row row -> Bool`.
- `reports/phase-4.md` semantic difference 11 says the expanded row model
  checks `manualPagination`. `Table.expandedRowModel` also short-circuits on
  `Config.manualExpanding`.
- `Table.allColumns` is the flattened tree, so it maps to TanStack's
  `getAllFlatColumns()`, not `getAllColumns()`. The counterpart to
  `getAllColumns()` is the `columns` field of `Config`.
- `Table.rowsInDisplayOrder` does not apply row pinning; it re-inserts
  expanded descendants when `paginateExpandedRows` is `False`. Row pinning is
  `topRows` / `centerRows` / `bottomRows`.

## Built-in function name mapping

Checked in both directions against
`reference/tanstack-table/packages/table-core/src/features/*/`:

- `sortFns` 6 of 6 match name for name.
- `aggregationFns` 11 of 11 match name for name.
- `filterFns` 18 of 18 match. TanStack also exports `filterFn_greaterThan`,
  `filterFn_greaterThanOrEqualTo`, `filterFn_lessThan`, and
  `filterFn_lessThanOrEqualTo` without putting them in its `filterFns`
  registry; all four exist here as ordinary `Table.FilterFn` values.

No Elm-only and no TanStack-only built-in.
