module CellSpanningFeatureTest exposing (pendingIntegration, suite)

{-| Ports `tests/implementation/features/cell-spanning/cellSpanningFeature.test.ts`.

`pendingIntegration` holds the cases that need the grouped or the expanded row
model, both still identity stubs in this worktree. Excluded cases are listed
in `reports/phase-6.md`.

The last case of the vitest file, "expands the selection to enclose a spanned
rectangle and counts it once", lives in `tests/CellSelectionSpanAwareTest.elm`
with the other span-aware selection cases.

-}

import Dict
import Expect
import Table
import Table.FilterFn as FilterFn
import Table.SortFn as SortFn
import Table.Value as Value
import Test exposing (Test, describe, test)


type alias TestRow =
    { id : String
    , region : String
    , team : String
    , amount : Float
    , subRows : SubRows
    }


{-| Elm forbids recursive type aliases, so the children are wrapped, exactly
as `tests/Fixtures.elm` does for `Person`.
-}
type SubRows
    = SubRows (List TestRow)


subRowsOf : TestRow -> List TestRow
subRowsOf r =
    case r.subRows of
        SubRows rows ->
            rows


leaf : String -> String -> String -> Float -> TestRow
leaf id region team amount =
    { id = id, region = region, team = team, amount = amount, subRows = SubRows [] }


{-| region-major so equal values are adjacent in the natural order.
-}
makeData : List TestRow
makeData =
    [ "North", "South", "East" ]
        |> List.concatMap
            (\region ->
                List.map (\t -> ( region, t )) (List.range 0 2)
            )
        |> List.indexedMap
            (\i ( region, t ) ->
                leaf (region ++ "-" ++ String.fromInt t) region ("Team " ++ String.fromInt t) (toFloat i)
            )


regionColumn : Table.Column TestRow
regionColumn =
    Table.column "region" (.region >> Value.String) |> Table.withSpanRows


teamColumn : Table.Column TestRow
teamColumn =
    Table.column "team" (.team >> Value.String)


amountColumn : Table.Column TestRow
amountColumn =
    Table.column "amount" (.amount >> Value.Number)


makeColumns : List (Table.Column TestRow)
makeColumns =
    [ regionColumn, teamColumn, amountColumn ]


configOf : List (Table.Column TestRow) -> Table.Config TestRow
configOf columns =
    Table.config columns
        |> Table.withGetRowId (\r _ _ -> r.id)
        |> Table.withSubRows subRowsOf


{-| core -> filtered -> grouped -> sorted -> expanded -> paginated.
-}
pipeline : Table.Config TestRow -> Table.State -> List TestRow -> Table.RowModel TestRow
pipeline cfg state data =
    Table.coreRowModelFromList cfg state data
        |> Table.filteredRowModel cfg state
        |> Table.groupedRowModel cfg state
        |> Table.sortedRowModel cfg state
        |> Table.expandedRowModel cfg state
        |> Table.paginatedRowModel cfg state


{-| `regionSpans` of the vitest file: the row span of every rendered row's
`region` cell.
-}
regionSpans : Table.Config TestRow -> Table.State -> List TestRow -> List Int
regionSpans cfg state data =
    spansOf cfg state data "region"


spansOf : Table.Config TestRow -> Table.State -> List TestRow -> String -> List Int
spansOf cfg state data columnId =
    let
        model : Table.RowModel TestRow
        model =
            pipeline cfg state data

        index : Table.CellSpanIndex
        index =
            Table.cellSpanIndex cfg state model
    in
    model.rows
        |> List.map (\r -> Table.cellRowSpan index (cellOf cfg state r columnId))


cellOf : Table.Config TestRow -> Table.State -> Table.Row TestRow -> String -> Table.Cell
cellOf cfg state r columnId =
    Table.getAllCells cfg state r
        |> List.filter (\cell -> cell.columnId == columnId)
        |> List.head
        |> Maybe.withDefault { id = "", columnId = "", rowId = "", value = Value.Null }


cellAt : Table.Config TestRow -> Table.State -> List TestRow -> String -> String -> Table.Cell
cellAt cfg state data rowId columnId =
    case Dict.get rowId (pipeline cfg state data).rowsById of
        Nothing ->
            { id = "", columnId = "", rowId = "", value = Value.Null }

        Just r ->
            cellOf cfg state r columnId


colSpansAt : Table.Config TestRow -> Table.State -> List TestRow -> String -> List String -> List Int
colSpansAt cfg state data rowId columnIds =
    let
        index : Table.CellSpanIndex
        index =
            Table.cellSpanIndex cfg state (pipeline cfg state data)
    in
    List.map (\columnId -> Table.cellColSpan index (cellAt cfg state data rowId columnId)) columnIds


base : Table.State
base =
    Table.initialState


suite : Test
suite =
    describe "cellSpanningFeature"
        [ describe "integration with the grouped and expanded stages" pendingIntegration
        , describe "spanning with sorting"
            [ test "recomputes spans when sorting changes adjacency" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            configOf
                                [ Table.withSortFn SortFn.basic regionColumn
                                , Table.withSortFn SortFn.basic teamColumn
                                , Table.withSortFn SortFn.basic amountColumn
                                ]

                        sortedBy : String -> Table.State
                        sortedBy columnId =
                            Table.setSorting [ { id = columnId, desc = False } ] base
                    in
                    Expect.equal
                        { natural = regionSpans cfg base makeData
                        , byTeam = regionSpans cfg (sortedBy "team") makeData
                        , runsByRegion =
                            regionSpans cfg (sortedBy "region") makeData
                                |> List.filter (\span -> span > 1)
                                |> List.length
                        }
                        { natural = [ 3, 0, 0, 3, 0, 0, 3, 0, 0 ]
                        , byTeam = [ 1, 1, 1, 1, 1, 1, 1, 1, 1 ]
                        , runsByRegion = 3
                        }
            ]
        , describe "spanning with filtering"
            [ test "merges neighbours when a filter removes the middle of a run" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            configOf
                                [ regionColumn
                                , Table.withFilterFn FilterFn.includesString teamColumn
                                , amountColumn
                                ]

                        data : List TestRow
                        data =
                            [ "North", "South", "East" ]
                                |> List.indexedMap
                                    (\i region ->
                                        [ leaf (region ++ "-0") region "keep" (toFloat (i * 3))
                                        , leaf (region ++ "-1") region "drop" (toFloat (i * 3 + 1))
                                        , leaf (region ++ "-2") region "keep" (toFloat (i * 3 + 2))
                                        ]
                                    )
                                |> List.concat

                        filtered : Table.State
                        filtered =
                            { base | columnFilters = [ { id = "team", value = Value.String "keep" } ] }
                    in
                    Expect.equal
                        { unfiltered = regionSpans cfg base data
                        , filtered = regionSpans cfg filtered data
                        , cleared = regionSpans cfg { base | columnFilters = [] } data
                        }
                        { unfiltered = [ 3, 0, 0, 3, 0, 0, 3, 0, 0 ]
                        , filtered = [ 2, 0, 2, 0, 2, 0 ]
                        , cleared = [ 3, 0, 0, 3, 0, 0, 3, 0, 0 ]
                        }
            ]
        , describe "spanning with pagination (the display-order regression tests)"
            [ test "splits a run at the page boundary" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            configOf makeColumns

                        onPage : Int -> Table.State
                        onPage pageIndex =
                            { base | pagination = { pageIndex = pageIndex, pageSize = 4 } }
                    in
                    Expect.equal
                        ( regionSpans cfg (onPage 0) makeData, regionSpans cfg (onPage 1) makeData )
                        ( [ 3, 0, 0, 1 ], [ 2, 0, 2, 0 ] )
            ]
        , describe "spanning with row pinning"
            [ test "breaks runs at pinned section boundaries and indexes every section" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            configOf makeColumns

                        state : Table.State
                        state =
                            { base | rowPinning = { top = [ "North-1" ], bottom = [ "East-2" ] } }

                        model : Table.RowModel TestRow
                        model =
                            pipeline cfg state makeData

                        source : Table.PinnedRowsSource TestRow
                        source =
                            { prePaginated = model, current = model }

                        sectionRows : List (Table.Row TestRow)
                        sectionRows =
                            Table.topRows cfg state source
                                ++ Table.centerRows state model
                                ++ Table.bottomRows cfg state source

                        index : Table.CellSpanIndex
                        index =
                            Table.cellSpanIndex cfg state model
                    in
                    sectionRows
                        |> List.map (\r -> Table.cellRowSpan index (cellOf cfg state r "region"))
                        |> Expect.equal [ 1, 2, 0, 3, 0, 0, 2, 0, 1 ]

            -- Adapted: there is no feature registry in this port, so "without
            -- rowPinningFeature registered" is an empty row-pinning slice.
            , test "spans without rowPinningFeature registered" <|
                \_ ->
                    regionSpans (configOf makeColumns) base makeData
                        |> Expect.equal [ 3, 0, 0, 3, 0, 0, 3, 0, 0 ]
            ]
        , describe "spanning with column pinning and visibility"
            [ test "clamps a column span at the pinned region boundary" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            configOf
                                [ Table.withSpanColumns (always Table.spanAllColumns) regionColumn
                                , teamColumn
                                , amountColumn
                                ]

                        state : Table.State
                        state =
                            Table.setColumnPinning { left = [], right = [ "team" ] } base
                    in
                    colSpansAt cfg state makeData "North-0" [ "region", "amount", "team" ]
                        |> Expect.equal [ 2, 0, 1 ]
            , test "shrinks a column span when a covered column is hidden" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            configOf
                                [ Table.withSpanColumns (always Table.spanAllColumns) regionColumn
                                , teamColumn
                                , amountColumn
                                ]

                        hidden : List String -> Table.State
                        hidden ids =
                            Table.setColumnVisibility (Dict.fromList (List.map (\id -> ( id, False )) ids)) base
                    in
                    Expect.equal
                        ( colSpansAt cfg (hidden [ "amount" ]) makeData "North-0" [ "region" ]
                        , colSpansAt cfg (hidden [ "amount", "team" ]) makeData "North-0" [ "region" ]
                        )
                        ( [ 2 ], [ 1 ] )
            , test "keeps row spans keyed by column id across reordering" <|
                \_ ->
                    regionSpans (configOf makeColumns) base makeData
                        |> Expect.equal [ 3, 0, 0, 3, 0, 0, 3, 0, 0 ]
            ]
        , describe "stale rows and data swaps"
            [ test "reports one for a cell whose row left the row model" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            configOf
                                [ regionColumn
                                , Table.withFilterFn FilterFn.includesString teamColumn
                                , amountColumn
                                ]

                        filtered : Table.State
                        filtered =
                            { base | columnFilters = [ { id = "team", value = Value.String "Team 2" } ] }

                        heldCell : Table.Cell
                        heldCell =
                            cellAt cfg base makeData "North-0" "region"
                    in
                    Expect.equal
                        { before = Table.cellRowSpan (Table.cellSpanIndex cfg base (pipeline cfg base makeData)) heldCell
                        , stillThere =
                            (pipeline cfg filtered makeData).rows
                                |> List.map Table.rowId
                                |> List.member "North-0"
                        , after =
                            Table.cellRowSpan (Table.cellSpanIndex cfg filtered (pipeline cfg filtered makeData)) heldCell
                        }
                        { before = 3, stillThere = False, after = 1 }
            , test "recomputes after the data array is replaced" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            configOf makeColumns

                        swapped : List TestRow
                        swapped =
                            [ leaf "x0" "West" "a" 0, leaf "x1" "West" "b" 1 ]
                    in
                    Expect.equal
                        ( regionSpans cfg base makeData, regionSpans cfg base swapped )
                        ( [ 3, 0, 0, 3, 0, 0, 3, 0, 0 ], [ 2, 0 ] )
            ]
        ]


{-| Written in full, kept out of `suite` because the stage each one exercises
is an identity stub in this worktree. See `reports/phase-6.md`.
-}
pendingIntegration : List Test
pendingIntegration =
    [ describe "spanning with expanded sub-rows"
        [ test "never merges a parent with its children, but merges true siblings" <|
            \_ ->
                let
                    cfg : Table.Config TestRow
                    cfg =
                        configOf makeColumns

                    data : List TestRow
                    data =
                        [ { id = "p0"
                          , region = "North"
                          , team = "Parent"
                          , amount = 0
                          , subRows =
                                SubRows
                                    [ leaf "c0" "North" "Child" 1
                                    , leaf "c1" "North" "Child" 2
                                    ]
                          }
                        , leaf "p1" "North" "Parent" 3
                        ]

                    state : Table.State
                    state =
                        { base | expanded = Table.expandAll }

                    model : Table.RowModel TestRow
                    model =
                        pipeline cfg state data

                    index : Table.CellSpanIndex
                    index =
                        Table.cellSpanIndex cfg state model
                in
                model.rows
                    |> List.map (\r -> ( Table.rowId r, Table.cellRowSpan index (cellOf cfg state r "region") ))
                    |> Expect.equal [ ( "p0", 1 ), ( "c0", 2 ), ( "c1", 0 ), ( "p1", 1 ) ]
        ]
    , describe "spanning with grouping"
        [ test "ignores spanRows on the grouped column and never merges group rows" <|
            \_ ->
                let
                    cfg : Table.Config TestRow
                    cfg =
                        configOf makeColumns

                    state : Table.State
                    state =
                        { base | grouping = [ "region" ], expanded = Table.expandAll }
                in
                regionSpans cfg state makeData
                    |> List.all (\span -> span == 1)
                    |> Expect.equal True
        ]
    ]
