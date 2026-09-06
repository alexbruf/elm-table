module RowPinningFeatureTest exposing (pendingIntegration, suite)

{-| Ports `tests/implementation/features/row-pinning/rowPinningFeature.test.ts`.

`pendingIntegration` holds the case that needs the grouped row model, which
is still a stub in this worktree. Excluded cases are listed in
`reports/phase-5.md`.

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


page : Int -> Table.RowModel Person -> Table.RowModel Person
page size from =
    let
        rows : List (Table.Row Person)
        rows =
            List.take size from.rows
    in
    { rows = rows
    , flatRows = rows
    , rowsById = Dict.fromList (List.map (\row -> ( Table.rowId row, row )) rows)
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


suite : Test
suite =
    describe "rowPinningFeature"
        [ describe "table methods"
            [ describe "setRowPinning"
                [ test "should call onRowPinningChange when invoked" <|
                    \_ ->
                        Table.setRowPinning { top = [ "0" ], bottom = [ "1" ] } state
                            |> .rowPinning
                            |> Expect.equal { top = [ "0" ], bottom = [ "1" ] }
                ]
            , describe "resetRowPinning"
                [ test "should reset to default state when defaultState is true" <|
                    \_ ->
                        state
                            |> Table.setRowPinning { top = [ "0" ], bottom = [ "1" ] }
                            |> Table.resetRowPinning
                            |> .rowPinning
                            |> Expect.equal { top = [], bottom = [] }
                , test "should reset to initial state when defaultState is false" <|
                    \_ ->
                        let
                            initial : Table.RowPinning
                            initial =
                                { top = [ "0" ], bottom = [ "1" ] }
                        in
                        state
                            |> Table.setRowPinning { top = [ "2" ], bottom = [] }
                            |> Table.setRowPinning initial
                            |> .rowPinning
                            |> Expect.equal initial
                ]
            , describe "getIsSomeRowsPinned"
                [ test "should return false when no rows are pinned" <|
                    \_ ->
                        Expect.all
                            [ \_ -> Expect.equal False (Table.isSomeRowsPinned state)
                            , \_ -> Expect.equal False (Table.isSomeRowsPinnedTop state)
                            , \_ -> Expect.equal False (Table.isSomeRowsPinnedBottom state)
                            ]
                            ()
                , test "should return true when rows are pinned" <|
                    \_ ->
                        let
                            pinned : Table.State
                            pinned =
                                pinningState [ "0" ] [ "1" ]
                        in
                        Expect.all
                            [ \_ -> Expect.equal True (Table.isSomeRowsPinned pinned)
                            , \_ -> Expect.equal True (Table.isSomeRowsPinnedTop pinned)
                            , \_ -> Expect.equal True (Table.isSomeRowsPinnedBottom pinned)
                            ]
                            ()
                ]
            , describe "getTopRows/getBottomRows/getCenterRows"
                [ test "should return correct rows for each section" <|
                    \_ ->
                        let
                            pinned : Table.State
                            pinned =
                                pinningState [ "0" ] [ "2" ]
                        in
                        Expect.all
                            [ \_ -> Expect.equal [ "0" ] (ids (Table.topRows cfg pinned whole))
                            , \_ -> Expect.equal [ "2" ] (ids (Table.bottomRows cfg pinned whole))
                            , \_ -> Expect.equal 8 (List.length (Table.centerRows pinned ten))
                            , \_ ->
                                Table.centerRows pinned ten
                                    |> ids
                                    |> List.filter (\rowId -> rowId == "0" || rowId == "2")
                                    |> Expect.equal []
                            ]
                            ()
                , test "should handle keepPinnedRows - false" <|
                    \_ ->
                        let
                            pinned : Table.State
                            pinned =
                                pinningState [ "0" ] [ "2" ]

                            config : Table.Config Person
                            config =
                                { cfg | keepPinnedRows = False }
                        in
                        Expect.all
                            [ \_ -> Expect.equal 1 (List.length (Table.topRows config pinned (source (page 2 ten))))
                            , \_ -> Expect.equal 0 (List.length (Table.bottomRows config pinned (source (page 2 ten))))
                            ]
                            ()
                ]
            , test "should handle keepPinnedRows - true" <|
                \_ ->
                    let
                        pinned : Table.State
                        pinned =
                            pinningState [ "0" ] [ "2" ]
                    in
                    Expect.all
                        [ \_ -> Expect.equal 1 (List.length (Table.topRows cfg pinned (source (page 2 ten))))
                        , \_ -> Expect.equal 1 (List.length (Table.bottomRows cfg pinned (source (page 2 ten))))
                        ]
                        ()
            ]
        , describe "row methods"
            [ describe "getCanPin"
                [ test "should return true by default" <|
                    \_ -> withRow "0" (\row -> Table.getCanPinRow cfg row |> Expect.equal True)
                , test "should return false when enableRowPinning is false" <|
                    \_ ->
                        withRow "0"
                            (\row ->
                                Table.getCanPinRow { cfg | enableRowPinning = always False } row
                                    |> Expect.equal False
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
            , describe "getIsPinned"
                [ test "should return false when row is not pinned" <|
                    \_ -> withRow "0" (\row -> Table.getIsRowPinned state row |> Expect.equal Table.rowUnpinned)
                , test "should return correct position when row is pinned" <|
                    \_ ->
                        let
                            pinned : Table.State
                            pinned =
                                pinningState [ "0" ] [ "1" ]
                        in
                        Expect.all
                            [ \_ -> withRow "0" (\row -> Table.getIsRowPinned pinned row |> Expect.equal Table.pinnedTop)
                            , \_ -> withRow "1" (\row -> Table.getIsRowPinned pinned row |> Expect.equal Table.pinnedBottom)
                            ]
                            ()
                ]
            , describe "getPinnedIndex"
                [ test "should return -1 when row is not pinned" <|
                    \_ -> withRow "0" (\row -> Table.getRowPinnedIndex cfg state whole row |> Expect.equal -1)
                , test "should return correct index for pinned rows" <|
                    \_ ->
                        let
                            pinned : Table.State
                            pinned =
                                pinningState [ "0", "1" ] [ "2" ]
                        in
                        Expect.all
                            [ \_ -> withRow "0" (\row -> Table.getRowPinnedIndex cfg pinned whole row |> Expect.equal 0)
                            , \_ -> withRow "1" (\row -> Table.getRowPinnedIndex cfg pinned whole row |> Expect.equal 1)
                            , \_ -> withRow "2" (\row -> Table.getRowPinnedIndex cfg pinned whole row |> Expect.equal 0)
                            ]
                            ()
                ]
            , describe "pin"
                [ test "should call onRowPinningChange when pinning row" <|
                    \_ ->
                        withRow "0"
                            (\row ->
                                Table.pinRow Table.pinnedTop row state
                                    |> .rowPinning
                                    |> Expect.equal { top = [ "0" ], bottom = [] }
                            )
                , test "should call onRowPinningChange when unpinning row" <|
                    \_ ->
                        withRow "0"
                            (\row ->
                                Table.pinRow Table.rowUnpinned row (pinningState [ "0" ] [])
                                    |> .rowPinning
                                    |> Expect.equal { top = [], bottom = [] }
                            )
                , test "should call onRowPinningChange when including leaf rows" <|
                    \_ ->
                        withRow "0"
                            (\row ->
                                Table.pinRowWith Table.pinnedTop
                                    { includeLeafRows = True, includeParentRows = False }
                                    ten
                                    row
                                    state
                                    |> .rowPinning
                                    |> Expect.equal { top = [ "0" ], bottom = [] }
                            )
                , test "should call onRowPinningChange when including parent rows" <|
                    \_ ->
                        withRow "0"
                            (\row ->
                                Table.pinRowWith Table.pinnedTop
                                    { includeLeafRows = False, includeParentRows = True }
                                    ten
                                    row
                                    state
                                    |> .rowPinning
                                    |> Expect.equal { top = [ "0" ], bottom = [] }
                            )
                ]
            ]
        ]


{-| Needs the grouped row model, which is an identity stub in this worktree.
-}
pendingIntegration : List Test
pendingIntegration =
    [ describe "getTopRows/getBottomRows/getCenterRows"
        [ test "does not throw when a pinned grouped row disappears after ungrouping" <|
            \_ ->
                let
                    data : List Person
                    data =
                        Fixtures.makeData [ 3 ]

                    groupedState : Table.State
                    groupedState =
                        { state | grouping = [ "status" ] }

                    groupedModel : Table.State -> Table.RowModel Person
                    groupedModel current =
                        Table.coreRowModelFromList cfg current data
                            |> Table.groupedRowModel cfg current

                    groupedRowId : String
                    groupedRowId =
                        groupedModel groupedState
                            |> .rows
                            |> List.head
                            |> Maybe.map Table.rowId
                            |> Maybe.withDefault "missing"

                    pinnedGrouped : Table.State
                    pinnedGrouped =
                        { groupedState | rowPinning = { top = [ groupedRowId ], bottom = [] } }

                    pinnedUngrouped : Table.State
                    pinnedUngrouped =
                        { state | rowPinning = { top = [ groupedRowId ], bottom = [] } }

                    sourceFor : Table.State -> Table.PinnedRowsSource Person
                    sourceFor current =
                        { prePaginated = groupedModel current, current = groupedModel current }
                in
                Expect.all
                    [ \_ ->
                        Expect.equal [ groupedRowId ]
                            (ids (Table.topRows cfg pinnedGrouped (sourceFor pinnedGrouped)))
                    , \_ ->
                        Expect.equal []
                            (ids (Table.topRows cfg pinnedUngrouped (sourceFor pinnedUngrouped)))
                    , \_ -> Expect.equal [ groupedRowId ] pinnedUngrouped.rowPinning.top
                    ]
                    ()
        ]
    ]
