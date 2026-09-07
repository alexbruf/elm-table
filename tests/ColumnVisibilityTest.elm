module ColumnVisibilityTest exposing (suite)

{-| Ports `tests/unit/features/column-visibility/columnVisibilityFeature.utils.test.ts`.

Excluded cases are listed in `reports/phase-5.md`.

-}

import Dict
import Expect
import Fixtures exposing (Person)
import Table
import Table.Value as Value
import Test exposing (Test, describe, test)


cfg : Table.Config Person
cfg =
    Fixtures.config


state : Table.State
state =
    Table.initialState


hiding : List String -> Table.State
hiding hidden =
    { state | columnVisibility = Dict.fromList (List.map (\columnId -> ( columnId, False )) hidden) }


groupedConfig : Table.Config Person
groupedConfig =
    Table.config
        [ Table.group "name"
            [ Table.column "firstName" (.firstName >> Value.String)
            , Table.column "lastName" (.lastName >> Value.String)
            ]
            |> Table.withHeader "Name"
        ]


groupedConfigNoHide : Table.Config Person
groupedConfigNoHide =
    Table.config
        [ Table.group "name"
            [ Table.column "firstName" (.firstName >> Value.String)
            , Table.column "lastName" (.lastName >> Value.String)
                |> Table.withEnableHiding False
            ]
        ]


columnNamed : Table.Config Person -> String -> Table.Column Person
columnNamed config columnId =
    Table.findColumn config columnId
        |> Maybe.withDefault (Table.display "missing")


withFirstRow : (Table.Row Person -> Expect.Expectation) -> Expect.Expectation
withFirstRow fn =
    case Table.coreRowModelFromList cfg state (Fixtures.makeData [ 1 ]) |> .rows |> List.head of
        Just row ->
            fn row

        Nothing ->
            Expect.fail "the fixture row model is empty"


leafIds : Table.Config Person -> List String
leafIds config =
    List.map Table.columnId (Table.leafColumns config)


suite : Test
suite =
    describe "columnVisibilityFeature.utils"
        [ describe "getDefaultColumnVisibilityState"
            [ test "should return empty object" <|
                \_ ->
                    Expect.equal Dict.empty Table.initialState.columnVisibility
            ]
        , describe "column_getIsVisible"
            [ test "should return true by default" <|
                \_ ->
                    Table.columnIsVisible state (columnNamed cfg "id")
                        |> Expect.equal True
            , test "should return false when column is hidden" <|
                \_ ->
                    Table.columnIsVisible (hiding [ "firstName" ]) (columnNamed cfg "firstName")
                        |> Expect.equal False
            , test "should return true if any child column is visible" <|
                \_ ->
                    Table.columnIsVisible (hiding [ "firstName" ]) (columnNamed groupedConfig "name")
                        |> Expect.equal True
            ]
        , describe "column_getCanHide"
            [ test "should return true by default" <|
                \_ ->
                    Table.columnCanHide cfg (columnNamed cfg "id")
                        |> Expect.equal True
            , test "should return false when hiding is disabled globally" <|
                \_ ->
                    Table.columnCanHide { cfg | enableHiding = False } (columnNamed cfg "id")
                        |> Expect.equal False
            , test "should return false when hiding is disabled for column" <|
                \_ ->
                    let
                        config : Table.Config Person
                        config =
                            Table.config
                                [ Table.column "firstName" (.firstName >> Value.String)
                                    |> Table.withEnableHiding False
                                ]
                    in
                    Table.columnCanHide config (columnNamed config "firstName")
                        |> Expect.equal False
            ]
        , describe "column_toggleVisibility"
            [ test "should toggle column visibility" <|
                \_ ->
                    Table.toggleColumnVisibility cfg (columnNamed cfg "firstName") Nothing state
                        |> .columnVisibility
                        |> Expect.equal (Dict.fromList [ ( "firstName", False ) ])
            , test "should set specific visibility when provided" <|
                \_ ->
                    Table.toggleColumnVisibility cfg (columnNamed cfg "firstName") (Just True) state
                        |> .columnVisibility
                        |> Expect.equal (Dict.fromList [ ( "firstName", True ) ])
            , test "should toggle hideable leaf columns for a group column" <|
                \_ ->
                    Table.toggleColumnVisibility groupedConfigNoHide
                        (columnNamed groupedConfigNoHide "name")
                        (Just False)
                        state
                        |> .columnVisibility
                        |> Expect.equal (Dict.fromList [ ( "firstName", False ) ])
            , test "should infer group visibility toggles from its leaf columns" <|
                \_ ->
                    Table.toggleColumnVisibility groupedConfig (columnNamed groupedConfig "name") Nothing state
                        |> .columnVisibility
                        |> Expect.equal (Dict.fromList [ ( "firstName", False ), ( "lastName", False ) ])
            , test "should not toggle when column cannot be hidden" <|
                \_ ->
                    let
                        config : Table.Config Person
                        config =
                            { cfg | enableHiding = False }
                    in
                    Table.toggleColumnVisibility config (columnNamed config "firstName") Nothing state
                        |> Expect.equal state
            ]
        , -- adapted: a handler is the checkbox state plus the transition it
          -- performs, and only the transition has a counterpart here.
          describe "column_getToggleVisibilityHandler"
            [ test "should return handler that toggles visibility based on checkbox state" <|
                \_ ->
                    Table.toggleColumnVisibility cfg (columnNamed cfg "firstName") (Just True) state
                        |> .columnVisibility
                        |> Expect.equal (Dict.fromList [ ( "firstName", True ) ])
            ]
        , describe "row_getVisibleCells"
            [ test "should return only visible cells" <|
                \_ ->
                    withFirstRow
                        (\row ->
                            Expect.all
                                [ \ids -> Expect.equal False (List.member "firstName" ids)
                                , \ids ->
                                    Expect.equal
                                        (List.length (Table.getAllCells cfg state row) - 1)
                                        (List.length ids)
                                ]
                                (Table.visibleCells cfg (hiding [ "firstName" ]) row
                                    |> List.map .columnId
                                )
                        )
            ]
        , describe "table_getVisibleFlatColumns"
            [ test "should return only visible flat columns" <|
                \_ ->
                    let
                        ids : List String
                        ids =
                            Table.visibleFlatColumns cfg (hiding [ "firstName" ])
                                |> List.map Table.columnId
                    in
                    Expect.all
                        [ \found -> Expect.equal False (List.member "firstName" found)
                        , \found ->
                            Expect.equal
                                (List.length (Table.allColumns cfg) - 1)
                                (List.length found)
                        ]
                        ids
            ]
        , describe "table_getVisibleLeafColumns"
            [ test "should return only visible leaf columns" <|
                \_ ->
                    let
                        ids : List String
                        ids =
                            Table.visibleLeafColumns cfg (hiding [ "firstName" ])
                                |> List.map Table.columnId
                    in
                    Expect.all
                        [ \found -> Expect.equal False (List.member "firstName" found)
                        , \found -> Expect.equal (List.length (leafIds cfg) - 1) (List.length found)
                        ]
                        ids
            ]
        , describe "table_setColumnVisibility"
            [ test "should call onColumnVisibilityChange with updater" <|
                \_ ->
                    Table.setColumnVisibility (Dict.fromList [ ( "firstName", False ) ]) state
                        |> .columnVisibility
                        |> Expect.equal (Dict.fromList [ ( "firstName", False ) ])
            ]
        , describe "table_resetColumnVisibility"
            [ test "should reset to empty state when defaultState is true" <|
                \_ ->
                    Table.resetColumnVisibility (hiding [ "firstName" ])
                        |> .columnVisibility
                        |> Expect.equal Dict.empty
            , test "should reset to initial state when defaultState is false" <|
                \_ ->
                    let
                        initial : Dict.Dict String Bool
                        initial =
                            Dict.fromList [ ( "firstName", False ) ]
                    in
                    Table.setColumnVisibility initial state
                        |> .columnVisibility
                        |> Expect.equal initial
            ]
        , describe "table_toggleAllColumnsVisible"
            [ test "should show all columns when value is true" <|
                \_ ->
                    Table.toggleAllColumnsVisible cfg (Just True) state
                        |> .columnVisibility
                        |> Expect.equal (Dict.fromList (List.map (\columnId -> ( columnId, True )) (leafIds cfg)))
            , test "should hide all columns that can be hidden when value is false" <|
                \_ ->
                    Table.toggleAllColumnsVisible cfg (Just False) state
                        |> .columnVisibility
                        |> Expect.equal (Dict.fromList (List.map (\columnId -> ( columnId, False )) (leafIds cfg)))
            ]
        , -- adapted: the handler is `toggleAllColumnsVisible` with the
          -- checkbox value; the event shape is dropped.
          describe "table_getToggleAllColumnsVisibilityHandler"
            [ test "should return handler that toggles all columns visibility based on checkbox state" <|
                \_ ->
                    Table.toggleAllColumnsVisible cfg (Just True) state
                        |> .columnVisibility
                        |> Expect.equal
                            (Dict.fromList (List.map (\columnId -> ( columnId, True )) (leafIds cfg)))
            ]
        , describe "table_getIsAllColumnsVisible"
            [ test "should return true when all columns are visible" <|
                \_ ->
                    Table.isAllColumnsVisible cfg state |> Expect.equal True
            , test "should return false when some columns are hidden" <|
                \_ ->
                    Table.isAllColumnsVisible cfg (hiding [ "firstName" ]) |> Expect.equal False
            ]
        , describe "table_getIsSomeColumnsVisible"
            [ test "should return true when some columns are visible" <|
                \_ ->
                    Table.isSomeColumnsVisible cfg (hiding [ "firstName" ]) |> Expect.equal True
            , test "should return false when no columns are visible" <|
                \_ ->
                    Table.isSomeColumnsVisible cfg (hiding (leafIds cfg)) |> Expect.equal False
            ]
        , describe "row_getVisibleCellsByColumnId"
            [ test "should key only visible cells by column id" <|
                \_ ->
                    withFirstRow
                        (\row ->
                            Expect.all
                                [ \cells -> Expect.equal Nothing (Dict.get "firstName" cells)
                                , \cells ->
                                    Expect.equal (Just "lastName")
                                        (Dict.get "lastName" cells |> Maybe.map .columnId)
                                , \cells ->
                                    Expect.equal
                                        (List.sort (List.map .columnId (Table.visibleCells cfg (hiding [ "firstName" ]) row)))
                                        (Dict.keys cells)
                                ]
                                (Table.visibleCellsByColumnId cfg (hiding [ "firstName" ]) row)
                        )
            ]
        ]
