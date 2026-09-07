---
title: Fuzzy Filtering
id: guide/fuzzy-filtering
---

Fuzzy filtering keeps rows that *approximately* match what the user typed,
rather than rows that contain it exactly. It is a filter function like any
other, so it is wired up with the same builders as
[Column Filtering](/guide/column-filtering) and
[Global Filtering](/guide/global-filtering). This page is the port of TanStack
Table's **Fuzzy Filtering** guide.

TanStack's version of this page uses the `@tanstack/match-sorter-utils`
package for both the match test and the ranking. `elm-table` depends only on
`elm/core` and `elm/time`, and there is no Elm port of that package, so this
page shows how to write the matcher yourself. Everything below is ordinary Elm
in your own module.

## State

Fuzzy filtering adds no state of its own. It is a filter function, so it reads
whichever slice you attach it to.

```elm
-- as a column filter
-- State.columnFilters : List ColumnFilter

-- as the global filter
-- State.globalFilter : Value
```

## Config options

None are specific to fuzzy filtering. The two that matter are the ones a
filter function is attached with, both covered elsewhere:

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `globalFilterFn` | `Maybe FilterFn` | `Nothing` | Set your fuzzy `FilterFn` here with `Table.withGlobalFilterFn` to search every column fuzzily. See [Global Filtering](/guide/global-filtering). |
| `manualFiltering` | `Bool` | `False` | `True` skips the filtering stage, so a client-side fuzzy filter never runs. |

## Column options

| Builder | Type | Default | Description |
| --- | --- | --- | --- |
| `withCustomFilter` | `(Row row -> Value -> Bool) -> Column row -> Column row` | `Nothing` | A predicate on the whole row and the raw filter value. The simplest place for a fuzzy match. |
| `withFilterFn` | `FilterFn -> Column row -> Column row` | `Nothing` | A `Table.FilterFn.FilterFn` built with `Table.FilterFn.custom`, which compares cell `Value` against filter `Value`. |
| `withCustomSort` | `(Row row -> Row row -> Order) -> Column row -> Column row` | `Nothing` | Order the surviving rows by match quality. See [Ranking](#ranking-by-match-quality). |

### Writing a fuzzy matcher

A small, honest fuzzy test is *subsequence matching*: the characters the user
typed have to appear in the cell text in that order, but not next to each
other. Typing `gho` matches "Grace **Ho**pper".

`consume` walks both strings once and returns how far into the text the match
completed, which is also the ranking score used later. `Nothing` means no
match.

```elm snippet=FuzzyFiltering.elm#fuzzySpan
```

```elm snippet=FuzzyFiltering.elm#consume
```

```elm snippet=FuzzyFiltering.elm#fuzzyMatches
```

### Using it as a column filter

`Table.withCustomFilter` hands your predicate the whole `Row` and the raw
filter `Value`, so it can build the text to search from any fields it likes.
The column below is TanStack's `fullName` column: an accessor that joins two
fields, filtered on the joined string.

```elm snippet=FuzzyFiltering.elm#fullName
```

```elm snippet=FuzzyFiltering.elm#fullNameColumn
```

The filter value arrives unresolved, because there is no `FilterFn` to resolve
it with. Lowercase it yourself, as `fuzzySpan` does.

### Using it as the global filter

For a search box that searches every column fuzzily, wrap the same matcher in
a `Table.FilterFn.FilterFn` and hand it to `Table.withGlobalFilterFn`.
`Table.FilterFn.custom` takes the cell value and the filter value;
`withAutoRemove` says when a filter value is blank enough to drop.

```elm snippet=FuzzyFiltering.elm#fuzzyFilterFn
```

```elm snippet=FuzzyFiltering.elm#fuzzyGlobalConfig
```

## Transitions

The same ones as the filter slice you attached it to:
[`setColumnFilter`](/reference/module/Table#setColumnFilter) and
[`resetColumnFilters`](/reference/module/Table#resetColumnFilters) for a column
filter, [`setGlobalFilter`](/reference/module/Table#setGlobalFilter) and
[`resetGlobalFilter`](/reference/module/Table#resetGlobalFilter) for the global
one. There is nothing fuzzy-specific to call.

## Queries

Also unchanged: [`getFilterValue`](/reference/module/Table#getFilterValue),
[`getIsFiltered`](/reference/module/Table#getIsFiltered), and the rest of the
list on [Column Filtering](/guide/column-filtering). A fuzzy filter is not
visible to the query functions as anything special.

## Ranking by match quality

TanStack ranks fuzzy results by storing a rank on each row during filtering
(`addMeta`, read back as `row.columnFiltersMeta[columnId]`) and then sorting on
it. **`elm-table` has no per-row `columnFiltersMeta`.** A filter function
returns a `Bool` and writes nothing back onto the row, which is a deliberate
difference recorded in the port notes; see
[Migrating from TanStack](/migrating).

So ranking is done by scoring again in the comparator. Compute the score from
the row, exactly as the filter did, and compare the two scores. When they tie,
fall back to an ordinary comparison, which is what TanStack's `fuzzySort` does
too.

```elm snippet=FuzzyFiltering.elm#rankOf
```

```elm snippet=FuzzyFiltering.elm#rankedColumn
```

The comparator needs the query string, and a `Column` is built before the
`State` exists, so the column is a function of the query and the `Config` is
built per query rather than once at the top level.

```elm snippet=FuzzyFiltering.elm#configFor
```

```elm snippet=FuzzyFiltering.elm#rankedRows
```

Scoring twice, once to filter and once per comparison, costs more than
TanStack's stored rank. For a large table, score every row into a `Dict`
keyed by row id in your `update` and have the comparator read that instead.

## What this page does not cover

- **`@tanstack/match-sorter-utils`, `rankItem`, and `compareItems`.** There is
  no Elm port. The subsequence matcher above stands in for `rankItem`; write
  a closer scorer if you need one.
- **`addMeta`, `columnFiltersMeta`, and the `filterMeta` slot.** No filter
  function can write per-row metadata. Rank in the comparator instead, as
  above.
- **The `filterFns` and `sortFns` registries.** Columns take functions
  directly, so there is nothing to register a `"fuzzy"` name in.

## Example

[Fuzzy Search](https://elm-table-examples.pages.dev/filters-fuzzy/), ported
from TanStack's Fuzzy Search example.

<iframe src="https://elm-table-examples.pages.dev/filters-fuzzy/" title="Fuzzy Search example" loading="lazy"></iframe>
