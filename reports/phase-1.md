# Phase 1: Built-in functions

`Table.Value`, `Table.SortFn`, `Table.FilterFn`, `Table.AggregationFn` implemented;
the three `unit/fns` vitest files ported case for case.

`make check` is green: elm-format `[]`, elm-review `I found no errors!`,
elm-test `Passed: 183 / Failed: 0` (5 of those are the phase 0 fixture tests).

## Coverage

Case counts are `grep -cE '^\s*(it|test)\(' <file>` against the vitest source;
ported/passing counts are `elm-test <file>` per Elm module.

| vitest file | cases | ported | passing | excluded |
| --- | --- | --- | --- | --- |
| `tests/unit/fns/sortFns.test.ts` | 41 | 41 | 41 | 0 |
| `tests/unit/fns/filterFns.test.ts` | 135 | 130 | 130 | 5 |
| `tests/unit/fns/aggregationFns.test.ts` | 8 | 7 | 7 | 1 |
| **total** | **184** | **178** | **178** | **6** |

Elm modules: `tests/SortFnTest.elm` (41), `tests/FilterFnTest.elm` (130),
`tests/AggregationFnTest.elm` (7). Every vitest `describe` / `it` name is
reproduced verbatim; a case with several `expect`s becomes one `test` with
`Expect.all`.

## Excluded cases

Each excluded name is kept as an `-- excluded` comment block at the point in the
Elm test file where it would otherwise sit.

| vitest file | case | reason |
| --- | --- | --- |
| filterFns | `constructFilterFn` > "applies both resolvers when filtering through the table row model" | needs Phase 3 row model |
| filterFns | `filter fn registry` > "registers the case-sensitive string equality filter fn" | asserts JS object identity against a registry object; Elm has neither |
| filterFns | `filter fn registry` > "registers the new built-in filter fns" | same registry identity assertion |
| filterFns | `auto filter fn for date columns` > "resolves inDateRange for Date-valued columns" | needs `column.getAutoFilterFn`, which arrives with Phase 3 filtering |
| filterFns | `auto filter fn for date columns` > "filters date rows through the table row model" | needs Phase 3 row model |
| aggregationFns | "preserves custom definition result inference" | TypeScript inference test that joins fake row ids; Elm aggregations receive values, not rows |

Two further cases are ported but lose one assertion each: `filterFns.arrHas` >
"matches scalar values against any filter value" and `filterFns.arrIncludes` >
"matches array values that include any filter value" also assert a `vi.spyOn`
call count on `row.getValue`. There is no row object in phase 1, so only the
behavioural assertion is ported (noted in a comment in the test).

## Semantic differences

1. **`Null` is both `null` and `undefined`.** Where the vitest file asserts the
   same result for `null` and for `undefined`, the two expectations collapse
   into one (marked with a comment). It changes one expected value outright:
   `unique(['a', null, undefined, 'a'])` is `['a', null]` in Elm, so
   `uniqueCount` is `2`, not `3`.
2. **`compareBetween`'s blank test.** TanStack treats only `''` and `undefined`
   as a blank endpoint, so a `null` minimum is a real minimum coerced to `0`.
   `Null` covers both in Elm, so a `Null` endpoint is always open-ended. Every
   ported case uses `''` / `undefined`, so no expected value changes.
3. **`Value.toString Null == ""`,** where JavaScript's `String(null)` is
   `"null"`. Only reachable through paths that `autoRemove` drops first (a null
   filter value passed to a string filter's `resolveFilterValue`, or to
   `compareGreaterThan`'s string fallback). No ported case reaches them.
4. **Invalid dates.** `Time.Posix` cannot hold `new Date(NaN)`, so the sortFns
   case "keeps invalid dates equal-like under relational comparison" is ported
   as the `Number NaN` timestamp such a date resolves to.
5. **`inDateRange` string parsing.** Elm has no `new Date(string)`, so
   `Table.FilterFn.toDateTimestamp` parses ISO 8601 `YYYY-MM-DD`, optionally
   with `THH:MM`, `THH:MM:SS` and a trailing `Z`; anything else is `NaN`, i.e.
   never in range. The ported cases only use `YYYY-MM-DD` and `'nope'`.
6. **Alphanumeric numeric chunks compare exactly.** TanStack uses
   `parseSmallInt` for chunks of at most 15 significant digits and falls back to
   `parseInt` (float precision collapse) above that. Elm compares significant
   digit count and then the digits lexicographically, which is identical at or
   below 15 digits and strictly more accurate above. The vocab regression case
   ("matches the previous filter-based implementation across all vocab pairs")
   is ported as a 625-pair comparison against an Elm port of the pre-refactor
   `split(/([0-9]+)/gm).filter(Boolean)` reference, and passes.
7. **`weakEquals` on objects.** JavaScript `==` compares two `Date`s or two
   arrays by reference, so distinct objects are never loosely equal; Elm
   compares them structurally. No ported case covers it.
8. **`Value.toNumber` is `Number(x)` via `String.toFloat`,** so JavaScript-only
   literal forms (`"0x10"`, `"Infinity"`) give `NaN` rather than `16` / `Infinity`.
9. **NaN is written `sqrt -1`,** not `0 / 0`: elm-review's `Simplify` rule
   rejects the literal `0 / 0` unless `expectNaN` is configured, and `review/`
   is out of scope for this phase.

## Additions to the contract

No exposed name or signature was removed or changed. Three values were added:

- `Table.Value.toNumber : Value -> Float` — JavaScript `Number(x)` coercion,
  shared by the sort, filter and aggregation comparators.
- `Table.SortFn.splitAlphaNumeric : String -> List String` — the
  `reSplitAlphaNumeric` port, so the `reSplitAlphaNumeric` describe block ports
  literally (`"item10"` → `[ "item", "10", "" ]`).
- `Table.FilterFn.toDateTimestamp : Value -> Float` — `toDateTimestamp` from
  `filterFns.ts`, exposed so the date-range tests can anchor the ISO parse
  against a known epoch value.

## Biggest risk for later phases

Phase 3 must apply `FilterFn.resolveFilterValue` **once per filter, in the row
model, before any row is tested**, and `FilterFn.autoRemove` before that. The
Elm `FilterFn.filter` deliberately mirrors TanStack and resolves only the
*cell* value, so a filtered row model that forgets the filter-value resolver
compiles and silently misbehaves: `includesString` stops being
case-insensitive, and `inNumberRange` compares against raw endpoints instead of
`[-Infinity, Infinity]`-normalised ones. The four filter-value resolver cases
ported here are the only guard until the row model exists.
