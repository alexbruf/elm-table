# Phase 8: usable demo

`demo/` is a standalone `Browser.element` application with its own
`elm.json` (`type: application`, `source-directories: ["src", "../src"]`). It
renders a 5,000 row keyword report generated in the browser from one integer
seed, with every feature wired to the package's `State`.

## Deployed URL

<https://elm-table-demo.pages.dev>

Cloudflare Pages project `elm-table-demo`, production branch `main`. The
deployment behind that hostname is `https://ecf7242f.elm-table-demo.pages.dev`.

## Build

```
make demo                 # root: make -C demo dist
make -C demo dev          # unoptimised build, same dist/ layout
make deploy               # root: make -C demo deploy -> demo/deploy.sh
make -C demo clean
```

`demo/dist` is `elm.js` plus `index.html`. The `dist` target runs

```
elm make src/Main.elm --optimize --output=dist/elm.js
bunx terser dist/elm.js --compress 'pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe' --mangle --output dist/elm.js
cp index.html dist/index.html
```

`bunx terser` was available offline, so no fallback was needed. The minified
bundle is 73 KB; `index.html` is 7 KB with the whole stylesheet inlined in a
`<style>` block, so the page is two requests.

`demo/deploy.sh` reads `CLOUDFLARE_ACCOUNT_ID` from the environment, falling
back to `set -a; . ../.env; set +a` inside the script (no shell command names
the env file), creates the Pages project when it is missing, and runs
`wrangler pages deploy dist --project-name elm-table-demo --branch main
--commit-dirty=true`.

## Modules

```
demo/src/Data.elm     the row type, the intent enum, the seeded generator
demo/src/Report.elm   Model, Msg, the ten columns, filter-state readers, formatting
demo/src/Timing.elm   the measured pipeline chain and the pure first-frame run
demo/src/Main.elm     init, update, the message-to-State mapping
demo/src/View.elm     the page
demo/index.html       template plus the inlined stylesheet
demo/banned.sh        the banned-lexicon check
```

The dataset is `Random.step (Random.list 5000 …) (Random.initialSeed seed)`
over 40 clusters, 10 modifiers and 15 tails, with a weighted intent, a
long-tail volume (`20 + n²/42`, so 20 to about 24,000), a position, a previous
position and the derived change, a URL, a crawl date inside the 90 days before
`Date.now()` (passed in as a flag), and 0 to 3 query variants per row.
`Table.withSubRows` reads the variants; the seed input plus **Regenerate**
rebuilds the array.

## Reviewer script

Run against the deployed URL in Chrome at 1500x2000, one interaction per step,
reading the footer after each. Every number is what the footer showed.

| step | action | rows after | core | filtered | grouped | sorted | expanded | paginated | total |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | first load | 5,000 | 32 | 0 | 1 | 0 | 1 | 0 | **34 ms** |
| 1 | intent = Commercial | 1,391 | 16 | 14 | 1 | 0 | 0 | 0 | **31 ms** |
| 2 | group by cluster | 40 | 16 | 10 | 17 | 0 | 0 | 2 | **45 ms** |
| 3 | sort by volume, descending | 40 | 36 | 12 | 10 | 5 | 0 | 2 | **65 ms** |
| 4 | expand the top group | 84 | 11 | 8 | 8 | 4 | 0 | 1 | **32 ms** |
| 5 | select three rows | 84 | 18 | 5 | 8 | 4 | 0 | 0 | **35 ms** |
| 6 | page size 50 | 84 | 14 | 10 | 8 | 4 | 0 | 0 | **36 ms** |

Slowest interaction end to end: **65 ms**, against the 200 ms budget. The
whole pipeline re-runs on every state change, so `core` (the 5,000 row core
model, 11 to 36 ms) is present in every number even when only the page size
moved.

Results at the end of the script: volume descending puts `icon library` first
with a summed volume of 403,936, a mean difficulty of 52.8, a mean position of
50.4 and a mean change of +0.8 across its 65 leaf rows; the header checkbox
and the group row's checkbox both render indeterminate; the pager reads
`Rows 1–50 of 84`, `Page 1 of 2`, `7 selected`.

`7 selected`, not `3`, is correct and is worth knowing before anyone files it
as a bug: `Config.enableSubRowSelection` defaults to `True`, so selecting a
parent row also writes its variants into `State.rowSelection`, and the readout
is `List.length (Table.selectedRowIds state)` as the brief asked. Two of the
three rows picked had two variants between them.

Also exercised by hand on the deployed build, outside the script:

- global search (`setGlobalFilter`): `backlink` gives 140 rows
- keyword text filter (`includesString`): `seo audit` gives 122 rows
- numeric ranges (`inNumberRange`): volume min 20,000 gives 423 rows, adding
  position 1 to 10 gives 40
- shift-click multi-sort: intent ascending then volume descending shows the
  `1` and `2` index badges from `getSortIndex`, and the badges only appear
  when more than one column is sorted
- column visibility (`toggleColumnVisibility`): hiding URL and Previous drops
  both from the header, the filter row and every body row
- pin left (`pinColumn pinnedLeft`): the keyword column and the select column
  stay put while the rest of the table scrolls under them
- sub-row expansion: expanding `self hosted website builder for mac` inserts
  `website builder download` with its own volume (41) and position (73),
  indented by `rowDepth`
- pagination: Next moves to `Rows 26–50 of 5,000`, Previous comes back;
  Previous is disabled on page 1
- Regenerate with seed 42 rebuilds the dataset and the subtitle

### Date range, verified off-browser

The date range filter is an `input type="date"` pair, and neither the
browser automation tool's `fill` nor its synthetic key events could drive Chrome's
date segments, so this one feature was verified by compiling a throwaway
`Platform.worker` against the demo's own `Report.config` and `Data.generate`
and running it under Node (the module was deleted afterwards):

```
unfiltered 5000 | blank endpoints 5000 | filters left 0 | august 1752 | from august 2230
```

That is: both endpoints blank leaves zero filters in `State.columnFilters`
(`rangeAutoRemove` drops it), `2026-08-01` to `2026-08-31` keeps 1,752 rows,
and an open upper bound from `2026-08-01` keeps 2,230. Against a 90 day spread
over 5,000 rows those are the expected counts. The filter value the demo
writes is `Value.List [ Date a, Date b ]` with `Value.Null` for a blank
endpoint, and the upper endpoint is the last millisecond of the chosen day so
the range covers it.

## Timing method

`Timing.measure` chains `Time.now` around each stage:

```elm
Time.now |> Task.andThen (\t0 ->
    let core = Table.coreRowModel config state data in
    clockAfter (sizeOf core) |> Task.andThen (\t1 -> …))
```

`clockAfter n = Task.succeed n |> Task.andThen (\_ -> Time.now)`. The argument
matters: `--optimize` plus terser's `pure_funcs=[A2…A9]` makes every wrapped
application removable and movable, so a stage whose only use is in the record
built at the end of the chain could be sunk past the clock read that is
supposed to end it. Passing `List.length model.rows + List.length
model.flatRows` into `Task.succeed` in the same scope pins the stage in front
of its own clock read.

`update` stores the six row models and the six timings in the model and `view`
only reads them, so no stage runs during rendering, and intermediate updates
cannot re-run the pipeline from `view`. `init` fills the model with
`Timing.run` (the same six stages, unmeasured) so the first paint is the real
table, then fires the measured chain.

`Time.now` is millisecond resolution, so a stage under a millisecond reads
`0 ms`. That is why `expanded` and `paginated` are usually 0.

## Package bugs and gaps

**None.** Every feature in the brief was expressed with the exposed API, and
nothing had to be computed outside the package or faked. Five notes for the
record, all behaviour rather than defects:

1. `Table.selectedRowIds : State -> List String` returns the raw selection
   set, which with the default `enableSubRowSelection = True` includes the
   sub-rows a parent selection propagated to. A caller that wants "how many
   rows did the user click" wants `selectedRowModel` over the pre-pagination
   model instead. Both are exposed; the demo uses `selectedRowIds` as the
   brief specified.
2. `Table.getRowCount cfg model` is `List.length model.rows`, so it has to be
   handed the pre-pagination (expanded) model, not the paginated one. Same for
   `getPageCount` and `getCanNextPage`. That matches TanStack, but the type
   `Config row -> RowModel row -> Int` does not say which model, and passing
   the paginated one silently gives a page count of 1.
3. `Config.getSubRows : row -> List row` forces sub-rows to have the row type.
   The demo's `Variant` is a smaller record, so `Data.subRows` maps each
   variant into a `Keyword` with an empty `variants` list. Fine, but worth a
   line in the README example, since it is the first thing a user with a
   nested-but-differently-shaped dataset hits.
4. `SortDir` is abstract, so the view compares with `dir == Table.sortAsc`.
   That works (`==` on a custom type), and it is the same shape as `Expanded`
   and `SortUndefined`, so no change is being asked for; it is just the one
   place the demo has to know that equality is the intended reading.
5. `leftHeaderGroups` over an empty pinned region returns an empty list, so
   `leftHeaderGroups ++ centerHeaderGroups` is the whole header row whether or
   not anything is pinned, and `leftVisibleCells ++ centerVisibleCells` is the
   whole cell list. The demo relies on that in both the header and the body,
   and it held in every state tested.

Aggregation on the date column is a small delight worth keeping: `Nothing`
means `'auto'`, which picks `extent` for a `Date` column, so a group row's
Crawled cell is a `Value.List [ Date a, Date b ]` that the demo renders as
`11 Jun 2026 to 5 Sep 2026`.

## Design rules

Whitespace-heavy layout with a 1,440 px measure and 72 px of top padding, two
font weights (400 and 600), one accent (`#2f57d8`, used for the sorted header,
the sort badge, active toggles, the selected row wash, a positive change and
focus rings), hierarchy by size and spacing, hairline row separators
(`#f1f2f4`) and no zebra striping, a system font stack, and no modals: the
search box, the group-by toggles, the sub-row toggle, the page-size picker,
the column chips, the pin toggle, the seed field and the filter row all sit
inline on the page. The table scrolls horizontally inside its own container
and the page never scrolls sideways.

### Banned lexicon

`demo/banned.sh` greps every banned word (as a fixed string, case-insensitive)
and every banned phrase (case-insensitive regex) across `demo/src`,
`demo/index.html`, `demo/dist/index.html` and `demo/dist/elm.js`, so the
generated vocabulary and the compiled string literals are covered as well as
the copy.

```
$ ./banned.sh
0 hits across: src index.html dist/index.html dist/elm.js
```

## One tooling note, not a product bug

Roughly an hour went into a phantom: the pager's Next button appeared dead in
every automated click. It was not. `agent-browser` dispatches the click at the
element's document coordinates without scrolling it into the viewport, and the
pager sits at y≈1705 on a 720 px-tall window. Scrolling first and clicking
again works, and so does clicking it by hand. Any later agent driving this
page should scroll the target into view before clicking anything below the
table.
