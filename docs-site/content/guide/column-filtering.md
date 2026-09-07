---
title: Column Filtering
id: guide/column-filtering
---

Filtering comes in two kinds. A **column filter** is applied to one column's
cell values; a **global filter** is one value tested against every searchable
column at once. This page is the port of TanStack Table's **Column Filtering**
guide; the other kind is on [Global Filtering](/guide/global-filtering).

Both kinds are applied by the same `filteredRowModel` stage of the
[pipeline](/guide/row-models), and a row has to pass both to survive.

```elm snippet=ColumnFiltering.elm#filteredRows
```

## Column filter state

`State.columnFilters` is a list, so several columns can be filtered at once.
The order is the order the filters were added, which is what
[`getFilterIndex`](/reference/module/Table#getFilterIndex) reports.

```elm
type alias ColumnFilter =
    { id : String
    , value : Value
    }


-- State.columnFilters : List ColumnFilter
-- Table.initialState.columnFilters == []
```

The `value` is a [`Value`](/guide/values), not a `String`, because a filter
value can be a number, a `[min, max]` range (`Value.List`), or a set of choices.
A text input produces `Value.String`; a range slider produces
`Value.List [ Value.Number low, Value.Number high ]`.

## Config options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableFilters` | `Bool` | `True` | Both column and global filtering. `False` switches off both. |
| `enableColumnFilters` | `Bool` | `True` | Column filtering for every column. |
| `filterFromLeafRows` | `Bool` | `False` | `False` filters parents first and drops a parent's whole subtree with it. `True` filters from the leaves up, keeping a parent whose descendant matches. |
| `maxLeafRowFilterDepth` | `Int` | `100` | How deep filtering reaches. `0` filters only root rows and leaves every sub-row alone. |
| `manualFiltering` | `Bool` | `False` | `True` makes `Table.filteredRowModel` return its input untouched. |

### Manual server-side filtering

Set `manualFiltering = True` when the rows arriving from the server are already
filtered. The filtering stage then passes the row model straight through while
the filter state, the transitions, and the query functions all keep working, so
your filter inputs are unchanged. Read `State.columnFilters` and send it with
your request. See [Client-Side vs Server-Side](/guide/client-side-vs-server-side).

### Filtering sub-rows

`filterFromLeafRows` and `maxLeafRowFilterDepth` only matter for a table with
sub-rows (see [Expanding](/guide/expanding) and [Grouping](/guide/grouping)).

By default a parent row that fails a filter takes its children with it, which
is the cheapest option and the right one when the user is searching top-level
rows. `filterFromLeafRows = True` reverses that: a parent stays as long as one
of its descendants matches.

`maxLeafRowFilterDepth = 0` keeps a matching parent's sub-rows even though they
do not match on their own.

```elm snippet=ColumnFiltering.elm#leafFilteringConfig
```

## Column options

| Builder | Type | Default | Description |
| --- | --- | --- | --- |
| `withFilterFn` | `FilterFn -> Column row -> Column row` | `Nothing` | The comparison between this column's cell value and the filter value. |
| `withCustomFilter` | `(Row row -> Value -> Bool) -> Column row -> Column row` | `Nothing` | A predicate on the whole row, used instead of a `FilterFn`. |
| `withEnableColumnFilter` | `Bool -> Column row -> Column row` | `True` | Column filtering for this column. |

A column with no accessor can never be filtered, whatever these say.

```elm snippet=ColumnFiltering.elm#columns
```

Note that `getCanFilter` answering `False` does not stop an entry that is
already in `State.columnFilters` from being applied. The filtered row model
applies every entry whose column exists, matching TanStack.

### Filter functions

A `Table.FilterFn.FilterFn` is four things, ported from the record TanStack's
`constructFilterFn` builds:

| Part | Signature | When it runs |
| --- | --- | --- |
| `filter` | `Value -> Value -> Bool` | Once per row: the cell value against the filter value. |
| `resolveFilterValue` | `Value -> Value` | Once per filter, before any row is tested. This is where a search string is lowercased and a range is normalised, so the work is not repeated per row. |
| `resolveDataValue` | `Value -> Value` | Once per row, on the cell value, before `filter` sees it. |
| `autoRemove` | `Value -> Bool` | On write: `True` means the filter value is blank enough that the filter should be dropped from state instead of stored. |

`Table.FilterFn.filter`, `resolveFilterValue`, `resolveDataValue`, and
`autoRemove` read those four parts back out of a `FilterFn`. Note that
`Table.FilterFn.filter` applies `resolveDataValue` to the cell value but
expects the filter value to already be resolved, because the row model resolves
it once for the whole pass.

These are the built-ins, grouped the way `Table.FilterFn` groups them. The
column marked *filter value* is the shape the `Value` in `State.columnFilters`
should have.

| TanStack `filterFns` | `Table.FilterFn` | Filter value |
| --- | --- | --- |
| **Basic** | | |
| `equals` | `equals` | Any `Value`; compared with Elm's `==`. |
| `weakEquals` | `weakEquals` | Any `Value`; compared with JavaScript's `==` rules, so `Value.String "1"` matches `Value.Number 1`. |
| **Strings** | | |
| `includesString` | `includesString` | A `String`, lowercased once. Case-insensitive substring match. |
| `includesStringSensitive` | `includesStringSensitive` | A `String`. Case-sensitive substring match. |
| `equalsString` | `equalsString` | A `String`, lowercased once. Case-insensitive whole-string match. |
| `equalsStringSensitive` | `equalsStringSensitive` | A `String`. Case-sensitive whole-string match. |
| `startsWith` | `startsWith` | A `String`, lowercased once. |
| `endsWith` | `endsWith` | A `String`, lowercased once. |
| **Blank** | | |
| `empty` | `empty` | An on/off flag; the value itself is not compared. Keeps rows whose cell is `Null` or whitespace only. |
| `notEmpty` | `notEmpty` | An on/off flag. Keeps rows whose cell is not blank. |
| **Numbers** | | |
| `greaterThan` | `greaterThan` | A `Number`, or a `String` when either side does not parse as a number. |
| `greaterThanOrEqualTo` | `greaterThanOrEqualTo` | As `greaterThan`. |
| `lessThan` | `lessThan` | As `greaterThan`. |
| `lessThanOrEqualTo` | `lessThanOrEqualTo` | As `greaterThan`. |
| **Ranges** | | |
| `between` | `between` | `Value.List [ min, max ]`, exclusive. A blank end is open. |
| `betweenInclusive` | `betweenInclusive` | `Value.List [ min, max ]`, inclusive. A blank end is open. |
| `inNumberRange` | `inNumberRange` | `Value.List [ min, max ]`, inclusive, numbers only. The ends are coerced and swapped when reversed. |
| `inDateRange` | `inDateRange` | `Value.List [ min, max ]` of `Date` values, timestamps, or `YYYY-MM-DD` strings. Inclusive; a blank end is open. |
| **Arrays** | | |
| `arrHas` | `arrHas` | `Value.List` of candidates; the cell is a scalar and has to equal one of them. |
| `arrIncludes` | `arrIncludes` | `Value.List` of candidates; a `List` cell has to contain one, a `String` cell has to contain one as a substring. |
| `arrIncludesAll` | `arrIncludesAll` | `Value.List`; a `List` cell has to contain every one of them. |
| `arrIncludesSome` | `arrIncludesSome` | `Value.List`; a `List` cell has to contain at least one. |

A column with no `withFilterFn` and no `withCustomFilter` filters with the
automatic choice, TanStack's `filterFn: 'auto'`. Here `Nothing` in
`Column.filterFn` *is* `'auto'`.
[`getAutoFilterFn`](/reference/module/Table#getAutoFilterFn) picks from the
type of the column's first non-null value: `includesString` for strings,
`inNumberRange` for numbers, `equals` for booleans, `arrIncludes` for lists,
`inDateRange` for dates, and `weakEquals` when every sampled value is `Null`.

### Custom filter functions

Build a `FilterFn` with `Table.FilterFn.custom` and add the parts you need.
Resolvers default to `identity`; `autoRemove` defaults to dropping `Null` and
the empty string.

```elm snippet=ColumnFiltering.elm#startsWithTrimmed
```

`Table.withCustomFilter` is the other route. It takes the whole `Row` and the
raw filter value, so it can look at fields the column's accessor does not
expose. The filter value it receives is **not** resolved, because there is no
`FilterFn` to resolve it with.

```elm snippet=ColumnFiltering.elm#activeDepartmentColumn
```

## Transitions

| Function | What it does |
| --- | --- |
| [`setColumnFilter`](/reference/module/Table#setColumnFilter) | Set one column's filter value: replaced in place when it already has one, appended otherwise, removed when the value should auto-remove. |
| [`setColumnFilters`](/reference/module/Table#setColumnFilters) | Replace `State.columnFilters` wholesale, dropping entries of known columns whose value should auto-remove. |
| [`resetColumnFilters`](/reference/module/Table#resetColumnFilters) | Clear every column filter. Useful for a "clear all" button. |

```elm snippet=ColumnFiltering.elm#update
```

`setColumnFilter` and `setColumnFilters` take a `RowModel` because
`autoRemove` is data-derived: deciding whether a value is blank enough to drop
means knowing which filter function the column uses, and for a column with no
`withFilterFn` that is the automatic choice, which is sampled from the rows.
Pass the row model you handed to `Table.filteredRowModel`, the one before
filtering.

```elm snippet=ColumnFiltering.elm#unfilteredRows
```

## Queries

| Function | Use it for |
| --- | --- |
| [`getFilterValue`](/reference/module/Table#getFilterValue) | The current value of a filter input. `Maybe Value`, `Nothing` when the column has no filter. |
| [`getCanFilter`](/reference/module/Table#getCanFilter) | Showing or disabling a filter input. |
| [`getIsFiltered`](/reference/module/Table#getIsFiltered) | A "this column is filtered" indicator. |
| [`getFilterIndex`](/reference/module/Table#getFilterIndex) | The order the filters were applied in. `-1` when the column has no filter. |
| [`getFilterFn`](/reference/module/Table#getFilterFn) | Showing which filter mode a column is in. `Nothing` when the column does not exist. |
| [`getAutoFilterFn`](/reference/module/Table#getAutoFilterFn) | The function the automatic choice would pick. |
| [`shouldAutoRemoveFilter`](/reference/module/Table#shouldAutoRemoveFilter) | Predicting whether a value you are about to write will be stored or dropped. |

```elm snippet=ColumnFiltering.elm#viewFilterInput
```

```elm snippet=ColumnFiltering.elm#activeFilterCount
```

`getFilterFn` and `getAutoFilterFn` take a `RowModel` to sample for the
automatic choice; pass the core row model. The other five read only the
`State` or the `Config`.

## What this page does not cover

- **Controlled state, `onColumnFiltersChange`, and atoms.** The `State` is
  always yours. See [Table State](/guide/table-state).
- **`initialState.columnFilters`.** Build your starting state by calling
  `setColumnFilters` on `Table.initialState`.
- **The `filterFns` registry.** There is no registry, so `getFilterFn` returns
  a `FilterFn` rather than a registered name, and a column takes the function
  itself.
- **`columnFiltersMeta` and `addMeta`.** A filter function cannot write
  per-row metadata back onto the row, so the ranking pattern TanStack's fuzzy
  guide uses is done differently here. See
  [Fuzzy Filtering](/guide/fuzzy-filtering).
- **`autoResetPageIndex`.** Filtering does not move the page index for you.
  Call `Table.resetPageIndex` in the same `update` branch as the filter
  change.

## Example

[Column Filters](https://elm-table-examples.pages.dev/filters/), ported from
TanStack's Filters example.

<iframe src="https://elm-table-examples.pages.dev/filters/" title="Column Filters example" loading="lazy"></iframe>
