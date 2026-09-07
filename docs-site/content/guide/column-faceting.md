---
title: Faceting
id: guide/column-faceting
---

Faceting works out what a filter UI should offer: which values a column still
has, how often each occurs, and what its numeric range is. It computes those
from the rows the table's *other* filters have already narrowed, so the
choices in one filter control stay live while the user edits it. This page is
the port of TanStack Table's **Faceting** guide.

Faceting never filters the table. It only produces values you can render.
[Column Filtering](/guide/column-filtering) owns the filter state and decides
which rows match.

## What is faceting?

For one column, faceting answers:

- Which values are available?
- How often does each occur?
- What are the smallest and largest values?
- Which rows should a facet calculation of your own run over?

That is what turns a plain checkbox list into one with counts:

```text
Department
☐ Engineering   3
☐ Design        2
☐ Sales         1
```

The names and the counts come from the faceted row model. Filter another
column to `active = True` and the counts change to describe only those rows.

### Faceting and aggregation are different

Both summarise rows, for different readers. Faceting produces metadata for a
filter control. [Aggregation](/guide/aggregation) computes a value to display,
such as a sum in a footer or on a group row. Faceted counts never create group
rows and never use a column's aggregation function.

- Filtering answers: which rows remain?
- Faceting answers: which filtering choices remain?
- Aggregation answers: what summary can be computed from these rows?

### How a facet responds to filters

A column's faceted row model applies every active filter **except that
column's own**. That is what lets a facet keep showing the alternatives the
user could switch to instead of collapsing to the one they already picked.

With a `Department` filter and a `Tags` filter:

1. The user picks `Department = Engineering`.
2. The `Tags` facet applies that filter and recounts its tags.
3. The user picks `Tags = compilers`.
4. The table shows Engineering rows tagged `compilers`.
5. The `Tags` facet still counts across all Engineering rows, because it
   leaves out its own filter.

The `Department` facet, meanwhile, now counts only rows tagged `compilers`.
That is how two facets narrow each other.

Passing [`globalFacetKey`](/reference/module/Table#globalFacetKey) as the
column id leaves out the global filter instead of a column filter, and
gathers values across every globally filterable column.

## State

Faceting has no state slice of its own. It reads `State.columnFilters` and
`State.globalFilter` to decide which filters to apply, and nothing else.

```elm
-- read, never written, by the faceting functions
-- State.columnFilters : List ColumnFilter
-- State.globalFilter : Value
```

## Config options

None are specific to faceting. Two affect it indirectly:

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableFilters` | `Bool` | `True` | `False` leaves nothing for a facet to leave out, so every facet describes the whole table. |
| `manualFiltering` | `Bool` | `False` | Faceting still applies filters itself, so it keeps working, but its counts will not match a server-filtered table. Compute facets on the server instead. |

## Column options

| Builder | Type | Default | Description |
| --- | --- | --- | --- |
| `withGetUniqueValues` | `(row -> List Value) -> Column row -> Column row` | `Nothing` | The values one row contributes to this column's facet. Without it a row contributes its single cell value. |

`withGetUniqueValues` is what a list-valued column needs: without it, a row
whose cell is `Value.List [ Value.String "navy", Value.String "compilers" ]`
contributes that whole list
as one facet value, which is not what a tag filter wants.

```elm snippet=Faceting.elm#columns
```

Because a row can contribute several values, the counts are occurrence counts
rather than row counts, and their total can be larger than the number of rows.
Return each value at most once per row if you want the counts to read as rows.
[`getUniqueValues`](/reference/module/Table#getUniqueValues) reports what one
row contributes for one column.

## Transitions

Faceting has none. It is read-only: nothing you call here changes the `State`.
A facet control writes through the ordinary filter transitions,
[`setColumnFilter`](/reference/module/Table#setColumnFilter) and
[`setGlobalFilter`](/reference/module/Table#setGlobalFilter), which are
covered on [Column Filtering](/guide/column-filtering).

## Queries

All three take the **pre-filtered** row model, the same one you hand to
`Table.filteredRowModel`, plus the column id whose own filter should be left
out.

| Function | Result | Use it for |
| --- | --- | --- |
| [`facetedRowModel`](/reference/module/Table#facetedRowModel) | `RowModel row`: the rows that pass every other active filter | A facet calculation of your own |
| [`facetedUniqueValues`](/reference/module/Table#facetedUniqueValues) | `List ( Value, Int )`: each distinct value with its count, in first-seen order | Checkboxes, select menus, autocomplete |
| [`facetedMinMax`](/reference/module/Table#facetedMinMax) | `Maybe ( Float, Float )`: the numeric range, `Nothing` when no cell coerces to a number | Number inputs and range sliders |
| [`globalFacetKey`](/reference/module/Table#globalFacetKey) | `String`, the id `"__global__"` | Pass it as the column id to facet across every globally filterable column |

`facetedUniqueValues` and `facetedMinMax` each build the faceted row model
themselves and then walk its `flatRows`, so every row of the tree contributes,
sub-rows included.

```elm snippet=Faceting.elm#prefilteredRows
```

```elm snippet=Faceting.elm#departmentOptions
```

The counts come back as an association list rather than TanStack's `Map`,
because `Value` is not `comparable` in Elm and cannot be a `Dict` key. Sort it
yourself if you want the options in an order.

```elm snippet=Faceting.elm#viewDepartmentFacet
```

For a range control, `facetedMinMax` gives the bounds:

```elm snippet=Faceting.elm#salaryRange
```

And for autocomplete on a search box, the same functions take
`Table.globalFacetKey` instead of a column id:

```elm snippet=Faceting.elm#searchSuggestions
```

When you need the rows rather than the summary, ask for the row model itself:

```elm snippet=Faceting.elm#departmentFacetRows
```

### Bucketed faceting

Dates, prices, and file sizes produce too many distinct values to list. Use
`withGetUniqueValues` to report a bucket key while the accessor keeps the raw
value for sorting and display, and give the column a filter function that
buckets the cell value the same way with
`Table.FilterFn.withResolveDataValue`.

```elm snippet=Faceting.elm#salaryBucket
```

```elm snippet=Faceting.elm#salaryBucketFilter
```

```elm snippet=Faceting.elm#salaryBucketColumn
```

Faceting and filtering have to use the same bucket definition, or the counts
will not match the rows a bucket selects. Sharing one `salaryBucket` function
between them is what keeps that true.

### Performance

Nothing is memoized in this package, so a faceting call walks the rows every
time it is made. Compute a facet once in `update` and store the result rather
than calling `facetedUniqueValues` inside a `List.map` over the options.
For a column with many distinct values, bucket them, show only the first
handful, or let the user search the list before you render it.

## What this page does not cover

- **Registering row model factories.** There is nothing to register; the three
  functions are always available.
- **Custom `facetedUniqueValues` / `facetedMinMaxValues` factories for
  server-side faceting.** There is no factory slot to override. Fetch the
  server's facets into your own model and render from that; the package's
  faceting functions are ordinary functions you can simply not call.
- **Memoization.** TanStack caches these row models. Here you decide what to
  keep, as with every other row model. See [Row Models](/guide/row-models).
- **`table.getGlobalFacetedRowModel()` and friends.** There is no separate
  global set of functions: pass `Table.globalFacetKey` to the same three.

## Example

[Faceted Filters](https://elm-table-examples.pages.dev/filters-faceted/),
ported from TanStack's Faceted Filters example.

<iframe src="https://elm-table-examples.pages.dev/filters-faceted/" title="Faceted Filters example" loading="lazy"></iframe>
