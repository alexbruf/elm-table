# elm-table

Elm 0.19.1 package `alexbruf/elm-table`: a headless port of TanStack Table core
(`packages/table-core`). Pure functions only. No ports, no JS, no DOM. The package
exposes data and state transitions; rendering is the user's job.

The full specification is `SPEC.md`. Read it before doing anything. `PORT_NOTES.md`
is the running log of the port: reference SHA, coverage table, semantic differences,
renames, and per-phase reports.

## Layout

```
src/Table.elm                  public facade: Config, State, Row, RowModel, pipeline, transitions
src/Table/Value.elm            the one Value union for cell values (String, Number, Bool, Date, Null)
src/Table/SortFn.elm           built-in sort fns
src/Table/FilterFn.elm         built-in filter fns
src/Table/AggregationFn.elm    built-in aggregation fns
src/Table/Internal/*.elm       one module per feature (not exposed in elm.json)
tests/                         elm-test suite; tests/Fixtures.elm holds the Person fixture
bench/                         timing harness for the 10k-row numbers (not part of the package)
examples/                      elm reactor runnable README example
demo/                          standalone Browser.element demo app (own elm.json, local path dep)
reference/tanstack-table/      shallow clone of TanStack Table (gitignored, read-only reference)
review/                        elm-review configuration
```

## Commands

```
make check        elm-format --validate, elm-review, elm-test   (must be green before every commit)
make test         elm-test only
make format       elm-format --yes src tests
make docs         elm make --docs=docs.json
make bench        run the 10k-row timing harness
make demo         build demo/dist (optimized + minified)
```

Use `bun` / `bunx` instead of `npm` / `npx` for any JS tooling (minifier, deploy).

## Reference code

TanStack source: `reference/tanstack-table/packages/table-core/src`
TanStack tests:  `reference/tanstack-table/packages/table-core/tests/{unit,implementation}`

Every Elm test file names the vitest file it ports in a module doc comment. Keep the
vitest `describe`/`it` names as elm-test `describe`/`test` names so coverage is auditable.

## Rules for contributors (human or agent)

1. Types in `Table.elm` are the shared contract. Changing `Row`, `State`, `Config`, or
   `Column` requires re-running the full test suite and a note in `PORT_NOTES.md`.
2. Never delete a ported test silently. A test that cannot be expressed in Elm (JS
   `undefined`, `NaN`, `-0`, prototype pollution) is either adjusted with a comment
   citing the `PORT_NOTES.md` entry, or listed as excluded there with a one-line reason.
3. Manual flags (`manualSorting`, `manualFiltering`, `manualGrouping`, `manualExpanding`,
   `manualPagination`) skip the stage and return the input row model unchanged.
4. No `Debug.*` in `src/`. `elm-format` and `elm-review` must be clean.
5. Custom sort and filter functions take `row` directly. Built-in fns operate on `Value`.
6. Feature code lives in `src/Table/Internal/<Feature>.elm`; `Table.elm` re-exports.
   Keep exposing-list additions under the `-- Phase N` section comments to avoid merge
   conflicts between parallel work.
7. Docs on every exposed value. `elm make --docs=docs.json` must succeed.
8. Commit at the end of each phase with all tests green; message `Phase N: <summary>`.
9. A shell hook blocks any Bash command whose text contains the env file name. Do not
   cat, grep, or echo it; deploy scripts read it through `set -a; source` inside a script.
