---
title: Table API
id: reference/table-api
---

TanStack's Table API Reference documents the table instance: the object `constructTable` returns, the options it is given, the state it holds, and the feature registry that decides which of its methods exist. elm-table has no table instance. A table is a `Config` (what the columns are and which flags are set), a `State` (what the user has done), and the row-model functions that turn the two into rows. This page maps TanStack's entries onto ours. Full signatures and doc comments live on the generated [`Table` module page](/reference/module/Table).

## Types and construction

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `Table` | — | No table instance. Pass a [`Config`](/reference/module/Table#Config) and a [`State`](/reference/module/Table#State) to the function you want; see [Config and State](/guide/config-and-state). |
| `TableOptions` | [`Config`](/reference/module/Table#Config) | A plain record, built once with [`config`](/reference/module/Table#config) and adjusted with the builders below or by record update. |
| `TableState` | [`State`](/reference/module/Table#State) | A plain record you keep in your own model. See [Table State](/guide/table-state). |
| `TableMeta` | — | No meta bag. Anything a renderer needs that is not a column value stays in your own model. |
| `TableFeature` | — | No feature registry. Every feature is compiled into the package and is inert until its state slice is non-empty. |
| `TableFeatures` | — | Same reason. There is no type parameter for "which features are on". |
| `StockFeatures` | — | Same reason. |
| `CoreFeatures` | — | Same reason. |
| `constructTable` | — | Nothing to construct. [`config`](/reference/module/Table#config) makes the config; [`rows`](/reference/module/Table#rows) makes the row model. |
| `tableOptions` | [`config`](/reference/module/Table#config) | TanStack's helper only fixes inference on an options object. Ours actually builds the record, with TanStack's defaults for every flag. |
| `tableFeatures` | — | No feature registry to declare. |
| `getInitialTableState` | [`initialState`](/reference/module/Table#initialState) | A value, not a function: nothing sorted, nothing filtered, nothing grouped, page 0 of size 10. |
| `DebugOptions` | — | No debug flags. The pipeline is a chain of pure functions you can call one stage at a time; see [Row Models](/guide/row-models). |

## State ownership

TanStack v9 stores each state slice in an atom and hands you `onChange` callbacks. In Elm the state is already yours: a transition takes a `State` and returns a new one, and you store it in your model.

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `BaseAtoms` | — | No atoms. [`State`](/reference/module/Table#State) is a record in your model. |
| `Atoms` | — | No derived atoms. Every read is a function of `Config` and `State`. |
| `ExternalAtoms` | — | Nothing to take ownership of, because state is external by default. |
| `OnChangeFn` | — | Transitions return a `State`. You decide what to do with it. |
| `Updater` | — | No "value or function" argument. A transition is already `State -> State`. |

## React-only entries

These are entries in TanStack's React adapter. Elm has no hooks and no component render props, so none of them has a counterpart. Rendering is entirely your code.

| TanStack | elm-table | Notes |
| --- | --- | --- |
| `useTable` | — | No hooks. Hold `Config` and `State` in your model. |
| `createTableHook` | — | No hooks to compose. |
| `ReactTable` | — | No framework-specific table type. |
| `AppReactTable` | — | Same reason. |
| `CreateTableHookOptions` | — | Same reason. |
| `Subscribe` | — | No subscriptions to state slices. An Elm `update` already runs on every message. |
| `FlexRender` | — | Column definitions hold data, not renderers. See [Column Definitions](/guide/column-defs). |
| `flexRender` | — | Write the `Html` yourself from the column id, the header string, and the cell value. |

## Config builders

Everything on this page's TanStack side that does exist here is reached through these. [`config`](/reference/module/Table#config) starts from TanStack's defaults; each builder changes one field. `Config` is a plain record, so any field the builders do not cover (`manualSorting`, `enableGrouping`, `filterFromLeafRows`, `pageCount`, and the rest) is set by record update.

| Value | What it does |
| --- | --- |
| [`config`](/reference/module/Table#config) | Builds a `Config` from a list of columns, with TanStack's defaults for every flag. |
| [`initialState`](/reference/module/Table#initialState) | The starting `State`. |
| [`withGetRowId`](/reference/module/Table#withGetRowId) | Give rows stable ids from the datum, its index among its siblings, and its parent's row id. Without it, root rows are `"0"`, `"1"`, and children `"0.1"`, `"0.2"`. |
| [`withSubRows`](/reference/module/Table#withSubRows) | Tell the core row model how to reach a row's children. |
| [`withDefaultColumn`](/reference/module/Table#withDefaultColumn) | Override the default column sizing (`150`, `20`, `9007199254740991`). |
| [`withGlobalFilterFn`](/reference/module/Table#withGlobalFilterFn) | Set the filter function the global filter uses. |
| [`withRowSelection`](/reference/module/Table#withRowSelection) | Decide per row whether it can be selected. |
| [`withRowCanExpand`](/reference/module/Table#withRowCanExpand) | Per-row override for "can this row expand?". It wins over `enableExpanding` and over the "has sub-rows" rule. |
| [`withIsRowExpanded`](/reference/module/Table#withIsRowExpanded) | Per-row override for "is this row expanded?". It wins over `State.expanded`. |
| [`withCellSpanning`](/reference/module/Table#withCellSpanning) | Allow or forbid cell spanning for the whole table. |
| [`withCellSelection`](/reference/module/Table#withCellSelection) | Allow or forbid cell selection for the whole table. |
| [`withCellSelectionWhen`](/reference/module/Table#withCellSelectionWhen) | Decide per cell whether it can be selected, replacing the boolean above. |
| [`withCellRangeSelection`](/reference/module/Table#withCellRangeSelection) | Allow or forbid extending a cell selection into a range, which is what shift-click and drag do. |
| [`withMultiCellRangeSelection`](/reference/module/Table#withMultiCellRangeSelection) | Allow or forbid adding and subtracting further rectangles, which is what ctrl-click and meta-click do. |

Two builders that read as table-level in TanStack are column builders here: [`withMaxAggregationDepth`](/reference/module/Table#withMaxAggregationDepth) and [`withEnableCellSelection`](/reference/module/Table#withEnableCellSelection) take a `Column`. They are on the [Column API](/reference/column-api) page.
