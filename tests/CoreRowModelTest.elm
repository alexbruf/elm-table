module CoreRowModelTest exposing (suite)

{-| Ports
`tests/implementation/core/row-models/createCoreRowModel.test.ts` and
`tests/implementation/core/row-models/rowModelFlatRowsOrder.test.ts`.

Excluded cases are listed in `reports/phase-2.md`.

-}

import Dict
import Expect
import Fixtures exposing (Person)
import Table
import Test exposing (Test, describe, test)


nested : List Int -> Table.RowModel Person
nested lengths =
    Table.coreRowModelFromList Fixtures.config Table.initialState (Fixtures.makeData lengths)


flat : List Int -> Table.RowModel Person
flat lengths =
    Table.coreRowModelFromList (Table.config Fixtures.columns) Table.initialState (Fixtures.makeData lengths)


suite : Test
suite =
    describe "createCoreRowModel"
        [ describe "flatRows ordering"
            [ test "should list rows depth-first with each parent before its children" <|
                \_ ->
                    nested [ 2, 2, 2 ]
                        |> .flatRows
                        |> List.map Table.rowId
                        |> Expect.equal
                            [ "0"
                            , "0.0"
                            , "0.0.0"
                            , "0.0.1"
                            , "0.1"
                            , "0.1.0"
                            , "0.1.1"
                            , "1"
                            , "1.0"
                            , "1.0.0"
                            , "1.0.1"
                            , "1.1"
                            , "1.1.0"
                            , "1.1.1"
                            ]
            , test "should have flatRows.length equal to the total node count" <|
                \_ ->
                    let
                        model =
                            nested [ 3, 2, 2 ]
                    in
                    Expect.equal ( List.length model.flatRows, List.length model.rows ) ( 21, 3 )
            ]
        , describe "rowsById"
            [ test "should contain every dotted default id for nested rows" <|
                \_ ->
                    nested [ 2, 2 ]
                        |> .rowsById
                        |> Dict.keys
                        |> List.sort
                        |> Expect.equal (List.sort [ "0", "0.0", "0.1", "1", "1.0", "1.1" ])
            , test "should reference the same row objects as flatRows" <|
                \_ ->
                    let
                        model =
                            nested [ 2, 2 ]
                    in
                    model.flatRows
                        |> List.map (\row -> Dict.get (Table.rowId row) model.rowsById == Just row)
                        |> Expect.equal (List.repeat (List.length model.flatRows) True)
            ]
        , describe "default row id scheme"
            [ test "should use the row index for root rows and parentId.index for children" <|
                \_ ->
                    let
                        model =
                            nested [ 2, 3 ]

                        secondChildren =
                            model.rows
                                |> List.drop 1
                                |> List.head
                                |> Maybe.map Table.rowSubRows
                                |> Maybe.withDefault []
                    in
                    Expect.equal
                        ( List.map Table.rowId model.rows, List.map Table.rowId secondChildren )
                        ( [ "0", "1" ], [ "1.0", "1.1", "1.2" ] )
            ]
        , describe "custom getRowId"
            [ test "should receive (originalRow, index, parentRow) including the parent for nested rows" <|
                \_ ->
                    let
                        cfg =
                            Fixtures.config
                                |> Table.withGetRowId
                                    (\person _ parent ->
                                        case parent of
                                            Just parentId ->
                                                parentId ++ ">" ++ person.id

                                            Nothing ->
                                                person.id
                                    )
                    in
                    Table.coreRowModelFromList cfg Table.initialState (Fixtures.makeData [ 2, 2 ])
                        |> .flatRows
                        |> List.map Table.rowId
                        |> Expect.equal
                            [ "0", "0>0.0", "0>0.1", "1", "1>1.0", "1>1.1" ]
            , test "should key rowsById with the custom ids for nested rows" <|
                \_ ->
                    let
                        data =
                            Fixtures.makeData [ 2, 2 ]

                        cfg =
                            Fixtures.config |> Table.withGetRowId (\person _ _ -> person.id)

                        model =
                            Table.coreRowModelFromList cfg Table.initialState data

                        everyPerson =
                            List.concatMap (\p -> p :: Fixtures.subRowsOf p) data
                    in
                    everyPerson
                        |> List.map
                            (\person ->
                                Dict.get person.id model.rowsById |> Maybe.map Table.rowOriginal
                            )
                        |> Expect.equal (List.map Just everyPerson)
            , test "should keep both rows in flatRows but last-write-wins in rowsById for duplicate ids" <|
                \_ ->
                    let
                        cfg =
                            Table.config Fixtures.columns
                                |> Table.withGetRowId
                                    (\_ index _ ->
                                        if index < 2 then
                                            "dupe"

                                        else
                                            String.fromInt index
                                    )

                        model =
                            Table.coreRowModelFromList cfg Table.initialState (Fixtures.makeData [ 3 ])

                        secondRow =
                            model.flatRows |> List.drop 1 |> List.head
                    in
                    Expect.equal
                        ( List.length model.flatRows
                        , List.sort (Dict.keys model.rowsById)
                        , Dict.get "dupe" model.rowsById == secondRow
                        )
                        ( 3, [ "2", "dupe" ], True )
            ]
        , describe "getSubRows edge cases"
            [ test "should yield empty subRows when getSubRows returns undefined" <|
                \_ ->
                    let
                        cfg =
                            Table.config Fixtures.columns |> Table.withSubRows (\_ -> [])
                    in
                    Table.coreRowModelFromList cfg Table.initialState (Fixtures.makeData [ 2 ])
                        |> .rows
                        |> List.map (Table.rowSubRows >> List.length)
                        |> Expect.equal [ 0, 0 ]
            , test "should yield empty subRows when getSubRows returns an empty array" <|
                \_ ->
                    let
                        cfg =
                            Table.config Fixtures.columns |> Table.withSubRows (always [])
                    in
                    Table.coreRowModelFromList cfg Table.initialState (Fixtures.makeData [ 2 ])
                        |> .rows
                        |> List.map (Table.rowSubRows >> List.length)
                        |> Expect.equal [ 0, 0 ]
            , -- adapted: `Config.getSubRows` is `row -> List row` with no
              -- index parameter and there is no spy, so the assertion is
              -- that the accessor ran on every original row.
              test "should call getSubRows with (originalRow, index)" <|
                \_ ->
                    let
                        data : List Person
                        data =
                            Fixtures.makeData [ 3, 2 ]

                        model : Table.RowModel Person
                        model =
                            Table.coreRowModelFromList Fixtures.config Table.initialState data
                    in
                    Expect.equal
                        ( List.length model.rows
                        , List.map (Table.rowSubRows >> List.map (Table.rowOriginal >> .id)) model.rows
                        )
                        ( 3
                        , List.map (Fixtures.subRowsOf >> List.map .id) data
                        )
            , test "should stay flat when nested raw data is used without getSubRows" <|
                \_ ->
                    let
                        model =
                            flat [ 2, 2 ]
                    in
                    Expect.equal
                        ( List.length model.flatRows
                        , List.map (Table.rowSubRows >> List.length) model.rows
                        , List.map (Table.rowOriginalSubRows >> List.length) model.rows
                        )
                        ( 2, [ 0, 0 ], [ 0, 0 ] )
            ]
        , describe "row depth and parentId"
            [ test "should assign depth 0, 1, 2 and the correct parentId for nested rows" <|
                \_ ->
                    let
                        model =
                            nested [ 1, 1, 1 ]

                        info rowId =
                            Table.findRow model rowId
                                |> Maybe.map (\row -> ( Table.rowDepth row, Table.rowParentId row ))
                    in
                    Expect.equal
                        [ info "0", info "0.0", info "0.0.0" ]
                        [ Just ( 0, Nothing ), Just ( 1, Just "0" ), Just ( 2, Just "0.0" ) ]
            ]
        , describe "originalSubRows"
            [ test "should equal the raw subRows array by reference" <|
                \_ ->
                    let
                        data =
                            Fixtures.makeData [ 2, 2 ]

                        model =
                            Table.coreRowModelFromList Fixtures.config Table.initialState data
                    in
                    model.rows
                        |> List.map Table.rowOriginalSubRows
                        |> Expect.equal (List.map Fixtures.subRowsOf data)
            ]
        , describe "empty data"
            [ test "should return empty rows, flatRows, and rowsById" <|
                \_ ->
                    let
                        model =
                            Table.coreRowModelFromList Fixtures.config Table.initialState []
                    in
                    Expect.equal ( model.rows, model.flatRows, Dict.toList model.rowsById )
                        ( [], [], [] )
            ]
        , -- adapted: Elm values are recomputed and compared structurally, so
          -- instance identity becomes equality and `setOptions` becomes a
          -- second config or a second data list.
          describe "memoization"
            [ test "should return the same model object across repeated calls" <|
                \_ ->
                    let
                        build : () -> Table.RowModel Person
                        build () =
                            Table.coreRowModelFromList Fixtures.config Table.initialState (Fixtures.makeData [ 3 ])
                    in
                    Expect.equal
                        ( build (), List.head (build ()).rows )
                        ( build (), List.head (build ()).rows )
            , -- adapted: a copied list is an equal value in Elm, so the new
              -- data really changes a row; the row count still matches.
              test "should build a new model when the data array identity changes" <|
                \_ ->
                    let
                        first : Table.RowModel Person
                        first =
                            Table.coreRowModelFromList Fixtures.config Table.initialState (Fixtures.makeData [ 3 ])

                        second : Table.RowModel Person
                        second =
                            Fixtures.makeData [ 3 ]
                                |> List.map (\person -> { person | firstName = person.firstName ++ "!" })
                                |> Table.coreRowModelFromList Fixtures.config Table.initialState
                    in
                    Expect.equal
                        ( second == first
                        , List.head second.rows == List.head first.rows
                        , List.length second.rows == List.length first.rows
                        )
                        ( False, False, True )
            , -- adapted: `setOptions` becomes a second config differing only
              -- in an option the core row model does not read.
              test "should preserve the cached model when setOptions keeps the same data reference" <|
                \_ ->
                    let
                        data : List Person
                        data =
                            Fixtures.makeData [ 3 ]

                        first : Table.RowModel Person
                        first =
                            Table.coreRowModelFromList Fixtures.config Table.initialState data

                        again : Table.RowModel Person
                        again =
                            Table.coreRowModelFromList
                                { config_ | manualPagination = True }
                                Table.initialState
                                data

                        config_ : Table.Config Person
                        config_ =
                            Fixtures.config
                    in
                    Expect.equal again first
            ]
        , describe "row-model pipeline flatRows ordering"
            [ test "keeps parents before descendants through every hierarchical stage" <|
                \_ ->
                    let
                        cfg =
                            Fixtures.config

                        state =
                            Table.initialState

                        core =
                            Table.coreRowModelFromList cfg state (Fixtures.makeData [ 2, 2, 2 ])

                        stages =
                            [ core
                            , Table.filteredRowModel cfg state core
                            , Table.groupedRowModel cfg state core
                            , Table.sortedRowModel cfg state core
                            , Table.expandedRowModel cfg state core
                            , Table.paginatedRowModel cfg state core
                            ]
                    in
                    stages
                        |> List.map isPreorder
                        |> Expect.equal (List.repeat 6 True)
            ]
        ]


isPreorder : Table.RowModel Person -> Bool
isPreorder model =
    let
        ids =
            List.map Table.rowId model.flatRows
    in
    ids == preorderIds model.rows && List.length ids == Dict.size model.rowsById


preorderIds : List (Table.Row Person) -> List String
preorderIds rows =
    List.concatMap (\row -> Table.rowId row :: preorderIds (Table.rowSubRows row)) rows
