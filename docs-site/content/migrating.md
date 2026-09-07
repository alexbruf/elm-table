---
title: Migrating from TanStack
id: migrating
---

This page is for someone who knows TanStack Table and wants to know what
changed. It is a list of the differences, with the TanStack form and the Elm
form side by side. Nothing here is a criticism of TanStack; the changes are what
a JavaScript library looks like once it is written in Elm.

If you are new to TanStack Table, read [Overview](/overview) and
[Quick Start](/quick-start) instead.

## The big one: there is no table instance

TanStack's `useTable` returns a `table` object that owns the options, owns the
state, memoizes the row models, and hangs every API off itself and off the
`column`, `row`, `header`, and `cell` objects it creates.

There is no such object here. It is replaced by three values you hold yourself:

| Value | What it is | Where it comes from |
| --- | --- | --- |
| `Table.Config row` | the column definitions and the table-level options | [`Table.config`](/reference/module/Table#config), then `with*` builders |
| `Table.State` | every state slice | [`Table.initialState`](/reference/module/Table#initialState), then transitions |
| `Table.RowModel row` | the rows the pipeline produced | [`Table.rows`](/reference/module/Table#rows) or one stage at a time |

Every function takes what it needs out of those three:

```ts
const table = useTable({ features, columns, data })

table.getRowModel().rows
table.getColumn('age').toggleSorting()
table.setPageIndex(2)
```

```elm
Table.rowsFromList config state people

Table.toggleSort config rowModel "age" { desc = Nothing, multi = False } state

Table.setPage config 2 state
```

Two consequences run through everything below. Every state transition is a pure
`... -> State -> State`, so you apply it in `update` and store the result. And
because the `Config` is a plain value, two tables never share anything by
accident.

See [Config and State](/guide/config-and-state) and
[Table State](/guide/table-state).

## Renames

| TanStack | elm-table | Note |
| --- | --- | --- |
| `sortingFn` (column option) | [`withSortFn`](/reference/module/Table#withSortFn) / [`withCustomSort`](/reference/module/Table#withCustomSort) | a built-in `SortFn` on the cell value, or your own comparison on the whole row |
| `filterFn` (column option) | [`withFilterFn`](/reference/module/Table#withFilterFn) / [`withCustomFilter`](/reference/module/Table#withCustomFilter) | same split |
| `aggregationFn` (column option) | [`withAggregationFn`](/reference/module/Table#withAggregationFn) | |
| `sortUndefined: 'first'` | [`Table.sortNullsFirst`](/reference/module/Table#sortNullsFirst) | passed to [`withSortUndefined`](/reference/module/Table#withSortUndefined) |
| `sortUndefined: 'last'` | [`Table.sortNullsLast`](/reference/module/Table#sortNullsLast) | |
| `sortUndefined: -1` | [`Table.sortNullsAsMinusOne`](/reference/module/Table#sortNullsAsMinusOne) | |
| `sortUndefined: 1` | [`Table.sortNullsAsPlusOne`](/reference/module/Table#sortNullsAsPlusOne) | |
| `expanded: true` | [`Table.expandAll`](/reference/module/Table#expandAll) | |
| `expanded: Record<string, boolean>` | [`Table.expandedIds`](/reference/module/Table#expandedIds) taking a `Set String` | read back with [`expandedIdsOf`](/reference/module/Table#expandedIdsOf) |
| `reSplitAlphaNumeric` | [`SortFn.splitAlphaNumeric`](/reference/module/Table-SortFn#splitAlphaNumeric) | |
| `column.toggleSorting` | [`Table.toggleSort`](/reference/module/Table#toggleSort) | |
| `table.setPageIndex` | [`Table.setPage`](/reference/module/Table#setPage) | |
| `column.getIsSorted(): false \| 'asc' \| 'desc'` | [`Table.getIsSorted`](/reference/module/Table#getIsSorted)`: State -> String -> Maybe SortDir` | compare against [`Table.sortAsc`](/reference/module/Table#sortAsc) / [`Table.sortDesc`](/reference/module/Table#sortDesc) |

Beyond the table, the general pattern is that a method on `table`, `column`,
`row`, `header`, or `cell` becomes a top-level function in `Table` whose first
arguments are the values that method would have read off `this`. So
`row.getIsSelected()` is `Table.getIsRowSelected state row`, and
`column.getSize()` is `Table.columnSize config column`.

## Semantic differences

### No function registries

TanStack looks a sort, filter, or aggregation function up by name in a registry
that lives on the table (`sortFns`, `filterFns`, `aggregationFns`). Here they
are values. You pass the function itself, so there is no name to register and no
name to mistype.

```ts
columnHelper.accessor('firstName', { sortingFn: 'text', filterFn: 'includesString' })
```

```elm snippet=Migrating.elm#columns
```

[`Table.getSortFn`](/reference/module/Table#getSortFn) and
[`Table.getFilterFn`](/reference/module/Table#getFilterFn) hand back the
function itself rather than a name. Run one with `SortFn.compare` or
`FilterFn.filter`:

```elm snippet=Migrating.elm#compareAges
```

`getSortFn` always returns a `SortFn`, and `getFilterFn` returns a
`Maybe FilterFn`. A column set up with `withCustomSort` or `withCustomFilter`
has no cell-level function, so these report the automatic choice for it while
the row model uses your comparison.

### One Null for null and undefined

`Table.Value` has no separate case for "missing" and "explicitly null". Both are
[`Value.Null`](/guide/values#null-covers-null-and-undefined).

Places where that shows: `unique` over `['a', null, undefined, 'a']` gives two
entries rather than three; a `Null` endpoint in a range filter is always
open-ended, where TanStack treats a `null` minimum as a real minimum coerced to
`0`; and `Null` grouping keys land in one bucket rather than a `null` bucket and
an `undefined` bucket.

### Value.List is the array cell value

A JavaScript array cell value becomes `Value.List (List Value)`. It exists so
`arrIncludes`, `arrIncludesAll`, `arrIncludesSome`, and `arrHas` have something
to test, so the `extent` and `unique` aggregations have something to return, and
so a `[min, max]` range filter value has a shape. See [Values](/guide/values).

### The pipeline is fixed and fully exposed

TanStack composes row models out of the factories you registered:
`createFilteredRowModel()`, `createSortedRowModel()` and so on, and calls them
through `table.getRowModel()`.

Here the order is fixed at core, filtered, grouped, sorted, expanded,
paginated. [`Table.rows`](/reference/module/Table#rows) runs all six, and each
stage is also a function of its own that takes the previous stage's `RowModel`.
So you can stop early, keep an intermediate result, or put a stage of your own
in the middle:

```elm snippet=Migrating.elm#stopAfterSorting
```

A `manual` flag on the config still skips a stage, the same as in TanStack. See
[Row Models](/guide/row-models).

### resetX goes to the feature's default

TanStack's `table.resetSorting()` resets to `table.initialState`, and
`table.resetSorting(true)` resets to the feature's blank default. There is no
table instance here to remember an initial state, so `Table.resetSorting` is
always the second form.

To go back to your own starting values, call the matching `setX`:

```elm snippet=Migrating.elm#backToMyStartSorting
```

Every `resetX` and what it restores is listed in
[Table State](/guide/table-state#resetting).

### Nothing is memoized

TanStack memoizes each row model and re-runs a stage only when its inputs
change. Every function here recomputes from its `Config`, `State`, and data. A
`Table.rows` call is the whole pipeline, every time.

The pattern that replaces the memoization is to compute the row model once per
`update` and store it in your model beside the state, which
[Table State](/guide/table-state#storing-the-row-model-next-to-the-state) shows.
For a sense of the cost: the full pipeline over 10,000 rows with one filter, one
sort, and a page size of 50 runs in about 90 ms.

### Custom sort and filter functions take the whole row

TanStack's `sortingFn` is `(rowA, rowB, columnId) => number` and its `filterFn`
is `(row, columnId, filterValue, addMeta) => boolean`, and both are also where a
built-in like `'text'` is named. That splits in two here.

[`withSortFn`](/reference/module/Table#withSortFn) and
[`withFilterFn`](/reference/module/Table#withFilterFn) take a built-in that
works on one column's `Value`.
[`withCustomSort`](/reference/module/Table#withCustomSort) takes
`Row row -> Row row -> Order` and
[`withCustomFilter`](/reference/module/Table#withCustomFilter) takes
`Row row -> Value -> Bool`, so a custom function can read the original record
and any other column. When a column has both, the custom one wins. The custom
filter receives the raw filter value, matching TanStack, which only applies
`resolveFilterValue` when the filter function carries one.

### Auto-detected functions are real functions, not the string 'auto'

TanStack's `'auto'` is a sentinel resolved through the registry.
[`getAutoSortFn`](/reference/module/Table#getAutoSortFn),
[`getAutoFilterFn`](/reference/module/Table#getAutoFilterFn), and
[`getAutoAggregationFn`](/reference/module/Table#getAutoAggregationFn) sample the
data and return the same kind of value `withSortFn`, `withFilterFn`, and
`withAggregationFn` take, so you can call it, pass it on, or ignore it.

### An 'auto' filter or aggregation function is Nothing

Because the functions are values, "no function set" is simply `Nothing` on the
column, which is what TanStack spells `'auto'`. Leave `withFilterFn` off a
column and the filtered row model resolves `getAutoFilterFn` for it. Leave
`withAggregationFn` off and grouping resolves `getAutoAggregationFn`, which is
`sum` for numbers and `extent` for dates.

Reading it back reflects that: `getFilterFn` and `getAggregationFn` return
`Maybe`, and `Nothing` means "the automatic one applies".

### An Infinity page size is Table.unlimitedPageSize

Elm has no `Infinity` for `Int`, so
[`Table.unlimitedPageSize`](/reference/module/Table#unlimitedPageSize) stands in
where TanStack writes `pageSize: Infinity`. It is `Number.MAX_SAFE_INTEGER`.

```elm snippet=Migrating.elm#everythingOnOnePage
```

A `pageCount` of `Infinity` has no counterpart. `Config.pageCount` is a
`Maybe Int`, and `Just -1` is TanStack's "row count unknown", which clamps
nothing.

### No per-row columnFiltersMeta

TanStack writes `row.columnFilters` and `row.columnFiltersMeta` onto the rows
during filtering, and a filter function can call `addMeta` to leave a score
behind for a later sort. That is how the fuzzy filtering recipe works.

The filtered row model here evaluates the resolved filters directly and produces
the same rows, with nothing written onto them. There is no `addMeta`.
[Fuzzy Filtering](/guide/fuzzy-filtering) shows what to do instead.

### ColumnRegion instead of an optional position argument

TanStack's pinning-aware APIs take an optional
`position?: 'start' | 'center' | 'end'`, where leaving it out means the whole
list. Elm has no optional arguments, so the position is a required
[`Table.ColumnRegion`](/reference/module/Table#ColumnRegion) with four values:
[`allColumnsRegion`](/reference/module/Table#allColumnsRegion) (the absent
argument), `leftColumnsRegion`, `centerColumnsRegion`, and
`rightColumnsRegion`.

```elm snippet=Migrating.elm#leftPinnedColumns
```

### left and right, not start and end

`State.columnPinning` has `left` and `right` fields, and the API keeps those
names: `Table.pinnedLeft`, `Table.pinnedRight`,
`Table.isSomeColumnsPinnedLeft`, and so on. TanStack's logical `start` / `end`
wording survives in one place only, the header ids the header builder produces,
because those id strings are asserted by the ported tests.

### The shift-click anchor is your state

TanStack keeps a `_lastSelectedRowId` on the table and works out from the click
event whether a range was meant.
[`Table.selectRange`](/reference/module/Table#selectRange) takes the anchor row
id as an argument instead, so the anchor is a field in your model.
[`Table.canSelectRange`](/reference/module/Table#canSelectRange) exposes the
guard, so you can tell a range apart from a plain toggle:

```elm snippet=Migrating.elm#selectTo
```

### Group ids and Null grouping keys

A group row's id is `columnId:groupKey`, joined to its parent group's id with
`>`: `department:Design`, `a:a1>b:b1>c:c1`. That is TanStack's
`createGroupedRowModel` verbatim, including the property that an id containing
`:` or `>` can in principle collide.

`Value.Null` grouping values land under the key `"null"`. TanStack keys a bucket
with `` `${groupingValue}` ``, so `null` gives `"null"` and `undefined` gives
`"undefined"`; with one `Null` here, both land in the same bucket.

### Group rows carry an aggregatedValues entry for every leaf column

TanStack replaces `getValue` on a group row, and the replacement returns
`undefined` for a column that is neither an ancestor grouping column nor
aggregatable. Elm rows have no method to replace, and `Table.getValue` would
otherwise fall through to the accessor on the group row's `original`, which is a
real leaf's record.

So a group row carries an explicit entry in
[`rowAggregatedValues`](/reference/module/Table#rowAggregatedValues) for every
leaf column, `Value.Null` included. `Dict.size (Table.rowAggregatedValues row)`
is the leaf column count on every group row, and "this column has no aggregate"
is a `Null` entry rather than a missing key:

```elm snippet=Migrating.elm#hasAggregatedValue
```

### sortUndefined is four functions

`sortUndefined: 'first' | 'last' | -1 | 1` becomes four values passed to
[`withSortUndefined`](/reference/module/Table#withSortUndefined):

```elm snippet=Migrating.elm#nullsLastColumn
```

The same treatment applies to the other string unions TanStack uses in options.
`Table.Expanded` is `expandAll` or `expandedIds`, `Table.GroupedColumnMode` is
`groupedColumnsReorder` / `groupedColumnsRemove` / `groupedColumnsIgnore`, and
so on: one function per variant, so a typo is a compile error.

## What has no counterpart

- **`features` and `tableFeatures()`.** Elm's compiler drops unused code, so
  there is no feature registration step and no tree-shaking option. Every
  feature is available on every table.
- **`flexRender`, `columnHelper`, and the rendering options** (`header`, `cell`,
  `footer` as renderers). This package produces data; you write the `Html`. A
  column's `withHeader` and `withFooter` take a `String` label.
- **`meta`, `columnMeta`, `filterMeta`, and the type helpers.** Your `row` type
  is your own record and your `Msg` type is your own union, so there is nothing
  to attach loosely typed extras to. See [Features](/guide/features).
- **`table.atoms`, `table.store`, and `table.Subscribe`.** See
  [Table State](/guide/table-state).
- **Keyed aggregations.** TanStack's `aggregationFn: [...]` produces an object
  per cell. An `AggregationFn` here is one fold plus an optional merge.
