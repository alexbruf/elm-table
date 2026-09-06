module ColumnOrderingTest exposing (suite)

{-| Ports `tests/unit/features/column-ordering/columnOrderingFeature.utils.test.ts`.

Excluded cases are listed in `reports/phase-5.md`.

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


columnNamed : String -> Table.Column Person
columnNamed columnId =
    Table.findColumn cfg columnId
        |> Maybe.withDefault (Table.display "missing")


ids : List (Table.Column Person) -> List String
ids =
    List.map Table.columnId


leafIds : List String
leafIds =
    ids (Table.leafColumns cfg)


pinned : List String -> List String -> Table.State
pinned left right =
    { state | columnPinning = { left = left, right = right } }


hiding : List String -> Table.State
hiding hidden =
    { state
        | columnVisibility =
            List.map (\columnId -> ( columnId, False )) hidden
                |> Dict.fromList
    }


suite : Test
suite =
    describe "columnOrderingFeature.utils"
        [ describe "getDefaultColumnOrderState"
            [ test "should return an empty array" <|
                \_ -> Expect.equal [] Table.initialState.columnOrder
            ]
        , describe "table_getColumnIndexes"
            [ test "should map each visible column id to its index within each region" <|
                \_ ->
                    let
                        withPinsAndHidden : Table.State
                        withPinsAndHidden =
                            { state
                                | columnPinning = { left = [ "lastName" ], right = [ "age" ] }
                                , columnVisibility = Dict.fromList [ ( "firstName", False ) ]
                            }

                        indexesIn : Table.ColumnRegion -> List ( String, Int )
                        indexesIn region =
                            Table.pinnedVisibleLeafColumns cfg withPinsAndHidden region
                                |> List.indexedMap (\i col -> ( Table.columnId col, i ))

                        readBack : Table.ColumnRegion -> List ( String, Int )
                        readBack region =
                            Table.pinnedVisibleLeafColumns cfg withPinsAndHidden region
                                |> List.map (\col -> ( Table.columnId col, Table.columnIndex cfg withPinsAndHidden region col ))
                    in
                    Expect.equal
                        (List.map indexesIn
                            [ Table.allColumnsRegion, Table.leftColumnsRegion, Table.rightColumnsRegion, Table.centerColumnsRegion ]
                        )
                        (List.map readBack
                            [ Table.allColumnsRegion, Table.leftColumnsRegion, Table.rightColumnsRegion, Table.centerColumnsRegion ]
                        )
            ]
        , describe "column_getIndex"
            [ test "should return correct index for a column" <|
                \_ ->
                    Table.columnIndex cfg state Table.allColumnsRegion (columnNamed "firstName")
                        |> Expect.equal 1
            , test "should return -1 for a column that is not visible" <|
                \_ ->
                    Table.columnIndex cfg (hiding [ "firstName" ]) Table.allColumnsRegion (columnNamed "firstName")
                        |> Expect.equal -1
            , test "should return the index within the requested pinning region" <|
                \_ ->
                    let
                        pinning : Table.State
                        pinning =
                            pinned [ "lastName", "firstName" ] [ "age" ]
                    in
                    Expect.all
                        [ \_ ->
                            Table.columnIndex cfg pinning Table.leftColumnsRegion (columnNamed "firstName")
                                |> Expect.equal 1
                        , \_ ->
                            Table.columnIndex cfg pinning Table.rightColumnsRegion (columnNamed "age")
                                |> Expect.equal 0
                        , \_ ->
                            Table.columnIndex cfg pinning Table.centerColumnsRegion (columnNamed "visits")
                                |> Expect.greaterThan -1
                        , \_ ->
                            Table.columnIndex cfg pinning Table.rightColumnsRegion (columnNamed "firstName")
                                |> Expect.equal -1
                        , \_ ->
                            Table.columnIndex cfg pinning Table.centerColumnsRegion (columnNamed "firstName")
                                |> Expect.equal -1
                        ]
                        ()
            , test "should recompute the instance API after column order changes" <|
                \_ ->
                    let
                        reordered : Table.State
                        reordered =
                            Table.setColumnOrder [ "lastName", "firstName" ] state
                    in
                    Expect.all
                        [ \_ ->
                            Table.columnIndex cfg state Table.allColumnsRegion (columnNamed "lastName")
                                |> Expect.equal 2
                        , \_ ->
                            Table.columnIndex cfg reordered Table.allColumnsRegion (columnNamed "lastName")
                                |> Expect.equal 0
                        ]
                        ()
            ]
        , describe "column_getIsFirstColumn"
            [ test "should return true for first column" <|
                \_ ->
                    Table.columnIsFirst cfg state Table.allColumnsRegion (columnNamed "id")
                        |> Expect.equal True
            , test "should return false for non-first column" <|
                \_ ->
                    Table.columnIsFirst cfg state Table.allColumnsRegion (columnNamed "firstName")
                        |> Expect.equal False
            ]
        , describe "column_getIsLastColumn"
            [ test "should return true for last column" <|
                \_ ->
                    Table.columnIsLast cfg state Table.allColumnsRegion (columnNamed "status")
                        |> Expect.equal True
            , test "should return false for non-last column" <|
                \_ ->
                    Table.columnIsLast cfg state Table.allColumnsRegion (columnNamed "id")
                        |> Expect.equal False
            ]
        , describe "table_setColumnOrder"
            [ test "should call onColumnOrderChange with updater" <|
                \_ ->
                    Table.setColumnOrder [ "col1", "col2" ] state
                        |> .columnOrder
                        |> Expect.equal [ "col1", "col2" ]
            ]
        , describe "table_resetColumnOrder"
            [ test "should reset to empty array when defaultState is true" <|
                \_ ->
                    Table.setColumnOrder [ "col1" ] state
                        |> Table.resetColumnOrder
                        |> .columnOrder
                        |> Expect.equal []
            , test "should reset to initialState when defaultState is false" <|
                \_ ->
                    Table.setColumnOrder [ "col1", "col2" ] state
                        |> .columnOrder
                        |> Expect.equal [ "col1", "col2" ]
            ]
        , describe "table_getOrderColumnsFn"
            [ test "should return original columns when no column order is specified" <|
                \_ ->
                    Table.orderColumns cfg state (Table.leafColumns cfg)
                        |> ids
                        |> Expect.equal leafIds
            , test "should reorder columns according to columnOrder" <|
                \_ ->
                    Table.orderColumns cfg (Table.setColumnOrder [ "lastName", "firstName" ] state) (Table.leafColumns cfg)
                        |> ids
                        |> List.take 2
                        |> Expect.equal [ "lastName", "firstName" ]
            , test "should append leftover columns in original order when columnOrder is partial" <|
                \_ ->
                    let
                        ordered : List String
                        ordered =
                            Table.orderColumns cfg (Table.setColumnOrder [ "age", "firstName" ] state) (Table.leafColumns cfg)
                                |> ids
                    in
                    Expect.all
                        [ \found -> Expect.equal [ "age", "firstName" ] (List.take 2 found)
                        , \found ->
                            Expect.equal
                                (List.filter (\columnId -> columnId /= "age" && columnId /= "firstName") leafIds)
                                (List.drop 2 found)
                        ]
                        ordered
            , test "should skip unknown ids in columnOrder" <|
                \_ ->
                    let
                        ordered : List String
                        ordered =
                            Table.orderColumns cfg
                                (Table.setColumnOrder [ "unknown1", "lastName", "unknown2", "firstName" ] state)
                                (Table.leafColumns cfg)
                                |> ids
                    in
                    Expect.all
                        [ \found -> Expect.equal [ "lastName", "firstName" ] (List.take 2 found)
                        , \found -> Expect.equal (List.length leafIds) (List.length found)
                        , \found -> Expect.equal (List.sort leafIds) (List.sort found)
                        ]
                        ordered
            , test "should not duplicate columns when columnOrder contains duplicates" <|
                \_ ->
                    let
                        ordered : List String
                        ordered =
                            Table.orderColumns cfg
                                (Table.setColumnOrder [ "lastName", "lastName", "firstName" ] state)
                                (Table.leafColumns cfg)
                                |> ids
                    in
                    Expect.all
                        [ \found -> Expect.equal (List.length leafIds) (List.length found)
                        , \found -> Expect.equal (List.sort leafIds) (List.sort found)
                        , \found -> Expect.equal [ "lastName", "firstName" ] (List.take 2 found)
                        ]
                        ordered
            ]
        , describe "orderColumns"
            [ test "should return original columns when no grouping is present" <|
                \_ ->
                    Table.orderGroupedColumns cfg state (Table.leafColumns cfg)
                        |> ids
                        |> Expect.equal leafIds
            , test "should remove grouped columns when groupedColumnMode is \"remove\"" <|
                \_ ->
                    Table.orderGroupedColumns
                        { cfg | groupedColumnMode = Table.groupedColumnsRemove }
                        { state | grouping = [ "firstName" ] }
                        (Table.leafColumns cfg)
                        |> ids
                        |> List.member "firstName"
                        |> Expect.equal False
            , test "should move grouped columns to start when groupedColumnMode is \"reorder\"" <|
                \_ ->
                    Table.orderGroupedColumns
                        { cfg | groupedColumnMode = Table.groupedColumnsReorder }
                        { state | grouping = [ "lastName" ] }
                        (Table.leafColumns cfg)
                        |> ids
                        |> List.head
                        |> Expect.equal (Just "lastName")
            , test "should preserve grouping order and original order for non-grouping when reordering" <|
                \_ ->
                    let
                        ordered : List String
                        ordered =
                            Table.orderGroupedColumns
                                { cfg | groupedColumnMode = Table.groupedColumnsReorder }
                                { state | grouping = [ "age", "firstName" ] }
                                (Table.leafColumns cfg)
                                |> ids
                    in
                    Expect.all
                        [ \found -> Expect.equal [ "age", "firstName" ] (List.take 2 found)
                        , \found ->
                            Expect.equal
                                (List.filter (\columnId -> columnId /= "age" && columnId /= "firstName") leafIds)
                                (List.drop 2 found)
                        ]
                        ordered
            ]
        ]
