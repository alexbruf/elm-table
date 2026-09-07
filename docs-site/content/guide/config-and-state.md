---
title: Config and State
id: guide/config-and-state
---

This page replaces TanStack Table's **Table Instance Guide**. That page is
about the `table` object returned by `useTable`, `createTable`, or
`injectTable`: the one place that holds the options, the state, the APIs, and
the row models, and the thing every render function reaches back into.

There is no table instance here. Nothing is constructed, nothing is held, and
no function reaches into a shared object. In its place are three values you
pass around explicitly.

## The Three Values

| Value | What it holds | Where it lives |
| --- | --- | --- |
| `Table.Config row` | The columns and every feature flag. Nothing that changes as the user works. | Built once, at the top level of a module. |
| `Table.State` | Every slice the user can change: sorting, filters, grouping, expansion, selection, pagination, column order, visibility, pinning, sizing, cell selection. | Your model. |
| `Table.RowModel row` | The processed rows: the row tree, the same rows flattened, and a lookup by id. | Computed from the two above plus your data. |

Almost every function in the package has the shape
`Config row -> State -> ... -> a`. Two tables therefore share nothing by
accident, and every transition is a value you can inspect, log, or store.

### Your Data

Any type works, and it never enters the `Config`. It is passed to whichever
pipeline function you call, so the same `Config` can process two different
lists. See [Data](/guide/data).

### Your Columns

Column definitions are the first argument to `Table.config`. See
[Column Definitions](/guide/column-defs) for the constructors and the full set
of per-column options.

### Building the Config

`Table.config` takes the column list and fills in TanStack's default for every
flag. The `with*` builders pipe onto it:

```elm snippet=ConfigState.elm#config
```

Build it once at the top level. It holds no state, so there is nothing to
recompute, and putting it in `view` rebuilds the column tree on every frame.
A `Config` that depends on runtime data, a generated column list or a
server-reported row count, is built where that data arrives, in `init` or
`update`.

`Config` is a plain record, so any field without a builder is a record update:

```elm snippet=ConfigState.elm#noGlobalFilter
```

Later versions of the package may add fields. That breaks code which pattern
matches on the record, and does not break a record update.

## Config Builders

Twelve options have a builder. They exist for the options whose values are
functions, where a builder reads better than a record update.

| Builder | Sets | Description |
| --- | --- | --- |
| [`withGetRowId`](/reference/module/Table#withGetRowId) | `getRowId` | Give rows stable ids from your own key. |
| [`withSubRows`](/reference/module/Table#withSubRows) | `getSubRows` | Reach a row's children in your data. |
| [`withDefaultColumn`](/reference/module/Table#withDefaultColumn) | `defaultColumn` | Change the size, minimum, and maximum every column falls back to. |
| [`withGlobalFilterFn`](/reference/module/Table#withGlobalFilterFn) | `globalFilterFn` | The filter function the global filter uses. |
| [`withRowSelection`](/reference/module/Table#withRowSelection) | `enableRowSelection` | Decide per row whether it can be selected. |
| [`withRowCanExpand`](/reference/module/Table#withRowCanExpand) | `getRowCanExpand` | Decide per row whether it can be expanded. |
| [`withIsRowExpanded`](/reference/module/Table#withIsRowExpanded) | `getIsRowExpanded` | Decide per row whether it is expanded, ignoring `State.expanded`. |
| [`withCellSpanning`](/reference/module/Table#withCellSpanning) | `enableCellSpanning` | Allow cell spanning table-wide. |
| [`withCellSelection`](/reference/module/Table#withCellSelection) | `enableCellSelection` | Allow cell selection table-wide. |
| [`withCellSelectionWhen`](/reference/module/Table#withCellSelectionWhen) | `cellSelectionFilter` | Decide per cell whether it can be selected. |
| [`withCellRangeSelection`](/reference/module/Table#withCellRangeSelection) | `enableCellRangeSelection` | Allow a selection to be extended into a range. |
| [`withMultiCellRangeSelection`](/reference/module/Table#withMultiCellRangeSelection) | `enableMultiCellRangeSelection` | Allow more than one range. |

## Config Options

Every field of `Table.Config row`, with the value `Table.config` gives it.

### Core

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `columns` | `List (Column row)` | The argument to `Table.config` | The column tree. |
| `getRowId` | `Maybe (row -> Int -> Maybe String -> String)` | `Nothing` | Row id from the datum, its index among its siblings, and its parent's id. `Nothing` uses the index path: `"0"`, `"0.1"`. |
| `getSubRows` | `row -> List row` | `\_ -> []` | A row's children. The default is a flat table. |

### Manual (Server-Side) Flags

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `manualFiltering` | `Bool` | `False` | Skip the filtered stage. |
| `manualGrouping` | `Bool` | `False` | Skip the grouped stage. |
| `manualSorting` | `Bool` | `False` | Skip the sorted stage. |
| `manualExpanding` | `Bool` | `False` | Skip the expanded stage. |
| `manualPagination` | `Bool` | `False` | Skip the paginated stage. |

See [Client-Side vs Server-Side](/guide/client-side-vs-server-side).

### Sorting

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableSorting` | `Bool` | `True` | Allow sorting anywhere in the table. |
| `enableMultiSort` | `Bool` | `True` | Allow more than one sorted column. |
| `maxMultiSortColCount` | `Int` | `9007199254740991` | How many columns a multi-sort may hold. The default is `Number.MAX_SAFE_INTEGER`, which is no practical limit. |
| `enableSortingRemoval` | `Bool` | `True` | Let the sort cycle return to unsorted rather than stopping at descending. |
| `enableMultiRemove` | `Bool` | `True` | Let a column be removed from a multi-sort. |
| `sortDescFirst` | `Maybe Bool` | `Nothing` | Table-wide first sort direction. `Nothing` leaves it to the column, then to the data. |

### Filtering

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableFilters` | `Bool` | `True` | Allow filtering at all, column and global. |
| `enableColumnFilters` | `Bool` | `True` | Allow per-column filters. |
| `enableGlobalFilter` | `Bool` | `True` | Allow the global filter. |
| `getColumnCanGlobalFilter` | `Maybe (Column row -> Bool)` | `Nothing` | Which columns the global filter searches. `Nothing` keeps a column whose first non-null value is a string or a number. |
| `globalFilterFn` | `Maybe FilterFn` | `Nothing` | The global filter's function. `Nothing` means auto-detect. |
| `filterFromLeafRows` | `Bool` | `False` | Filter leaf rows and keep their ancestors, instead of filtering parents first. |
| `maxLeafRowFilterDepth` | `Int` | `100` | How deep filtering descends into sub-rows. |

See [Column Filtering](/guide/column-filtering) and
[Global Filtering](/guide/global-filtering).

### Grouping and Expanding

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableGrouping` | `Bool` | `True` | Allow grouping. |
| `groupedColumnMode` | `GroupedColumnMode` | `Table.groupedColumnsReorder` | What happens to a column that is being grouped by: `groupedColumnsReorder` moves it to the front, `groupedColumnsRemove` drops it, `groupedColumnsIgnore` leaves it. |
| `enableExpanding` | `Bool` | `True` | Allow expanding. |
| `getRowCanExpand` | `Maybe (Row row -> Bool)` | `Nothing` | Override the "has sub-rows" rule per row. |
| `getIsRowExpanded` | `Maybe (Row row -> Bool)` | `Nothing` | Decide expansion from the row instead of from `State.expanded`. |

See [Grouping](/guide/grouping), [Aggregation](/guide/aggregation), and
[Expanding](/guide/expanding).

### Pagination

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `paginateExpandedRows` | `Bool` | `True` | Count expanded sub-rows towards the page size. `False` keeps a parent's expanded children on its page. |
| `pageCount` | `Maybe Int` | `Nothing` | A server-reported page count. `Just -1` means unknown. |
| `rowCount` | `Maybe Int` | `Nothing` | A server-reported row count. |

See [Pagination](/guide/pagination).

### Row Selection and Row Pinning

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableRowSelection` | `Row row -> Bool` | `always True` | Whether a row can be selected. |
| `enableMultiRowSelection` | `Row row -> Bool` | `always True` | Whether selecting a row keeps the others selected. |
| `enableSubRowSelection` | `Row row -> Bool` | `always True` | Whether selecting a parent selects its children. |
| `enableRowPinning` | `Row row -> Bool` | `always True` | Whether a row can be pinned. |
| `keepPinnedRows` | `Bool` | `True` | Take pinned rows from the pre-pagination model, so a pinned row stays visible when it is not on the current page. `False` pins only rows of the current page. |

These four take a `Row row` rather than a `Bool`, because TanStack accepts
either a boolean or a per-row predicate; `always True` and `always False` cover
the boolean cases. See [Row Selection](/guide/row-selection) and
[Row Pinning](/guide/row-pinning).

### Columns

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableColumnPinning` | `Bool` | `True` | Allow column pinning. |
| `enableHiding` | `Bool` | `True` | Allow columns to be hidden. |
| `defaultColumn` | `SizeDefaults` | `{ size = 150, minSize = 20, maxSize = 9007199254740991 }` | The sizes a column falls back to when it sets none. |

See [Column Pinning](/guide/column-pinning),
[Column Visibility](/guide/column-visibility), and
[Column Sizing](/guide/column-sizing).

### Cell Spanning and Cell Selection

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableCellSpanning` | `Bool` | `True` | Allow cells to span. `False` makes every span `1`. |
| `enableCellSelection` | `Bool` | `True` | Allow cells to be selected. |
| `cellSelectionFilter` | `Maybe (Cell -> Bool)` | `Nothing` | A per-cell check applied on top of the table and column flags. |
| `enableCellRangeSelection` | `Bool` | `True` | Allow a selection to be extended into a rectangle. |
| `enableMultiCellRangeSelection` | `Bool` | `True` | Allow further rectangles to be added or subtracted. |

See [Cell Spanning](/guide/cell-spanning) and
[Cell Selection](/guide/cell-selection).

## State

`Table.State` is one record with thirteen slices, one per feature. It is yours:
you put it in your model, you pass it to every function, and you replace it
with what a transition returns. Nothing in the package holds a copy, so what
you store is the whole truth.

[`Table.initialState`](/reference/module/Table#initialState) is every slice at
its default.

| Slice | Type | `initialState` | Feature |
| --- | --- | --- | --- |
| `sorting` | `List SortColumn` | `[]` | [Sorting](/guide/sorting). Each entry is `{ id : String, desc : Bool }`, in priority order. |
| `columnFilters` | `List ColumnFilter` | `[]` | [Column Filtering](/guide/column-filtering). Each entry is `{ id : String, value : Value }`. |
| `globalFilter` | `Value` | `Value.Null` | [Global Filtering](/guide/global-filtering). `Null` and `String ""` both mean no filter. |
| `grouping` | `List String` | `[]` | [Grouping](/guide/grouping). Column ids, outermost first. |
| `expanded` | `Expanded` | `Table.expandedIds Set.empty` | [Expanding](/guide/expanding). Either `expandedIds` with a set of row ids or `Table.expandAll`. |
| `rowSelection` | `Set String` | `Set.empty` | [Row Selection](/guide/row-selection). Selected row ids. |
| `pagination` | `Pagination` | `{ pageIndex = 0, pageSize = 10 }` | [Pagination](/guide/pagination). |
| `columnOrder` | `List String` | `[]` | [Column Ordering](/guide/column-ordering). Empty means the order in the `Config`. |
| `columnVisibility` | `Dict String Bool` | `Dict.empty` | [Column Visibility](/guide/column-visibility). A missing key means visible. |
| `columnPinning` | `ColumnPinning` | `{ left = [], right = [] }` | [Column Pinning](/guide/column-pinning). Column ids per edge. |
| `columnSizing` | `Dict String Float` | `Dict.empty` | [Column Sizing](/guide/column-sizing). A missing key uses the column's own size. |
| `rowPinning` | `RowPinning` | `{ top = [], bottom = [] }` | [Row Pinning](/guide/row-pinning). Row ids per edge. |
| `cellSelection` | `List CellSelectionRange` | `[]` | [Cell Selection](/guide/cell-selection). Rectangles, applied in order. |

`State` is a plain record too, so starting somewhere other than the default is
a record update on `initialState`:

```elm snippet=ConfigState.elm#startingState
```

### Transitions

Every state change is a function ending in `State -> State`, so it composes
with `|>` and returns a value you store. `Table.toggleSort`,
`Table.setColumnFilter`, `Table.setPage`, `Table.toggleRowSelected`, and the
rest are listed on the feature guides.

Three of them take a `RowModel` as well, because their answer depends on the
data: `toggleSort` needs the automatic first sort direction,
`setColumnFilter` needs to know whether the filter should auto-remove itself,
and `toggleExpanded` needs the row tree. Pass the model you already have.

Each feature also has a `resetX`, which returns that slice to the package's
default rather than to a starting state you chose. There is no instance
carrying your `initialState` around. To go back to your own starting point,
call the matching `setX` with it.

## Queries

The functions you call while rendering all take the `Config`, usually the
`State`, and sometimes a `RowModel`:

```elm
Table.visibleLeafColumns : Config row -> State -> List (Column row)
Table.getIsSorted : State -> String -> Maybe SortDir
Table.getValue : Config row -> Row row -> String -> Value
```

They are the counterpart of TanStack's `table.getVisibleLeafColumns()`,
`column.getIsSorted()`, and `cell.getValue()`, with the receiver passed in
rather than captured. The full list is in the
[Table module reference](/reference/module/Table), and the API reference pages
group them the way TanStack's do:
[Table API](/reference/table-api), [Column API](/reference/column-api),
[Row API](/reference/row-api), [Cell API](/reference/cell-api), and
[Header API](/reference/header-api).

## Row Models

[`Table.rowsFromList`](/reference/module/Table#rowsFromList) runs the whole
pipeline: core, filtered, grouped, sorted, expanded, paginated. Each stage is
also exposed on its own, so you can stop early or inspect what one stage did.

Nothing is memoized, so the row model is computed exactly when you call for it.
That makes it the third thing worth keeping in your model, next to the `State`:

```elm
type alias Model =
    { state : Table.State
    , rowModel : Table.RowModel Person
    }
```

Recompute it in `update`, when the state or the data changes, rather than in
`view`:

```elm snippet=ConfigState.elm#update
```

```elm snippet=ConfigState.elm#recompute
```

[Row Models](/guide/row-models) covers the stages themselves.
[Table State](/guide/table-state) covers the ownership patterns: a table
inside a larger model, two tables side by side, keeping the row model in step,
and resetting a slice.
