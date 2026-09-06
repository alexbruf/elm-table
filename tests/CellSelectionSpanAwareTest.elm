module CellSelectionSpanAwareTest exposing (suite)

{-| Ports `tests/implementation/features/cell-selection/cellSelectionSpanAware.test.ts`,
plus the one cell-selection case of
`tests/implementation/features/cell-spanning/cellSpanningFeature.test.ts`.

Every case of both blocks is ported; see `reports/phase-6.md`.

-}

import Dict
import Expect
import Table
import Table.Value as Value
import Test exposing (Test, describe, test)


type alias TestRow =
    { id : String
    , region : String
    , team : String
    , amount : Float
    }


{-| Three regions of three rows, region-major so runs exist naturally.
-}
makeData : List TestRow
makeData =
    [ "North", "South", "East" ]
        |> List.concatMap (\region -> List.map (\t -> ( region, t )) (List.range 0 2))
        |> List.indexedMap
            (\i ( region, t ) ->
                { id = region ++ "-" ++ String.fromInt t
                , region = region
                , team = "Team " ++ String.fromInt t
                , amount = toFloat i
                }
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


configOf : List (Table.Column TestRow) -> Table.Config TestRow
configOf columns =
    Table.config columns
        |> Table.withGetRowId (\r _ _ -> r.id)


cfg : Table.Config TestRow
cfg =
    configOf [ regionColumn, teamColumn, amountColumn ]


base : Table.State
base =
    Table.initialState


rowsOf : Table.Config TestRow -> Table.State -> Table.SelectionRows TestRow
rowsOf config state =
    let
        prePaginated : Table.RowModel TestRow
        prePaginated =
            Table.coreRowModelFromList config state makeData
                |> Table.filteredRowModel config state
                |> Table.groupedRowModel config state
                |> Table.sortedRowModel config state
                |> Table.expandedRowModel config state
    in
    { prePaginated = prePaginated
    , current = Table.paginatedRowModel config state prePaginated
    }


rows : Table.SelectionRows TestRow
rows =
    rowsOf cfg base


getCell : Table.Config TestRow -> Table.SelectionRows TestRow -> String -> String -> Table.Cell
getCell config selectionRows rowId columnId =
    case Dict.get rowId selectionRows.prePaginated.rowsById of
        Nothing ->
            { id = "", columnId = "", rowId = "", value = Value.Null }

        Just row ->
            Table.getAllCells config base row
                |> List.filter (\cell -> cell.columnId == columnId)
                |> List.head
                |> Maybe.withDefault { id = "", columnId = "", rowId = "", value = Value.Null }


cellOf : String -> String -> Table.Cell
cellOf =
    getCell cfg rows


rangeOf : String -> String -> String -> String -> Table.CellSelectionRange
rangeOf =
    Table.cellRange


bounds : Int -> Int -> Int -> Int -> Table.CellSelectionBounds
bounds minRowIndex maxRowIndex minColumnIndex maxColumnIndex =
    { minRowIndex = minRowIndex
    , maxRowIndex = maxRowIndex
    , minColumnIndex = minColumnIndex
    , maxColumnIndex = maxColumnIndex
    }


suite : Test
suite =
    describe "cell selection with cell spanning"
        [ expandSuite
        , edgesSuite
        , navigationSuite
        , derivedSuite
        , absentSuite
        , columnSpanSuite
        , spanningFeatureSuite
        ]


expandSuite : Test
expandSuite =
    describe "selection expands to enclose merged cells"
        [ test "expands a range that clips a merge to the full merge" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.setCellSelection [ rangeOf "North-1" "team" "North-1" "region" ] base
                in
                Expect.equal
                    { bounds = Table.cellSelectionBounds cfg state rows
                    , anchorRegion = Table.cellIsSelected cfg state rows (cellOf "North-0" "region")
                    , lastTeam = Table.cellIsSelected cfg state rows (cellOf "North-2" "team")
                    , amount = Table.cellIsSelected cfg state rows (cellOf "North-0" "amount")
                    }
                    { bounds = [ bounds 0 2 0 1 ]
                    , anchorRegion = True
                    , lastTeam = True
                    , amount = False
                    }
        , test "does not expand a range that avoids every merge" <|
            \_ ->
                Table.setCellSelection [ rangeOf "North-0" "team" "North-1" "amount" ] base
                    |> (\state -> Table.cellSelectionBounds cfg state rows)
                    |> Expect.equal [ bounds 0 1 1 2 ]
        , test "expands exclude operations so a merge is never partially selected" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.setCellSelection
                            [ rangeOf "North-0" "region" "South-2" "amount"
                            , { anchorRowId = "North-1"
                              , anchorColumnId = "region"
                              , focusRowId = "North-1"
                              , focusColumnId = "region"
                              , operation = Table.excludeCells
                              }
                            ]
                            base
                in
                Expect.equal
                    { merge =
                        List.range 0 2
                            |> List.map
                                (\i ->
                                    Table.cellIsSelected cfg state rows (cellOf ("North-" ++ String.fromInt i) "region")
                                )
                    , team = Table.cellIsSelected cfg state rows (cellOf "North-1" "team")
                    , south = Table.cellIsSelected cfg state rows (cellOf "South-0" "region")
                    }
                    { merge = [ False, False, False ], team = True, south = True }
        , test "keeps stored corners stable while spanning is toggled" <|
            \_ ->
                let
                    off : Table.Config TestRow
                    off =
                        Table.withCellSpanning False cfg

                    state : Table.State
                    state =
                        Table.setCellSelection [ rangeOf "North-1" "region" "North-1" "team" ] base
                in
                Expect.equal
                    ( Table.cellSelectionBounds off state (rowsOf off base)
                    , Table.cellSelectionBounds cfg state rows
                    )
                    ( [ bounds 1 1 0 1 ], [ bounds 0 2 0 1 ] )
        ]


edgesSuite : Test
edgesSuite =
    describe "selection edges around merged cells"
        [ test "draws the outline at the merge rectangle boundary" <|
            \_ ->
                Table.setCellSelection [ rangeOf "North-0" "region" "North-2" "region" ] base
                    |> (\state -> Table.cellSelectionEdges cfg state rows (cellOf "North-0" "region"))
                    |> Expect.equal { top = True, right = True, bottom = True, left = True }
        , test "opens the merge edge that faces adjacent selected cells" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.setCellSelection [ rangeOf "North-0" "region" "North-2" "team" ] base
                in
                Expect.equal
                    ( Table.cellSelectionEdges cfg state rows (cellOf "North-0" "region")
                    , Table.cellSelectionEdges cfg state rows (cellOf "North-1" "team")
                    )
                    ( { top = True, right = False, bottom = True, left = True }
                    , { top = False, right = True, bottom = False, left = False }
                    )
        , test "marks a side as an edge when any strip cell is outside" <|
            \_ ->
                Table.setCellSelection
                    [ rangeOf "North-0" "region" "North-2" "region"
                    , rangeOf "North-1" "team" "North-1" "team"
                    ]
                    base
                    |> (\state -> Table.cellSelectionEdges cfg state rows (cellOf "North-0" "region"))
                    |> .right
                    |> Expect.equal True
        ]


navigationSuite : Test
navigationSuite =
    describe "navigation treats a merge as one stop"
        [ test "crosses a merge with a single vertical step" <|
            \_ ->
                Table.setFocusedCell "North-0" "region" base
                    |> Table.moveCellSelection cfg rows Table.cellDown
                    |> (\state -> Table.focusedCell cfg state rows)
                    |> Maybe.map (\cell -> ( cell.rowId, cell.columnId ))
                    |> Expect.equal (Just ( "South-0", "region" ))
        , test "snaps an entering step to the merge anchor" <|
            \_ ->
                Table.setFocusedCell "North-1" "team" base
                    |> Table.moveCellSelection cfg rows Table.cellLeft
                    |> (\state -> Table.focusedCell cfg state rows)
                    |> Maybe.map (\cell -> ( cell.rowId, cell.columnId ))
                    |> Expect.equal (Just ( "North-0", "region" ))
        , test "extends a selection past a merge in one step" <|
            \_ ->
                Table.setFocusedCell "East-2" "region" base
                    |> Table.extendCellSelection cfg rows Table.cellUp
                    |> (\state -> Table.cellSelectionBounds cfg state rows)
                    |> Expect.equal [ bounds 3 8 0 0 ]
        ]


derivedSuite : Test
derivedSuite =
    let
        state : Table.State
        state =
            Table.setCellSelection [ rangeOf "North-0" "region" "North-2" "team" ] base
    in
    describe "derived reads dedupe covered cells"
        [ test "counts a merge once and skips covered ids" <|
            \_ ->
                let
                    ids : List String
                    ids =
                        Table.selectedCellIds cfg state rows
                in
                Expect.equal
                    { count = Table.selectedCellCount cfg state rows
                    , length = List.length ids
                    , hasAnchor = List.member "North-0_region" ids
                    , hasCovered = List.member "North-1_region" ids
                    }
                    { count = 4, length = 4, hasAnchor = True, hasCovered = False }
        , test "keeps ranges data as the full lattice grid" <|
            \_ ->
                Table.selectedCellRangesData cfg state rows
                    |> List.head
                    |> Expect.equal
                        (Just
                            [ [ Value.String "North", Value.String "Team 0" ]
                            , [ Value.String "North", Value.String "Team 1" ]
                            , [ Value.String "North", Value.String "Team 2" ]
                            ]
                        )
        ]


absentSuite : Test
absentSuite =
    describe "spanning absent or disabled leaves selection untouched"
        [ test "behaves lattice-wise when enableCellSpanning is false" <|
            \_ ->
                let
                    off : Table.Config TestRow
                    off =
                        Table.withCellSpanning False cfg

                    offRows : Table.SelectionRows TestRow
                    offRows =
                        rowsOf off base

                    state : Table.State
                    state =
                        Table.setCellSelection [ rangeOf "North-1" "region" "North-1" "team" ] base
                in
                Expect.equal
                    ( Table.cellSelectionBounds off state offRows
                    , Table.selectedCellCount off state offRows
                    )
                    ( [ bounds 1 1 0 1 ], 2 )

        -- Adapted: there is no feature registry, so "without the spanning
        -- feature" is a table whose columns declare no spans.
        , test "reports no merge bounds without the spanning feature" <|
            \_ ->
                let
                    bare : Table.Config TestRow
                    bare =
                        configOf
                            [ Table.column "region" (.region >> Value.String)
                            , teamColumn
                            , amountColumn
                            ]

                    bareRows : Table.SelectionRows TestRow
                    bareRows =
                        rowsOf bare base

                    state : Table.State
                    state =
                        Table.setCellSelection [ rangeOf "North-1" "region" "North-1" "team" ] base
                in
                Expect.equal
                    ( Table.cellSelectionMergeBounds bare base bareRows
                    , Table.cellSelectionBounds bare state bareRows
                    )
                    ( [], [ bounds 1 1 0 1 ] )
        ]


columnSpanSuite : Test
columnSpanSuite =
    describe "column spans map into merge bounds"
        [ test "emits a horizontal-only span as a one-row merge and expands to it" <|
            \_ ->
                let
                    config : Table.Config TestRow
                    config =
                        configOf
                            [ regionColumn
                            , teamColumn
                                |> Table.withSpanColumns
                                    (\row ->
                                        if Table.rowId row == "South-1" then
                                            2

                                        else
                                            1
                                    )
                            , amountColumn
                            ]

                    configRows : Table.SelectionRows TestRow
                    configRows =
                        rowsOf config base

                    state : Table.State
                    state =
                        Table.setCellSelection [ rangeOf "South-1" "amount" "South-1" "amount" ] base
                in
                Expect.equal
                    { merges = Table.cellSelectionMergeBounds config base configRows
                    , bounds = Table.cellSelectionBounds config state configRows
                    , count = Table.selectedCellCount config state configRows
                    }
                    { merges =
                        [ bounds 0 2 0 0
                        , bounds 3 5 0 0
                        , bounds 6 8 0 0
                        , bounds 4 4 1 2
                        ]
                    , bounds = [ bounds 4 4 1 2 ]
                    , count = 1
                    }
        , test "emits a row-and-column rectangle as one merge, not one per row" <|
            \_ ->
                let
                    config : Table.Config TestRow
                    config =
                        configOf
                            [ regionColumn
                                |> Table.withSpanColumns
                                    (\row ->
                                        if (Table.rowOriginal row).region == "North" then
                                            2

                                        else
                                            1
                                    )
                            , teamColumn
                            , amountColumn
                            ]

                    configRows : Table.SelectionRows TestRow
                    configRows =
                        rowsOf config base

                    state : Table.State
                    state =
                        Table.setCellSelection [ rangeOf "North-1" "team" "North-1" "team" ] base
                in
                Expect.equal
                    { merges = Table.cellSelectionMergeBounds config base configRows
                    , bounds = Table.cellSelectionBounds config state configRows
                    , count = Table.selectedCellCount config state configRows
                    , covered =
                        Table.cellIsSelected config state configRows (getCell config configRows "North-2" "team")
                    }
                    { merges = [ bounds 0 2 0 1, bounds 3 5 0 0, bounds 6 8 0 0 ]
                    , bounds = [ bounds 0 2 0 1 ]
                    , count = 1
                    , covered = True
                    }
        ]


spanningFeatureSuite : Test
spanningFeatureSuite =
    describe "cell selection composes with spanning"
        [ test "expands the selection to enclose a spanned rectangle and counts it once" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.setCellSelection [ rangeOf "North-1" "region" "North-1" "team" ] base

                    covered : Table.Cell
                    covered =
                        cellOf "North-1" "region"

                    index : Table.CellSpanIndex
                    index =
                        Table.cellSpanIndex cfg base rows.current
                in
                Expect.equal
                    { bounds = Table.cellSelectionBounds cfg state rows
                    , rowSpan = Table.cellRowSpan index covered
                    , isSelected = Table.cellIsSelected cfg state rows covered
                    , count = Table.selectedCellCount cfg state rows
                    , hasCovered = List.member "North-1_region" (Table.selectedCellIds cfg state rows)
                    }
                    { bounds = [ bounds 0 2 0 1 ]
                    , rowSpan = 0
                    , isSelected = True
                    , count = 4
                    , hasCovered = False
                    }
        ]
