---
title: Sorting
id: guide/sorting
---

Sorting orders the rows of every level of the row tree by one or more columns.
The order is held in one state slice, `State.sorting`, and applied by the
`sortedRowModel` stage of the [pipeline](/guide/row-models). This page is the
port of TanStack Table's **Sorting** guide.

There is nothing to register and no feature to add. The sorting stage is always
in the pipeline; with an empty `State.sorting` it returns its input unchanged.

```elm snippet=Sorting.elm#sortedRows
```

## Sorting state

`State.sorting` is a list, so the table can be sorted by several columns at
once. The first entry decides, the second breaks its ties, and the row's
original index breaks the last tie, which makes the sort stable.

```elm
type alias SortColumn =
    { id : String
    , desc : Bool
    }


-- State.sorting : List SortColumn
-- Table.initialState.sorting == []
```

You own the `State`, so there is no "controlled" and "uncontrolled" split to
choose between. To start a table pre-sorted, build your initial state from
`Table.initialState`:

```elm
initialState : Table.State
initialState =
    Table.setSorting [ { id = "lastName", desc = True } ] Table.initialState
```

## Config options

These are fields of the `Config` record, which is TanStack's `TableOptions`.
`Table.config` sets the defaults below; change one with a record update.

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableSorting` | `Bool` | `True` | Sorting for the whole table. `False` makes [`getCanSort`](/reference/module/Table#getCanSort) answer `False` for every column. |
| `enableMultiSort` | `Bool` | `True` | Whether a column may join an existing sort. A column's own `withEnableMultiSort` wins over this. |
| `maxMultiSortColCount` | `Int` | `9007199254740991` | How many columns a multi-sort keeps. Adding one past the cap drops the oldest entry from the front of the list. |
| `enableSortingRemoval` | `Bool` | `True` | Whether the toggle cycle may return to "not sorted". |
| `enableMultiRemove` | `Bool` | `True` | Whether the toggle cycle may return to "not sorted" during a multi-sort. |
| `sortDescFirst` | `Maybe Bool` | `Nothing` | The first direction a click sorts in, for every column. `Nothing` leaves the choice to the data. |
| `manualSorting` | `Bool` | `False` | `True` makes `Table.sortedRowModel` return its input untouched. |

```elm snippet=Sorting.elm#sortLimitedConfig
```

### Manual server-side sorting

Set `manualSorting = True` when the server returns rows already in order. The
sorting stage then passes the row model straight through, but every query
function still works, so your headers keep their arrows and your `Msg` handler
still calls `Table.toggleSort`. Read `State.sorting` and send it with your
request. See [Client-Side vs Server-Side](/guide/client-side-vs-server-side).

## Column options

| Builder | Type | Default | Description |
| --- | --- | --- | --- |
| `withSortFn` | `SortFn -> Column row -> Column row` | `Nothing` | The comparison for this column's cell values. |
| `withCustomSort` | `(Row row -> Row row -> Order) -> Column row -> Column row` | `Nothing` | A comparison on whole rows, used instead of a `SortFn`. |
| `withSortDescFirst` | `Bool -> Column row -> Column row` | `Nothing` | First click sorts descending (`True`) or ascending (`False`). |
| `withInvertSorting` | `Bool -> Column row -> Column row` | `False` | Flip the resulting row order without changing the asc/desc cycle. |
| `withSortUndefined` | `SortUndefined -> Column row -> Column row` | `Nothing` | Where `Null` cell values go. |
| `withEnableSorting` | `Bool -> Column row -> Column row` | `True` | Sorting for this column. |
| `withEnableMultiSort` | `Bool -> Column row -> Column row` | `Nothing` | Whether this column may join an existing sort. `Nothing` falls back to `Config.enableMultiSort`. |

A column with no accessor (a display column) can never sort, whatever these
say.

```elm snippet=Sorting.elm#columns
```

### Sort functions

`Table.SortFn.SortFn` is a comparison between two cell `Value`s in ascending
order, plus an optional normaliser that runs on both sides first. Descending
order is applied by the row model, so a `SortFn` never has to think about
direction.

| `Table.SortFn` | What it compares |
| --- | --- |
| `alphanumeric` | Mixed letters and digits, case-insensitive, so `item2` comes before `item10`. Slower, more accurate for strings containing numbers. |
| `alphanumericCaseSensitive` | The same, case-sensitive. |
| `text` | Plain string comparison, case-insensitive. Faster, but `item10` comes before `item2`. |
| `textCaseSensitive` | Plain string comparison, case-sensitive. |
| `datetime` | `Date` values, by timestamp. |
| `basic` | A single `a > b` / `a < b` comparison on the raw `Value`. The fastest. |

`Table.SortFn.splitAlphaNumeric` is the chunker the two alphanumeric functions
use, ported from TanStack's `reSplitAlphaNumeric`. It cuts a string into runs
of digits and runs of non-digits so the runs can be compared pairwise.

A column with no `withSortFn` sorts with the automatic choice, TanStack's
`sortFn: 'auto'`. [`getAutoSortFn`](/reference/module/Table#getAutoSortFn)
samples the first ten rows: a `Date` gives `datetime`, a string holding digits
gives `alphanumeric`, any other string gives `text`, and anything else gives
`basic`.

### Custom sorting functions

There are two ways to write your own, and they differ in what the comparison
receives.

`Table.SortFn.custom` builds a `SortFn` from a comparison on two `Value`s, and
`Table.SortFn.withResolveDataValue` attaches a normaliser that runs on each
value before the comparison. This is the split TanStack's `constructSortFn`
uses, and it means a variant of an existing function only has to change the
normaliser.

```elm snippet=Sorting.elm#lastWord
```

`Table.withCustomSort` takes a comparison on two whole `Row`s instead, so it
can reach fields the column's accessor does not expose. A column set up this
way has no `SortFn`; the row model uses the row comparison directly.

```elm snippet=Sorting.elm#byLastNameColumn
```

Neither form needs to handle the sort direction. Return `LT`, `EQ`, or `GT`
for ascending order and the row model does the rest.

### Sorting direction

The first direction a column sorts in is decided in this order: the column's
`withSortDescFirst`, then `Config.sortDescFirst`, then the data. The data rule
is [`getAutoSortDir`](/reference/module/Table#getAutoSortDir): the first
non-null value among the first ten rows decides, strings start ascending and
everything else starts descending.

Set `withSortDescFirst` explicitly on columns whose values can be `Null`, since
a run of nulls can make the automatic choice pick the wrong type.

### Invert sorting

`withInvertSorting True` keeps the ascending/descending cycle exactly as it is
but flips the row order it produces. Use it for values where a low number is
the good one, such as a rank or a golf score.

```elm snippet=Sorting.elm#rankColumn
```

### Sorting null values

`Value.Null` covers both JavaScript's `null` and `undefined`, so TanStack's
`sortUndefined` column option becomes `Table.withSortUndefined` and its four
values are named constants.

| TanStack `sortUndefined` | elm-table | Effect |
| --- | --- | --- |
| `'first'` | `Table.sortNullsFirst` | `Null` cells go to the front of the list, whichever way the column is sorted. |
| `'last'` | `Table.sortNullsLast` | `Null` cells go to the end of the list, whichever way the column is sorted. |
| `-1` | `Table.sortNullsAsMinusOne` | `Null` sorts with higher priority, so ascending puts nulls first and descending puts them last. |
| `1` | `Table.sortNullsAsPlusOne` | `Null` sorts with lower priority, so ascending puts nulls last. |
| `false` | no `withSortUndefined` call | `Null` reaches the sort function like any other value, and the function decides. |

When both cells are `Null` the entry is skipped and the next sorted column
decides, which is TanStack's `continue`.

```elm snippet=Sorting.elm#nullableColumn
```

## Transitions

Every transition has the shape `... -> State -> State`. Call one in `update`
and store the result.

| Function | What it does |
| --- | --- |
| [`toggleSort`](/reference/module/Table#toggleSort) | Step one column's sort: add it, replace the sort with it, flip its direction, or remove it. |
| [`setSorting`](/reference/module/Table#setSorting) | Replace `State.sorting` outright. |
| [`clearSorting`](/reference/module/Table#clearSorting) | Remove one column from `State.sorting`, leaving the others in order. |
| [`resetSorting`](/reference/module/Table#resetSorting) | Clear every sort. |

```elm snippet=Sorting.elm#update
```

`toggleSort` takes a `{ desc : Maybe Bool, multi : Bool }` record, which is
TanStack's `column.toggleSorting(desc, isMulti)`. `desc = Just d` sets the
direction outright instead of stepping the cycle; `desc = Nothing` steps it.
`multi = True` asks to add the column to the existing sort rather than replace
it.

It also takes a `RowModel`, which the other three transitions do not, because
the first direction a column sorts in can depend on the data (see
[Sorting direction](#sorting-direction)). Pass the filtered row model, which is
what TanStack samples.

TanStack decides multi-sorting from a DOM event with `isMultiSortEvent`, whose
default reads the shift key. There is no such option here: your `Msg` carries
whatever your click handler decided, and you pass it as `multi`.

### Multi-sorting

`multi = True` only adds to the sort when the column allows it. The column's
`withEnableMultiSort` wins over `Config.enableMultiSort`; when a column
forbids multi-sorting, sorting by it replaces the whole sort.
`Config.maxMultiSortColCount` caps how many columns a multi-sort keeps.

### Sorting removal

The default cycle for a column whose first direction is ascending is:

```text
not sorted -> asc -> desc -> not sorted -> asc -> ...
```

With `Config.enableSortingRemoval = False` the "not sorted" step is skipped
after the first sort, so at least one column stays sorted:

```text
not sorted -> asc -> desc -> asc -> desc -> ...
```

`Config.enableMultiRemove` is the same switch for a multi-sort. Note that
sorting by another column without `multi` still replaces the whole sort, so
this only prevents a column from unsorting itself.

## Queries

These read the state back while you render. None of them changes anything.

| Function | Use it for |
| --- | --- |
| [`getCanSort`](/reference/module/Table#getCanSort) | Enabling or disabling the sort control on a header. |
| [`getCanMultiSort`](/reference/module/Table#getCanMultiSort) | Enabling or disabling a multi-sort control. |
| [`getIsSorted`](/reference/module/Table#getIsSorted) | The arrow on a header. Returns `Maybe SortDir`: `Nothing`, `Just Table.sortAsc`, or `Just Table.sortDesc`. |
| [`getSortIndex`](/reference/module/Table#getSortIndex) | The 1, 2, 3 badge in a multi-sort. Returns `-1` when the column is not sorted. |
| [`getNextSortingOrder`](/reference/module/Table#getNextSortingOrder) | A tooltip or `aria-label` saying what the next click will do. `Nothing` means it will clear the sort. |
| [`getFirstSortDir`](/reference/module/Table#getFirstSortDir) | Which direction the first click will sort in. |
| [`getAutoSortDir`](/reference/module/Table#getAutoSortDir) | The direction the data suggests, before any option overrides it. |
| [`getSortFn`](/reference/module/Table#getSortFn) | Showing which comparison a column uses. |
| [`getAutoSortFn`](/reference/module/Table#getAutoSortFn) | The comparison the automatic choice would pick. |

```elm snippet=Sorting.elm#viewSortHeader
```

`getIsSorted` returns `Maybe SortDir` rather than TanStack's
`false | 'asc' | 'desc'`, so a header renders with a `case` and no string
comparison.

```elm snippet=Sorting.elm#nextSortLabel
```

The four readers that resolve an automatic choice (`getAutoSortFn`,
`getSortFn`, `getAutoSortDir`, `getFirstSortDir`) take a `RowModel` to sample.
`getNextSortingOrder` takes one because it calls `getFirstSortDir`.

## What this page does not cover

- **Controlled state, `onSortingChange`, and atoms.** The `State` is always
  yours, in your model, so there is no second way to own it. See
  [Table State](/guide/table-state).
- **`initialState.sorting`.** Build your starting state with `setSorting` on
  `Table.initialState`, as shown above.
- **`autoResetSorting`.** Nothing watches your data for changes. Call
  `Table.resetSorting` yourself when you replace the data.
- **The `sortFns` registry.** There is no registry, so `getSortFn` returns a
  `SortFn` rather than a registered name, and a column takes the function
  itself.
- **`isMultiSortEvent`.** Your click handler decides; you pass `multi`.

## Example

[Sorting](https://elm-table-examples.pages.dev/sorting/), ported from
TanStack's Sorting example.

<iframe src="https://elm-table-examples.pages.dev/sorting/" title="Sorting example" loading="lazy"></iframe>
