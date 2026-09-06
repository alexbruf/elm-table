module RowSelectionTest exposing (suite)

{-| Ports `tests/unit/features/row-selection/rowSelectionFeature.utils.test.ts`.

The paginated row model is an argument here, so the cases about the current
page build their page by slicing the core row model. Excluded cases are
listed in `reports/phase-5.md`.

-}

import Dict
import Expect
import Fixtures exposing (Person)
import Set
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


{-| The first `size` root rows with their sub-rows, standing in for the
paginated row model.
-}
page : Int -> Table.RowModel Person -> Table.RowModel Person
page size source =
    let
        rows : List (Table.Row Person)
        rows =
            List.take size source.rows

        flat : List (Table.Row Person)
        flat =
            List.concatMap (\row -> row :: Table.getLeafRows row) rows
    in
    { rows = rows
    , flatRows = flat
    , rowsById = Dict.fromList (List.map (\row -> ( Table.rowId row, row )) flat)
    }


selecting : List String -> Table.State
selecting rowIds =
    { state | rowSelection = Set.fromList rowIds }


selected : Table.State -> List String
selected current =
    Set.toList current.rowSelection


withRow : Table.RowModel Person -> String -> (Table.Row Person -> Expect.Expectation) -> Expect.Expectation
withRow source rowId fn =
    case Table.findRow source rowId of
        Just row ->
            fn row

        Nothing ->
            Expect.fail ("no row " ++ rowId)


rowIdIsNot : String -> Table.Row Person -> Bool
rowIdIsNot rowId row =
    Table.rowId row /= rowId


suite : Test
suite =
    describe "rowSelectionFeature.utils"
        [ describe "getDefaultRowSelectionState"
            [ test "should return an empty map and a new instance each time" <|
                \_ -> Expect.equal Set.empty Table.initialState.rowSelection
            ]
        , describe "table_setRowSelection"
            [ test "should route the updater through onRowSelectionChange" <|
                \_ ->
                    Table.setRowSelection (Set.singleton "0") state
                        |> selected
                        |> Expect.equal [ "0" ]
            ]
        , describe "table_resetRowSelection"
            [ test "should reset to an empty map when defaultState is true" <|
                \_ ->
                    Table.resetRowSelection (selecting [ "0" ])
                        |> selected
                        |> Expect.equal []
            , test "should reset to the initial selection by default" <|
                \_ ->
                    Table.setRowSelection (Set.fromList [ "0", "2" ]) (selecting [ "1" ])
                        |> selected
                        |> Expect.equal [ "0", "2" ]
            ]
        , describe "table_getSelectedRowIds"
            [ test "should list the selected row ids" <|
                \_ ->
                    Table.selectedRowIds (selecting [ "0", "3" ])
                        |> Expect.equal [ "0", "3" ]
            , test "should return an empty array with no selection" <|
                \_ -> Table.selectedRowIds state |> Expect.equal []
            ]
        , describe "table_getIsSomeRowsSelected"
            [ test "should return false with no selection" <|
                \_ -> Table.getIsSomeRowsSelected state |> Expect.equal False
            , test "should return true when any row id is selected" <|
                \_ -> Table.getIsSomeRowsSelected (selecting [ "0" ]) |> Expect.equal True
            ]
        , describe "table_getIsAllRowsSelected"
            [ test "should return true when every selectable row is selected" <|
                \_ ->
                    Table.getIsAllRowsSelected cfg (selecting [ "0", "1", "2", "3", "4" ]) (model [ 5 ])
                        |> Expect.equal True
            , test "should return false when a selectable row is unselected" <|
                \_ ->
                    Table.getIsAllRowsSelected cfg (selecting [ "0", "1", "2", "3" ]) (model [ 5 ])
                        |> Expect.equal False
            , test "should ignore rows that cannot be selected" <|
                \_ ->
                    Table.getIsAllRowsSelected
                        { cfg | enableRowSelection = rowIdIsNot "0" }
                        (selecting [ "1", "2", "3", "4" ])
                        (model [ 5 ])
                        |> Expect.equal True
            , test "should return false with an empty selection" <|
                \_ -> Table.getIsAllRowsSelected cfg state (model [ 5 ]) |> Expect.equal False
            , test "should ignore sub-rows when enableSubRowSelection is false" <|
                \_ ->
                    let
                        noSubRows : Table.Config Person
                        noSubRows =
                            { cfg | enableSubRowSelection = always False }
                    in
                    Expect.all
                        [ \_ ->
                            Table.getIsAllRowsSelected noSubRows (selecting [ "0", "1", "2" ]) (model [ 3, 2 ])
                                |> Expect.equal True
                        , \_ ->
                            Table.getIsAllRowsSelected noSubRows (selecting [ "0", "1" ]) (model [ 3, 2 ])
                                |> Expect.equal False
                        ]
                        ()
            , test "should ignore only blocked subtrees with an enableSubRowSelection predicate" <|
                \_ ->
                    Table.getIsAllRowsSelected
                        { cfg | enableSubRowSelection = rowIdIsNot "0" }
                        (selecting [ "0", "1", "1.0", "1.1", "2", "2.0", "2.1" ])
                        (model [ 3, 2 ])
                        |> Expect.equal True
            ]
        , describe "table_getIsAllPageRowsSelected"
            [ test "should only consider rows on the current page" <|
                \_ ->
                    Table.getIsAllPageRowsSelected cfg (selecting [ "0", "1" ]) (page 2 (model [ 5 ]))
                        |> Expect.equal True
            , test "should return false when a page row is unselected" <|
                \_ ->
                    Table.getIsAllPageRowsSelected cfg (selecting [ "0" ]) (page 2 (model [ 5 ]))
                        |> Expect.equal False
            , test "should ignore sub-rows when enableSubRowSelection is false" <|
                \_ ->
                    Table.getIsAllPageRowsSelected
                        { cfg | enableSubRowSelection = always False }
                        (selecting [ "0", "1" ])
                        (page 2 (model [ 3, 2 ]))
                        |> Expect.equal True
            ]
        , describe "table_getIsSomePageRowsSelected"
            [ test "should return true when a current-page row is selected" <|
                \_ ->
                    Table.getIsSomePageRowsSelected cfg (selecting [ "0" ]) (page 2 (model [ 5 ]))
                        |> Expect.equal True
            , test "should return false when only off-page rows are selected" <|
                \_ ->
                    Table.getIsSomePageRowsSelected cfg (selecting [ "4" ]) (page 2 (model [ 5 ]))
                        |> Expect.equal False
            ]
        , describe "table_toggleAllPageRowsSelected"
            [ test "should select only the current page rows" <|
                \_ ->
                    Table.toggleAllPageRowsSelected cfg (page 2 (model [ 5 ])) (Just True) state
                        |> selected
                        |> Expect.equal [ "0", "1" ]
            , test "should deselect page rows while preserving off-page selection" <|
                \_ ->
                    Table.toggleAllPageRowsSelected cfg
                        (page 2 (model [ 5 ]))
                        (Just False)
                        (selecting [ "0", "1", "4" ])
                        |> selected
                        |> Expect.equal [ "4" ]
            ]
        , describe "row_toggleSelected"
            [ test "should select an unselected row" <|
                \_ ->
                    withRow (model [ 5 ])
                        "0"
                        (\row ->
                            Table.toggleRowSelected cfg (model [ 5 ]) row Nothing state
                                |> selected
                                |> Expect.equal [ "0" ]
                        )
            , test "should deselect a selected row" <|
                \_ ->
                    withRow (model [ 5 ])
                        "0"
                        (\row ->
                            Table.toggleRowSelected cfg (model [ 5 ]) row Nothing (selecting [ "0", "1" ])
                                |> selected
                                |> Expect.equal [ "1" ]
                        )
            , test "should select children recursively by default" <|
                \_ ->
                    withRow (model [ 3, 2 ])
                        "0"
                        (\row ->
                            Table.toggleRowSelected cfg (model [ 3, 2 ]) row (Just True) state
                                |> selected
                                |> Expect.equal [ "0", "0.0", "0.1" ]
                        )
            , test "should not select children when selectChildren is false" <|
                \_ ->
                    withRow (model [ 3, 2 ])
                        "0"
                        (\row ->
                            Table.toggleRowSelectedWith cfg
                                { selectChildren = False, deselectParents = False }
                                (model [ 3, 2 ])
                                row
                                (Just True)
                                state
                                |> selected
                                |> Expect.equal [ "0" ]
                        )
            , test "should not select children when sub-row selection is disabled" <|
                \_ ->
                    withRow (model [ 3, 2 ])
                        "0"
                        (\row ->
                            Table.toggleRowSelected { cfg | enableSubRowSelection = always False }
                                (model [ 3, 2 ])
                                row
                                (Just True)
                                state
                                |> selected
                                |> Expect.equal [ "0" ]
                        )
            , test "should clear other selections when multi-select is disabled" <|
                \_ ->
                    withRow (model [ 5 ])
                        "0"
                        (\row ->
                            Table.toggleRowSelected { cfg | enableMultiRowSelection = always False }
                                (model [ 5 ])
                                row
                                (Just True)
                                (selecting [ "1" ])
                                |> selected
                                |> Expect.equal [ "0" ]
                        )
            , test "should select the clicked parent row when multi-select is disabled" <|
                \_ ->
                    withRow (model [ 3, 2 ])
                        "0"
                        (\row ->
                            Table.toggleRowSelected { cfg | enableMultiRowSelection = always False }
                                (model [ 3, 2 ])
                                row
                                (Just True)
                                state
                                |> selected
                                |> Expect.equal [ "0" ]
                        )
            , test "should prune ancestor ids when deselecting with deselectParents" <|
                \_ ->
                    withRow (model [ 3, 2 ])
                        "0.0"
                        (\row ->
                            Table.toggleRowSelectedWith cfg
                                { selectChildren = True, deselectParents = True }
                                (model [ 3, 2 ])
                                row
                                (Just False)
                                (selecting [ "0", "0.0", "0.1" ])
                                |> selected
                                |> Expect.equal [ "0.1" ]
                        )
            , test "should leave ancestor ids by default when deselecting a child" <|
                \_ ->
                    withRow (model [ 3, 2 ])
                        "0.0"
                        (\row ->
                            Table.toggleRowSelected cfg
                                (model [ 3, 2 ])
                                row
                                (Just False)
                                (selecting [ "0", "0.0", "0.1" ])
                                |> selected
                                |> Expect.equal [ "0", "0.1" ]
                        )
            , test "should prune every ancestor on a deep deselect with deselectParents" <|
                \_ ->
                    withRow (model [ 2, 2, 2 ])
                        "0.0.0"
                        (\row ->
                            Table.toggleRowSelectedWith cfg
                                { selectChildren = True, deselectParents = True }
                                (model [ 2, 2, 2 ])
                                row
                                (Just False)
                                (selecting [ "0", "0.0", "0.0.0", "0.0.1", "0.1", "0.1.0", "0.1.1" ])
                                |> selected
                                |> Expect.equal [ "0.0.1", "0.1", "0.1.0", "0.1.1" ]
                        )
            , test "should prune ancestors that cannot be selected" <|
                \_ ->
                    withRow (model [ 3, 2 ])
                        "0.0"
                        (\row ->
                            Table.toggleRowSelectedWith { cfg | enableRowSelection = rowIdIsNot "0" }
                                { selectChildren = True, deselectParents = True }
                                (model [ 3, 2 ])
                                row
                                (Just False)
                                (selecting [ "0", "0.0", "0.1" ])
                                |> selected
                                |> Expect.equal [ "0.1" ]
                        )
            , test "should not add or prune ancestors when selecting with deselectParents" <|
                \_ ->
                    withRow (model [ 3, 2 ])
                        "0.0"
                        (\row ->
                            Table.toggleRowSelectedWith cfg
                                { selectChildren = True, deselectParents = True }
                                (model [ 3, 2 ])
                                row
                                (Just True)
                                (selecting [ "0" ])
                                |> selected
                                |> Expect.equal [ "0", "0.0" ]
                        )
            ]
        , describe "row_getIsSomeSelected / row_getIsAllSubRowsSelected"
            [ test "should report a partial child selection" <|
                \_ ->
                    withRow (model [ 3, 2 ])
                        "0"
                        (\row ->
                            Expect.all
                                [ \_ -> Table.getIsSomeSelected cfg (selecting [ "0.0" ]) row |> Expect.equal True
                                , \_ -> Table.getIsAllSubRowsSelected cfg (selecting [ "0.0" ]) row |> Expect.equal False
                                ]
                                ()
                        )
            , test "should report a full child selection" <|
                \_ ->
                    withRow (model [ 3, 2 ])
                        "0"
                        (\row ->
                            Expect.all
                                [ \_ -> Table.getIsSomeSelected cfg (selecting [ "0.0", "0.1" ]) row |> Expect.equal False
                                , \_ -> Table.getIsAllSubRowsSelected cfg (selecting [ "0.0", "0.1" ]) row |> Expect.equal True
                                ]
                                ()
                        )
            , test "should report nothing for rows without subRows" <|
                \_ ->
                    withRow (model [ 5 ])
                        "0"
                        (\row ->
                            Expect.all
                                [ \_ -> Table.getIsSomeSelected cfg state row |> Expect.equal False
                                , \_ -> Table.getIsAllSubRowsSelected cfg state row |> Expect.equal False
                                ]
                                ()
                        )
            , test "should report nothing when no sub-rows are selectable" <|
                \_ ->
                    withRow (model [ 3, 2 ])
                        "0"
                        (\row ->
                            let
                                noSelection : Table.Config Person
                                noSelection =
                                    { cfg | enableRowSelection = always False }
                            in
                            Expect.all
                                [ \_ -> Table.getIsSomeSelected noSelection state row |> Expect.equal False
                                , \_ -> Table.getIsAllSubRowsSelected noSelection state row |> Expect.equal False
                                ]
                                ()
                        )
            ]
        , describe "row selection flags"
            [ test "row_getCanSelect should default to true and respect boolean options" <|
                \_ ->
                    withRow (model [ 5 ])
                        "0"
                        (\row ->
                            Expect.all
                                [ \_ -> Table.getCanSelect cfg row |> Expect.equal True
                                , \_ ->
                                    Table.getCanSelect { cfg | enableRowSelection = always False } row
                                        |> Expect.equal False
                                ]
                                ()
                        )
            , test "row_getCanSelect should support row predicates" <|
                \_ ->
                    let
                        onlyOne : Table.Config Person
                        onlyOne =
                            { cfg | enableRowSelection = \row -> Table.rowId row == "1" }
                    in
                    Expect.all
                        [ \_ -> withRow (model [ 5 ]) "0" (\row -> Table.getCanSelect onlyOne row |> Expect.equal False)
                        , \_ -> withRow (model [ 5 ]) "1" (\row -> Table.getCanSelect onlyOne row |> Expect.equal True)
                        ]
                        ()
            , test "row_getCanSelectSubRows should default to true and respect options" <|
                \_ ->
                    withRow (model [ 5 ])
                        "0"
                        (\row ->
                            Expect.all
                                [ \_ -> Table.getCanSelectSubRows cfg row |> Expect.equal True
                                , \_ ->
                                    Table.getCanSelectSubRows { cfg | enableSubRowSelection = always False } row
                                        |> Expect.equal False
                                ]
                                ()
                        )
            , test "row_getCanMultiSelect should default to true and respect options" <|
                \_ ->
                    withRow (model [ 5 ])
                        "0"
                        (\row ->
                            Expect.all
                                [ \_ -> Table.getCanMultiSelect cfg row |> Expect.equal True
                                , \_ ->
                                    Table.getCanMultiSelect { cfg | enableMultiRowSelection = always False } row
                                        |> Expect.equal False
                                ]
                                ()
                        )
            ]
        , describe "row_getIsSelected"
            [ test "should read the selection state for this row id" <|
                \_ ->
                    Expect.all
                        [ \_ -> withRow (model [ 5 ]) "0" (\row -> Table.getIsRowSelected (selecting [ "0" ]) row |> Expect.equal True)
                        , \_ -> withRow (model [ 5 ]) "1" (\row -> Table.getIsRowSelected (selecting [ "0" ]) row |> Expect.equal False)
                        ]
                        ()
            ]
        , describe "table_toggleAllRowsSelected"
            [ test "should select every selectable row" <|
                \_ ->
                    Table.toggleAllRowsSelected cfg (model [ 5 ]) (Just True) state
                        |> selected
                        |> Expect.equal [ "0", "1", "2", "3", "4" ]
            , test "should skip rows that cannot be selected" <|
                \_ ->
                    Table.toggleAllRowsSelected { cfg | enableRowSelection = rowIdIsNot "0" }
                        (model [ 5 ])
                        (Just True)
                        state
                        |> selected
                        |> Expect.equal [ "1", "2", "3", "4" ]
            , test "should toggle based on the current selection when no value is passed" <|
                \_ ->
                    Table.toggleAllRowsSelected cfg (model [ 5 ]) Nothing state
                        |> selected
                        |> List.length
                        |> Expect.equal 5
            , test "should select every row including sub-rows by default" <|
                \_ ->
                    Table.toggleAllRowsSelected cfg (model [ 3, 2 ]) (Just True) state
                        |> selected
                        |> List.length
                        |> Expect.equal 9
            , test "should not select sub-rows when enableSubRowSelection is false" <|
                \_ ->
                    Table.toggleAllRowsSelected { cfg | enableSubRowSelection = always False }
                        (model [ 3, 2 ])
                        (Just True)
                        state
                        |> selected
                        |> Expect.equal [ "0", "1", "2" ]
            , test "should skip subtrees blocked by an enableSubRowSelection predicate" <|
                \_ ->
                    Table.toggleAllRowsSelected { cfg | enableSubRowSelection = rowIdIsNot "0" }
                        (model [ 3, 2 ])
                        (Just True)
                        state
                        |> selected
                        |> Expect.equal [ "0", "1", "1.0", "1.1", "2", "2.0", "2.1" ]
            , test "should skip descendants of blocked ancestors at any depth" <|
                \_ ->
                    let
                        result : List String
                        result =
                            Table.toggleAllRowsSelected { cfg | enableSubRowSelection = rowIdIsNot "0" }
                                (model [ 2, 2, 2 ])
                                (Just True)
                                state
                                |> selected
                    in
                    Expect.all
                        [ \found -> Expect.equal True (List.member "0" found)
                        , \found -> Expect.equal False (List.member "0.0" found)
                        , \found -> Expect.equal False (List.member "0.0.0" found)
                        , \found -> Expect.equal True (List.member "1.0" found)
                        , \found -> Expect.equal True (List.member "1.0.0" found)
                        ]
                        result
            , test "should keep rows that cannot be selected when deselecting all" <|
                \_ ->
                    Table.toggleAllRowsSelected { cfg | enableRowSelection = rowIdIsNot "0" }
                        (model [ 5 ])
                        (Just False)
                        (selecting [ "0", "1" ])
                        |> selected
                        |> Expect.equal [ "0" ]
            , test "should clear rows that cannot be selected with deselectAll" <|
                \_ ->
                    Table.deselectAllRows (selecting [ "0", "1" ])
                        |> selected
                        |> Expect.equal []
            ]
        ]
