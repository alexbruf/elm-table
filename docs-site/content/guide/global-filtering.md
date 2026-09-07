---
title: Global Filtering
id: guide/global-filtering
---

A **global filter** is a single value, usually a search box, tested against
every searchable column at once. A row survives when at least one of those
columns matches. This page is the port of TanStack Table's **Global Filtering**
guide; per-column filters are on
[Column Filtering](/guide/column-filtering).

The global filter and the column filters are applied by the same
`filteredRowModel` stage of the [pipeline](/guide/row-models), and a row has to
pass both.

```elm snippet=GlobalFiltering.elm#filteredRows
```

## Global filter state

`State.globalFilter` is one [`Value`](/guide/values), not a list, because there
is only ever one global filter. `Value.Null` means "no global filter".

```elm
-- State.globalFilter : Value
-- Table.initialState.globalFilter == Value.Null
```

A search box writes `Value.String`. The slice is a `Value` rather than a
`String` so a custom global filter function can take a range, a set of choices,
or anything else `Value` can hold, which is what TanStack's `any` typing of
this slice is for.

## Config options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableGlobalFilter` | `Bool` | `True` | Global filtering for every column. |
| `enableFilters` | `Bool` | `True` | Both column and global filtering. `False` switches off both. |
| `globalFilterFn` | `Maybe FilterFn` | `Nothing` | The comparison the global filter uses. `Nothing` means the automatic choice. Set it with `Table.withGlobalFilterFn`. |
| `getColumnCanGlobalFilter` | `Maybe (Column row -> Bool)` | `Nothing` | Decide per column whether the global filter searches it. `Nothing` uses the default rule below. |
| `manualFiltering` | `Bool` | `False` | `True` makes `Table.filteredRowModel` return its input untouched. |

`Table.withGlobalFilterFn` is the one builder here; the other fields are set
with a record update on `Table.config`.

```elm snippet=GlobalFiltering.elm#config
```

A column is searched by the global filter when all of these hold: it has an
accessor, `Config.enableFilters` and `Config.enableGlobalFilter` are on, the
column has not opted out with `withEnableGlobalFilter False`, and
`Config.getColumnCanGlobalFilter` agrees. The default rule, when that field is
`Nothing`, keeps a column only if its first non-null value is a string or a
number, which is TanStack's default.

```elm snippet=GlobalFiltering.elm#namesOnlyConfig
```

### Global filter function

`Config.globalFilterFn` takes the same `Table.FilterFn.FilterFn` a column takes.
The full list of built-ins, the four parts of a `FilterFn`, and how to write
your own are on [Column Filtering](/guide/column-filtering).

TanStack's guide lists the subset of its filter functions that make sense
against a mixed set of columns, leaving out the ones that only suit a single
typed column. The same subset applies here: `includesString`,
`includesStringSensitive`,
`equalsString`, `equals`, `weakEquals`, `arrHas`, `arrIncludes`,
`arrIncludesAll`, `arrIncludesSome`, `inNumberRange`, `between`, and
`betweenInclusive` all work against a mixed set of columns.

With no `globalFilterFn` set, the global filter uses
[`globalAutoFilterFn`](/reference/module/Table#globalAutoFilterFn), which is
`Table.FilterFn.includesString`.

## Column options

| Builder | Type | Default | Description |
| --- | --- | --- | --- |
| `withEnableGlobalFilter` | `Bool -> Column row -> Column row` | `Nothing` | Whether the global filter searches this column. `Nothing` falls back to `Config.enableGlobalFilter` and `Config.getColumnCanGlobalFilter`. |

There is no per-column global filter function: the global filter uses one
comparison for every column it searches.

```elm snippet=GlobalFiltering.elm#columns
```

## Transitions

| Function | What it does |
| --- | --- |
| [`setGlobalFilter`](/reference/module/Table#setGlobalFilter) | Set the global filter value. |
| [`resetGlobalFilter`](/reference/module/Table#resetGlobalFilter) | Clear it, back to `Value.Null`. |

```elm snippet=GlobalFiltering.elm#update
```

Neither takes a `RowModel`. Unlike
[`setColumnFilter`](/reference/module/Table#setColumnFilter), the global filter
value is stored as written: there is no `autoRemove` step, so an empty search
string is kept in state and simply matches everything.

## Queries

| Function | Use it for |
| --- | --- |
| [`getCanGlobalFilter`](/reference/module/Table#getCanGlobalFilter) | Listing or debugging which columns the search box actually searches. |
| [`getGlobalFilterFn`](/reference/module/Table#getGlobalFilterFn) | Showing which comparison the search uses. Always returns a `FilterFn`. |
| [`globalAutoFilterFn`](/reference/module/Table#globalAutoFilterFn) | The default, `Table.FilterFn.includesString`. It is a value, not a function. |
| [`globalFacetKey`](/reference/module/Table#globalFacetKey) | The column id `"__global__"`, which the faceting functions take to mean "across every globally filterable column". See [Faceting](/guide/column-faceting). |

Read the current value straight off the state; there is no getter for it.

```elm snippet=GlobalFiltering.elm#viewSearchInput
```

`getCanGlobalFilter` takes a `RowModel` because the default column rule samples
the data for the column's value type. Pass the row model you handed to
`Table.filteredRowModel`.

```elm snippet=GlobalFiltering.elm#searchedColumnIds
```

## What this page does not cover

- **Controlled state, `onGlobalFilterChange`, and atoms.** The `State` is
  always yours. See [Table State](/guide/table-state).
- **`initialState.globalFilter`.** Call `setGlobalFilter` on
  `Table.initialState`.
- **`resetGlobalFilter(true)`.** `resetGlobalFilter` always clears the value;
  there is no "back to the initial state" variant, because the package does
  not keep a copy of your starting state.
- **The `filterFns` registry.** `Config.globalFilterFn` holds the function
  itself, not a registered name.
- **A global filter UI.** As in TanStack, no input is rendered for you. Wire
  one up as shown above.

## Example

[Column Filters](https://elm-table-examples.pages.dev/filters/), ported from
TanStack's Filters example, which includes a global search box.

<iframe src="https://elm-table-examples.pages.dev/filters/" title="Column Filters example" loading="lazy"></iframe>
