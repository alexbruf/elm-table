module ExpandingRowModelTest exposing (suite)

{-| Ports
`tests/implementation/features/row-expanding/createExpandedRowModel.test.ts`
and `tests/implementation/features/row-expanding/rowExpandingFeature.test.ts`,
plus the one `createPaginatedRowModel.test.ts` case phase 3 left for the
expanded row model (`reports/phase-3.md`).
-}

import Expect
import Set
import Table
import Table.Value as Value
import Test exposing (Test, describe, test)



-- FIXTURE


type alias Person =
    { firstName : String
    , subRows : Kids
    }


type Kids
    = Kids (List Person)


kidsOf : Person -> List Person
kidsOf row =
    case row.subRows of
        Kids kids ->
            kids


person : String -> List Person -> Person
person firstName kids =
    Person firstName (Kids kids)


{-| 2 roots x 2 children x 2 grandchildren.
-}
nestedData : List Person
nestedData =
    List.range 0 1
        |> List.map
            (\i ->
                person ("parent-" ++ String.fromInt i)
                    (List.range 0 1
                        |> List.map
                            (\j ->
                                person
                                    ("child-" ++ String.fromInt i ++ "." ++ String.fromInt j)
                                    (List.range 0 1
                                        |> List.map
                                            (\k ->
                                                person
                                                    ("grandchild-"
                                                        ++ String.fromInt i
                                                        ++ "."
                                                        ++ String.fromInt j
                                                        ++ "."
                                                        ++ String.fromInt k
                                                    )
                                                    []
                                            )
                                    )
                            )
                    )
            )


config : Table.Config Person
config =
    Table.config [ Table.column "firstName" (.firstName >> Value.String) ]
        |> Table.withSubRows kidsOf


expandedIdsState : List String -> Table.State
expandedIdsState rowIds =
    { plain | expanded = Table.expandedIds (Set.fromList rowIds) }


plain : Table.State
plain =
    Table.initialState


preExpanded : Table.Config Person -> Table.State -> List Person -> Table.RowModel Person
preExpanded cfg state data =
    Table.coreRowModelFromList cfg state data


expandedModel : Table.Config Person -> Table.State -> List Person -> Table.RowModel Person
expandedModel cfg state data =
    Table.expandedRowModel cfg state (preExpanded cfg state data)


ids : Table.RowModel Person -> List String
ids model =
    List.map Table.rowId model.rows



-- SUITE


suite : Test
suite =
    describe "createExpandedRowModel"
        [ describe "expand all"
            [ test "should include every subRow in depth-first display order when all rows are expanded" <|
                \_ ->
                    ids (expandedModel config { plain | expanded = Table.expandAll } nestedData)
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
            ]
        , describe "per-id expansion"
            [ test "should surface only direct children when a single root is expanded" <|
                \_ ->
                    ids (expandedModel config (expandedIdsState [ "0" ]) nestedData)
                        |> Expect.equal [ "0", "0.0", "0.1", "1" ]
            , test "should surface grandchildren when both the root and its child are expanded" <|
                \_ ->
                    ids (expandedModel config (expandedIdsState [ "0", "0.0" ]) nestedData)
                        |> Expect.equal [ "0", "0.0", "0.0.0", "0.0.1", "0.1", "1" ]
            , test "should not surface an expanded child while its parent is collapsed" <|
                \_ ->
                    ids (expandedModel config (expandedIdsState [ "0.0" ]) nestedData)
                        |> Expect.equal [ "0", "1" ]
            ]
        , describe "options.getIsRowExpanded"
            [ test "should drive the model output via the getIsRowExpanded option override" <|
                \_ ->
                    let
                        cfg : Table.Config Person
                        cfg =
                            config
                                |> Table.withIsRowExpanded (\row -> Table.rowId row == "0")
                    in
                    ids (expandedModel cfg (expandedIdsState [ "1" ]) nestedData)
                        |> Expect.equal [ "0", "0.0", "0.1", "1" ]
            ]
        , describe "flatRows and rowsById passthrough"
            [ test "should pass through the pre-expansion flatRows and rowsById unchanged" <|
                \_ ->
                    let
                        state : Table.State
                        state =
                            expandedIdsState [ "0" ]

                        pre : Table.RowModel Person
                        pre =
                            preExpanded config state nestedData

                        model : Table.RowModel Person
                        model =
                            Table.expandedRowModel config state pre
                    in
                    Expect.equal
                        { sameFlatRows = model.flatRows == pre.flatRows
                        , sameRowsById = model.rowsById == pre.rowsById
                        , flatRows = List.length model.flatRows
                        }
                        { sameFlatRows = True, sameRowsById = True, flatRows = 14 }
            ]
        , describe "empty state early returns"
            [ test "should return the pre-model identity when nothing is expanded" <|
                \_ ->
                    let
                        pre : Table.RowModel Person
                        pre =
                            preExpanded config plain nestedData
                    in
                    Expect.equal (Table.expandedRowModel config plain pre == pre) True
            , test "should return the pre-model identity when there is no data" <|
                \_ ->
                    let
                        state : Table.State
                        state =
                            { plain | expanded = Table.expandAll }

                        pre : Table.RowModel Person
                        pre =
                            preExpanded config state []

                        model : Table.RowModel Person
                        model =
                            Table.expandedRowModel config state pre
                    in
                    Expect.equal ( model == pre, model.rows ) ( True, [] )
            ]
        , describe "paginateExpandedRows: false"
            [ test "should return the pre-model identity even with rows expanded" <|
                \_ ->
                    let
                        cfg : Table.Config Person
                        cfg =
                            { config | paginateExpandedRows = False }

                        state : Table.State
                        state =
                            expandedIdsState [ "0" ]

                        pre : Table.RowModel Person
                        pre =
                            preExpanded cfg state nestedData

                        model : Table.RowModel Person
                        model =
                            Table.expandedRowModel cfg state pre
                    in
                    Expect.equal ( model == pre, ids model ) ( True, [ "0", "1" ] )
            ]
        , describe "manualExpanding"
            [ test "should return the pre-model identity when manualExpanding is true" <|
                \_ ->
                    let
                        cfg : Table.Config Person
                        cfg =
                            { config | manualExpanding = True }

                        state : Table.State
                        state =
                            expandedIdsState [ "0" ]

                        pre : Table.RowModel Person
                        pre =
                            preExpanded cfg state nestedData

                        model : Table.RowModel Person
                        model =
                            Table.expandedRowModel cfg state pre
                    in
                    Expect.equal ( model == pre, ids model ) ( True, [ "0", "1" ] )
            ]
        , describe "memoization"
            [ test "should produce a new model when expanded state changes" <|
                \_ ->
                    -- The `expect(second).not.toBe(first)` half is instance
                    -- identity; the row list it guards is asserted here.
                    let
                        first : Table.RowModel Person
                        first =
                            expandedModel config (expandedIdsState [ "0" ]) nestedData

                        second : Table.RowModel Person
                        second =
                            expandedModel config (expandedIdsState [ "0", "0.0" ]) nestedData
                    in
                    Expect.equal
                        { changed = ids second /= ids first
                        , rows = ids second
                        }
                        { changed = True
                        , rows = [ "0", "0.0", "0.0.0", "0.0.1", "0.1", "1" ]
                        }
            ]
        , featureSuite
        , paginationSuite
        ]



-- rowExpandingFeature.test.ts


pairs : List Person
pairs =
    [ person "Parent 1" [ person "Child 1" [] ]
    , person "Parent 2" [ person "Child 2" [] ]
    ]


featureSuite : Test
featureSuite =
    describe "row expanding feature"
        [ test "assigns display indexes in expanded row order before pagination" <|
            \_ ->
                let
                    cfg : Table.Config Person
                    cfg =
                        config

                    pageOne : Table.State
                    pageOne =
                        { plain | pagination = { pageIndex = 0, pageSize = 1 } }

                    at : Table.State -> { rows : List String, indexes : List Int }
                    at state =
                        let
                            model : Table.RowModel Person
                            model =
                                Table.prePaginationRowModel cfg
                                    state
                                    (Table.coreRowModelFromList cfg state pairs)
                        in
                        { rows = List.map Table.rowId model.rows
                        , indexes = List.map (Table.displayIndex cfg state model) model.rows
                        }

                    expanded : Table.State
                    expanded =
                        { pageOne | expanded = Table.expandedIds (Set.singleton "0") }
                in
                Expect.equal ( at expanded, at pageOne )
                    ( { rows = [ "0", "0.0", "1" ], indexes = [ 0, 1, 2 ] }
                    , { rows = [ "0", "1" ], indexes = [ 0, 1 ] }
                    )
        , test "updates the paginated row model when expanded state changes and expanded rows are not paginated" <|
            \_ ->
                let
                    cfg : Table.Config Person
                    cfg =
                        { config | paginateExpandedRows = False }

                    collapsed : Table.State
                    collapsed =
                        { plain | pagination = { pageIndex = 0, pageSize = 1 } }

                    expanded : Table.State
                    expanded =
                        { collapsed | expanded = Table.expandedIds (Set.singleton "0") }

                    secondPage : Table.State
                    secondPage =
                        { expanded | pagination = { pageIndex = 1, pageSize = 1 } }

                    final : Table.State -> Table.RowModel Person
                    final state =
                        Table.rowsFromList cfg state pairs

                    prePaginated : Table.State -> Table.RowModel Person
                    prePaginated state =
                        Table.prePaginationRowModel cfg
                            state
                            (Table.coreRowModelFromList cfg state pairs)

                    displayOrder : Table.State -> List String
                    displayOrder state =
                        Table.rowsInDisplayOrder cfg state (prePaginated state)
                            |> List.map Table.rowId
                in
                Expect.equal
                    { collapsedRows = List.map Table.rowId (final collapsed).rows
                    , collapsedOrder = displayOrder collapsed
                    , expandedState = expanded.expanded == Table.expandedIds (Set.singleton "0")
                    , expandedRows = List.map Table.rowId (final expanded).rows
                    , expandedOrder = displayOrder expanded
                    , expandedIndexes =
                        List.map (Table.displayIndex cfg expanded (prePaginated expanded))
                            (final expanded).rows
                    , secondPageRows = List.map Table.rowId (final secondPage).rows
                    , secondPageIndex =
                        (final secondPage).rows
                            |> List.head
                            |> Maybe.map (Table.displayIndex cfg secondPage (prePaginated secondPage))
                    , collapsedAgainOrder = displayOrder collapsed
                    , missingChild =
                        Table.findRow (prePaginated collapsed) "0.0"
                            |> Maybe.map (Table.displayIndex cfg collapsed (prePaginated collapsed))
                    }
                    { collapsedRows = [ "0" ]
                    , collapsedOrder = [ "0", "1" ]
                    , expandedState = True
                    , expandedRows = [ "0", "0.0" ]
                    , expandedOrder = [ "0", "0.0", "1" ]
                    , expandedIndexes = [ 0, 1 ]
                    , secondPageRows = [ "1" ]
                    , secondPageIndex = Just 2
                    , collapsedAgainOrder = [ "0", "1" ]
                    , missingChild = Just -1
                    }
        ]



-- createPaginatedRowModel.test.ts, re-homed from phase 3


paginationSuite : Test
paginationSuite =
    describe "createPaginatedRowModel manualPagination"
        [ test "should include expanded children when expanded rows bypass manual pagination" <|
            \_ ->
                -- Re-homed from `tests/PaginationRowModelTest.elm`: with
                -- pagination manual and `paginateExpandedRows` off it is the
                -- expanded row model that splices the children in.
                let
                    cfg : Table.Config Person
                    cfg =
                        { config | manualPagination = True, paginateExpandedRows = False }

                    data : List Person
                    data =
                        List.range 0 2
                            |> List.map
                                (\i ->
                                    person ("parent-" ++ String.fromInt i)
                                        (List.range 0 1
                                            |> List.map
                                                (\j ->
                                                    person
                                                        ("child-"
                                                            ++ String.fromInt i
                                                            ++ "."
                                                            ++ String.fromInt j
                                                        )
                                                        []
                                                )
                                        )
                                )

                    state : Table.State
                    state =
                        { plain
                            | expanded = Table.expandedIds (Set.singleton "0")
                            , pagination = { pageIndex = 0, pageSize = 2 }
                        }
                in
                Table.rowsFromList cfg state data
                    |> .rows
                    |> List.map Table.rowId
                    |> Expect.equal [ "0", "0.0", "0.1", "1", "2" ]
        ]
