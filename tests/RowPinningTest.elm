module RowPinningTest exposing (suite)

{-| Ports `tests/unit/features/row-pinning/rowPinningFeature.utils.test.ts`.

The pinned row lists take both row models as one argument, so the cases that
mock `table.getRowModel()` build the current page by slicing the core row
model. Excluded cases are listed in `reports/phase-5.md`.

-}

import Dict
import Expect
import Fixtures exposing (Person)
import Table
import Test exposing (Test, describe, test)


cfg : Table.Config Person
cfg =
    Fixtures.config


state : Table.State
state =
    Table.initialState


model : List Int -> Table.RowModel Person
model lengths =
    Table.coreRowModelFromList cfg state (Fixtures.makeData lengths)


ten : Table.RowModel Person
ten =
    model [ 10 ]


{-| The first `size` root rows, standing in for the current page.
-}
page : Int -> Table.RowModel Person -> Table.RowModel Person
page size from =
    let
        rows : List (Table.Row Person)
        rows =
            List.take size from.rows

        flat : List (Table.Row Person)
        flat =
            List.concatMap (\row -> row :: Table.getLeafRows row) rows
    in
    { rows = rows
    , flatRows = flat
    , rowsById = Dict.fromList (List.map (\row -> ( Table.rowId row, row )) flat)
    }


source : Table.RowModel Person -> Table.PinnedRowsSource Person
source current =
    { prePaginated = ten, current = current }


whole : Table.PinnedRowsSource Person
whole =
    source ten


pinningState : List String -> List String -> Table.State
pinningState top bottom =
    { state | rowPinning = { top = top, bottom = bottom } }


ids : List (Table.Row Person) -> List String
ids =
    List.map Table.rowId


withRow : String -> (Table.Row Person -> Expect.Expectation) -> Expect.Expectation
withRow rowId fn =
    case Table.findRow ten rowId of
        Just row ->
            fn row

        Nothing ->
            Expect.fail ("no row " ++ rowId)


withNestedRow : Table.RowModel Person -> String -> (Table.Row Person -> Expect.Expectation) -> Expect.Expectation
withNestedRow nested rowId fn =
    case Table.findRow nested rowId of
        Just row ->
            fn row

        Nothing ->
            Expect.fail ("no row " ++ rowId)


suite : Test
suite =
    describe "rowPinningFeature.utils"
        [ describe "getDefaultRowPinningState"
            [ test "should return default row pinning state with empty top and bottom arrays" <|
                \_ -> Expect.equal { top = [], bottom = [] } Table.initialState.rowPinning
            ]
        , describe "table_setRowPinning"
            [ test "should call onRowPinningChange with the updater function" <|
                \_ ->
                    Table.setRowPinning { top = [ "1" ], bottom = [ "2" ] } state
                        |> .rowPinning
                        |> Expect.equal { top = [ "1" ], bottom = [ "2" ] }
            , test "should handle undefined onRowPinningChange without error" <|
                \_ ->
                    Table.setRowPinning { top = [], bottom = [] } state
                        |> .rowPinning
                        |> Expect.equal { top = [], bottom = [] }
            ]
        , describe "table_resetRowPinning"
            [ test "should reset to default state when defaultState is true" <|
                \_ ->
                    Table.resetRowPinning (pinningState [ "1" ] [])
                        |> .rowPinning
                        |> Expect.equal { top = [], bottom = [] }
            , test "should reset to initial state when defaultState is false" <|
                \_ ->
                    Table.setRowPinning { top = [ "1" ], bottom = [ "2" ] } state
                        |> .rowPinning
                        |> Expect.equal { top = [ "1" ], bottom = [ "2" ] }
            , test "should reset to default state when no initial state exists" <|
                \_ ->
                    Table.resetRowPinning (pinningState [ "1" ] [])
                        |> .rowPinning
                        |> Expect.equal { top = [], bottom = [] }
            ]
        , describe "table_getIsSomeRowsPinned"
            [ test "should return false when no rows are pinned" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal False (Table.isSomeRowsPinned state)
                        , \_ -> Expect.equal False (Table.isSomeRowsPinnedTop state)
                        , \_ -> Expect.equal False (Table.isSomeRowsPinnedBottom state)
                        ]
                        ()
            , test "should return true when rows are pinned to top" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal True (Table.isSomeRowsPinned (pinningState [ "0" ] []))
                        , \_ -> Expect.equal True (Table.isSomeRowsPinnedTop (pinningState [ "0" ] []))
                        , \_ -> Expect.equal False (Table.isSomeRowsPinnedBottom (pinningState [ "0" ] []))
                        ]
                        ()
            , test "should return true when rows are pinned to bottom" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal True (Table.isSomeRowsPinned (pinningState [] [ "0" ]))
                        , \_ -> Expect.equal False (Table.isSomeRowsPinnedTop (pinningState [] [ "0" ]))
                        , \_ -> Expect.equal True (Table.isSomeRowsPinnedBottom (pinningState [] [ "0" ]))
                        ]
                        ()
            , test "should handle undefined state" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal False (Table.isSomeRowsPinned state)
                        , \_ -> Expect.equal False (Table.isSomeRowsPinnedTop state)
                        , \_ -> Expect.equal False (Table.isSomeRowsPinnedBottom state)
                        ]
                        ()
            ]
        , describe "table_getTopRows and table_getBottomRows"
            [ test "should return empty arrays when no rows are pinned" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal [] (Table.topRows cfg state whole)
                        , \_ -> Expect.equal [] (Table.bottomRows cfg state whole)
                        ]
                        ()
            , test "should return pinned rows with position property" <|
                \_ ->
                    let
                        pinned : Table.State
                        pinned =
                            pinningState [ "0" ] [ "1" ]
                    in
                    Expect.all
                        [ \_ -> Expect.equal [ "0" ] (ids (Table.topRows cfg pinned whole))
                        , \_ -> Expect.equal [ "1" ] (ids (Table.bottomRows cfg pinned whole))
                        , \_ ->
                            Expect.equal (Table.findRow ten "0" |> Maybe.map List.singleton)
                                (Just (Table.topRows cfg pinned whole))
                        ]
                        ()
            , test "should handle keepPinnedRows=false by only returning visible rows" <|
                \_ ->
                    let
                        pinned : Table.State
                        pinned =
                            pinningState [ "0", "8" ] [ "1", "9" ]

                        config : Table.Config Person
                        config =
                            { cfg | keepPinnedRows = False }
                    in
                    Expect.all
                        [ \_ -> Expect.equal [ "0" ] (ids (Table.topRows config pinned (source (page 5 ten))))
                        , \_ -> Expect.equal [ "1" ] (ids (Table.bottomRows config pinned (source (page 5 ten))))
                        ]
                        ()
            , test "should handle keepPinnedRows=true by returning all pinned rows regardless of visibility" <|
                \_ ->
                    let
                        pinned : Table.State
                        pinned =
                            pinningState [ "0", "8" ] [ "1", "9" ]
                    in
                    Expect.all
                        [ \_ -> Expect.equal [ "0", "8" ] (ids (Table.topRows cfg pinned (source (page 5 ten))))
                        , \_ -> Expect.equal [ "1", "9" ] (ids (Table.bottomRows cfg pinned (source (page 5 ten))))
                        ]
                        ()
            , test "should handle undefined state" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal [] (Table.topRows cfg state whole)
                        , \_ -> Expect.equal [] (Table.bottomRows cfg state whole)
                        ]
                        ()
            ]
        , describe "table_getCenterRows"
            [ test "should return all rows when no rows are pinned" <|
                \_ ->
                    Table.centerRows state ten |> Expect.equal ten.rows
            , test "should return only unpinned rows when some rows are pinned" <|
                \_ ->
                    let
                        pinned : Table.State
                        pinned =
                            pinningState [ "0", "1" ] [ "8", "9" ]
                    in
                    Expect.all
                        [ \_ ->
                            Expect.equal (ten.rows |> List.drop 2 |> List.take 6)
                                (Table.centerRows pinned ten)
                        , \_ ->
                            Table.centerRows pinned ten
                                |> ids
                                |> List.filter (\rowId -> List.member rowId [ "0", "1", "8", "9" ])
                                |> Expect.equal []
                        ]
                        ()
            , test "should handle undefined state" <|
                \_ -> Table.centerRows state ten |> Expect.equal ten.rows
            ]
        , describe "row_getCanPin"
            [ test "should return true when enableRowPinning is undefined" <|
                \_ -> withRow "0" (\row -> Table.getCanPinRow cfg row |> Expect.equal True)
            , test "should return false when enableRowPinning is false" <|
                \_ ->
                    withRow "0"
                        (\row ->
                            Table.getCanPinRow { cfg | enableRowPinning = always False } row
                                |> Expect.equal False
                        )
            , test "should return true when enableRowPinning is true" <|
                \_ ->
                    withRow "0"
                        (\row ->
                            Table.getCanPinRow { cfg | enableRowPinning = always True } row
                                |> Expect.equal True
                        )
            , test "should use enableRowPinning function when provided" <|
                \_ ->
                    let
                        config : Table.Config Person
                        config =
                            { cfg | enableRowPinning = \row -> Table.rowId row == "1" }
                    in
                    Expect.all
                        [ \_ -> withRow "0" (\row -> Table.getCanPinRow config row |> Expect.equal False)
                        , \_ -> withRow "1" (\row -> Table.getCanPinRow config row |> Expect.equal True)
                        ]
                        ()
            ]
        , describe "row_getIsPinned"
            [ test "should return false when no rows are pinned" <|
                \_ -> withRow "0" (\row -> Table.getIsRowPinned state row |> Expect.equal Table.rowUnpinned)
            , test "should return \"top\" when row is pinned to top" <|
                \_ ->
                    withRow "0"
                        (\row -> Table.getIsRowPinned (pinningState [ "0" ] []) row |> Expect.equal Table.pinnedTop)
            , test "should return \"bottom\" when row is pinned to bottom" <|
                \_ ->
                    withRow "0"
                        (\row -> Table.getIsRowPinned (pinningState [] [ "0" ]) row |> Expect.equal Table.pinnedBottom)
            , test "should handle undefined state" <|
                \_ -> withRow "0" (\row -> Table.getIsRowPinned state row |> Expect.equal Table.rowUnpinned)
            ]
        , describe "row_getPinnedIndex"
            [ test "should return -1 when row is not pinned" <|
                \_ -> withRow "0" (\row -> Table.getRowPinnedIndex cfg state whole row |> Expect.equal -1)
            , test "should return correct index for top pinned rows" <|
                \_ ->
                    let
                        pinned : Table.State
                        pinned =
                            pinningState [ "0", "1", "2" ] []
                    in
                    Expect.all
                        [ \_ -> withRow "0" (\row -> Table.getRowPinnedIndex cfg pinned whole row |> Expect.equal 0)
                        , \_ -> withRow "1" (\row -> Table.getRowPinnedIndex cfg pinned whole row |> Expect.equal 1)
                        , \_ -> withRow "2" (\row -> Table.getRowPinnedIndex cfg pinned whole row |> Expect.equal 2)
                        ]
                        ()
            , test "should return correct index for bottom pinned rows" <|
                \_ ->
                    let
                        pinned : Table.State
                        pinned =
                            pinningState [] [ "0", "1", "2" ]
                    in
                    Expect.all
                        [ \_ -> withRow "0" (\row -> Table.getRowPinnedIndex cfg pinned whole row |> Expect.equal 0)
                        , \_ -> withRow "1" (\row -> Table.getRowPinnedIndex cfg pinned whole row |> Expect.equal 1)
                        , \_ -> withRow "2" (\row -> Table.getRowPinnedIndex cfg pinned whole row |> Expect.equal 2)
                        ]
                        ()
            , test "should handle undefined state" <|
                \_ -> withRow "0" (\row -> Table.getRowPinnedIndex cfg state whole row |> Expect.equal -1)
            ]
        , describe "row_pin"
            [ test "should pin a row to top" <|
                \_ ->
                    withRow "0"
                        (\row ->
                            Table.pinRow Table.pinnedTop row state
                                |> .rowPinning
                                |> Expect.equal { top = [ "0" ], bottom = [] }
                        )
            , test "should pin a row to bottom" <|
                \_ ->
                    withRow "0"
                        (\row ->
                            Table.pinRow Table.pinnedBottom row state
                                |> .rowPinning
                                |> Expect.equal { top = [], bottom = [ "0" ] }
                        )
            , test "should unpin a row when position is false" <|
                \_ ->
                    withRow "0"
                        (\row ->
                            Table.pinRow Table.rowUnpinned row (pinningState [ "0" ] [])
                                |> .rowPinning
                                |> Expect.equal { top = [], bottom = [] }
                        )
            , test "should include leaf rows when includeLeafRows is true" <|
                \_ ->
                    let
                        nested : Table.RowModel Person
                        nested =
                            model [ 3, 2 ]
                    in
                    withNestedRow nested
                        "0"
                        (\row ->
                            Table.pinRowWith Table.pinnedTop
                                { includeLeafRows = True, includeParentRows = False }
                                nested
                                row
                                state
                                |> .rowPinning
                                |> Expect.equal { top = [ "0", "0.0", "0.1" ], bottom = [] }
                        )
            , test "should include parent rows when includeParentRows is true" <|
                \_ ->
                    let
                        nested : Table.RowModel Person
                        nested =
                            model [ 3, 2 ]
                    in
                    withNestedRow nested
                        "0.0"
                        (\row ->
                            Table.pinRowWith Table.pinnedTop
                                { includeLeafRows = False, includeParentRows = True }
                                nested
                                row
                                state
                                |> .rowPinning
                                |> Expect.equal { top = [ "0", "0.0" ], bottom = [] }
                        )
            , test "should maintain existing pinned rows when pinning additional rows" <|
                \_ ->
                    withRow "0"
                        (\row ->
                            Table.pinRow Table.pinnedTop row (pinningState [ "1" ] [ "2" ])
                                |> .rowPinning
                                |> Expect.equal { top = [ "1", "0" ], bottom = [ "2" ] }
                        )
            , test "should remove row from other position when moving between top and bottom" <|
                \_ ->
                    withRow "0"
                        (\row ->
                            Table.pinRow Table.pinnedBottom row (pinningState [ "0" ] [])
                                |> .rowPinning
                                |> Expect.equal { top = [], bottom = [ "0" ] }
                        )
            ]
        ]
