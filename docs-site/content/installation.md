---
title: Installation
id: installation
---

Before we dig into the API, let's get you set up.

## Install the package

```bash
elm install viewengine/elm-table
```

That writes `viewengine/elm-table` into the `dependencies` of your
`elm.json`. There is nothing to install with `npm` or `bun`: the package is
pure Elm, has no ports, and ships no JavaScript.

## Requirements

| | |
| --- | --- |
| Elm | 0.19.1 (the `elm.json` constraint is `0.19.0 <= v < 0.20.0`) |
| Dependencies | `elm/core` and `elm/time` |
| Browser support | whatever your Elm app already supports; the package touches no DOM API |

`elm/time` is a dependency because `Table.Value` has a `Date` case that
carries a `Time.Posix`. If your data has no dates you never have to import
it.

## Modules

Five modules are exposed.

| Module | What it holds |
| --- | --- |
| [`Table`](/reference/module/Table) | `Config`, `State`, `Row`, `RowModel`, the column builders, the six pipeline stages, and every state transition. |
| [`Table.Value`](/reference/module/Table-Value) | The one cell value type and its two coercions. |
| [`Table.SortFn`](/reference/module/Table-SortFn) | Built-in sort functions. |
| [`Table.FilterFn`](/reference/module/Table-FilterFn) | Built-in filter functions. |
| [`Table.AggregationFn`](/reference/module/Table-AggregationFn) | Built-in aggregations for group rows. |

A typical import block:

```elm
import Table
import Table.AggregationFn as AggregationFn
import Table.FilterFn as FilterFn
import Table.SortFn as SortFn
import Table.Value as Value
```

Nothing is opt-in. Unlike TanStack v9 there is no `tableFeatures({...})`
registration step, because Elm's dead-code elimination already drops the
stages you never call. Every feature is available from the moment you install
the package, and a table that only reads `Table.rowsFromList` pays for the
core row model alone once `elm make --optimize` has run.

## Next

- [Quick Start](/quick-start) builds a working table from nothing.
- [Config and State](/guide/config-and-state) explains the two values you own.
- [Migrating from TanStack](/migrating) if you already know the JavaScript API.
