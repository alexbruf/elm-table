---
title: Values
id: guide/values
---

Every column accessor returns a `Table.Value.Value`. It is one union type with
six constructors, and it is the type the built-in sort, filter, and aggregation
functions compare. This page is about that type: why it exists, what each
constructor is for, and the two coercion helpers the built-ins rely on.

TanStack has no page for this. In TypeScript a cell value is whatever the
accessor returns, and the built-in functions reach for JavaScript's own
coercions when they need to compare two of them.

## Why there is one union type at all

A built-in sort function has to order two cells without knowing anything about
your row type. A built-in filter has to decide whether a cell matches a filter
value. An aggregation has to fold a list of cells into one. In TypeScript those
functions take `unknown` and lean on `<`, `==`, `String(x)` and `Number(x)`.
Elm has no `unknown` and no coercions, so the port needs a concrete type the
comparisons can be written against. That type is `Value`.

```elm
type Value
    = String String
    | Number Float
    | Bool Bool
    | Date Time.Posix
    | List (List Value)
    | Null
```

`Value` is fully exposed, so you construct and pattern match on it directly.

## Writing an accessor

[`Table.column`](/reference/module/Table#column) takes a column id and an
accessor `row -> Value`. Most accessors are a field access composed with a
constructor:

```elm snippet=Values.elm#personColumns
```

An `Int` field needs `toFloat` first, because `Number` holds a `Float`.

`Date` holds a `Time.Posix`, so a date column reads a `Time.Posix` field and
sorts with [`SortFn.datetime`](/reference/module/Table-SortFn#datetime):

```elm snippet=Values.elm#eventColumns
```

A field that may be missing becomes `Null`:

```elm snippet=Values.elm#maybeString
```

## Null covers null and undefined

`Value` has no separate case for "missing" and "explicitly null". JavaScript's
`null` and `undefined` both read back as `Null` everywhere a cell value is read.

That is deliberate and it shows up in a few places:

- `Table.SortFn` places `Null` cells with
  [`Table.withSortUndefined`](/reference/module/Table#withSortUndefined); there
  is nothing else for it to place.
- The `unique` aggregation over `[ "a", null, undefined, "a" ]` gives
  `[ "a", Null ]` in Elm and three entries in TanStack, so `uniqueCount` is `2`
  rather than `3`.
- Grouping puts `Null` values under the key `"null"`, which merges TanStack's
  separate `null` and `undefined` buckets. See [Grouping](/guide/grouping).

[`Table.Value.isNull`](/reference/module/Table-Value#isNull) is the test:

```elm
Value.isNull (Table.getValue config row "department")
```

## Value.List is the array cell value

`List (List Value)` is the counterpart of a JavaScript array cell value. It
exists because several built-ins need one to work on:

- [`FilterFn.arrIncludes`](/reference/module/Table-FilterFn#arrIncludes),
  [`arrIncludesAll`](/reference/module/Table-FilterFn#arrIncludesAll),
  [`arrIncludesSome`](/reference/module/Table-FilterFn#arrIncludesSome), and
  [`arrHas`](/reference/module/Table-FilterFn#arrHas) test a cell against a
  filter value that is itself a list.
- [`AggregationFn.extent`](/reference/module/Table-AggregationFn#extent) returns
  a two-element `List` (the minimum and the maximum), and
  [`unique`](/reference/module/Table-AggregationFn#unique) returns the distinct
  values as a `List`.
- Range filter values, the `[ min, max ]` pair that
  [`inNumberRange`](/reference/module/Table-FilterFn#inNumberRange) and
  [`between`](/reference/module/Table-FilterFn#between) expect, are a `List` of
  two values.

```elm snippet=Values.elm#tagsColumn
```

## toString and toNumber

The built-in functions compare cells the way JavaScript would, so the port needs
JavaScript's two coercions.
[`Value.toString`](/reference/module/Table-Value#toString) is `String(x)` and
[`Value.toNumber`](/reference/module/Table-Value#toNumber) is `Number(x)`.

### toString

| Value | `toString` |
| --- | --- |
| `String "ada"` | `"ada"` |
| `Number 1` | `"1"` |
| `Number 1.5` | `"1.5"` |
| `Bool True` | `"true"` |
| `Bool False` | `"false"` |
| `Date posix` | the millisecond timestamp as a string |
| `List items` | each item's `toString`, joined with `","` |
| `Null` | `""` |

`Null` is the one place this is not literally `String(x)`: JavaScript's
`String(null)` is `"null"`, and TanStack writes `String(x ?? '')` at every call
site that matters, so `""` is the behaviour the built-ins actually see.

### toNumber

| Value | `toNumber` |
| --- | --- |
| `Number 29` | `29` |
| `String "29"` | `29` |
| `String ""` | `0` |
| `String "abc"` | `NaN` |
| `Bool True` | `1` |
| `Bool False` | `0` |
| `Date posix` | the millisecond timestamp |
| `List []` | `0` |
| `List [ item ]` | `toNumber item` |
| `List _` (two or more) | `NaN` |
| `Null` | `0` |

A string is parsed with Elm's `String.toFloat` after trimming, which covers
every decimal form JavaScript accepts but not the JavaScript-only literals:
`"0x10"` and `"Infinity"` give `NaN` here where `Number(x)` gives `16` and
`Infinity`. `NaN` compares `False` against everything, exactly as it does in
JavaScript.

### Dates

Two more differences follow from `Date` holding a `Time.Posix`:

- `Time.Posix` cannot hold JavaScript's `new Date(NaN)`. An invalid date is a
  `Number NaN` instead, which sorts and filters the way an invalid date does.
- [`FilterFn.inDateRange`](/reference/module/Table-FilterFn#inDateRange) parses
  string endpoints with
  [`FilterFn.toDateTimestamp`](/reference/module/Table-FilterFn#toDateTimestamp),
  which accepts ISO 8601 only: `YYYY-MM-DD`, optionally with `THH:MM` or
  `THH:MM:SS` and a trailing `Z`. Anything else is `NaN`, so it is never in
  range. There is no `new Date(string)` in Elm to fall back on.

## Formatting a cell

`Value.toString` is there for the built-ins, and it is fine for a quick render.
For anything a person reads, pattern match instead. That is how you get
thousands separators, a real date format, and a placeholder for a missing value:

```elm snippet=Values.elm#formatCell
```

## Your own logic never has to go through Value

`Value` is the type the *built-in* functions speak. Your own sort and filter
functions receive the `Table.Row row`, so they can read the original record and
any other column on it:

```elm snippet=Values.elm#fullNameColumn
```

[`Table.withCustomSort`](/reference/module/Table#withCustomSort) takes
`Row row -> Row row -> Order` and
[`Table.withCustomFilter`](/reference/module/Table#withCustomFilter) takes
`Row row -> Value -> Bool`, where the `Value` is the filter value from state.
[`Table.rowOriginal`](/reference/module/Table#rowOriginal) gets you back to your
own record. A custom function wins over a built-in one on the same column.

The built-in [`SortFn`](/reference/module/Table-SortFn) and
[`FilterFn`](/reference/module/Table-FilterFn) values work on one column's
`Value`, and both modules expose a `custom` constructor if you want to write a
comparison at that level instead.

## Not covered here

TanStack's "Table and Column Meta" and "Type Helpers" pages have no counterpart,
because Elm's own types do that job; that is noted on
[Features](/guide/features).
