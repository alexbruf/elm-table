# elm-table

Headless table state and row-model pipeline for Elm 0.19.1, a port of
[TanStack Table](https://github.com/TanStack/table) core.

There is no table instance. The package renders nothing, holds no state of
its own, and calls no ports. You keep a `Table.State` in your model, feed it
and your data through the pipeline, and draw whatever `Html` you want from
the row model that comes back. Every function is `Config row -> State ->
...`, so two tables never share anything by accident and every transition is
a plain value you can inspect, log, or store.

Rows go through six pipeline stages, always in this order:

```
core → filtered → grouped → sorted → expanded → paginated
```

`Table.rows` runs all six. Each stage is also exposed on its own
(`filteredRowModel`, `sortedRowModel`, ...) so you can stop early, inspect an
intermediate `RowModel`, or splice in your own manual stage.

Docs: <https://elm-table-docs.pages.dev> (guides and API reference, mirroring the TanStack Table docs)

Examples: <https://elm-table-examples.pages.dev> (34 ports of the TanStack Table examples, each with its Elm source)

Column resizing ships as pure resize state (`startColumnResize`, `updateColumnResize`, `endColumnResize`; you wire the pointer events) and virtualization pairs the sorted or expanded row model with `FabienHenon/elm-infinite-list-view`; see the [Column Resizing](https://elm-table-docs.pages.dev/guide/column-resizing/) and [Virtualization](https://elm-table-docs.pages.dev/guide/virtualization/) guides and their examples.

Demo: <https://elm-table-demo.pages.dev> (5,000 generated keyword rows; sort, filter, group, expand, select, paginate, pin, with pipeline timings in the footer). Source in `demo/`, build with `make demo`.

## Install

```
elm install viewengine/elm-table
```

## Example

Sorting, filtering, grouping, and pagination together, rendered as a plain
`Html.table`. This is `examples/src/Main.elm`, copied here byte-for-byte;
run `make example` to compile it, or open `examples/` in `elm reactor`.

```elm
-- This file is embedded byte-for-byte in the README. If you change it here,
-- copy it into the matching code block in README.md, and the other way
-- around.


module Main exposing (main)

import Browser
import Dict
import Html exposing (Html, button, div, input, label, p, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (checked, disabled, style, type_, value)
import Html.Events exposing (onClick, onInput)
import Table
import Table.AggregationFn as AggregationFn
import Table.FilterFn as FilterFn
import Table.Value as Value


type alias Person =
    { id : String
    , firstName : String
    , lastName : String
    , department : String
    , age : Int
    , salary : Float
    }


people : List Person
people =
    [ Person "1" "Ada" "Lovelace" "Engineering" 36 98000
    , Person "2" "Grace" "Hopper" "Engineering" 45 112000
    , Person "3" "Katherine" "Johnson" "Engineering" 41 105000
    , Person "4" "Margaret" "Hamilton" "Engineering" 38 108000
    , Person "5" "Radia" "Perlman" "Engineering" 50 121000
    , Person "6" "Susan" "Kare" "Design" 34 89000
    , Person "7" "Jony" "Ive" "Design" 47 130000
    , Person "8" "Don" "Norman" "Design" 55 99000
    , Person "9" "Julie" "Zhuo" "Design" 29 95000
    , Person "10" "Dieter" "Rams" "Design" 60 88000
    , Person "11" "Mary" "Barra" "Sales" 44 91000
    , Person "12" "Zig" "Ziglar" "Sales" 52 87000
    , Person "13" "Brian" "Tracy" "Sales" 58 93000
    , Person "14" "Grant" "Cardone" "Sales" 39 97000
    , Person "15" "Jill" "Konrath" "Sales" 42 85000
    , Person "16" "Tony" "Hsieh" "Support" 33 72000
    , Person "17" "Shep" "Hyken" "Support" 48 75000
    , Person "18" "Blake" "Morgan" "Support" 31 71000
    , Person "19" "Micah" "Solomon" "Support" 37 74000
    , Person "20" "Jeff" "Toister" "Support" 45 76000
    ]


config : Table.Config Person
config =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First name"
            |> Table.withFilterFn FilterFn.includesString
        , Table.column "lastName" (.lastName >> Value.String)
            |> Table.withHeader "Last name"
        , Table.column "department" (.department >> Value.String)
            |> Table.withHeader "Department"
        , Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
        , Table.column "salary" (.salary >> Value.Number)
            |> Table.withHeader "Salary"
            |> Table.withAggregationFn AggregationFn.sum
        ]
        |> Table.withGetRowId (\person _ _ -> person.id)


type alias Model =
    { state : Table.State
    }


init : Model
init =
    { state = Table.initialState }


{-| The row model for the current state. A real app computes this once in
`update` and stores it in the model instead of rebuilding it here and again
in `update` below; this README keeps the two separate so each function stays
a one-liner.
-}
rowModel : Table.State -> Table.RowModel Person
rowModel state =
    Table.rowsFromList config state people


type Msg
    = SortBy String
    | FilterFirstName String
    | ToggleGroupByDepartment
    | ToggleExpandRow (Table.Row Person)
    | GoToPreviousPage
    | GoToNextPage


update : Msg -> Model -> Model
update msg model =
    case msg of
        SortBy columnId ->
            { model
                | state =
                    Table.toggleSort config
                        (rowModel model.state)
                        columnId
                        { desc = Nothing, multi = False }
                        model.state
            }

        FilterFirstName text ->
            { model
                | state =
                    Table.setColumnFilter config
                        (rowModel model.state)
                        "firstName"
                        (Value.String text)
                        model.state
            }

        ToggleGroupByDepartment ->
            { model | state = Table.toggleGrouping "department" model.state }

        ToggleExpandRow row ->
            { model
                | state =
                    Table.toggleExpanded config (rowModel model.state) row Nothing model.state
            }

        GoToPreviousPage ->
            { model | state = Table.previousPage config model.state }

        GoToNextPage ->
            { model | state = Table.nextPage config model.state }


view : Model -> Html Msg
view model =
    let
        model_ =
            rowModel model.state

        columns_ =
            Table.visibleLeafColumns config model.state

        visibleRows =
            Table.rowsInDisplayOrder config model.state model_
    in
    div []
        [ p []
            [ label []
                [ text "Filter first name: "
                , input [ value (currentFilterText model.state), onInput FilterFirstName ] []
                ]
            ]
        , p []
            [ label []
                [ input
                    [ type_ "checkbox"
                    , checked (Table.getIsGrouped model.state "department")
                    , onClick ToggleGroupByDepartment
                    ]
                    []
                , text " Group by department"
                ]
            ]
        , table []
            [ thead [] [ tr [] (List.map (viewHeaderCell model.state) columns_) ]
            , tbody [] (List.map (viewRow model.state) visibleRows)
            ]
        , p []
            [ button
                [ onClick GoToPreviousPage
                , disabled (not (Table.getCanPreviousPage model.state))
                ]
                [ text "Previous" ]
            , text
                (" Page "
                    ++ String.fromInt (model.state.pagination.pageIndex + 1)
                    ++ " of "
                    ++ String.fromInt (Table.getPageCount config model.state model_)
                    ++ " "
                )
            , button
                [ onClick GoToNextPage
                , disabled (not (Table.getCanNextPage config model.state model_))
                ]
                [ text "Next" ]
            ]
        ]


currentFilterText : Table.State -> String
currentFilterText state =
    Table.getFilterValue state "firstName"
        |> Maybe.map Value.toString
        |> Maybe.withDefault ""


viewHeaderCell : Table.State -> Table.Column Person -> Html Msg
viewHeaderCell state col =
    let
        columnId =
            Table.columnId col

        label_ =
            Maybe.withDefault columnId (Table.columnHeader col)
    in
    th
        [ onClick (SortBy columnId), style "cursor" "pointer" ]
        [ text (label_ ++ sortIndicator state columnId) ]


sortIndicator : Table.State -> String -> String
sortIndicator state columnId =
    case Table.getIsSorted state columnId of
        Nothing ->
            ""

        Just dir ->
            if dir == Table.sortAsc then
                " (asc)"

            else
                " (desc)"


viewRow : Table.State -> Table.Row Person -> Html Msg
viewRow state row =
    tr [] (List.map (viewCell state row) (Table.visibleLeafColumns config state))


viewCell : Table.State -> Table.Row Person -> Table.Column Person -> Html Msg
viewCell state row col =
    let
        columnId =
            Table.columnId col
    in
    if Table.cellIsGrouped state row columnId then
        td [] [ button [ onClick (ToggleExpandRow row) ] [ text (groupLabel state row) ] ]

    else if Table.rowIsGrouped row then
        if Dict.member columnId (Table.rowAggregatedValues row) then
            td [] [ text (Value.toString (Table.getValue config row columnId)) ]

        else
            td [] []

    else
        td [] [ text (Value.toString (Table.getValue config row columnId)) ]


groupLabel : Table.State -> Table.Row Person -> String
groupLabel state row =
    (if Table.getIsExpanded config state row then
        "- "

     else
        "+ "
    )
        ++ Value.toString (Table.rowGroupingValue row)
        ++ " ("
        ++ String.fromInt (List.length (Table.rowLeafRows row))
        ++ ")"


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
```

## API map

- **`Table`** — the facade. `Config`, `State`, `Row`, `RowModel`, the column
  and header builders, the six pipeline stages, and every state transition
  (`toggleSort`, `setColumnFilter`, `toggleGrouping`, `toggleExpanded`,
  `setPage`, row and column selection, pinning, ordering, visibility, and
  sizing).
- **`Table.Value`** — the one cell value type (`String`, `Number`, `Bool`,
  `Date`, `List`, `Null`) plus `toString` and `toNumber`, the JavaScript-style
  coercions the built-in functions below use.
- **`Table.SortFn`** — built-in sort functions (`alphanumeric`, `text`,
  `datetime`, `basic`, ...) for `withSortFn`.
- **`Table.FilterFn`** — built-in filter functions (`includesString`,
  `equals`, `inNumberRange`, `arrIncludes`, ...) for `withFilterFn`.
- **`Table.AggregationFn`** — built-in aggregations (`sum`, `mean`, `min`,
  `max`, `unique`, ...) for `withAggregationFn`, run on group rows.

## Differences from TanStack

1. **No function registries.** A `SortFn`, `FilterFn`, or `AggregationFn` is
   a value you pass to `withSortFn` / `withFilterFn` / `withAggregationFn`,
   not a string name looked up in a table-wide registry. `getSortFn` and
   `getFilterFn` hand back the function itself.
2. **One `Null` for `null` and `undefined`.** `Table.Value` has no separate
   case for "missing" versus "explicitly null"; both read back as `Null`
   everywhere a cell value is read.
3. **`Value.List` is the array cell value.** It exists so `arrIncludes`,
   `arrIncludesAll`, `arrIncludesSome`, and the `extent` / `unique`
   aggregations have something to operate on without a caller reaching for
   `Value` in a one-off way.
4. **The pipeline is fixed and fully exposed:** core → filtered → grouped →
   sorted → expanded → paginated. Each stage takes the previous stage's
   `RowModel`, so a caller can stop early, inspect any intermediate result,
   or replace a stage with a manual one.
5. **`resetX` means "back to the feature's built-in default,"** not "back to
   a remembered `table.initialState`" — there is no table instance to carry
   one. To restore your own starting state, call the matching `setX` with it.
6. **Nothing is memoized.** Every function recomputes from its `Config`,
   `State`, and data; there is no cached `getCoreRowModel()` result between
   calls. An app that wants that caches the `RowModel` itself, typically once
   per `update`.
7. **Custom sort and filter functions take the whole row.** `withCustomSort`
   and `withCustomFilter` receive a `Row row`, so they can read other
   columns; the built-in `SortFn` and `FilterFn` values work on one column's
   `Value` instead.
8. **Auto-detected functions are real functions, not the string `"auto"`.**
   `getAutoSortFn`, `getAutoFilterFn`, and `getAutoAggregationFn` sample the
   data and return the same kind of value `withSortFn` / `withFilterFn` /
   `withAggregationFn` would take.

## Development

```
make check   # elm-format --validate, elm-review, elm-test
make test    # elm-test only
make docs    # elm make --docs=docs.json
make bench   # the 10,000-row timing benchmark
make demo    # build demo/dist (optimized + minified)
```

Deploying the demo needs Cloudflare credentials in a local env file; copy
`.env.example` and fill it in.
