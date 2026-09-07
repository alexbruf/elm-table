---
title: Comparison with elm-sortable-table
id: comparison
---

[`evancz/elm-sortable-table`](https://package.elm-lang.org/packages/evancz/elm-sortable-table/latest/)
is the table package the Elm community already had. If you are choosing between
the two, the honest summary is that they solve different problems and the
smaller one is often the right answer.

`elm-sortable-table` sorts, and it renders. You give `Table.config` a list of
column definitions that say how to produce the `Html` for a cell, keep a `State`
that holds which column is sorted, and call `Table.view` to get the table back.
The markup is written for you.

This package does not sort only, and it does not render at all. It produces a
row model from a `Config`, a `State`, and your data, and you write every element
yourself.

## Side by side

| | `elm-sortable-table` | `elm-table` |
| --- | --- | --- |
| Features | sorting | sorting, filtering, global filtering, faceting, grouping, aggregation, expanding, pagination, row and cell selection, row and column pinning, column ordering, visibility, sizing, cell spanning |
| Rendering | the package renders the table | you render everything |
| Column definitions | say how to draw a cell | say how to read a value ([`Table.Value`](/guide/values)) |
| State | which column is sorted | a [record with one slice per feature](/guide/table-state) |
| Output | `Html msg` | a [`RowModel`](/guide/row-models) of rows, cells, and headers |
| Styling and markup | follows the package's structure | entirely yours |
| Ported from | its own design | [TanStack Table](https://tanstack.com/table) core |

## When the smaller package is the better choice

Reach for `elm-sortable-table` when:

- you want a sortable list of records and nothing else;
- you would rather not write `thead`, `tbody`, and the click handlers;
- the default markup suits the page you are putting it on;
- you want the smallest amount of code between your data and something on
  screen.

That is a real and common case, and the extra surface here buys you nothing in
it.

## When this package is the better choice

Reach for `elm-table` when:

- you need anything past sorting: filtering, grouping, pagination, selection,
  pinning, and the rest;
- you have to own the markup, because of a design system, a virtualized body, a
  sticky header, or a layout that is not a plain `table`;
- you are porting a TanStack Table app and want the same feature names, the same
  row-model stages, and the same behaviour;
- you want each state transition to be a value you can test on its own.

The cost is that you write the view. A rendered table is roughly the same length
as the one in [Quick Start](/quick-start), and none of it is generated for you.

## A practical note

Both packages expose a module named `Table`, so a single Elm project cannot
depend on both. Pick one per project.
