module CellSpanningTest exposing (suite)

{-| Ports `tests/unit/features/cell-spanning/cellSpanningFeature.utils.test.ts`.

Excluded cases are listed in `reports/phase-6.md`.

-}

import Dict
import Expect
import Table
import Table.Value as Value exposing (Value)
import Test exposing (Test, describe, test)


type alias TestRow =
    { id : String
    , region : Maybe String
    , team : String
    , amount : Maybe Float
    , isSummary : Bool
    }


row : String -> Maybe String -> String -> Maybe Float -> TestRow
row id region team amount =
    { id = id, region = region, team = team, amount = amount, isSummary = False }


summaryRow : String -> Maybe String -> String -> Maybe Float -> TestRow
summaryRow id region team amount =
    { id = id, region = region, team = team, amount = amount, isSummary = True }


maybeString : Maybe String -> Value
maybeString value =
    case value of
        Just text ->
            Value.String text

        Nothing ->
            Value.Null


maybeNumber : Maybe Float -> Value
maybeNumber value =
    case value of
        Just number ->
            Value.Number number

        Nothing ->
            Value.Null


defaultData : List TestRow
defaultData =
    [ row "r0" (Just "North") "Alpha" (Just 1)
    , row "r1" (Just "North") "Alpha" (Just 2)
    , row "r2" (Just "North") "Bravo" (Just 3)
    , row "r3" (Just "South") "Bravo" (Just 4)
    , row "r4" (Just "South") "Alpha" (Just 5)
    ]


regionColumn : Table.Column TestRow
regionColumn =
    Table.column "region" (.region >> maybeString) |> Table.withSpanRows


teamColumn : Table.Column TestRow
teamColumn =
    Table.column "team" (.team >> Value.String)


amountColumn : Table.Column TestRow
amountColumn =
    Table.column "amount" (.amount >> maybeNumber)


defaultColumns : List (Table.Column TestRow)
defaultColumns =
    [ regionColumn, teamColumn, amountColumn ]


configOf : List (Table.Column TestRow) -> Table.Config TestRow
configOf columns =
    Table.config columns
        |> Table.withGetRowId (\r _ _ -> r.id)


state : Table.State
state =
    Table.initialState


modelOf : Table.Config TestRow -> List TestRow -> Table.RowModel TestRow
modelOf cfg data =
    Table.coreRowModelFromList cfg state data


index : Table.Config TestRow -> List TestRow -> Table.CellSpanIndex
index cfg data =
    Table.cellSpanIndex cfg state (modelOf cfg data)


{-| `cell_getRowSpan` of one column, over every row of the row model, the way
the vitest helper `rowSpansOf` does.
-}
rowSpansOf : Table.Config TestRow -> List TestRow -> String -> List Int
rowSpansOf cfg data columnId =
    let
        spans : Table.CellSpanIndex
        spans =
            index cfg data
    in
    (modelOf cfg data).rows
        |> List.filterMap
            (\r ->
                Table.getAllCells cfg state r
                    |> List.filter (\cell -> cell.columnId == columnId)
                    |> List.head
            )
        |> List.map (Table.cellRowSpan spans)


cellsOf : Table.Config TestRow -> List TestRow -> String -> Dict.Dict String Table.Cell
cellsOf cfg data rowId =
    case Dict.get rowId (modelOf cfg data).rowsById of
        Nothing ->
            Dict.empty

        Just r ->
            Table.getAllCells cfg state r
                |> List.map (\cell -> ( cell.columnId, cell ))
                |> Dict.fromList


cellAt : Table.Config TestRow -> List TestRow -> String -> String -> Table.Cell
cellAt cfg data rowId columnId =
    Dict.get columnId (cellsOf cfg data rowId)
        |> Maybe.withDefault { id = "", columnId = "", rowId = "", value = Value.Null }


suite : Test
suite =
    describe "cellSpanningFeature.utils"
        [ describe "table_getCellSpanIndex"
            [ test "detects value runs with the anchor holding the run length" <|
                \_ ->
                    index (configOf defaultColumns) defaultData
                        |> Table.cellSpanIndexRowSpans
                        |> Dict.get "region"
                        |> Expect.equal (Just [ 3, 0, 0, 2, 0 ])
            , test "stores no array for a column whose every run has length one" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            configOf [ regionColumn, Table.withSpanRows teamColumn, amountColumn ]

                        data : List TestRow
                        data =
                            [ row "r0" (Just "North") "Alpha" (Just 1)
                            , row "r1" (Just "South") "Bravo" (Just 2)
                            , row "r2" (Just "North") "Alpha" (Just 3)
                            ]

                        spans : Dict.Dict String (List Int)
                        spans =
                            Table.cellSpanIndexRowSpans (index cfg data)
                    in
                    Expect.equal
                        ( Dict.get "region" spans, Dict.get "team" spans, rowSpansOf cfg data "region" )
                        ( Nothing, Nothing, [ 1, 1, 1 ] )
            , test "never merges nullish values under the default comparison" <|
                \_ ->
                    let
                        data : List TestRow
                        data =
                            [ row "r0" Nothing "Alpha" (Just 1)
                            , row "r1" Nothing "Alpha" (Just 2)
                            , row "r2" (Just "North") "Alpha" Nothing
                            , row "r3" (Just "North") "Alpha" Nothing
                            ]
                    in
                    rowSpansOf (configOf defaultColumns) data "region"
                        |> Expect.equal [ 1, 1, 2, 0 ]
            , test "merges nullish values when a predicate opts in" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            configOf
                                [ Table.withSpanRowsWhen (\ctx -> ctx.anchorValue == ctx.value) regionColumn
                                , teamColumn
                                , amountColumn
                                ]

                        data : List TestRow
                        data =
                            [ row "r0" Nothing "Alpha" (Just 1)
                            , row "r1" Nothing "Alpha" (Just 2)
                            , row "r2" (Just "North") "Alpha" (Just 3)
                            ]
                    in
                    rowSpansOf cfg data "region" |> Expect.equal [ 2, 0, 1 ]

            -- Adjusted: Elm's `==` is not JavaScript's `Object.is`. `NaN` is
            -- unequal to itself and `-0 == 0`, so the two NaN rows do not
            -- merge and the two zero rows do. See `reports/phase-6.md`.
            , test "merges NaN values and keeps -0 and 0 distinct, following Object.is" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            configOf [ Table.withSpanRows amountColumn ]

                        data : List TestRow
                        data =
                            [ row "r0" (Just "x") "x" (Just (sqrt -1))
                            , row "r1" (Just "x") "x" (Just (sqrt -1))
                            , row "r2" (Just "x") "x" (Just (negate 0))
                            , row "r3" (Just "x") "x" (Just 0)
                            ]
                    in
                    rowSpansOf cfg data "amount" |> Expect.equal [ 1, 1, 2, 0 ]
            , test "anchors predicate runs so every candidate compares against the run start" <|
                \_ ->
                    let
                        -- The predicate cannot record into a mutable list, so
                        -- it answers `True` only for the exact
                        -- (anchor, previous, row) triples the anchored
                        -- comparison must produce. A chained implementation
                        -- would hand r2 an anchor of r1 and the run would
                        -- break.
                        seen : List ( String, String, String )
                        seen =
                            [ ( "r0", "r0", "r1" ), ( "r0", "r1", "r2" ) ]

                        triple : Table.RowSpanContext TestRow -> ( String, String, String )
                        triple ctx =
                            ( (Table.rowOriginal ctx.anchorRow).id
                            , (Table.rowOriginal ctx.previousRow).id
                            , (Table.rowOriginal ctx.row).id
                            )

                        cfg : Table.Config TestRow
                        cfg =
                            configOf
                                [ Table.withSpanRowsWhen (\ctx -> List.member (triple ctx) seen) regionColumn
                                , teamColumn
                                , amountColumn
                                ]

                        data : List TestRow
                        data =
                            [ row "r0" (Just "North") "a" (Just 1)
                            , row "r1" (Just "North") "a" (Just 2)
                            , row "r2" (Just "North") "a" (Just 3)
                            ]
                    in
                    rowSpansOf cfg data "region" |> Expect.equal [ 3, 0, 0 ]
            , test "spans no cells when disabled at the table or column level" <|
                \_ ->
                    let
                        disabledTable : List Int
                        disabledTable =
                            rowSpansOf (Table.withCellSpanning False (configOf defaultColumns)) defaultData "region"

                        disabledColumn : List Int
                        disabledColumn =
                            rowSpansOf
                                (configOf [ Table.withEnableCellSpanning False regionColumn, teamColumn, amountColumn ])
                                defaultData
                                "region"
                    in
                    Expect.equal ( disabledTable, disabledColumn )
                        ( [ 1, 1, 1, 1, 1 ], [ 1, 1, 1, 1, 1 ] )
            , test "resolves column spans with covered cells reporting zero" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            configOf
                                [ Table.withSpanColumns
                                    (\r ->
                                        if (Table.rowOriginal r).isSummary then
                                            3

                                        else
                                            1
                                    )
                                    (Table.column "region" (.region >> maybeString))
                                , teamColumn
                                , amountColumn
                                ]

                        data : List TestRow
                        data =
                            [ row "r0" (Just "North") "Alpha" (Just 1)
                            , summaryRow "r1" (Just "Total") "" (Just 6)
                            ]

                        spans : Table.CellSpanIndex
                        spans =
                            index cfg data
                    in
                    Expect.equal
                        ( ( Table.cellColSpan spans (cellAt cfg data "r1" "region")
                          , Table.cellColSpan spans (cellAt cfg data "r1" "team")
                          , Table.cellColSpan spans (cellAt cfg data "r1" "amount")
                          )
                        , ( Table.cellIsCovered spans (cellAt cfg data "r1" "team")
                          , Table.cellColSpan spans (cellAt cfg data "r0" "region")
                          )
                        )
                        ( ( 3, 0, 0 ), ( True, 1 ) )
            , test "clamps Infinity column spans to the remaining columns" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            configOf
                                [ regionColumn
                                , Table.withSpanColumns (always Table.spanAllColumns) teamColumn
                                , amountColumn
                                ]

                        spans : Table.CellSpanIndex
                        spans =
                            index cfg defaultData
                    in
                    Expect.equal
                        ( Table.cellColSpan spans (cellAt cfg defaultData "r0" "team")
                        , Table.cellColSpan spans (cellAt cfg defaultData "r0" "amount")
                        , Table.cellColSpan spans (cellAt cfg defaultData "r0" "region")
                        )
                        ( 2, 0, 1 )
            , test "ends a vertical run at a horizontally spanning row" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            configOf
                                [ regionColumn
                                    |> Table.withSpanColumns
                                        (\r ->
                                            if (Table.rowOriginal r).isSummary then
                                                Table.spanAllColumns

                                            else
                                                1
                                        )
                                , teamColumn
                                , amountColumn
                                ]

                        data : List TestRow
                        data =
                            [ row "r0" (Just "North") "a" (Just 1)
                            , row "r1" (Just "North") "a" (Just 2)
                            , summaryRow "r2" (Just "North") "" (Just 3)
                            , row "r3" (Just "North") "b" (Just 4)
                            ]
                    in
                    rowSpansOf cfg data "region" |> Expect.equal [ 2, 0, 1, 1 ]
            , test "covers the full rectangle when a cell spans rows and columns" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            configOf
                                [ regionColumn |> Table.withSpanColumns (always 2)
                                , teamColumn
                                , amountColumn
                                ]

                        data : List TestRow
                        data =
                            [ row "r0" (Just "North") "a" (Just 1)
                            , row "r1" (Just "North") "b" (Just 2)
                            ]

                        spans : Table.CellSpanIndex
                        spans =
                            index cfg data

                        covered : List Bool
                        covered =
                            [ cellAt cfg data "r0" "team"
                            , cellAt cfg data "r1" "region"
                            , cellAt cfg data "r1" "team"
                            ]
                                |> List.map (Table.cellIsCovered spans)
                    in
                    Expect.equal
                        { anchorRowSpan = Table.cellRowSpan spans (cellAt cfg data "r0" "region")
                        , anchorColSpan = Table.cellColSpan spans (cellAt cfg data "r0" "region")
                        , anchorTeamColSpan = Table.cellColSpan spans (cellAt cfg data "r0" "team")
                        , belowRowSpan = Table.cellRowSpan spans (cellAt cfg data "r1" "region")
                        , belowTeamColSpan = Table.cellColSpan spans (cellAt cfg data "r1" "team")
                        , covered = covered
                        , anchorCovered = Table.cellIsCovered spans (cellAt cfg data "r0" "region")
                        }
                        { anchorRowSpan = 2
                        , anchorColSpan = 2
                        , anchorTeamColSpan = 0
                        , belowRowSpan = 0
                        , belowTeamColSpan = 0
                        , covered = [ True, True, True ]
                        , anchorCovered = False
                        }
            , test "handles empty and single-row tables without storing spans" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            configOf defaultColumns

                        single : List TestRow
                        single =
                            List.take 1 defaultData
                    in
                    Expect.equal
                        { emptyRows = Table.cellSpanIndexRowIds (index cfg [])
                        , emptyKeys = Dict.keys (Table.cellSpanIndexRowSpans (index cfg []))
                        , singleSpans = rowSpansOf cfg single "region"
                        , singleKeys = Dict.keys (Table.cellSpanIndexRowSpans (index cfg single))
                        }
                        { emptyRows = []
                        , emptyKeys = []
                        , singleSpans = [ 1 ]
                        , singleKeys = []
                        }
            ]
        , describe "statics without the feature registered"
            -- Adapted: there is no feature registry in this port, so "the
            -- static path still works" is the ordinary path.
            [ test "reports spans of one and builds an index from the row model" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            configOf [ regionColumn, teamColumn ]

                        firstCell : Table.Cell
                        firstCell =
                            (modelOf cfg defaultData).rows
                                |> List.head
                                |> Maybe.map (Table.getAllCells cfg state)
                                |> Maybe.andThen List.head
                                |> Maybe.withDefault { id = "", columnId = "", rowId = "", value = Value.Null }
                    in
                    Expect.equal
                        ( Table.cellRowSpan (index cfg defaultData) firstCell
                        , Table.findColumn cfg "team" |> Maybe.map (Table.columnCanSpan cfg)
                        )
                        ( 3, Just True )
            ]
        ]
