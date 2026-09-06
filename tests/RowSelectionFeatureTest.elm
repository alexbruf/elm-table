module RowSelectionFeatureTest exposing (pendingIntegration, suite)

{-| Ports `tests/implementation/features/row-selection/rowSelectionFeature.test.ts`.

`pendingIntegration` holds the cases that need the filtered, grouped, or
sorted row model, which is still a stub in this worktree. They are listed in
`reports/phase-5.md`; wire them in with
`describe "pending" pendingIntegration` once the pipeline stages land.

Excluded cases are listed in `reports/phase-5.md`.

-}

import Expect
import Fixtures exposing (Person, Status(..), SubRows(..))
import Set
import Table
import Table.FilterFn as FilterFn
import Table.Value as Value
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


selecting : List String -> Table.State
selecting ids =
    { state | rowSelection = Set.fromList ids }


selected : Table.State -> List String
selected current =
    Set.toList current.rowSelection


rowIds : List (Table.Row Person) -> List String
rowIds =
    List.map Table.rowId


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


person : String -> Person
person id =
    Person id "John" "Doe" 30 100 50 Relationship (SubRows [])


idConfig : Table.Config Person
idConfig =
    Fixtures.config |> Table.withGetRowId (\p _ _ -> p.id)


idModel : Table.RowModel Person
idModel =
    Table.coreRowModelFromList idConfig state (List.map person [ "123", "456", "789" ])


statusConfig : Table.Config Person
statusConfig =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
        , Table.column "status" (.status >> Fixtures.statusToString >> Value.String)
            |> Table.withFilterFn FilterFn.equalsString
        ]


staticModel : Table.RowModel Person -> Table.RowModel Person
staticModel =
    identity


suite : Test
suite =
    describe "rowSelectionFeature"
        [ describe "integration with the grouped, expanded and paginated stages" pendingIntegration
        , describe "selectRowsFn"
            [ test "should only return rows that are selected" <|
                \_ ->
                    let
                        result : Table.RowModel Person
                        result =
                            Table.selectedRowModel (selecting [ "0", "2" ]) (model [ 5 ])
                    in
                    Expect.all
                        [ \found -> Expect.equal 2 (List.length found.rows)
                        , \found -> Expect.equal 2 (List.length found.flatRows)
                        , \found -> Expect.equal [ "0", "2" ] (List.sort (rowIds found.flatRows))
                        ]
                        result
            , test "should recurse into subRows and only return selected subRows" <|
                \_ ->
                    let
                        result : Table.RowModel Person
                        result =
                            Table.selectedRowModel (selecting [ "0", "0.0" ]) (model [ 3, 2 ])
                    in
                    Expect.all
                        [ \found ->
                            found.rows
                                |> List.head
                                |> Maybe.map (Table.rowSubRows >> List.length)
                                |> Expect.equal (Just 1)
                        , \found -> Expect.equal 2 (List.length found.flatRows)
                        , \found -> Expect.equal [ "0", "0.0" ] (List.sort (rowIds found.flatRows))
                        ]
                        result
            , test "should collect selected descendants of unselected parents" <|
                \_ ->
                    let
                        result : Table.RowModel Person
                        result =
                            Table.selectedRowModel (selecting [ "0.0" ]) (model [ 3, 2 ])
                    in
                    Expect.all
                        [ \found -> Expect.equal 0 (List.length found.rows)
                        , \found -> Expect.equal [ "0.0" ] (rowIds found.flatRows)
                        ]
                        result
            , test "should preserve three levels of selected row structure and prototypes" <|
                \_ ->
                    let
                        result : Table.RowModel Person
                        result =
                            Table.selectedRowModel (selecting [ "0", "0.0", "0.0.0" ]) (model [ 1, 1, 1 ])
                    in
                    Expect.all
                        [ \found -> Expect.equal [ "0", "0.0", "0.0.0" ] (rowIds found.flatRows)
                        , \_ -> Expect.equal [ "0", "0.0", "0.0.0" ] (List.sort (Table.selectedRowIds (selecting [ "0", "0.0", "0.0.0" ])))
                        , \found ->
                            found.rows
                                |> List.head
                                |> Maybe.andThen (Table.rowSubRows >> List.head)
                                |> Maybe.andThen (Table.rowSubRows >> List.head)
                                |> Maybe.map Table.rowId
                                |> Expect.equal (Just "0.0.0")
                        ]
                        result
            , test "should collect a selected grandchild beneath two unselected ancestors" <|
                \_ ->
                    let
                        result : Table.RowModel Person
                        result =
                            Table.selectedRowModel (selecting [ "0.0.0" ]) (model [ 1, 1, 1 ])
                    in
                    Expect.all
                        [ \found -> Expect.equal [] found.rows
                        , \found -> Expect.equal [ "0.0.0" ] (rowIds found.flatRows)
                        , \found ->
                            Expect.equal (Just "0.0.0")
                                (Table.findRow found "0.0.0" |> Maybe.map Table.rowId)
                        ]
                        result
            , test "should return an empty list if no rows are selected" <|
                \_ ->
                    let
                        result : Table.RowModel Person
                        result =
                            Table.selectedRowModel state (model [ 5 ])
                    in
                    Expect.all
                        [ \found -> Expect.equal 0 (List.length found.rows)
                        , \found -> Expect.equal 0 (List.length found.flatRows)
                        , \_ -> Expect.equal [] (Table.selectedRowIds state)
                        ]
                        result
            ]
        , describe "isRowSelected"
            [ test "should return true if the row id exists in selection and is set to true" <|
                \_ ->
                    withRow idModel
                        "123"
                        (\row -> Table.getIsRowSelected (selecting [ "123" ]) row |> Expect.equal True)
            , test "should return false if the row id exists in selection and is set to false" <|
                \_ ->
                    withRow idModel
                        "456"
                        (\row -> Table.getIsRowSelected (selecting [ "123" ]) row |> Expect.equal False)
            , test "should return false if the row id does not exist in selection" <|
                \_ ->
                    withRow idModel
                        "789"
                        (\row -> Table.getIsRowSelected (selecting [ "123" ]) row |> Expect.equal False)
            , test "should return false if selection is an empty object" <|
                \_ ->
                    withRow idModel
                        "789"
                        (\row -> Table.getIsRowSelected state row |> Expect.equal False)
            ]
        , describe "isSubRowSelected"
            [ test "should return false if there are no sub-rows" <|
                \_ ->
                    withRow (model [ 3 ])
                        "0"
                        (\row -> Table.subRowSelection cfg state row |> Expect.equal Table.noSubRowsSelected)
            , test "should return false if no sub-rows are selected" <|
                \_ ->
                    withRow (model [ 3, 2 ])
                        "0"
                        (\row -> Table.subRowSelection cfg state row |> Expect.equal Table.noSubRowsSelected)
            , test "should return false if no sub-rows are selectable" <|
                \_ ->
                    withRow (model [ 3, 2 ])
                        "0"
                        (\row ->
                            Table.subRowSelection { cfg | enableRowSelection = always False } state row
                                |> Expect.equal Table.noSubRowsSelected
                        )
            , test "should return some if no children are selectable, but a grand-child is and is selected" <|
                \_ ->
                    withRow (model [ 3, 2, 2 ])
                        "0"
                        (\row ->
                            Table.subRowSelection
                                { cfg | enableRowSelection = \r -> Table.rowId r == "0.0.1" }
                                (selecting [ "0.0.1" ])
                                row
                                |> Expect.equal Table.someSubRowsSelected
                        )
            , test "should return some if some sub-rows are selected" <|
                \_ ->
                    withRow (model [ 3, 2 ])
                        "0"
                        (\row ->
                            Table.subRowSelection cfg (selecting [ "0.0" ]) row
                                |> Expect.equal Table.someSubRowsSelected
                        )
            , test "should return all if all sub-rows are selected" <|
                \_ ->
                    withRow (model [ 3, 2 ])
                        "0"
                        (\row ->
                            Table.subRowSelection cfg (selecting [ "0.0", "0.1" ]) row
                                |> Expect.equal Table.allSubRowsSelected
                        )
            , test "should return all if all selectable sub-rows are selected" <|
                \_ ->
                    withRow (model [ 3, 2 ])
                        "0"
                        (\row ->
                            Table.subRowSelection
                                { cfg | enableRowSelection = \r -> Table.rowIndex r == 0 }
                                (selecting [ "0.0" ])
                                row
                                |> Expect.equal Table.allSubRowsSelected
                        )
            , test "should return some when some nested sub-rows are selected" <|
                \_ ->
                    withRow (model [ 3, 2, 2 ])
                        "0"
                        (\row ->
                            Table.subRowSelection cfg (selecting [ "0.0.0" ]) row
                                |> Expect.equal Table.someSubRowsSelected
                        )
            ]
        , describe "toggleAllRowsSelected"
            [ test "deselects only in-model ids by default, preserving out-of-model ids" <|
                \_ ->
                    Table.toggleAllRowsSelected cfg (model [ 5 ]) (Just False) (selecting [ "0", "2", "99" ])
                        |> selected
                        |> Expect.equal [ "99" ]
            , test "clears the entire selection when opts.deselectAll is true" <|
                \_ ->
                    Table.deselectAllRows (selecting [ "0", "2", "99" ])
                        |> selected
                        |> Expect.equal []
            , test "does not clear selection when deselectAll is paired with a select" <|
                \_ ->
                    Table.toggleAllRowsSelected cfg (model [ 5 ]) (Just True) (selecting [ "0", "2", "99" ])
                        |> selected
                        |> List.member "99"
                        |> Expect.equal True
            , test "toggles top-level rows only when enableSubRowSelection is false" <|
                \_ ->
                    let
                        noSubRows : Table.Config Person
                        noSubRows =
                            { cfg | enableSubRowSelection = always False }

                        once : Table.State
                        once =
                            Table.toggleAllRowsSelected noSubRows (model [ 3, 2 ]) Nothing state

                        twice : Table.State
                        twice =
                            Table.toggleAllRowsSelected noSubRows (model [ 3, 2 ]) Nothing once
                    in
                    Expect.all
                        [ \_ -> Expect.equal [ "0", "1", "2" ] (selected once)
                        , \_ -> Expect.equal True (Table.getIsAllRowsSelected noSubRows once (model [ 3, 2 ]))
                        , \_ -> Expect.equal [] (selected twice)
                        ]
                        ()
            , test "keeps rows that cannot be selected when deselecting all" <|
                \_ ->
                    let
                        guarded : Table.Config Person
                        guarded =
                            { cfg | enableRowSelection = rowIdIsNot "0" }
                    in
                    Expect.all
                        [ \_ ->
                            Table.toggleAllRowsSelected guarded (model [ 5 ]) (Just False) (selecting [ "0", "1" ])
                                |> selected
                                |> Expect.equal [ "0" ]
                        , \_ ->
                            Table.deselectAllRows (selecting [ "0", "1" ])
                                |> selected
                                |> Expect.equal []
                        ]
                        ()
            ]
        , describe "deselectParents"
            [ test "prunes stale parent ids through a select-parent-then-deselect-children sequence" <|
                \_ ->
                    let
                        source : Table.RowModel Person
                        source =
                            model [ 3, 2 ]

                        deselect : String -> Table.State -> Table.State
                        deselect rowId current =
                            case Table.findRow source rowId of
                                Just row ->
                                    Table.toggleRowSelectedWith cfg
                                        { selectChildren = True, deselectParents = True }
                                        source
                                        row
                                        (Just False)
                                        current

                                Nothing ->
                                    current
                    in
                    withRow source
                        "0"
                        (\parent ->
                            let
                                afterSelect : Table.State
                                afterSelect =
                                    Table.toggleRowSelected cfg source parent (Just True) state

                                afterFirst : Table.State
                                afterFirst =
                                    deselect "0.0" afterSelect

                                afterSecond : Table.State
                                afterSecond =
                                    deselect "0.1" afterFirst
                            in
                            Expect.all
                                [ \_ -> Expect.equal [ "0", "0.0", "0.1" ] (selected afterSelect)
                                , \_ -> Expect.equal [ "0.1" ] (selected afterFirst)
                                , \_ -> Expect.equal False (Table.getIsRowSelected afterFirst parent)
                                , \_ -> Expect.equal True (Table.getIsSomeSelected cfg afterFirst parent)
                                , \_ -> Expect.equal [] (selected afterSecond)
                                , \_ -> Expect.equal False (Table.getIsSomeSelected cfg afterSecond parent)
                                ]
                                ()
                        )
            ]
        , describe "memoization"
            [ test "recomputes getIsAllRowsSelected when enableSubRowSelection changes" <|
                \_ ->
                    let
                        current : Table.State
                        current =
                            selecting [ "0", "1", "2" ]
                    in
                    Expect.all
                        [ \_ -> Expect.equal False (Table.getIsAllRowsSelected cfg current (model [ 3, 2 ]))
                        , \_ ->
                            Expect.equal True
                                (Table.getIsAllRowsSelected
                                    { cfg | enableSubRowSelection = always False }
                                    current
                                    (model [ 3, 2 ])
                                )
                        ]
                        ()
            , test "memoizes getIsSomePageRowsSelected until selection changes" <|
                \_ ->
                    Expect.all
                        [ \_ ->
                            Expect.equal True
                                (Table.getIsSomePageRowsSelected cfg (selecting [ "0" ]) (model [ 10 ]))
                        , \_ ->
                            Expect.equal False
                                (Table.getIsSomePageRowsSelected cfg state (model [ 10 ]))
                        ]
                        ()
            ]
        ]


{-| Cases that need the filtered, grouped, or sorted row model. They are
written against the pipeline stages, which are identity stubs in this
worktree.
-}
pendingIntegration : List Test
pendingIntegration =
    let
        data : List Person
        data =
            Fixtures.staticData

        core : Table.State -> Table.RowModel Person
        core current =
            Table.coreRowModelFromList statusConfig current data
    in
    [ describe "selected row models source the correct pipeline models"
        [ test "getFilteredSelectedRowModel excludes selected rows that are filtered out" <|
            \_ ->
                let
                    current : Table.State
                    current =
                        { state
                            | columnFilters = [ { id = "status", value = Value.String "single" } ]
                            , rowSelection = Set.fromList [ "0", "2" ]
                        }

                    filteredSelected : Table.RowModel Person
                    filteredSelected =
                        Table.filteredRowModel statusConfig current (core current)
                            |> staticModel
                            |> Table.selectedRowModel current
                in
                Expect.all
                    [ \found -> Expect.equal [ "2" ] (rowIds found.rows)
                    , \found -> Expect.equal 1 (List.length found.flatRows)
                    , \_ ->
                        Expect.equal 2
                            (List.length (Table.selectedRowModel current (core current)).flatRows)
                    ]
                    filteredSelected
        , test "getGroupedSelectedRowModel returns a selected group row" <|
            \_ ->
                let
                    current : Table.State
                    current =
                        { state
                            | grouping = [ "status" ]
                            , rowSelection = Set.singleton "status:single"
                        }

                    groupedSelected : Table.RowModel Person
                    groupedSelected =
                        Table.groupedRowModel statusConfig current (core current)
                            |> Table.sortedRowModel statusConfig current
                            |> Table.selectedRowModel current
                in
                Expect.all
                    [ \found -> Expect.equal 1 (List.length found.rows)
                    , \found -> Expect.equal [ "status:single" ] (rowIds found.rows)
                    , \found -> Expect.equal [ "status:single" ] (rowIds found.flatRows)
                    ]
                    groupedSelected
        , test "getGroupedSelectedRowModel collects a selected leaf under an unselected group" <|
            \_ ->
                let
                    current : Table.State
                    current =
                        { state
                            | grouping = [ "status" ]
                            , rowSelection = Set.singleton "2"
                        }

                    groupedSelected : Table.RowModel Person
                    groupedSelected =
                        Table.groupedRowModel statusConfig current (core current)
                            |> Table.sortedRowModel statusConfig current
                            |> Table.selectedRowModel current
                in
                Expect.all
                    [ \found -> Expect.equal [] found.rows
                    , \found -> Expect.equal [ "2" ] (rowIds found.flatRows)
                    ]
                    groupedSelected
        ]
    ]
