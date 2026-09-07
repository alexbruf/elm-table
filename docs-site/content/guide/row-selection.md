---
title: Row Selection
id: guide/row-selection
---

Row selection keeps track of which rows a user has picked, by row id. It is
the port of TanStack Table's **Row Selection** guide and its
`rowSelectionFeature`. There is no feature to register here: every function
below is in `Table`, and the state slice is always present.

Because the selection is keyed by row id, give your rows meaningful ids with
`Table.withGetRowId`. Without it a row's id is its position in the data,
which stops meaning anything as soon as the data reorders.

```elm snippet=RowSelection.elm#config
```

## State

The slice is a `Set` of selected row ids.

```elm
-- in Table.State
, rowSelection : Set String

-- in Table.initialState
, rowSelection = Set.empty
```

Selecting a parent row writes the parent's id and the ids of its selectable
descendants into the set, so `Table.selectedRowIds` includes sub-rows
whenever `enableSubRowSelection` allows the descent. Deselecting one child
afterwards does not remove the parent id unless you ask for it; see
`deselectParents` under [Transitions](#transitions).

You own this state, the same way you own every other slice. See
[Table State](/guide/table-state) for where to keep it.

## Config options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enableRowSelection` | `Row row -> Bool` | `always True` | Can this row be selected at all. |
| `enableMultiRowSelection` | `Row row -> Bool` | `always True` | Can this row take part in a multi-row selection. Answer `False` for radio-button behaviour. |
| `enableSubRowSelection` | `Row row -> Bool` | `always True` | Does selecting this row also select its sub-rows. |

All three are predicates on the `Row`, not booleans. TanStack accepts
`boolean | ((row) => boolean)` for each; a single function type covers both,
and `always False` is the boolean form.

### Enable row selection conditionally

`Table.withRowSelection` sets the first of the three.

```elm snippet=RowSelection.elm#activeRowsOnly
```

Use [`getCanSelect`](/reference/module/Table#getCanSelect) in your UI to
disable the checkbox of a row the predicate rejects.

### Single row selection

`Config` is a plain record, so the other two options are a record update.

```elm snippet=RowSelection.elm#singleRowSelection
```

### Sub-row selection

```elm snippet=RowSelection.elm#noSubRowSelection
```

When a parent blocks sub-row selection, `toggleAllRowsSelected` and
`toggleAllPageRowsSelected` skip that parent's descendants, and
`getIsAllRowsSelected` and `getIsAllPageRowsSelected` ignore them when
deciding whether everything is selected.

## Column options

None. Row selection is a table-level feature; no `with*` builder on a column
affects it. A checkbox column is an ordinary
[`Table.display`](/reference/module/Table#display) column that you render
yourself.

## Transitions

| Transition | Type | What it does |
| --- | --- | --- |
| [`toggleRowSelected`](/reference/module/Table#toggleRowSelected) | `Config row -> RowModel row -> Row row -> Maybe Bool -> State -> State` | Select or deselect one row; `Nothing` flips it. Sub-rows follow along. |
| [`toggleRowSelectedWith`](/reference/module/Table#toggleRowSelectedWith) | `Config row -> SelectOptions -> RowModel row -> Row row -> Maybe Bool -> State -> State` | The same, with explicit `SelectOptions`. |
| [`toggleAllRowsSelected`](/reference/module/Table#toggleAllRowsSelected) | `Config row -> RowModel row -> Maybe Bool -> State -> State` | Select or deselect every row of the model you pass. |
| [`toggleAllPageRowsSelected`](/reference/module/Table#toggleAllPageRowsSelected) | `Config row -> RowModel row -> Maybe Bool -> State -> State` | The same for the current page; pass the paginated row model. |
| [`selectRange`](/reference/module/Table#selectRange) | `Config row -> RowModel row -> String -> Row row -> Bool -> State -> State` | Set every row between an anchor id and this row to the given value. |
| [`selectRangeWith`](/reference/module/Table#selectRangeWith) | `Config row -> SelectOptions -> RowModel row -> String -> Row row -> Bool -> State -> State` | The same, with explicit `SelectOptions`. |
| [`setRowSelection`](/reference/module/Table#setRowSelection) | `Set String -> State -> State` | Replace the selection. |
| [`deselectAllRows`](/reference/module/Table#deselectAllRows) | `State -> State` | Clear the selection, including ids of rows that can no longer be selected. |
| [`resetRowSelection`](/reference/module/Table#resetRowSelection) | `State -> State` | Clear the selection. |

`SelectOptions` is a plain record with a default:

```elm
type alias SelectOptions =
    { selectChildren : Bool
    , deselectParents : Bool
    }


-- Table.defaultSelectOptions
{ selectChildren = True, deselectParents = False }
```

`selectChildren = False` changes only the rows explicitly named, leaving
sub-rows alone. `deselectParents = True` removes ancestor ids when a row is
deselected, so a parent does not stay in the set after one of its children is
switched off.

```elm snippet=RowSelection.elm#pruneParents
```

### Wiring a checkbox to a `Msg`

The message carries the row, the checkbox's new value, and whether Shift was
held.

```elm snippet=RowSelection.elm#update
```

### Shift range selection

Two things differ from TanStack here.

First, **the anchor is your state**. TanStack stores the last interacted row
id on the table instance as `_lastSelectedRowId`. There is no instance here,
so the anchor is a field in your model, and you decide when it moves and when
it clears.

```elm snippet=RowSelection.elm#init
```

Second, **the range is resolved against the pre-pagination rows in display
order**. `selectRange` walks the row model you hand it, so pass the model
before the page slice (filtering, grouping, sorting, and expansion applied,
pagination not). A shift-click then covers rows on other pages, which is what
TanStack's `getRowsInDisplayOrder` does.

```elm snippet=RowSelection.elm#prePaginated
```

[`canSelectRange`](/reference/module/Table#canSelectRange) is the guard.
Both endpoints have to be in that display order and allow multi-selection.
When it answers `False`, fall back to an ordinary toggle, which is what the
handler below does.

```elm snippet=RowSelection.elm#applyRowClick
```

## Queries

| Query | Type | Answers |
| --- | --- | --- |
| [`getIsRowSelected`](/reference/module/Table#getIsRowSelected) | `State -> Row row -> Bool` | Is this row selected? |
| [`getIsSomeSelected`](/reference/module/Table#getIsSomeSelected) | `Config row -> State -> Row row -> Bool` | Is part, but not all, of this row's sub-tree selected? |
| [`getIsAllSubRowsSelected`](/reference/module/Table#getIsAllSubRowsSelected) | `Config row -> State -> Row row -> Bool` | Is this row's whole sub-tree selected? |
| [`subRowSelection`](/reference/module/Table#subRowSelection) | `Config row -> State -> Row row -> SubRowSelection` | How much of the sub-tree is selected, as one value. |
| [`getIsSomeRowsSelected`](/reference/module/Table#getIsSomeRowsSelected) | `State -> Bool` | Is anything selected at all? |
| [`getIsAllRowsSelected`](/reference/module/Table#getIsAllRowsSelected) | `Config row -> State -> RowModel row -> Bool` | Is every selectable row of that model selected? |
| [`getIsAllPageRowsSelected`](/reference/module/Table#getIsAllPageRowsSelected) | `Config row -> State -> RowModel row -> Bool` | The same for the current page. |
| [`getIsSomePageRowsSelected`](/reference/module/Table#getIsSomePageRowsSelected) | `Config row -> State -> RowModel row -> Bool` | Is any row of the current page selected or partly selected? |
| [`getCanSelect`](/reference/module/Table#getCanSelect) | `Config row -> Row row -> Bool` | Can this row be selected? |
| [`getCanSelectSubRows`](/reference/module/Table#getCanSelectSubRows) | `Config row -> Row row -> Bool` | Can selecting it select its sub-rows? |
| [`getCanMultiSelect`](/reference/module/Table#getCanMultiSelect) | `Config row -> Row row -> Bool` | Can it join a multi-row selection? |
| [`canSelectRange`](/reference/module/Table#canSelectRange) | `Config row -> State -> RowModel row -> String -> Row row -> Bool` | Would a range from this anchor be a range, rather than a plain toggle? |
| [`selectedRowIds`](/reference/module/Table#selectedRowIds) | `State -> List String` | The selected ids. |
| [`selectedRowModel`](/reference/module/Table#selectedRowModel) | `State -> RowModel row -> RowModel row` | The model with only the selected rows kept. |

`SubRowSelection` is an abstract type with one value per case:
`Table.noSubRowsSelected`, `Table.someSubRowsSelected`, and
`Table.allSubRowsSelected`.

```elm snippet=RowSelection.elm#subTreeLabel
```

### Reading the selected rows

TanStack has three selected row models: `getSelectedRowModel`,
`getFilteredSelectedRowModel`, and `getGroupedSelectedRowModel`. Here that is
one function applied to whichever model you care about, since you already
hold each stage of the pipeline.

```elm snippet=RowSelection.elm#selectedPeople
```

Selected descendants of an unselected parent stay in `flatRows` and
`rowsById` but not in `rows`, matching TanStack.

## Render row selection UI

Nothing about the markup is decided for you. A header "select all" checkbox
reads the two table-wide queries, and the indeterminate look is a DOM
property, so it is set with `Html.Attributes.property`.

```elm snippet=RowSelection.elm#viewSelectAllHeader
```

```elm snippet=RowSelection.elm#indeterminate
```

The per-row checkbox is disabled when the row cannot be selected, checked
when the row or its whole sub-tree is selected, and indeterminate when only
part of its sub-tree is.

```elm snippet=RowSelection.elm#viewRowCheckbox
```

```elm snippet=RowSelection.elm#rowIsChecked
```

The Shift modifier and the checkbox's resulting value come out of the same
click event.

```elm snippet=RowSelection.elm#rowClickDecoder
```

The `getCanSelectSubRows` and `getIsAllSubRowsSelected` clauses only matter
for tables with sub-rows. With flat data, `getIsRowSelected` on its own is
enough.

## Not ported

- **Toggle handlers.** `row.getToggleSelectedHandler()`,
  `table.getToggleAllRowsSelectedHandler()`, and their siblings are DOM event
  plumbing. Their state halves are the transitions above; you write the
  `Html.Events` attribute.
- **`enableRowRangeSelection` and `isRowRangeSelectionEvent`.** Range
  selection is opt-in at the call site here: you call `selectRange` when your
  own event says to, so there is no flag to switch off and no event predicate
  to replace.
- **`onRowSelectionChange` and `atoms`.** Every transition returns a new
  `State`; storing it is your `update` function's job.
- **`autoResetAll`.** Nothing resets itself when the data changes. Call
  `resetRowSelection` yourself if that is what you want.

## Example

[Row Selection](https://elm-table-examples.pages.dev/row-selection/), ported from
TanStack's Row Selection example.

<iframe src="https://elm-table-examples.pages.dev/row-selection/" title="Row Selection example" loading="lazy"></iframe>
