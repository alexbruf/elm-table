---
title: Aggregation
id: guide/aggregation
---

## Aggregation

An aggregation folds many cell values of one column into a single value: a
sum, a mean, a count, a min and max pair. Group rows use aggregations to show
something for the rows hidden inside them, and a table footer uses one to show
a grand total. This page ports TanStack Table's *Aggregation (React) Guide*.

Aggregation is separate from [Grouping](/guide/grouping). You can put a total
in a footer without ever grouping a row, and you can group rows without
configuring any aggregation.

The built-in functions live in
[`Table.AggregationFn`](/reference/module/Table-AggregationFn) and are plain
values you hand to
[`withAggregationFn`](/reference/module/Table#withAggregationFn). There is no
registry and no string names.

## State

Aggregation owns no state slice. It reads `State.grouping` to know which
columns are grouped, because that decides which rows are group rows and which
of their cells are aggregated:

```elm
-- in Table.State
grouping : List String

-- in Table.initialState
grouping = []
```

## Config options

There is no aggregation-specific `Config` field. The two grouping fields
below decide whether group rows exist at all, and so whether any aggregated
cell exists:

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableGrouping` | `Bool` | `True` | With it `False`, no column can be grouped and the grouped stage produces no group rows. |
| `manualGrouping` | `Bool` | `False` | Skip the grouped stage. Footer totals through [`aggregationValue`](/reference/module/Table#aggregationValue) still work. |

TanStack's `manualAggregation` option, which turns off the local calculation
so a server value is used instead, has no counterpart here. To show a server
total, put it in your own model and render it.

## Column options

| Builder | Type | Default | Description |
| --- | --- | --- | --- |
| [`withAggregationFn`](/reference/module/Table#withAggregationFn) | `AggregationFn -> Column row -> Column row` | none | The aggregation for this column. |
| [`withMaxAggregationDepth`](/reference/module/Table#withMaxAggregationDepth) | `Int -> Column row -> Column row` | `0` | How far below the rows being aggregated to look for values. |

Leaving `withAggregationFn` off is TanStack's `aggregationFn: 'auto'`. The
automatic choice reads the first row of the row model handed in: `sum` for a
`Number` column, `extent` for a `Date` column, and no aggregation for
anything else.

```elm snippet=Aggregation.elm#columns
```

`withMaxAggregationDepth` picks a frontier below the starting rows. `0`, the
default, aggregates the starting rows themselves. `1` aggregates their direct
sub-rows. A branch that ends before the depth is reached contributes its own
deepest row, so nothing is silently dropped.

```elm snippet=Aggregation.elm#deepestOnly
```

### Built-in aggregations

| Function | Result | Has a merge |
| --- | --- | --- |
| [`sum`](/reference/module/Table-AggregationFn#sum) | Sum of `Number` values; anything else counts as zero. | yes |
| [`min`](/reference/module/Table-AggregationFn#min) | Smallest `Number` or `Date`, `Null` when there is none. | yes |
| [`max`](/reference/module/Table-AggregationFn#max) | Largest `Number` or `Date`, `Null` when there is none. | yes |
| [`extent`](/reference/module/Table-AggregationFn#extent) | `Value.List [ min, max ]`, or `[ Null, Null ]` when there is no comparable value. | yes |
| [`mean`](/reference/module/Table-AggregationFn#mean) | Arithmetic mean of numeric values, `Null` when there is none. | no |
| [`median`](/reference/module/Table-AggregationFn#median) | Median of `Number` values, `Null` when there is none. | no |
| [`unique`](/reference/module/Table-AggregationFn#unique) | Distinct values in first-seen order, as a `Value.List`. | no |
| [`uniqueCount`](/reference/module/Table-AggregationFn#uniqueCount) | How many distinct values there are. | no |
| [`count`](/reference/module/Table-AggregationFn#count) | How many rows there are. | yes |
| [`first`](/reference/module/Table-AggregationFn#first) | The first row's value, `Null` for no rows. | yes |
| [`last`](/reference/module/Table-AggregationFn#last) | The last row's value, `Null` for no rows. | yes |

### Custom aggregations and `merge`

[`custom`](/reference/module/Table-AggregationFn#custom) builds an
aggregation from a fold over the values:

```elm snippet=Aggregation.elm#tagList
```

[`withMerge`](/reference/module/Table-AggregationFn#withMerge) adds a second
fold, and this is what the "Has a merge" column above is about. When groups
nest, a parent group can combine the values its child groups already computed
instead of re-reading every leaf row. A sum of sums is the same number as a
sum of everything, so `sum` carries a merge. A mean of means is not the same
number as a mean of everything, so `mean` does not, and a nested `mean` folds
the leaf frontier directly.

```elm snippet=Aggregation.elm#runningTotal
```

The merge runs exactly where TanStack runs it: only when a group has
sub-rows, every one of them is a group row of a different column, and the
aggregation carries a merge.

To run a fold outside the table entirely, reach for
[`aggregate`](/reference/module/Table-AggregationFn#aggregate) (the leaf fold)
or [`merge`](/reference/module/Table-AggregationFn#merge) (the child fold, as
a `Maybe`):

```elm snippet=Aggregation.elm#salaryTotalOfList
```

## Transitions

Aggregation has no state transitions. Nothing about it is stored in `State`;
it is computed from the `Config`, the rows, and `State.grouping` every time
you ask.

## Queries

| Function | Signature | Description |
| --- | --- | --- |
| [`getAutoAggregationFn`](/reference/module/Table#getAutoAggregationFn) | `Config row -> RowModel row -> String -> Maybe AggregationFn` | The automatic choice for a column, read off the first row of the model. |
| [`getAggregationFn`](/reference/module/Table#getAggregationFn) | `Config row -> RowModel row -> String -> Maybe AggregationFn` | The column's own function, or the automatic one. |
| [`aggregationValue`](/reference/module/Table#aggregationValue) | `Config row -> RowModel row -> String -> Value` | Aggregate one column over a row model, at the column's own depth. TanStack's `column.getAggregationValue()`. |
| [`aggregationValueOf`](/reference/module/Table#aggregationValueOf) | `Config row -> RowModel row -> String -> { maxDepth : Int, rows : List (Row row) } -> Value` | Aggregate one column over a row list and depth you choose. TanStack's `column.getAggregationValue({ rows, maxDepth })`. |
| [`cellIsAggregated`](/reference/module/Table#cellIsAggregated) | `Config row -> RowModel row -> State -> Row row -> String -> Bool` | Is this cell an aggregated one? |
| [`rowAggregatedValues`](/reference/module/Table#rowAggregatedValues) | `Row row -> Dict String Value` | The whole aggregated map of a group row, keyed by column id. |
| [`maxSubRowDepth`](/reference/module/Table#maxSubRowDepth) | `RowModel row -> Int` | The deepest structural depth in a row model, for picking a `maxDepth`. |

Both `aggregationValue` and `aggregationValueOf` take a `RowModel` because an
automatic aggregation function is chosen by sampling a row.
`aggregationValueOf` also drops duplicate row ids from the list you give it,
since a caller-supplied list can hold a row and one of its own ancestors;
`aggregationValue` reads a whole row model, so it skips that check.

### A footer total

Call [`aggregationValue`](/reference/module/Table#aggregationValue) with the
pre-grouped row model, which is the filtered one, to get TanStack's default
grand total: filtering counts, grouping and sorting and pagination do not.

```elm snippet=Aggregation.elm#preGrouped
```

```elm snippet=Aggregation.elm#viewFooterCell
```

Use [`aggregationValueOf`](/reference/module/Table#aggregationValueOf) when
you want a different set of rows, such as the selected ones:

```elm snippet=Aggregation.elm#selectedTotal
```

### Aggregated cells

On a group row, [`getValue`](/reference/module/Table#getValue) already returns
the aggregated value, so an aggregated cell needs no special reader. Use
[`cellIsAggregated`](/reference/module/Table#cellIsAggregated) when you want
to render it differently, which is what TanStack's `aggregatedCell` column
option is for:

```elm snippet=Aggregation.elm#viewCell
```

Group rows carry an explicit `aggregatedValues` entry for **every** leaf
column, including a `Null` for the columns with no aggregation. TanStack
replaces `getValue` on a group row and returns `undefined` for those columns;
Elm rows have no method to replace, and a group row's datum is a real leaf
row's datum, so writing an explicit `Null` is what stops a group row from
reporting its first member's value. One consequence:
`Dict.size (Table.rowAggregatedValues row)` is the leaf column count on every
group row.

## Not covered

TanStack lets a column carry an array of aggregations
(`aggregationFn: ['count', 'mean', ...]`), producing an object of results
keyed by name. An `AggregationFn` here is one fold plus an optional merge,
and a cell holds one `Value`, so there is no counterpart. Configure a second
column, or compute the extra numbers yourself with
[`aggregate`](/reference/module/Table-AggregationFn#aggregate).

TanStack's `getAggregationValue` column option, which lets a column answer an
aggregation request with a server-provided value before any local
calculation, is also not ported, and neither is `manualAggregation`. Keep
server totals in your own model.

Custom aggregations receive the list of `Value`s, not a context record, so
TanStack's `column`, `columnId`, `maxDepth`, `table`, `groupingRow`, and
`subRows` context members have no counterpart. Worker-backed row models are
out of scope.

## Example

[Aggregation](https://elm-table-examples.pages.dev/aggregation/), ported from
TanStack's Aggregation example.

<iframe src="https://elm-table-examples.pages.dev/aggregation/" title="Aggregation example" loading="lazy"></iframe>
