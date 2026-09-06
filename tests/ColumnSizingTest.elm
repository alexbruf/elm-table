module ColumnSizingTest exposing (suite)

{-| Ports `tests/unit/features/column-sizing/columnSizingFeature.utils.test.ts`.

Excluded cases are listed in `reports/phase-5.md`.

-}

import Dict
import Expect
import Table
import Table.Value as Value
import Test exposing (Test, describe, test)


type alias Item =
    { id : String
    , a : String
    , b : String
    , c : String
    , d : String
    }


state : Table.State
state =
    Table.initialState


sized : List ( String, Float ) -> Table.State
sized entries =
    { state | columnSizing = Dict.fromList entries }


col : String -> (Item -> String) -> Table.Column Item
col columnId get =
    Table.column columnId (get >> Value.String)


sizedCol : String -> (Item -> String) -> Float -> Table.Column Item
sizedCol columnId get px =
    col columnId get |> Table.withSize px


columnNamed : Table.Config Item -> String -> Table.Column Item
columnNamed cfg columnId =
    Table.findColumn cfg columnId
        |> Maybe.withDefault (Table.display "missing")


plain : Table.Config Item
plain =
    Table.config [ col "a" .a ]


withSize200 : Table.Config Item
withSize200 =
    Table.config [ sizedCol "a" .a 200 ]


grouped : Table.Config Item
grouped =
    Table.config
        [ Table.group "group"
            [ sizedCol "a" .a 100
            , sizedCol "b" .b 200
            ]
            |> Table.withHeader "Group"
        ]


sizedA100 : Table.Config Item
sizedA100 =
    Table.config [ sizedCol "a" .a 100 ]


threeLevels : Table.Config Item
threeLevels =
    Table.config
        [ Table.group "outer"
            [ Table.group "inner"
                [ sizedCol "a" .a 100
                , sizedCol "b" .b 200
                ]
            ]
        ]


twoColumns : Table.Config Item
twoColumns =
    Table.config [ sizedCol "a" .a 100, sizedCol "b" .b 200 ]


fourColumns : Table.Config Item
fourColumns =
    Table.config
        [ sizedCol "a" .a 100
        , sizedCol "b" .b 200
        , sizedCol "c" .c 50
        , sizedCol "d" .d 75
        ]


threeColumns : Table.Config Item
threeColumns =
    Table.config [ sizedCol "a" .a 100, sizedCol "b" .b 200, sizedCol "c" .c 50 ]


twoGroups : Table.Config Item
twoGroups =
    Table.config
        [ Table.group "g1" [ sizedCol "a" .a 100, sizedCol "b" .b 200 ] |> Table.withHeader "g1"
        , Table.group "g2" [ sizedCol "c" .c 50, sizedCol "d" .d 75 ] |> Table.withHeader "g2"
        ]


headerRowAt : Int -> Table.Config Item -> Table.State -> List (Table.Header Item)
headerRowAt index cfg current =
    Table.headerGroups cfg current
        |> List.drop index
        |> List.head
        |> Maybe.map .headers
        |> Maybe.withDefault []


headerAt : Int -> Int -> Table.Config Item -> Table.State -> Maybe (Table.Header Item)
headerAt groupIndex headerIndex cfg current =
    headerRowAt groupIndex cfg current
        |> List.drop headerIndex
        |> List.head


sizeOfHeader : Int -> Int -> Table.Config Item -> Table.State -> Float
sizeOfHeader groupIndex headerIndex cfg current =
    headerAt groupIndex headerIndex cfg current
        |> Maybe.map (Table.getHeaderSize cfg current)
        |> Maybe.withDefault -1


startOfHeader : Int -> Int -> Table.Config Item -> Table.State -> Float
startOfHeader groupIndex headerIndex cfg current =
    headerAt groupIndex headerIndex cfg current
        |> Maybe.map (Table.getHeaderStart cfg current (headerRowAt groupIndex cfg current))
        |> Maybe.withDefault -1


startOf : Table.Config Item -> Table.State -> String -> Float
startOf cfg current columnId =
    Table.getColumnStart cfg current Table.allColumnsRegion (columnNamed cfg columnId)


afterOf : Table.Config Item -> Table.State -> String -> Float
afterOf cfg current columnId =
    Table.getColumnAfter cfg current Table.allColumnsRegion (columnNamed cfg columnId)


isFloat : Float -> Float -> Expect.Expectation
isFloat expected actual =
    Expect.within (Expect.Absolute 0.0001) expected actual


suite : Test
suite =
    describe "columnSizingFeature.utils"
        [ describe "header_getSize"
            [ test "returns default size for a leaf header" <|
                \_ -> sizeOfHeader 0 0 plain state |> isFloat 150
            , test "returns columnDef.size for a leaf header" <|
                \_ -> sizeOfHeader 0 0 withSize200 state |> isFloat 200
            , test "returns sum of subHeader sizes for a parent header" <|
                \_ -> sizeOfHeader 0 0 grouped state |> isFloat 300
            , test "respects columnSizing state" <|
                \_ -> sizeOfHeader 0 0 sizedA100 (sized [ ( "a", 250 ) ]) |> isFloat 250
            , test "sums three levels and recomputes group sizes after a leaf resize" <|
                \_ ->
                    let
                        resized : Table.State
                        resized =
                            Table.setColumnSizing (Dict.fromList [ ( "a", 400 ) ]) state
                    in
                    Expect.all
                        [ \_ -> sizeOfHeader 1 0 threeLevels state |> isFloat 300
                        , \_ -> sizeOfHeader 0 0 threeLevels state |> isFloat 300
                        , \_ -> sizeOfHeader 1 0 threeLevels resized |> isFloat 600
                        , \_ -> sizeOfHeader 0 0 threeLevels resized |> isFloat 600
                        ]
                        ()
            ]
        , describe "header_getStart"
            [ test "returns 0 for the first header" <|
                \_ -> startOfHeader 0 0 twoColumns state |> isFloat 0
            , test "returns size of preceding header for the second header" <|
                \_ -> startOfHeader 0 1 twoColumns state |> isFloat 100
            , test "returns running sum of preceding sizes" <|
                \_ ->
                    Expect.all
                        [ \_ -> startOfHeader 0 0 fourColumns state |> isFloat 0
                        , \_ -> startOfHeader 0 1 fourColumns state |> isFloat 100
                        , \_ -> startOfHeader 0 2 fourColumns state |> isFloat 300
                        , \_ -> startOfHeader 0 3 fourColumns state |> isFloat 350
                        ]
                        ()
            , test "respects columnSizing state" <|
                \_ -> startOfHeader 0 1 twoColumns (sized [ ( "a", 75 ) ]) |> isFloat 75
            , test "updates getStart when columnSizing changes (memo invalidation)" <|
                \_ ->
                    Expect.all
                        [ \_ -> startOfHeader 0 1 twoColumns state |> isFloat 100
                        , \_ -> startOfHeader 0 1 twoColumns (sized [ ( "a", 500 ) ]) |> isFloat 500
                        ]
                        ()
            , test "returns running sum across nested header groups (parent row)" <|
                \_ ->
                    Expect.all
                        [ \_ -> startOfHeader 0 0 twoGroups state |> isFloat 0
                        , \_ -> startOfHeader 0 1 twoGroups state |> isFloat 300
                        , \_ -> startOfHeader 1 0 twoGroups state |> isFloat 0
                        , \_ -> startOfHeader 1 1 twoGroups state |> isFloat 100
                        , \_ -> startOfHeader 1 2 twoGroups state |> isFloat 300
                        , \_ -> startOfHeader 1 3 twoGroups state |> isFloat 350
                        ]
                        ()
            , test "returns 0 for a single-header group" <|
                \_ -> startOfHeader 0 0 sizedA100 state |> isFloat 0
            ]
        , describe "column_getStart"
            [ test "returns 0 for the first column" <|
                \_ -> startOf twoColumns state "a" |> isFloat 0
            , test "returns size of preceding column for the second column" <|
                \_ -> startOf twoColumns state "b" |> isFloat 100
            , test "returns running sum of preceding column sizes" <|
                \_ ->
                    Expect.all
                        [ \_ -> startOf fourColumns state "a" |> isFloat 0
                        , \_ -> startOf fourColumns state "b" |> isFloat 100
                        , \_ -> startOf fourColumns state "c" |> isFloat 300
                        , \_ -> startOf fourColumns state "d" |> isFloat 350
                        ]
                        ()
            , test "respects columnSizing state" <|
                \_ ->
                    startOf threeColumns (sized [ ( "a", 75 ), ( "b", 30 ) ]) "c" |> isFloat 105
            , test "updates getStart when columnSizing changes (memo invalidation)" <|
                \_ ->
                    Expect.all
                        [ \_ -> startOf twoColumns state "b" |> isFloat 100
                        , \_ -> startOf twoColumns (sized [ ( "a", 500 ) ]) "b" |> isFloat 500
                        ]
                        ()
            ]
        , describe "column_getAfter"
            [ test "returns 0 for the last column" <|
                \_ -> afterOf twoColumns state "b" |> isFloat 0
            , test "returns size of following column for the second-to-last column" <|
                \_ -> afterOf twoColumns state "a" |> isFloat 200
            , test "returns running sum of following column sizes" <|
                \_ ->
                    Expect.all
                        [ \_ -> afterOf fourColumns state "a" |> isFloat 325
                        , \_ -> afterOf fourColumns state "b" |> isFloat 125
                        , \_ -> afterOf fourColumns state "c" |> isFloat 75
                        , \_ -> afterOf fourColumns state "d" |> isFloat 0
                        ]
                        ()
            , test "respects columnSizing state" <|
                \_ ->
                    afterOf threeColumns (sized [ ( "b", 30 ), ( "c", 25 ) ]) "a" |> isFloat 55
            , test "updates getAfter when columnSizing changes (memo invalidation)" <|
                \_ ->
                    Expect.all
                        [ \_ -> afterOf twoColumns state "a" |> isFloat 200
                        , \_ -> afterOf twoColumns (sized [ ( "b", 500 ) ]) "a" |> isFloat 500
                        ]
                        ()
            ]
        , describe "column offsets with grouping (memo invalidation)"
            [ test "reorders visible leaf columns, headers, and cells in lockstep after setGrouping" <|
                \_ ->
                    let
                        withGrouping : Table.State
                        withGrouping =
                            { state | grouping = [ "b" ] }

                        rowOf : Table.State -> Maybe (Table.Row Item)
                        rowOf current =
                            Table.coreRowModelFromList threeColumns current items
                                |> .rows
                                |> List.head
                    in
                    Expect.all
                        [ \_ ->
                            Table.visibleLeafColumns threeColumns state
                                |> List.map Table.columnId
                                |> Expect.equal [ "a", "b", "c" ]
                        , \_ ->
                            headerRowAt 0 threeColumns state
                                |> List.map Table.headerColumnId
                                |> Expect.equal [ "a", "b", "c" ]
                        , \_ ->
                            Table.visibleLeafColumns threeColumns withGrouping
                                |> List.map Table.columnId
                                |> Expect.equal [ "b", "a", "c" ]
                        , \_ ->
                            headerRowAt 0 threeColumns withGrouping
                                |> List.map Table.headerColumnId
                                |> Expect.equal [ "b", "a", "c" ]
                        , \_ ->
                            rowOf withGrouping
                                |> Maybe.map (Table.getAllCells threeColumns withGrouping >> List.map .columnId)
                                |> Expect.equal (Just [ "b", "a", "c" ])
                        ]
                        ()
            , test "updates getStart and getAfter after setGrouping" <|
                \_ ->
                    let
                        withGrouping : Table.State
                        withGrouping =
                            { state | grouping = [ "b" ] }
                    in
                    Expect.all
                        [ \_ -> startOf threeColumns state "c" |> isFloat 300
                        , \_ -> afterOf threeColumns state "b" |> isFloat 50
                        , \_ -> startOf threeColumns withGrouping "b" |> isFloat 0
                        , \_ -> startOf threeColumns withGrouping "a" |> isFloat 200
                        , \_ -> startOf threeColumns withGrouping "c" |> isFloat 300
                        , \_ -> afterOf threeColumns withGrouping "b" |> isFloat 150
                        , \_ -> afterOf threeColumns withGrouping "a" |> isFloat 50
                        , \_ -> afterOf threeColumns withGrouping "c" |> isFloat 0
                        ]
                        ()
            ]
        , describe "sizing state defaults"
            [ test "getDefaultColumnSizingState should return an empty map and a new instance each time" <|
                \_ -> Expect.equal Dict.empty Table.initialState.columnSizing
            , test "getDefaultColumnSizingColumnDef should return the built-in sizing defaults" <|
                \_ ->
                    Expect.all
                        [ \cfg -> Table.columnSize cfg (columnNamed cfg "a") |> isFloat 150
                        , \cfg -> Table.columnMinSize cfg (columnNamed cfg "a") |> isFloat 20
                        , \cfg -> Table.columnMaxSize cfg (columnNamed cfg "a") |> isFloat 9007199254740991
                        ]
                        plain
            ]
        , describe "column_getSize"
            [ test "should fall back to the built-in default size" <|
                \_ -> Table.getColumnSize plain state (columnNamed plain "a") |> isFloat 150
            , test "should prefer committed sizing state over the columnDef size" <|
                \_ ->
                    Table.getColumnSize sizedA100 (sized [ ( "a", 250 ) ]) (columnNamed sizedA100 "a")
                        |> isFloat 250
            , test "should clamp to minSize" <|
                \_ ->
                    let
                        cfg : Table.Config Item
                        cfg =
                            Table.config [ col "a" .a |> Table.withMinSize 50 ]
                    in
                    Table.getColumnSize cfg (sized [ ( "a", 5 ) ]) (columnNamed cfg "a") |> isFloat 50
            , test "should clamp to maxSize" <|
                \_ ->
                    let
                        cfg : Table.Config Item
                        cfg =
                            Table.config [ col "a" .a |> Table.withSize 500 |> Table.withMaxSize 300 ]
                    in
                    Table.getColumnSize cfg state (columnNamed cfg "a") |> isFloat 300
            ]
        , describe "column_resetSize"
            [ test "should remove only this column from the sizing state" <|
                \_ ->
                    Table.resetColumnSize "a" (sized [ ( "a", 250 ), ( "b", 300 ) ])
                        |> .columnSizing
                        |> Expect.equal (Dict.fromList [ ( "b", 300 ) ])
            ]
        , describe "table_setColumnSizing / table_resetColumnSizing"
            [ test "should route the updater through onColumnSizingChange" <|
                \_ ->
                    Table.setColumnSizing (Dict.fromList [ ( "a", 123 ) ]) state
                        |> .columnSizing
                        |> Expect.equal (Dict.fromList [ ( "a", 123 ) ])
            , test "should reset to an empty map when defaultState is true" <|
                \_ ->
                    Table.resetColumnSizing (sized [ ( "a", 250 ) ])
                        |> .columnSizing
                        |> Expect.equal Dict.empty
            , test "should reset to the initial sizing by default" <|
                \_ ->
                    Table.setColumnSizing (Dict.fromList [ ( "a", 250 ) ]) state
                        |> .columnSizing
                        |> Expect.equal (Dict.fromList [ ( "a", 250 ) ])
            ]
        , describe "table_getColumnOffsets"
            [ test "should build start and after offsets per column" <|
                \_ ->
                    let
                        offsets : Table.ColumnRegion -> (Table.Config Item -> Table.State -> Table.ColumnRegion -> Table.Column Item -> Float) -> List ( String, Float )
                        offsets region fn =
                            Table.pinnedVisibleLeafColumns threeColumns state region
                                |> List.map (\c -> ( Table.columnId c, fn threeColumns state region c ))
                    in
                    Expect.all
                        [ \_ ->
                            offsets Table.allColumnsRegion Table.getColumnStart
                                |> Expect.equal [ ( "a", 0 ), ( "b", 100 ), ( "c", 300 ) ]
                        , \_ ->
                            offsets Table.allColumnsRegion Table.getColumnAfter
                                |> Expect.equal [ ( "a", 250 ), ( "b", 50 ), ( "c", 0 ) ]
                        , \_ ->
                            Expect.equal
                                (offsets Table.allColumnsRegion Table.getColumnStart)
                                (offsets Table.centerColumnsRegion Table.getColumnStart)
                        , \_ -> Expect.equal [] (offsets Table.leftColumnsRegion Table.getColumnStart)
                        , \_ -> Expect.equal [] (offsets Table.rightColumnsRegion Table.getColumnStart)
                        ]
                        ()
            ]
        , describe "total sizes"
            [ test "table_getTotalSize should sum the full header row" <|
                \_ -> Table.totalSize twoColumns state |> isFloat 300
            , test "should sum each pinning region separately" <|
                \_ ->
                    let
                        pinned : Table.State
                        pinned =
                            { state | columnPinning = { left = [ "a" ], right = [ "c" ] } }
                    in
                    Expect.all
                        [ \_ -> Table.leftTotalSize threeColumns pinned |> isFloat 100
                        , \_ -> Table.centerTotalSize threeColumns pinned |> isFloat 200
                        , \_ -> Table.rightTotalSize threeColumns pinned |> isFloat 50
                        , \_ -> Table.totalSize threeColumns pinned |> isFloat 350
                        ]
                        ()
            , test "should return 0 for empty pinning regions" <|
                \_ ->
                    Expect.all
                        [ \_ -> Table.leftTotalSize sizedA100 state |> isFloat 0
                        , \_ -> Table.rightTotalSize sizedA100 state |> isFloat 0
                        , \_ -> Table.centerTotalSize sizedA100 state |> isFloat 100
                        ]
                        ()
            ]
        ]


items : List Item
items =
    [ Item "1" "a1" "b1" "c1" "d1"
    , Item "2" "a2" "b2" "c2" "d2"
    ]
