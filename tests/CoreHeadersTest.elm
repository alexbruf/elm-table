module CoreHeadersTest exposing (suite)

{-| Ports `tests/unit/core/headers/constructHeader.test.ts` and
`tests/unit/core/headers/coreHeadersFeature.utils.test.ts`.

Excluded cases are listed in `reports/phase-2.md`.

-}

import Dict
import Expect
import Table
import Table.Value as Value
import Test exposing (Test, describe, test)


type alias Item =
    { a : String
    , b : String
    , c : String
    }


col : String -> (Item -> String) -> Table.Column Item
col columnId get =
    Table.column columnId (get >> Value.String)


config : Table.Config Item
config =
    Table.config
        [ Table.group "group" [ col "a" .a, col "b" .b ] |> Table.withHeader "Group"
        , col "c" .c
        ]


deepConfig : Table.Config Item
deepConfig =
    Table.config
        [ Table.group "outer"
            [ Table.group "inner" [ col "a" .a, col "b" .b ]
            , col "c" .c
            ]
        ]


mixedConfig : Table.Config Item
mixedConfig =
    Table.config
        [ col "a" .a
        , Table.group "group"
            [ col "b" .b
            , Table.group "nested" [ col "c" .c ] |> Table.withHeader "Nested"
            ]
            |> Table.withHeader "Group"
        ]


hiding : List String -> Table.State
hiding hidden =
    let
        state =
            Table.initialState
    in
    { state | columnVisibility = Dict.fromList (List.map (\columnId -> ( columnId, False )) hidden) }


groupsOf : Table.Config Item -> Table.State -> List (List (Table.Header Item))
groupsOf cfg state =
    Table.headerGroups cfg state |> List.map .headers


columnIdsAt : Int -> List (List (Table.Header Item)) -> List String
columnIdsAt row groups =
    groups |> List.drop row |> List.head |> Maybe.withDefault [] |> List.map Table.headerColumnId


rowAt : Int -> List (List (Table.Header Item)) -> List (Table.Header Item)
rowAt row groups =
    groups |> List.drop row |> List.head |> Maybe.withDefault []


findByColumn : String -> List (Table.Header Item) -> Maybe (Table.Header Item)
findByColumn columnId headers =
    headers |> List.filter (\h -> Table.headerColumnId h == columnId) |> List.head


suite : Test
suite =
    describe "core headers"
        [ describe "constructHeader"
            [ test "should create a column with all core column APIs and properties" <|
                \_ ->
                    let
                        single =
                            Table.config [ col "test-column" .a ]

                        header =
                            Table.headerGroups single Table.initialState
                                |> List.concatMap .headers
                                |> List.head
                    in
                    header
                        |> Maybe.map
                            (\h ->
                                { id = Table.headerId h
                                , columnId = Table.headerColumnId h
                                , colSpan = Table.headerColSpan h
                                , rowSpan = Table.headerRowSpan h
                                , depth = Table.headerDepth h
                                , index = Table.headerIndex h
                                , isPlaceholder = Table.headerIsPlaceholder h
                                , placeholderId = Table.headerPlaceholderId h
                                , subHeaders = List.length (Table.headerSubHeaders h)
                                }
                            )
                        |> Expect.equal
                            (Just
                                { id = "test-column"
                                , columnId = "test-column"
                                , colSpan = 1
                                , rowSpan = 1
                                , depth = 1
                                , index = 0
                                , isPlaceholder = False
                                , placeholderId = Nothing
                                , subHeaders = 0
                                }
                            )
            ]
        , describe "table_getHeaderGroups"
            [ test "should build one group per column depth" <|
                \_ ->
                    let
                        groups =
                            groupsOf config Table.initialState
                    in
                    Expect.equal ( List.length groups, columnIdsAt 1 groups )
                        ( 2, [ "a", "b", "c" ] )
            , test "should exclude hidden columns" <|
                \_ ->
                    groupsOf config (hiding [ "b" ])
                        |> columnIdsAt 1
                        |> Expect.equal [ "a", "c" ]
            , test "should preserve nested spans and shrink them when a leaf is hidden" <|
                \_ ->
                    let
                        groups =
                            groupsOf deepConfig Table.initialState

                        hiddenGroups =
                            groupsOf deepConfig (hiding [ "b" ])

                        spanOf row columnId source =
                            source |> rowAt row |> findByColumn columnId |> Maybe.map Table.headerColSpan
                    in
                    Expect.equal
                        { groups = List.length groups
                        , outer = spanOf 0 "outer" groups
                        , inner = spanOf 1 "inner" groups
                        , leaves =
                            rowAt 2 groups
                                |> List.map (\h -> ( Table.headerColumnId h, Table.headerColSpan h, Table.headerRowSpan h ))
                        , hiddenOuter = spanOf 0 "outer" hiddenGroups
                        , hiddenInner = spanOf 1 "inner" hiddenGroups
                        , hiddenLeaves = columnIdsAt 2 hiddenGroups
                        }
                        { groups = 3
                        , outer = Just 3
                        , inner = Just 2
                        , leaves = [ ( "a", 1, 1 ), ( "b", 1, 1 ), ( "c", 1, 0 ) ]
                        , hiddenOuter = Just 2
                        , hiddenInner = Just 1
                        , hiddenLeaves = [ "a", "c" ]
                        }
            ]
        , describe "header rowSpan for uneven column trees"
            [ test "should give the top placeholder of a chain the full span and cover the leaf" <|
                \_ ->
                    let
                        groups =
                            groupsOf config Table.initialState
                    in
                    Expect.equal
                        { count = List.length groups
                        , top =
                            rowAt 0 groups
                                |> List.map
                                    (\h ->
                                        ( Table.headerColumnId h
                                        , Table.headerIsPlaceholder h
                                        , ( Table.headerColSpan h, Table.headerRowSpan h )
                                        )
                                    )
                        , leaves =
                            rowAt 1 groups
                                |> List.map
                                    (\h ->
                                        ( Table.headerId h
                                        , Table.headerIsPlaceholder h
                                        , ( Table.headerColSpan h, Table.headerRowSpan h )
                                        )
                                    )
                        }
                        { count = 2
                        , top =
                            [ ( "group", False, ( 2, 1 ) )
                            , ( "c", True, ( 1, 2 ) )
                            ]
                        , leaves =
                            [ ( "a", False, ( 1, 1 ) )
                            , ( "b", False, ( 1, 1 ) )
                            , ( "c", False, ( 1, 0 ) )
                            ]
                        }
            , test "should give every rowSpan length in a three-level mixed tree" <|
                \_ ->
                    let
                        groups =
                            groupsOf mixedConfig Table.initialState

                        spans =
                            groups
                                |> List.map
                                    (List.map
                                        (\h ->
                                            ( Table.headerColumnId h
                                            , Table.headerIsPlaceholder h
                                            , Table.headerRowSpan h
                                            )
                                        )
                                    )

                        totals =
                            groups |> List.map (List.map Table.headerColSpan >> List.sum)
                    in
                    Expect.equal ( List.length groups, spans, totals )
                        ( 3
                        , [ [ ( "a", True, 3 ), ( "group", False, 1 ) ]
                          , [ ( "a", True, 0 ), ( "b", True, 2 ), ( "nested", False, 1 ) ]
                          , [ ( "a", False, 0 ), ( "b", False, 0 ), ( "c", False, 1 ) ]
                          ]
                        , [ 3, 3, 3 ]
                        )
            , test "should shrink rowSpans when hiding columns flattens the tree" <|
                \_ ->
                    let
                        groups =
                            groupsOf config (hiding [ "a", "b" ])
                    in
                    Expect.equal
                        ( List.length groups
                        , rowAt 0 groups
                            |> List.map
                                (\h ->
                                    ( Table.headerColumnId h
                                    , Table.headerIsPlaceholder h
                                    , Table.headerRowSpan h
                                    )
                                )
                        )
                        ( 1, [ ( "c", False, 1 ) ] )
            ]
        , describe "header_getLeafHeaders"
            [ test "should collect descendant leaf headers before the header itself" <|
                \_ ->
                    groupsOf config Table.initialState
                        |> rowAt 0
                        |> findByColumn "group"
                        |> Maybe.map (Table.getLeafHeaders >> List.map Table.headerColumnId)
                        |> Expect.equal (Just [ "a", "b", "group" ])
            , test "should return only itself for a leaf header" <|
                \_ ->
                    let
                        leaf =
                            groupsOf config Table.initialState
                                |> rowAt 1
                                |> findByColumn "a"
                    in
                    Maybe.map Table.getLeafHeaders leaf
                        |> Expect.equal (Maybe.map List.singleton leaf)
            , test "should preserve descendant-first identity across three levels" <|
                \_ ->
                    let
                        groups =
                            groupsOf
                                (Table.config
                                    [ Table.group "outer"
                                        [ Table.group "inner" [ col "a" .a, col "b" .b ] ]
                                    ]
                                )
                                Table.initialState

                        outer =
                            rowAt 0 groups |> List.head

                        expected =
                            rowAt 2 groups ++ rowAt 1 groups ++ rowAt 0 groups
                    in
                    Expect.equal
                        ( Maybe.map (Table.getLeafHeaders >> List.map Table.headerColumnId) outer
                        , Maybe.map Table.getLeafHeaders outer
                        )
                        ( Just [ "a", "b", "inner", "outer" ], Just expected )
            ]
        , describe "table_getLeafHeaders"
            [ test "should collect the leaf headers reachable from the top header row" <|
                \_ ->
                    let
                        found =
                            Table.leafHeaders config Table.initialState
                                |> List.map Table.headerColumnId
                    in
                    -- the vitest case asserts expect.arrayContaining(['a', 'b', 'c'])
                    [ "a", "b", "c" ]
                        |> List.map (\columnId -> List.member columnId found)
                        |> Expect.equal [ True, True, True ]
            ]
        ]
