# Port notes

Running log for the Elm port of TanStack Table core. See `SPEC.md` for the plan.

## Reference

- Repo: https://github.com/TanStack/table, branch `main`
- Commit: `36733a38b6a77878eea616b25012c47a0f93d4da` (shallow clone, 2026-09-06)
- Local path: `reference/tanstack-table` (gitignored)
- Scope: `packages/table-core/src` and `packages/table-core/tests/{unit,implementation}`

## Design decisions

1. **`Value` has a `List` constructor.** The spec lists five constructors
   (`String`, `Number`, `Bool`, `Date`, `Null`). A sixth, `List (List Value)`,
   was added so array cell values exist: `arrIncludes`, `arrIncludesAll`,
   `arrIncludesSome`, the `extent` and `unique` aggregations, and range filter
   values (`[min, max]`) all need one. `Null` stands in for both `null` and
   `undefined`.
2. **Built-in filter fns carry their resolvers.** TanStack v9 filter fns are
   records of `filter`, `resolveFilterValue`, `resolveDataValue`, `autoRemove`.
   The Elm `FilterFn` is an opaque record with the same four parts so the
   `constructFilterFn` tests can be ported.

## Phase reports

### Phase 0: Setup

- Package skeleton, `make check` (elm-format, elm-review package template,
  elm-test), fixtures, placeholder test.
- Tests: 4 ported (fixture shape only) / 4 passing / 0 excluded.
- Biggest risk for phase 1: JavaScript coercion cases in `filterFns.test.ts`
  (`"1" == 1`, `String(null)`, `NaN`) that have no direct Elm counterpart.

## Coverage table

Filled in per phase. Cases are counted as `it(` / `test(` calls in the vitest
file.

| vitest file | cases | ported | passing | excluded |
| --- | --- | --- | --- | --- |

## Semantic differences

None yet.

## Renames

None yet.
