---
title: Column Definitions
id: guide/column-defs
---

Column definitions are the largest thing you write. They decide:

- what value each column reads out of a row, which is what sorting, filtering,
  grouping, faceting, and aggregation all operate on;
- the header rows, including nested header groups, and the footers;
- which columns exist for display only, such as a checkbox or a row-actions
  button.

This page is the Elm counterpart of TanStack Table's **Column Definitions
Guide**. It is about building `Table.Column` values with
[`Table.column`](/reference/module/Table#column),
[`Table.display`](/reference/module/Table#display), and
[`Table.group`](/reference/module/Table#group). For reading a column back
during rendering, see [Columns](/guide/columns).

## Column Def Types

The same three kinds of column exist here, and each has its own constructor.

| Kind | Constructor | Has an accessor | What it is for |
| --- | --- | --- | --- |
| Accessor column | `Table.column id accessor` | Yes | A column with an underlying value. Can be sorted, filtered, grouped, aggregated, and faceted. |
| Display column | `Table.display id` | No | Arbitrary content: a selection checkbox, an expander, a row-actions button. |
| Group column | `Table.group id children` | No | Nesting. Produces a header spanning its children and no cells of its own. |

Display and group columns have no value, so the sorting, filtering, and
grouping options below have nothing to work with on them. Setting one is not an
error; it simply never applies.

```elm snippet=ColumnDefs.elm#selectColumn
```

```elm snippet=ColumnDefs.elm#groupedColumns
```

`Table.group` stamps each child with its parent id and its depth, so a column
tree needs no table instance to make sense of. [Header
Groups](/guide/header-groups) covers the header rows that come out of it.

## Column Helpers

TanStack's `createColumnHelper` exists so TypeScript can infer the value type
of a column from the key or function you gave it, and so the feature set is
carried in the type. Neither problem exists here.

`Table.column` takes the accessor directly, and Elm infers `row` from it. A
list of `Table.Column Person` is checked against your data when you pass it to
`Table.rowsFromList`, so a column that reads the wrong record is a compile
error at the point you wrote it. There is no helper to construct and no type
parameter to pass.

## Creating Accessor Columns

An accessor column is an id and a function from a row to a
[`Value`](/guide/values):

```elm
Table.column : String -> (row -> Value) -> Column row
```

`Value` is the one union type the built-in sort, filter, and aggregation
functions work on. Its constructors are `String`, `Number`, `Bool`, `Date`,
`List`, and `Null`.

```elm snippet=ColumnDefs.elm#accessorColumns
```

Note the shapes: `Value.Number` takes a `Float`, so an `Int` field goes through
`toFloat`; `Value.List` takes a `List Value`, which is what the array filter
functions and the `unique` and `extent` aggregations read.

### Accessor Functions

Because the accessor is a plain function, a computed column is no different
from a stored one. Whatever the function returns is the value the whole
pipeline sees:

```elm snippet=ColumnDefs.elm#fullNameColumn
```

Reaching into nested records is the same idea: `.name >> .first >> Value.String`.
See [Data](/guide/data#deep-keyed-data).

### No `accessorKey`

TanStack offers a string shorthand, `accessorKey: 'firstName'`, plus a dotted
form for nested objects and a numeric-string form for arrays. All three are
missing here for one reason: an Elm record cannot be indexed by a string, so
there is nothing for a key to look up. Every accessor column takes a function.

Nothing is lost. `.firstName >> Value.String` is the shorthand's equivalent and
is checked by the compiler, `'name.first'` becomes `.name >> .first`, and an
array index becomes a pattern match or a `List` accessor of your own. The
warning in TanStack's guide about a literal period inside a key does not apply,
because nothing parses the id.

## Unique Column IDs

Every column carries the id you gave its constructor. There is no derivation
step: no id is guessed from a key and none is taken from a header string, so
the two rules TanStack has for when each of those applies collapse into one.

Ids must be unique across the whole column tree, group columns included,
because everything else refers to a column by id.
[`Table.getValue`](/reference/module/Table#getValue),
[`Table.toggleSort`](/reference/module/Table#toggleSort),
[`Table.setColumnFilter`](/reference/module/Table#setColumnFilter),
`State.columnOrder`, `State.columnVisibility`, and `State.columnSizing` are all
keyed by it. A duplicate id is not rejected; it makes the later column
unreachable through the earlier one's id.

[`Table.columnId`](/reference/module/Table#columnId) reads it back, and
[`Table.findColumn`](/reference/module/Table#findColumn) looks a column up in
a `Config` by id.

## Dynamic Column Definitions

A column list is an ordinary `List`, so building it from the data is just
`List.map`. See [Data](/guide/data#data-of-unknown-shape) for the row type to
use when the shape is not known ahead of time, and pick a sort and filter
function per column from whatever runtime check you can make on a sample value.

There is no stable-identity rule to observe when you do this. Nothing is
memoized against the column list, so rebuilding it is only a question of the
work it costs. Build the `Config` once where it is cheap to, which for a
generated column list means when the data arrives, not in `view`.

## Column Formatting and Rendering

This is the largest difference from TanStack. There, a column def carries
`cell`, `aggregatedCell`, `header`, and `footer` render functions, and
`flexRender` dispatches on whatever each one returned.

Here a column carries no render functions at all. You write the `Html`
yourself, in your own view, from the values the package hands you. That is what
makes `flexRender` unnecessary, and it is why the header and footer options are
plain `String` rather than functions.

### Cell Formatting

Read the value and render it however you like:

```elm
td [] [ text (Value.toString (Table.getValue config row (Table.columnId col))) ]
```

[`Value.toString`](/reference/module/Table-Value#toString) is TanStack's
`String(value)` coercion, useful as a default. Pattern match on the `Value`
instead when you want your own formatting, and reach the original record with
[`Table.rowOriginal`](/reference/module/Table#rowOriginal) when the cell needs
more than one field. [Cells](/guide/cells) covers the cell-level queries.

### Aggregated Cell Formatting

Group rows read differently from leaf rows, and you branch on that yourself.
[`Table.rowIsGrouped`](/reference/module/Table#rowIsGrouped) says whether a row
is a group row, [`Table.cellIsGrouped`](/reference/module/Table#cellIsGrouped)
says whether this is the cell of the column being grouped by, and
[`Table.cellIsAggregated`](/reference/module/Table#cellIsAggregated) says
whether the cell holds an aggregated value. [Grouping](/guide/grouping) and
[Aggregation](/guide/aggregation) walk through the branches.

### Header and Footer Text

`Table.withHeader` and `Table.withFooter` take a `String`, not a render
function. Anything richer than text is something your view builds; the string
is only the label the column carries.

Both are optional, so
[`Table.columnHeader`](/reference/module/Table#columnHeader) and
[`Table.columnFooter`](/reference/module/Table#columnFooter) return
`Maybe String`. Views usually fall back to the id:

```elm snippet=ColumnDefs.elm#headerText
```

Writing that line once and reusing it is worth doing, because every header cell
needs it. [Headers](/guide/headers) covers the header cells themselves, which
are what you render for a table with column groups.

## Feature Options on Column Defs

Every other option is a `with*` builder that takes a `Column row` and returns
one, so they pipe:

```elm snippet=ColumnDefs.elm#salaryColumn
```

The tables below list every builder that applies to a column, the field it sets
on the internal `Column` record, and the value that field starts with. They are
grouped the way TanStack groups its column options.

### Identity and Labels

| Builder | Field | Type | Default |
| --- | --- | --- | --- |
| `Table.column`, `Table.display`, `Table.group` | `id` | `String` | The first argument. Required. |
| `Table.column` | `accessorFn` | `Maybe (row -> Value)` | `Nothing` for `display` and `group`. |
| `Table.group` | `columns` | `List (Column row)` | `[]` for `column` and `display`. |
| `Table.withHeader` | `header` | `Maybe String` | `Nothing` |
| `Table.withFooter` | `footer` | `Maybe String` | `Nothing` |

`depth` and `parentId` are stamped by `Table.group` and are not settable;
`Table.columnDepth` and `Table.columnParentId` read them.

### Sorting

| Builder | Field | Type | Default | Description |
| --- | --- | --- | --- | --- |
| `Table.withSortFn` | `sortFn` | `Maybe SortFn` | `Nothing` | The built-in sort function. `Nothing` means auto-detect from the data, TanStack's `'auto'`. |
| `Table.withCustomSort` | `customSort` | `Maybe (Row row -> Row row -> Order)` | `Nothing` | Compare whole rows, so the comparison can read other columns. Takes precedence over `sortFn`. |
| `Table.withSortDescFirst` | `sortDescFirst` | `Maybe Bool` | `Nothing` | Whether the first click sorts descending. `Nothing` falls back to `Config.sortDescFirst`, then to the data. |
| `Table.withInvertSorting` | `invertSorting` | `Bool` | `False` | Flip this column's direction, for values where bigger means worse. |
| `Table.withSortUndefined` | `sortUndefined` | `Maybe SortUndefined` | `Nothing` | Where `Null` values land. `Nothing` behaves as `Table.sortNullsLast`. |
| `Table.withEnableSorting` | `enableSorting` | `Bool` | `True` | Allow sorting on this column. |
| `Table.withEnableMultiSort` | `enableMultiSort` | `Maybe Bool` | `Nothing` | Allow this column in a multi-column sort. `Nothing` falls back to `Config.enableMultiSort`. |

See [Sorting](/guide/sorting).

### Filtering

| Builder | Field | Type | Default | Description |
| --- | --- | --- | --- | --- |
| `Table.withFilterFn` | `filterFn` | `Maybe FilterFn` | `Nothing` | The built-in filter function. `Nothing` means auto-detect, TanStack's `'auto'`. |
| `Table.withCustomFilter` | `customFilter` | `Maybe (Row row -> Value -> Bool)` | `Nothing` | Decide per row, given the row and the filter value. Takes precedence over `filterFn`. |
| `Table.withEnableColumnFilter` | `enableColumnFilter` | `Bool` | `True` | Allow a column filter on this column. |
| `Table.withEnableGlobalFilter` | `enableGlobalFilter` | `Maybe Bool` | `Nothing` | Include this column in the global filter. `Just False` opts out; `Just True` opts in past the default check; `Nothing` leaves it to `Config.getColumnCanGlobalFilter`, whose default keeps a column when its first non-null value is a string or a number. A column with no accessor is never included. |

See [Column Filtering](/guide/column-filtering) and
[Global Filtering](/guide/global-filtering).

### Grouping and Aggregation

| Builder | Field | Type | Default | Description |
| --- | --- | --- | --- | --- |
| `Table.withAggregationFn` | `aggregationFn` | `Maybe AggregationFn` | `Nothing` | How a group row summarises this column. `Nothing` means auto-detect: `sum` for a numeric column, `extent` for a date column, and no aggregation for anything else. |
| `Table.withMaxAggregationDepth` | `maxAggregationDepth` | `Int` | `0` | How far below a group row the aggregation looks. `0` aggregates the group's member rows; `1` descends one level into their children first. |
| `Table.withGetGroupingValue` | `getGroupingValue` | `Maybe (row -> Int -> Value)` | `Nothing` | The value to group by when it differs from the accessor. The `Int` is the row's index. |
| `Table.withEnableGrouping` | `enableGrouping` | `Bool` | `True` | Allow grouping by this column. |

See [Grouping](/guide/grouping) and [Aggregation](/guide/aggregation).

### Faceting

| Builder | Field | Type | Default | Description |
| --- | --- | --- | --- | --- |
| `Table.withGetUniqueValues` | `getUniqueValues` | `Maybe (row -> List Value)` | `Nothing` | The faceting values of one row, when a single cell holds several. `Nothing` uses the accessor's value as the only one. |

See [Faceting](/guide/column-faceting).

### Visibility, Pinning, and Sizing

| Builder | Field | Type | Default | Description |
| --- | --- | --- | --- | --- |
| `Table.withEnableHiding` | `enableHiding` | `Bool` | `True` | Allow this column to be hidden. |
| `Table.withEnablePinning` | `enablePinning` | `Bool` | `True` | Allow this column to be pinned left or right. |
| `Table.withSize` | `size` | `Maybe Float` | `Nothing` | Width in pixels. `Nothing` falls back to `Config.defaultColumn.size`, which is `150`. |
| `Table.withMinSize` | `minSize` | `Maybe Float` | `Nothing` | Minimum width. Falls back to `Config.defaultColumn.minSize`, which is `20`. |
| `Table.withMaxSize` | `maxSize` | `Maybe Float` | `Nothing` | Maximum width. Falls back to `Config.defaultColumn.maxSize`, which is `9007199254740991`. |

`Table.columnSize` returns the size clamped between the minimum and the
maximum. See [Column Visibility](/guide/column-visibility),
[Column Pinning](/guide/column-pinning), and
[Column Sizing](/guide/column-sizing).

### Cell Spanning and Cell Selection

| Builder | Field | Type | Default | Description |
| --- | --- | --- | --- | --- |
| `Table.withEnableCellSpanning` | `enableCellSpanning` | `Bool` | `True` | Allow this column to span. |
| `Table.withSpanRows` | `spanRows` | `Maybe (SpanRows row)` | `Nothing` | Merge adjacent rows whose value for this column is equal. `Null` never merges. |
| `Table.withSpanRowsWhen` | `spanRows` | `Maybe (SpanRows row)` | `Nothing` | The predicate form of the same field, given a `RowSpanContext`. |
| `Table.withSpanColumns` | `spanColumns` | `Maybe (Row row -> Int)` | `Nothing` | How many columns this cell spans in a given row. `Table.spanAllColumns` reaches the end of the region. |
| `Table.withEnableCellSelection` | `enableCellSelection` | `Bool` | `True` | Allow this column's cells to be selected. |

See [Cell Spanning](/guide/cell-spanning) and
[Cell Selection](/guide/cell-selection).

Options that live on the `Config` rather than on a column, including every
`manual*` flag and the table-wide enable flags these columns fall back to, are
listed in [Config and State](/guide/config-and-state).

## Column Meta

TanStack column defs take a `meta` field for hanging your own typed data on a
column, usually so a render function can read it back off the column object.
There is no counterpart here.

A render function that needs extra information is a function you wrote, so pass
it what it needs. When the information really is per column, keep a
`Dict String yourThing` in your own model keyed by column id, which is the same
lookup with a type you control.
