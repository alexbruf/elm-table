---
title: Data
id: guide/data
---

Tables start with your data. This page is the Elm counterpart of TanStack
Table's **Data Guide**, which is about the `TData` generic, reaching values out
of nested objects, sub-rows, and giving the `data` array a stable reference.

The short version: any record type works, the accessor is a function so there
are no string key paths, sub-rows come from
[`Table.withSubRows`](/reference/module/Table#withSubRows), stable ids come from
[`Table.withGetRowId`](/reference/module/Table#withGetRowId), and there is no
stable-reference rule at all because nothing is memoized.

## Defining Your Row Type

TanStack calls your row type `TData` and threads it through every table,
column, row, and cell type. Here the same type is the `row` parameter of
`Table.Config row`, `Table.Column row`, `Table.Row row`, and
`Table.RowModel row`, and it is inferred from your accessors.

Any type works: a record, a custom type, a tuple, even a `Dict`. The package
never looks at a row directly. It only calls the accessor functions you gave
each column, plus `withGetRowId` and `withSubRows` if you set them.

The examples in these docs use one fixture:

```elm
type alias Person =
    { id : String
    , firstName : String
    , lastName : String
    , department : String
    , age : Int
    , salary : Float
    , active : Bool
    , tags : List String
    }
```

A column reads one field of it and wraps the result in a
[`Value`](/guide/values), the single union type every built-in sort, filter,
and aggregation function works on:

```elm snippet=Data.elm#stableIds
```

There is no `columnHelper` and no type parameter to pass. `Table.column` gets
its `row` type from the accessor you hand it, and the compiler checks that
every column in one `Table.config` list agrees. See
[Column Definitions](/guide/column-defs).

## Deep Keyed Data

TanStack lets an `accessorKey` be a dotted path, `'name.first'`, because
JavaScript objects can be indexed by string. Elm records cannot, so this
package has no key-path form: every accessor column takes a function, which
covers the same ground.

Given nested records:

```elm
type alias Employee =
    { name : { first : String, last : String }
    , info : { age : Int, visits : Int }
    }
```

reach into them with ordinary field access:

```elm snippet=Data.elm#nestedColumns
```

Because the accessor is a plain function, a computed value is no different
from a stored one: `\person -> Value.String (person.firstName ++ " " ++ person.lastName)`
is a valid accessor. Whatever it returns is what sorting, filtering, grouping,
and faceting see.

TanStack's note about periods in a key does not apply. Column ids here are
opaque strings; nothing parses them.

## Nested Sub-Row Data

If a row can contain child rows, tell the core row model how to reach them
with `Table.withSubRows`. TanStack looks for a `subRows` field by convention;
here you pass the function, so the field can be called anything, and the row
type can be a custom type rather than a record:

```elm snippet=Data.elm#categoryConfig
```

An Elm type alias cannot refer to itself, so a self-nesting row type has to be
a custom type like `Category` above. The accessors then pattern match on the
constructor.

Sub-rows are resolved once, by the core row model, before any other stage
runs. Depth, parent id, and the flattened row list all come from that pass.
[Expanding](/guide/expanding) covers which sub-rows are shown.

## Stable Row Ids

Without `withGetRowId`, a root row's id is its index as a string, `"0"`,
`"1"`, `"2"`, and a child's id is its parent's id, a dot, and its own index:
`"0.1"`. That is fine until the data reorders, at which point selected,
expanded, and pinned rows follow the position rather than the record.

Pass `Table.withGetRowId` when your data has a real key. It receives the datum,
its index among its siblings, and its parent's row id:

```elm
Table.withGetRowId : (row -> Int -> Maybe String -> String) -> Config row -> Config row
```

Row ids are what [Row Selection](/guide/row-selection),
[Expanding](/guide/expanding), and [Row Pinning](/guide/row-pinning) store in
`State`, so a stable id is what lets that state survive a refetch. This matters
most with [server-side processing](/guide/client-side-vs-server-side), where
each response is a different list of records.

## Data of Unknown Shape

When the columns are only known at runtime (an arbitrary API response, an
uploaded CSV, a user-configured report), pick a row type that can hold anything
and generate the column list from the data. `Dict String String` is the usual
choice:

```elm
Table.column key
    (\row -> Dict.get key row |> Maybe.map Value.String |> Maybe.withDefault Value.Null)
```

Build that list with `List.map` over the keys of the first record. You lose
per-field types, exactly as TanStack does with `Record<string, unknown>`, and
you pick a sort and filter function per column from whatever runtime check you
can make. Everything else works unchanged.

## Passing Data In: `rows` and `rowsFromList`

Two functions run the pipeline, and they differ only in the container they
take:

| Function | Data argument | Use it when |
| --- | --- | --- |
| [`Table.rows`](/reference/module/Table#rows) | `Array row` | Your data is already an `Array`, usually because you index into it elsewhere. |
| [`Table.rowsFromList`](/reference/module/Table#rowsFromList) | `List row` | Your data is a `List`, which is what a JSON decoder and most Elm code produce. |

```elm snippet=Data.elm#fromList
```

```elm snippet=Data.elm#fromArray
```

`Table.rows` calls `Array.toList` and then `rowsFromList`, so neither is
faster. Pick the one that matches the type you already hold.
[`Table.coreRowModel`](/reference/module/Table#coreRowModel) and
[`Table.coreRowModelFromList`](/reference/module/Table#coreRowModelFromList)
pair off the same way. Every other stage takes a `RowModel`, so the choice is
made once, at the start.

## No Stable Reference to Keep

TanStack's longest section warns that `data` and `columns` must keep a stable
JavaScript reference, because row models are memoized against those references
and an unstable one both rebuilds every row on each render and can drive
auto-reset features into a render loop.

None of that exists here. Nothing in this package is memoized, so nothing is
compared by reference, and there is no auto-reset hook that fires when a row
model recomputes. Rebuilding your data list on every call is correct, if
wasteful.

The cost is the other side of the same coin: every call recomputes. Calling
`Table.rowsFromList` in `view` runs all six stages on every frame. The fix is
to compute the row model once in `update` and store it in your model next to
the `State`:

```elm
type alias Model =
    { state : Table.State
    , rowModel : Table.RowModel Person
    }
```

[Table State](/guide/table-state) is about that pattern: who owns the `State`,
when to store the `RowModel` beside it, and how to keep the two in step.

`Config` deserves the same treatment for a different reason. It holds no state,
so build it once at the top level of your module rather than inside `view`. See
[Config and State](/guide/config-and-state).

## How This Package Transforms Data

Your data is never modified. Each pipeline stage builds a new `RowModel`, and
every `Table.Row` keeps the original datum, which
[`Table.rowOriginal`](/reference/module/Table#rowOriginal) hands back unchanged.

What does change is the row set and the values read from it. Filtering drops
rows, grouping replaces them with group rows that carry aggregated values,
sorting reorders every level of the tree, expanding flattens branches into the
list, and pagination keeps one page. [Row Models](/guide/row-models) walks
through each stage; [Rows](/guide/rows) covers what a row carries.

## How Much Data Can It Handle?

The package's benchmark, on 10,000 rows with `elm make --optimize`, measures:

| Case | Shape | Median |
| --- | --- | --- |
| Core row model, flat | 10,000 rows | 15.1 ms |
| Core row model, nested | 2,500 parents x 3 children | 12.4 ms |
| Full pipeline | one filter, one sort, page size 50 | 94.3 ms |
| Full pipeline with grouping | plus 20 groups, `sum` and `mean`, expand all | 166.3 ms |

Those numbers are one machine and one row shape. What they cost you depends on
the number of columns, the work your accessors do, and the device. Measure with
your own data.

Two things move the number more than row count does. Recomputing the row model
more often than the state changes is the common one, and storing it in your
model fixes it. Running stages you do not need is the other: if the server
already sorted the rows, set `manualSorting` and the stage is skipped
altogether. See [Client-Side vs Server-Side](/guide/client-side-vs-server-side)
for that decision, and [Virtualization](/guide/virtualization) for the separate
question of how many rows you draw.
