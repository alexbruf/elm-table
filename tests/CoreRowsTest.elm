module CoreRowsTest exposing (suite)

{-| Ports `tests/unit/core/rows/constructRow.test.ts` and
`tests/unit/core/rows/coreRowsFeature.utils.test.ts`.

Excluded cases are listed in `reports/phase-2.md`.

-}

import Dict
import Expect
import Fixtures exposing (Person, Status(..), SubRows(..))
import Table
import Table.Value as Value
import Test exposing (Test, describe, test)


flatConfig : Table.Config Person
flatConfig =
    Table.config Fixtures.columns


flatModel : Int -> Table.RowModel Person
flatModel count =
    Table.coreRowModelFromList flatConfig Table.initialState (Fixtures.makeData [ count ])


nestedModel : List Int -> Table.RowModel Person
nestedModel lengths =
    Table.coreRowModelFromList Fixtures.config Table.initialState (Fixtures.makeData lengths)


firstRow : Table.RowModel Person -> Maybe (Table.Row Person)
firstRow model =
    List.head model.rows


cellsById : Table.Config Person -> Table.Row Person -> Dict.Dict String Table.Cell
cellsById cfg row =
    Table.getAllCells cfg Table.initialState row
        |> List.foldl (\cell acc -> Dict.insert cell.columnId cell acc) Dict.empty


{-| The `constructRow` fixture: a parent with two leaves, built as data.
-}
leafPerson : String -> Person
leafPerson name =
    Person (String.toLower name) name "Leaf" 0 0 0 Relationship (SubRows [])


parentPerson : List Person -> Person
parentPerson children =
    Person "parent" "Parent" "Row" 0 0 0 Relationship (SubRows children)


leafRowIdsWith : (Person -> List Person) -> List String
leafRowIdsWith subRows =
    let
        cfg : Table.Config Person
        cfg =
            Table.config Fixtures.columns
                |> Table.withGetRowId (\person _ _ -> person.id)
                |> Table.withSubRows subRows

        model : Table.RowModel Person
        model =
            Table.coreRowModelFromList cfg
                Table.initialState
                [ parentPerson [ leafPerson "A", leafPerson "B" ] ]
    in
    Table.findRow model "parent"
        |> Maybe.map (Table.getLeafRows >> List.map Table.rowId)
        |> Maybe.withDefault []


suite : Test
suite =
    describe "core rows"
        [ describe "constructRow"
            [ test "should create a row with all core row APIs and properties" <|
                \_ ->
                    Table.findRow (nestedModel [ 1, 1 ]) "0.0"
                        |> Maybe.map
                            (\row ->
                                { id = Table.rowId row
                                , index = Table.rowIndex row
                                , depth = Table.rowDepth row
                                , parentId = Table.rowParentId row
                                , subRows = List.length (Table.rowSubRows row)
                                , originalId = .id (Table.rowOriginal row)
                                , leafRows = Table.rowLeafRows row
                                , groupingColumnId = Table.rowGroupingColumnId row
                                , groupingValue = Table.rowGroupingValue row
                                , aggregatedValues = Dict.toList (Table.rowAggregatedValues row)
                                }
                            )
                        |> Expect.equal
                            (Just
                                { id = "0.0"
                                , index = 0
                                , depth = 1
                                , parentId = Just "0"
                                , subRows = 0
                                , originalId = "0.0"
                                , leafRows = []
                                , groupingColumnId = Nothing
                                , groupingValue = Value.Null
                                , aggregatedValues = []
                                }
                            )
            ]
        , -- adapted: `getLeafRows` is a pure read, so the memo becomes
          -- "repeated reads agree" and the mutated `subRows` becomes a
          -- second config whose sub-row accessor reverses the children.
          describe "constructRow memoization"
            [ test "memoizes getLeafRows until subRows changes" <|
                \_ ->
                    Expect.equal
                        { first = leafRowIdsWith Fixtures.subRowsOf
                        , second = leafRowIdsWith Fixtures.subRowsOf
                        , reordered = leafRowIdsWith (Fixtures.subRowsOf >> List.reverse)
                        }
                        { first = [ "a", "b" ]
                        , second = [ "a", "b" ]
                        , reordered = [ "b", "a" ]
                        }
            ]
        , describe "row_getAllCells"
            [ test "should build one cell per leaf column in leaf column order" <|
                \_ ->
                    flatModel 1
                        |> firstRow
                        |> Maybe.map
                            (\row ->
                                ( Table.getAllCells flatConfig Table.initialState row
                                    |> List.map .columnId
                                , Table.getAllCells flatConfig Table.initialState row
                                    |> List.all (\cell -> cell.rowId == Table.rowId row)
                                )
                            )
                        |> Expect.equal
                            (Just ( List.map Table.columnId (Table.leafColumns flatConfig), True ))
            , -- adapted: cells are plain records built on demand, so
              -- instance reuse becomes structural equality across two calls.
              test "should reuse cell instances across calls" <|
                \_ ->
                    let
                        cellsOf : () -> Maybe (List Table.Cell)
                        cellsOf () =
                            flatModel 1
                                |> firstRow
                                |> Maybe.map (Table.getAllCells flatConfig Table.initialState)
                    in
                    Expect.equal (cellsOf ()) (cellsOf ())
            , test "should preserve cell identity across column order changes" <|
                \_ ->
                    flatModel 1
                        |> firstRow
                        |> Maybe.map
                            (\row ->
                                let
                                    state =
                                        Table.initialState

                                    ordered =
                                        { state | columnOrder = [ "lastName", "firstName" ] }

                                    before =
                                        Table.getAllCells flatConfig state row

                                    after =
                                        Table.getAllCells flatConfig ordered row
                                in
                                ( List.take 2 after |> List.map .columnId
                                , List.sortBy .columnId before == List.sortBy .columnId after
                                )
                            )
                        |> Expect.equal (Just ( [ "lastName", "firstName" ], True ))
            ]
        , describe "row_getValue"
            [ test "should read and cache the accessor value" <|
                \_ ->
                    flatModel 1
                        |> firstRow
                        |> Maybe.map
                            (\row ->
                                ( Table.getValue flatConfig row "firstName"
                                , Table.getValue flatConfig row "firstName"
                                )
                            )
                        |> Expect.equal
                            (Just ( Value.String "Mallory", Value.String "Mallory" ))
            , test "should return undefined for unknown columns" <|
                \_ ->
                    flatModel 1
                        |> firstRow
                        |> Maybe.map
                            (\row -> Table.getValue (Table.config Fixtures.columns) row "not-a-column")
                        |> Expect.equal (Just Value.Null)
            ]
        , describe "row_getUniqueValues"
            [ test "should wrap the accessor value in an array by default" <|
                \_ ->
                    flatModel 1
                        |> firstRow
                        |> Maybe.map
                            (\row ->
                                ( Table.getUniqueValues flatConfig row "firstName"
                                , [ Table.getValue flatConfig row "firstName" ]
                                )
                            )
                        |> Maybe.map (\( actual, expected ) -> actual == expected)
                        |> Expect.equal (Just True)
            , test "should prefer getUniqueValues and cache the result per row" <|
                \_ ->
                    let
                        cfg =
                            Table.config
                                [ Table.column "firstName" (.firstName >> Value.String)
                                    |> Table.withGetUniqueValues
                                        (\_ -> [ Value.String "x", Value.String "y" ])
                                ]
                    in
                    Table.coreRowModelFromList cfg Table.initialState (Fixtures.makeData [ 1 ])
                        |> firstRow
                        |> Maybe.map
                            (\row ->
                                ( Table.getUniqueValues cfg row "firstName"
                                , Table.getUniqueValues cfg row "firstName"
                                )
                            )
                        |> Expect.equal
                            (Just
                                ( [ Value.String "x", Value.String "y" ]
                                , [ Value.String "x", Value.String "y" ]
                                )
                            )
            , test "should return undefined for unknown columns" <|
                \_ ->
                    flatModel 1
                        |> firstRow
                        |> Maybe.map
                            (\row ->
                                Table.getUniqueValues (Table.config Fixtures.columns) row "not-a-column"
                            )
                        |> Expect.equal (Just [])
            ]
        , describe "row tree readers"
            [ test "memoizes the deepest structural sub-row depth on the table" <|
                \_ ->
                    nestedModel [ 2, 2, 2 ]
                        |> Table.maxSubRowDepth
                        |> Expect.equal 2
            , test "returns zero for flat and empty row models" <|
                \_ ->
                    Expect.equal
                        ( Table.maxSubRowDepth (flatModel 2)
                        , Table.maxSubRowDepth (flatModel 0)
                        )
                        ( 0, 0 )
            , test "row_getLeafRows should flatten all descendants" <|
                \_ ->
                    Table.findRow (nestedModel [ 2, 2, 2 ]) "0"
                        |> Maybe.map (Table.getLeafRows >> List.map Table.rowId)
                        |> Expect.equal
                            (Just [ "0.0", "0.0.0", "0.0.1", "0.1", "0.1.0", "0.1.1" ])
            , test "row_getParentRow should return the direct parent or undefined" <|
                \_ ->
                    let
                        model =
                            nestedModel [ 3, 2 ]
                    in
                    Expect.equal
                        ( Table.findRow model "0.1"
                            |> Maybe.andThen (Table.getParentRow model)
                            |> Maybe.map Table.rowId
                        , Table.findRow model "0"
                            |> Maybe.andThen (Table.getParentRow model)
                            |> Maybe.map Table.rowId
                        )
                        ( Just "0", Nothing )
            , test "row_getParentRows should collect ancestors from root to parent" <|
                \_ ->
                    let
                        model =
                            nestedModel [ 2, 2, 2 ]
                    in
                    Expect.equal
                        ( Table.findRow model "0.1.0"
                            |> Maybe.map (Table.getParentRows model >> List.map Table.rowId)
                        , Table.findRow model "1"
                            |> Maybe.map (Table.getParentRows model)
                        )
                        ( Just [ "0", "0.1" ], Just [] )
            ]
        , describe "row_getAllCellsByColumnId"
            [ test "should key this row cells by column id" <|
                \_ ->
                    flatModel 1
                        |> firstRow
                        |> Maybe.map
                            (\row ->
                                let
                                    byId =
                                        cellsById flatConfig row
                                in
                                ( Dict.keys byId |> List.sort
                                , Dict.get "firstName" byId
                                    |> Maybe.map (\cell -> ( cell.columnId, cell.rowId ))
                                )
                            )
                        |> Expect.equal
                            (Just
                                ( List.sort (List.map Table.columnId (Table.leafColumns flatConfig))
                                , Just ( "firstName", "0" )
                                )
                            )
            ]
        , describe "table_getRowId"
            [ test "should default to the row index for root rows" <|
                \_ ->
                    flatModel 2
                        |> .rows
                        |> List.map Table.rowId
                        |> Expect.equal [ "0", "1" ]
            , test "should join parent ids with a dot for child rows" <|
                \_ ->
                    Table.findRow (nestedModel [ 2, 3 ]) "1"
                        |> Maybe.map (Table.rowSubRows >> List.map Table.rowId)
                        |> Expect.equal (Just [ "1.0", "1.1", "1.2" ])
            , test "should prefer options.getRowId" <|
                \_ ->
                    let
                        data =
                            Fixtures.makeData [ 2 ]

                        cfg =
                            flatConfig |> Table.withGetRowId (\person _ _ -> person.id)
                    in
                    Table.coreRowModelFromList cfg Table.initialState data
                        |> .rowsById
                        |> Dict.keys
                        |> Expect.equal (List.sort (List.map .id data))
            ]
        , describe "table_getRow"
            [ test "should find rows by id, including nested rows" <|
                \_ ->
                    let
                        model =
                            nestedModel [ 3, 2 ]
                    in
                    Expect.equal
                        ( Table.findRow model "1" |> Maybe.map Table.rowId
                        , Table.findRow model "0.1" |> Maybe.map Table.rowId
                        )
                        ( Just "1", Just "0.1" )
            , test "should throw for unknown row ids" <|
                \_ ->
                    -- Elm has no exceptions: the lookup reports Nothing instead
                    Table.findRow (flatModel 1) "not-a-row"
                        |> Maybe.map Table.rowId
                        |> Expect.equal Nothing
            ]
        ]
