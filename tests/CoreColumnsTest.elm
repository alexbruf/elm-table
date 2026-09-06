module CoreColumnsTest exposing (suite)

{-| Ports `tests/unit/core/columns/constructColumn.test.ts` and
`tests/unit/core/columns/coreColumnsFeature.utils.test.ts`.

Excluded cases are listed in `reports/phase-2.md`.

-}

import Expect
import Table
import Table.Value as Value
import Test exposing (Test, describe, test)


type alias Item =
    { a : String
    , b : String
    , c : String
    }


columns : List (Table.Column Item)
columns =
    [ Table.group "group"
        [ Table.column "a" (.a >> Value.String)
        , Table.column "b" (.b >> Value.String)
        ]
        |> Table.withHeader "Group"
    , Table.column "c" (.c >> Value.String)
    ]


config : Table.Config Item
config =
    Table.config columns


deepConfig : Table.Config Item
deepConfig =
    Table.config
        [ Table.group "outer"
            [ Table.group "inner"
                [ Table.column "a" (.a >> Value.String)
                , Table.column "b" (.b >> Value.String)
                ]
            , Table.column "c" (.c >> Value.String)
            ]
        ]


ids : List (Table.Column Item) -> List String
ids =
    List.map Table.columnId


suite : Test
suite =
    describe "core columns"
        [ describe "constructColumn"
            [ test "should create a column with all core column APIs and properties" <|
                \_ ->
                    let
                        col =
                            Table.column "test-column" (.a >> Value.String)
                    in
                    Expect.equal
                        ( Table.columnId col
                        , Table.columnDepth col
                        , ( Table.columnParentId col
                          , Table.columnColumns col
                          , Table.columnAccessor col /= Nothing
                          )
                        )
                        ( "test-column", 0, ( Nothing, [], True ) )
            ]
        , describe "table_getAllColumns"
            [ test "should build the nested column tree from column defs" <|
                \_ ->
                    let
                        top =
                            Table.config columns |> .columns

                        groupColumn =
                            List.head top
                    in
                    Expect.equal
                        ( ids top
                        , Maybe.map (Table.columnColumns >> ids) groupColumn
                        , Maybe.andThen
                            (Table.columnColumns
                                >> List.head
                                >> Maybe.map (\c -> ( Table.columnParentId c, Table.columnDepth c ))
                            )
                            groupColumn
                        )
                        ( [ "group", "c" ], Just [ "a", "b" ], Just ( Just "group", 1 ) )
            , test "should preserve ordering, parents, depths, and leaf children across three levels" <|
                \_ ->
                    let
                        find columnId =
                            Table.findColumn deepConfig columnId

                        depthOf columnId =
                            Maybe.map Table.columnDepth (find columnId)

                        parentOf columnId =
                            Maybe.andThen Table.columnParentId (find columnId)

                        childrenOf columnId =
                            Maybe.map (Table.columnColumns >> ids) (find columnId)
                    in
                    Expect.equal
                        { children = ( childrenOf "outer", childrenOf "inner" )
                        , depths = [ depthOf "outer", depthOf "inner", depthOf "a", depthOf "b", depthOf "c" ]
                        , parents = [ parentOf "inner", parentOf "c", parentOf "a", parentOf "b" ]
                        , leaves = [ childrenOf "a", childrenOf "b", childrenOf "c" ]
                        }
                        { children = ( Just [ "inner", "c" ], Just [ "a", "b" ] )
                        , depths = [ Just 0, Just 1, Just 2, Just 2, Just 1 ]
                        , parents = [ Just "outer", Just "outer", Just "inner", Just "inner" ]
                        , leaves = [ Just [], Just [], Just [] ]
                        }
            ]
        , describe "column_getFlatColumns"
            [ test "should flatten a group column with itself first" <|
                \_ ->
                    Table.findColumn config "group"
                        |> Maybe.map (Table.columnFlatColumns >> ids)
                        |> Expect.equal (Just [ "group", "a", "b" ])
            , test "should return only itself for a leaf column" <|
                \_ ->
                    Table.findColumn config "c"
                        |> Maybe.map (Table.columnFlatColumns >> ids)
                        |> Expect.equal (Just [ "c" ])
            ]
        , describe "column_getLeafColumns"
            [ test "should return the descendants of a group column" <|
                \_ ->
                    Table.findColumn config "group"
                        |> Maybe.map (Table.columnLeafColumns >> ids)
                        |> Expect.equal (Just [ "a", "b" ])
            , test "should return only itself for a leaf column" <|
                \_ ->
                    Table.findColumn config "c"
                        |> Maybe.map (Table.columnLeafColumns >> ids)
                        |> Expect.equal (Just [ "c" ])
            ]
        , describe "table_getAllFlatColumns / table_getAllFlatColumnsById"
            [ test "should include group and leaf columns" <|
                \_ ->
                    Expect.equal
                        ( ids (Table.allColumns config)
                        , Maybe.map Table.columnId (Table.findColumn config "a")
                        )
                        ( [ "group", "a", "b", "c" ], Just "a" )
            ]
        , describe "table_getAllLeafColumns / table_getAllLeafColumnsById"
            [ test "should exclude group columns" <|
                \_ ->
                    Expect.equal
                        ( ids (Table.leafColumns config)
                        , List.member "group" (ids (Table.leafColumns config))
                        )
                        ( [ "a", "b", "c" ], False )
            ]
        , describe "table_getColumn"
            [ test "should find group and leaf columns by id" <|
                \_ ->
                    Expect.equal
                        ( Maybe.map Table.columnId (Table.findColumn config "group")
                        , Maybe.map Table.columnId (Table.findColumn config "b")
                        )
                        ( Just "group", Just "b" )
            , test "should return undefined for unknown column ids" <|
                \_ ->
                    Table.findColumn config "missing"
                        |> Maybe.map Table.columnId
                        |> Expect.equal Nothing
            ]
        , describe "table_getDefaultColumnDef"
            [ test "should let options.defaultColumn win" <|
                \_ ->
                    let
                        custom =
                            Table.config columns
                                |> Table.withDefaultColumn { size = 200, minSize = 40, maxSize = 400 }
                    in
                    Table.findColumn custom "a"
                        |> Maybe.map
                            (\col ->
                                ( Table.columnSize custom col
                                , Table.columnMinSize custom col
                                , ( Table.columnMaxSize custom col
                                  , Table.columnSize custom
                                        (Table.column "a" (.a >> Value.String)
                                            |> Table.withSize 500
                                        )
                                  )
                                )
                            )
                        |> Expect.equal (Just ( 200, 40, ( 400, 400 ) ))
            ]
        ]
