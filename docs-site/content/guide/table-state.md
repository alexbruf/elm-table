---
title: Table State
id: guide/table-state
---

TanStack Table describes itself as a state-management coordinator for tables.
The same sentence fits this package, with one change: the state is a plain
record that lives in your own model, and nothing in the package keeps a copy of
it.

`Table.State` is a record with one field per feature. You create one with
[`Table.initialState`](/reference/module/Table#initialState), store it in your
model, hand it to every function that needs it, and replace it when something
happens. There is no table instance, no store, and no subscription.

## The state record

```elm
type alias State =
    { sorting : List SortColumn
    , columnFilters : List ColumnFilter
    , globalFilter : Value
    , grouping : List String
    , expanded : Expanded
    , rowSelection : Set String
    , pagination : Pagination
    , columnOrder : List String
    , columnVisibility : Dict String Bool
    , columnPinning : ColumnPinning
    , columnSizing : Dict String Float
    , rowPinning : RowPinning
    , cellSelection : List CellSelectionRange
    }
```

Every slice is always present. TanStack v9 only creates a state slice for a
feature you registered in `features`; here the record is fixed, and a feature
you never touch simply leaves its slice at the value `Table.initialState` gave
it.

| Slice | Type | `initialState` | Guide |
| --- | --- | --- | --- |
| `sorting` | `List Table.SortColumn` (`{ id : String, desc : Bool }`) | `[]` | [Sorting](/guide/sorting) |
| `columnFilters` | `List Table.ColumnFilter` (`{ id : String, value : Value }`) | `[]` | [Column Filtering](/guide/column-filtering) |
| `globalFilter` | `Table.Value.Value` | `Value.Null` | [Global Filtering](/guide/global-filtering) |
| `grouping` | `List String` | `[]` | [Grouping](/guide/grouping) |
| `expanded` | `Table.Expanded` | `Table.expandedIds Set.empty` | [Expanding](/guide/expanding) |
| `rowSelection` | `Set String` | `Set.empty` | [Row Selection](/guide/row-selection) |
| `pagination` | `Table.Pagination` (`{ pageIndex : Int, pageSize : Int }`) | `{ pageIndex = 0, pageSize = 10 }` | [Pagination](/guide/pagination) |
| `columnOrder` | `List String` | `[]` | [Column Ordering](/guide/column-ordering) |
| `columnVisibility` | `Dict String Bool` | `Dict.empty` | [Column Visibility](/guide/column-visibility) |
| `columnPinning` | `Table.ColumnPinning` (`{ left : List String, right : List String }`) | `{ left = [], right = [] }` | [Column Pinning](/guide/column-pinning) |
| `columnSizing` | `Dict String Float` | `Dict.empty` | [Column Sizing](/guide/column-sizing) |
| `rowPinning` | `Table.RowPinning` (`{ top : List String, bottom : List String }`) | `{ top = [], bottom = [] }` | [Row Pinning](/guide/row-pinning) |
| `cellSelection` | `List Table.CellSelectionRange` | `[]` | [Cell Selection](/guide/cell-selection) |

`Table.Expanded` is the one slice that is not a plain data structure. It is
either [`Table.expandAll`](/reference/module/Table#expandAll) (TanStack's
`expanded: true`) or
[`Table.expandedIds`](/reference/module/Table#expandedIds) wrapping a
`Set String`. Read it back with
[`Table.expandedIdsOf`](/reference/module/Table#expandedIdsOf), which gives
`Nothing` for `expandAll`.

## Accessing table state

Read a slice off the record:

```elm
model.state.pagination.pageIndex

model.state.sorting
```

Or use the query function a feature exposes, which applies that feature's rules
instead of making you re-derive them:

```elm
Table.getIsSorted model.state "age"

Table.getFilterValue model.state "firstName"

Table.getIsGrouped model.state "department"
```

TanStack's page spends most of its length on how to read state without
re-rendering too much: `table.atoms`, `table.store`, the `useTable` selector,
and `table.Subscribe`. None of that has a counterpart here. Elm's update loop
already decides when `view` runs, and a read of `model.state` is a plain record
access with no subscription attached.

## Setting table state

Every transition has the shape `... -> State -> State`. It is a pure function
from one state to the next, so it composes with `|>` and can be tested on its
own:

```elm
{ model | state = Table.setPage config 2 model.state }
```

Prefer the transitions over editing the record by hand. They carry the feature's
own rules: [`setColumnFilter`](/reference/module/Table#setColumnFilter) drops a
blank filter value instead of storing it,
[`setPage`](/reference/module/Table#setPage) clamps to the page count,
[`setPageSize`](/reference/module/Table#setPageSize) moves the page index so the
row at the top of the page stays in view, and
[`toggleSort`](/reference/module/Table#toggleSort) respects the multi-sort cap.
Writing the record field yourself skips all of that.

```elm snippet=TableState.elm#update
```

### Which row model a transition wants

Three transitions take a `Table.RowModel row` as well as the state, because
their answer depends on the data:
[`toggleSort`](/reference/module/Table#toggleSort) has to sample values to pick
a first sort direction, [`setColumnFilter`](/reference/module/Table#setColumnFilter)
has to find the column's automatic filter function to decide whether the value
auto-removes, and [`toggleExpanded`](/reference/module/Table#toggleExpanded) has
to turn `expandAll` into concrete row ids before the change lands.

Each one wants a different stage of the [pipeline](/guide/row-models):

| Transition | Stage it wants | Why |
| --- | --- | --- |
| `setColumnFilter`, `setColumnFilters` | the core row model | filtering runs after the core stage, so the values it inspects are the unfiltered ones |
| `toggleSort` | the pre-sort model: core, filtered, grouped | sorting runs on the grouped model, so the first sort direction is sampled from the rows that will actually be sorted |
| `toggleExpanded` | the sorted model | expansion runs on the sorted model, so that is where the expandable row ids come from |

```elm snippet=TableState.elm#coreOnly
```

```elm snippet=TableState.elm#preSorted
```

```elm snippet=TableState.elm#preExpanded
```

Passing the full [`Table.rows`](/reference/module/Table#rows) result to all
three is common in small tables and is what the
[Quick Start](/quick-start) example does. It gives the same answer whenever the
later stages do not remove rows these functions read, which stops being true
once pagination cuts the row list down or a manual stage is switched on. Passing
the stage named above is always right.

## Storing the row model next to the state

Nothing in this package is memoized. Every call recomputes from its `Config`,
`State`, and data, so calling `Table.rows` twice does the work twice. The usual
answer is to compute the row model once per `update` and store it in the model
beside the state:

```elm
type alias Model =
    { data : List Person
    , state : Table.State
    , rowModel : Table.RowModel Person
    }
```

One helper keeps the two in step. Every branch of `update` that changes the
state or the data goes through it, and `view` only ever reads `model.rowModel`:

```elm snippet=TableState.elm#withState
```

```elm snippet=TableState.elm#init
```

The rule is: the stored row model must be rebuilt whenever the state changes or
the data changes. If you forget, the table renders the previous state's rows.

## Custom initial state

To start with something other than the defaults, build a state value once and
use it in `init`.

Elm's record update syntax needs a plain name on the left, so bind
`Table.initialState` first:

```elm snippet=TableState.elm#startState
```

The same thing written with transitions, which is safer because each one applies
its feature's rules:

```elm snippet=TableState.elm#startStateFromTransitions
```

Unlike TanStack's `initialState` table option, this is just a value. The package
never sees it and never remembers it, which is what the next section is about.

## Resetting

`resetX` puts a slice back to the **feature's built-in default**, not back to a
starting state you supplied. It is TanStack's `resetX(table, true)`, the
"blank/default state" form. TanStack's plain `table.resetSorting()` resets to
`table.initialState`, and there is no table instance here to hold one.

| Function | Puts the slice back to |
| --- | --- |
| [`resetSorting`](/reference/module/Table#resetSorting) | `sorting = []` |
| [`resetColumnFilters`](/reference/module/Table#resetColumnFilters) | `columnFilters = []` |
| [`resetGlobalFilter`](/reference/module/Table#resetGlobalFilter) | `globalFilter = Value.Null` |
| [`resetGrouping`](/reference/module/Table#resetGrouping) | `grouping = []` |
| [`resetExpanded`](/reference/module/Table#resetExpanded) | `expanded = Table.expandedIds Set.empty` |
| [`resetRowSelection`](/reference/module/Table#resetRowSelection) | `rowSelection = Set.empty` |
| [`resetPagination`](/reference/module/Table#resetPagination) | `pagination = { pageIndex = 0, pageSize = 10 }` |
| [`resetPageIndex`](/reference/module/Table#resetPageIndex) | `pageIndex = 0` |
| [`resetPageSize`](/reference/module/Table#resetPageSize) | `pageSize = 10` |
| [`resetColumnOrder`](/reference/module/Table#resetColumnOrder) | `columnOrder = []`, restoring definition order |
| [`resetColumnVisibility`](/reference/module/Table#resetColumnVisibility) | `columnVisibility = Dict.empty`, which shows every column |
| [`resetColumnPinning`](/reference/module/Table#resetColumnPinning) | `columnPinning = { left = [], right = [] }` |
| [`resetColumnSizing`](/reference/module/Table#resetColumnSizing) | `columnSizing = Dict.empty` |
| [`resetColumnSize`](/reference/module/Table#resetColumnSize) | one column's entry removed, the rest left alone |
| [`resetRowPinning`](/reference/module/Table#resetRowPinning) | `rowPinning = { top = [], bottom = [] }` |

`cellSelection` has no `resetCellSelection`; the equivalent is
[`clearCellSelection`](/reference/module/Table#clearCellSelection), which drops
every range.

To go back to *your* starting state, call the matching `setX` with the value you
started from. Keep that value in scope, the way `startState` above is a
top-level declaration, and restoring one slice is one call:

```elm
Table.setSorting startState.sorting model.state
```

## Controlled state

There is no controlled/uncontrolled split, because the state is always yours.
TanStack has to offer `initialState`, external `state` plus `on[State]Change`,
and external atoms, so an app can decide which slices it owns. Here the answer
is fixed: you own all of them.

That removes several TanStack options outright. There is no `state` option, no
`atoms` option, no `on[State]Change` callback, and no `onStateChange`. The
"updater is a value or a function" question does not arise either, since a
transition is already a function from the old state to the new one and you can
wrap it in any function of your own.

Server-side work, which is TanStack's main reason for controlled state, is a
matter of reading the slice you need out of your model and putting it in the
request, plus a `manual` flag on the config. See
[Client-Side vs Server-Side](/guide/client-side-vs-server-side).

## Putting state in a URL or a flag

Because `Table.State` is a plain record of plain data, a slice can be written to
a query string, a flag, or `localStorage` without going through the package.
There is no serializer in the package; the encoding is yours to pick.

```elm snippet=TableState.elm#sortingParam
```

```elm snippet=TableState.elm#sortingFromParam
```

Feed the decoded slice back in through the matching `setX` so the feature's
rules still apply, then build the row model from the result:

```elm snippet=TableState.elm#stateFromParams
```

`expanded` is the one slice that needs an accessor rather than a field read,
because `Table.Expanded` is opaque:

```elm snippet=TableState.elm#expandedParam
```

## What TanStack's page covers that this one does not

- **`table.atoms`, `table.store`, `table.state`, selectors, and
  `table.Subscribe`.** These exist so a React component can re-render on some
  state changes and not others. Elm decides that itself.
- **`on[State]Change` callbacks and state updaters.** A transition returns the
  next state; what you do with it is ordinary `update` code.
- **Feature-based state.** TanStack only creates a slice for a registered
  feature. Every slice is always present here, and a feature you do not use
  costs you its `initialState` value and nothing more.
- **State types.** TanStack exports `SortingState`, `PaginationState`,
  `TableState<typeof features>` and so on for annotating React state. The Elm
  types are the ones in the table above, all exposed from `Table`:
  `SortColumn`, `ColumnFilter`, `Pagination`, `ColumnPinning`, `RowPinning`,
  `Expanded`, `CellSelectionRange`, and `State` itself.
