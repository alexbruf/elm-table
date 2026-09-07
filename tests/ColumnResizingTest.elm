module ColumnResizingTest exposing (suite)

{-| Ports
`tests/unit/features/column-resizing/columnResizingFeature.utils.test.ts`.

TanStack drives the whole feature through the closure
`header_getResizeHandler` returns, so its `header_getResizeHandler` cases are
ported against the three transitions this package splits that closure into:
`startColumnResize`, `updateColumnResize`, `endColumnResize`, each given the
`clientX` of the event the vitest case dispatches. The cases that only assert
event plumbing - listener registration and removal, `requestAnimationFrame`
coalescing, multi-touch filtering, passive listener support - are excluded
and listed in `reports/column-resizing.md`.

The last block holds cases with no vitest counterpart, for the paths the
vitest file never exercises.

-}

import Dict
import Expect
import Fixtures exposing (Person)
import Table
import Table.Value as Value
import Test exposing (Test, describe, test)



-- FIXTURES


{-| `makeTable(1)`: the generated `Person` columns, every one at the default
size of 150. TanStack's resizing tests exercise `onChange` mode unless they
say otherwise; the package default is `resizeOnEnd`, as in TanStack.
-}
config : Table.Config Person
config =
    onChangeMode Fixtures.config


state : Table.State
state =
    Table.initialState


defaultResizing : Table.ColumnResizingState
defaultResizing =
    { columnSizingStart = []
    , deltaOffset = Nothing
    , deltaPercentage = Nothing
    , isResizingColumn = Nothing
    , startOffset = Nothing
    , startSize = Nothing
    }


resizingFirstName : Table.ColumnResizingState
resizingFirstName =
    { defaultResizing | isResizingColumn = Just "firstName" }


{-| The zero-width column of the two "startSize is zero" cases: the vitest
fake reports `getSize: () => 0` for both the header and its leaf column.
-}
zeroWidth : Table.Config Person
zeroWidth =
    onChangeMode
        (Table.config
            [ Table.column "firstName" (.firstName >> Value.String)
                |> Table.withSize 0
                |> Table.withMinSize 0
            ]
        )


{-| Commit sizes on every move, as TanStack's tests expect.
-}
onChangeMode : Table.Config Person -> Table.Config Person
onChangeMode cfg =
    { cfg | columnResizeMode = Table.resizeOnChange }


columnNamed : Table.Config Person -> String -> Table.Column Person
columnNamed cfg columnId =
    Table.findColumn cfg columnId
        |> Maybe.withDefault (Table.display "missing")


{-| Run an assertion against a leaf header, which is what a resize handle
sits on.
-}
onHeader : Table.Config Person -> String -> (Table.Header Person -> Expect.Expectation) -> Expect.Expectation
onHeader cfg columnId assert =
    case List.filter (\h -> Table.headerColumnId h == columnId) (Table.leafHeaders cfg state) of
        header :: _ ->
            assert header

        [] ->
            Expect.fail ("no header for column " ++ columnId)


sizeOf : Table.State -> String -> Maybe Float
sizeOf current columnId =
    Dict.get columnId current.columnSizing



-- SUITE


suite : Test
suite =
    describe "columnResizingFeature.utils"
        [ describe "getDefaultColumnResizingState"
            [ test "should return default column resizing state" <|
                \_ ->
                    Expect.equal Table.initialState.columnResizing
                        { columnSizingStart = []
                        , deltaOffset = Nothing
                        , deltaPercentage = Nothing
                        , isResizingColumn = Nothing
                        , startOffset = Nothing
                        , startSize = Nothing
                        }
            ]
        , describe "column_getCanResize"
            [ test "should return true when column resizing is enabled" <|
                \_ ->
                    Table.columnCanResize config (columnNamed config "firstName")
                        |> Expect.equal True
            , test "should return false when column resizing is disabled globally" <|
                \_ ->
                    Table.columnCanResize { config | enableColumnResizing = False }
                        (columnNamed config "firstName")
                        |> Expect.equal False
            , test "should return false when column resizing is disabled for specific column" <|
                \_ ->
                    let
                        cfg : Table.Config Person
                        cfg =
                            Table.config
                                [ Table.column "firstName" (.firstName >> Value.String)
                                    |> Table.withEnableResizing False
                                ]
                    in
                    Table.columnCanResize cfg (columnNamed cfg "firstName")
                        |> Expect.equal False
            ]
        , describe "column_getIsResizing"
            [ test "should return true when column is being resized" <|
                \_ ->
                    Table.columnIsResizing { state | columnResizing = resizingFirstName }
                        (columnNamed config "firstName")
                        |> Expect.equal True
            , test "should return false when column is not being resized" <|
                \_ ->
                    Table.columnIsResizing state (columnNamed config "firstName")
                        |> Expect.equal False
            ]
        , describe "table_setColumnResizing"
            [ test "should call onColumnResizingChange with updater" <|
                \_ ->
                    let
                        newState : Table.ColumnResizingState
                        newState =
                            { columnSizingStart = []
                            , deltaOffset = Just 50
                            , deltaPercentage = Just 0.25
                            , isResizingColumn = Just "firstName"
                            , startOffset = Just 100
                            , startSize = Just 200
                            }
                    in
                    Table.setColumnResizing newState state
                        |> .columnResizing
                        |> Expect.equal newState
            ]
        , describe "table_resetHeaderSizeInfo"
            [ test "should reset to default state when defaultState is true" <|
                \_ ->
                    Table.resetColumnResizing { state | columnResizing = resizingFirstName }
                        |> .columnResizing
                        |> Expect.equal defaultResizing
            , test "should reset to initial state when defaultState is false" <|
                \_ ->
                    let
                        initial : Table.ColumnResizingState
                        initial =
                            { columnSizingStart = []
                            , deltaOffset = Just 50
                            , deltaPercentage = Just 0.25
                            , isResizingColumn = Just "firstName"
                            , startOffset = Just 100
                            , startSize = Just 200
                            }
                    in
                    Table.setColumnResizing initial { state | columnResizing = defaultResizing }
                        |> .columnResizing
                        |> Expect.equal initial
            ]
        , describe "header_getResizeHandler"
            [ test "should not resize when column resizing is disabled" <|
                \_ ->
                    let
                        cfg : Table.Config Person
                        cfg =
                            { config | enableColumnResizing = False }
                    in
                    onHeader cfg "firstName" <|
                        \header ->
                            Table.startColumnResize cfg state header 100
                                |> .columnResizing
                                |> Expect.equal defaultResizing
            , test "should update immediately in onChange mode" <|
                \_ ->
                    onHeader config "firstName" <|
                        \header ->
                            Table.startColumnResize config state header 100
                                |> Table.updateColumnResize config 150
                                |> (\next -> sizeOf next "firstName")
                                |> Expect.equal (Just 200)
            , test "should allow resizing a column from zero width" <|
                \_ ->
                    onHeader zeroWidth "firstName" <|
                        \header ->
                            let
                                moved : Table.State
                                moved =
                                    Table.startColumnResize zeroWidth state header 100
                                        |> Table.updateColumnResize zeroWidth 150
                            in
                            case sizeOf moved "firstName" of
                                Just size ->
                                    Expect.greaterThan 0 size

                                Nothing ->
                                    Expect.fail "no committed size for firstName"
            , test "should not produce NaN when startSize is zero" <|
                \_ ->
                    onHeader zeroWidth "firstName" <|
                        \header ->
                            Table.startColumnResize zeroWidth state header 100
                                |> Table.updateColumnResize zeroWidth 150
                                |> .columnResizing
                                |> .deltaPercentage
                                |> Expect.equal (Just 0)
            , test "should cancel a pending coalesced move on mouse up and commit the end position" <|
                \_ ->
                    onHeader config "firstName" <|
                        \header ->
                            Table.startColumnResize config state header 100
                                |> Table.updateColumnResize config 110
                                |> Table.updateColumnResize config 120
                                |> Table.updateColumnResize config 150
                                |> Table.endColumnResize config
                                |> (\next -> sizeOf next "firstName")
                                |> Expect.equal (Just 200)
            , test "should not commit sizing on move ticks in onEnd mode, only at drag end" <|
                \_ ->
                    let
                        cfg : Table.Config Person
                        cfg =
                            { config | columnResizeMode = Table.resizeOnEnd }
                    in
                    onHeader cfg "firstName" <|
                        \header ->
                            let
                                moved : Table.State
                                moved =
                                    Table.startColumnResize cfg state header 100
                                        |> Table.updateColumnResize cfg 140

                                ended : Table.State
                                ended =
                                    Table.updateColumnResize cfg 150 moved
                                        |> Table.endColumnResize cfg
                            in
                            Expect.equal
                                { committedDuringMove = moved.columnSizing
                                , deltaOffset = moved.columnResizing.deltaOffset
                                , committedAtEnd = sizeOf ended "firstName"
                                , isResizingColumn = ended.columnResizing.isResizingColumn
                                }
                                { committedDuringMove = Dict.empty
                                , deltaOffset = Just 40
                                , committedAtEnd = Just 200
                                , isResizingColumn = Nothing
                                }
            , test "should cleanup event listeners and reset state on touchcancel" <|
                \_ ->
                    onHeader config "firstName" <|
                        \header ->
                            let
                                ended : Table.State
                                ended =
                                    Table.startColumnResize config state header 100
                                        |> Table.updateColumnResize config 150
                                        |> Table.endColumnResize config

                                afterCancel : Table.State
                                afterCancel =
                                    Table.updateColumnResize config 300 ended
                            in
                            Expect.equal
                                { isResizingColumn = ended.columnResizing.isResizingColumn
                                , committed = sizeOf ended "firstName"
                                , afterCancel = sizeOf afterCancel "firstName"
                                }
                                { isResizingColumn = Nothing
                                , committed = Just 200
                                , afterCancel = Just 200
                                }
            ]
        , describe "elm-table additions"
            [ test "startColumnResize records the starting offset, size and leaf sizes" <|
                \_ ->
                    onHeader config "firstName" <|
                        \header ->
                            Table.startColumnResize config state header 100
                                |> .columnResizing
                                |> Expect.equal
                                    { columnSizingStart = [ ( "firstName", 150 ) ]
                                    , deltaOffset = Just 0
                                    , deltaPercentage = Just 0
                                    , isResizingColumn = Just "firstName"
                                    , startOffset = Just 100
                                    , startSize = Just 150
                                    }
            , test "an rtl drag counts leftward movement as growth" <|
                \_ ->
                    let
                        cfg : Table.Config Person
                        cfg =
                            { config | columnResizeDirection = Table.resizeRtl }
                    in
                    onHeader cfg "firstName" <|
                        \header ->
                            let
                                moved : Table.State
                                moved =
                                    Table.startColumnResize cfg state header 100
                                        |> Table.updateColumnResize cfg 50
                            in
                            Expect.equal
                                { deltaOffset = moved.columnResizing.deltaOffset
                                , size = sizeOf moved "firstName"
                                }
                                { deltaOffset = Just 50
                                , size = Just 200
                                }
            , test "a drag past the left edge is floored at -0.999999 of the starting width" <|
                \_ ->
                    onHeader config "firstName" <|
                        \header ->
                            let
                                moved : Table.State
                                moved =
                                    Table.startColumnResize config state header 1000
                                        |> Table.updateColumnResize config 0
                            in
                            Expect.equal
                                { deltaPercentage = moved.columnResizing.deltaPercentage
                                , size = sizeOf moved "firstName"
                                }
                                { deltaPercentage = Just -0.999999
                                , size = Just 0
                                }
            , test "resizing a group header resizes every leaf under it" <|
                \_ ->
                    let
                        cfg : Table.Config Person
                        cfg =
                            onChangeMode
                                (Table.config
                                    [ Table.group "name"
                                        [ Table.column "firstName" (.firstName >> Value.String)
                                        , Table.column "lastName" (.lastName >> Value.String)
                                        ]
                                    ]
                                )

                        groupHeader : List (Table.Header Person)
                        groupHeader =
                            Table.headerGroups cfg state
                                |> List.concatMap .headers
                                |> List.filter (\h -> Table.headerColumnId h == "name")
                    in
                    case groupHeader of
                        header :: _ ->
                            let
                                moved : Table.State
                                moved =
                                    Table.startColumnResize cfg state header 100
                                        |> Table.updateColumnResize cfg 250
                            in
                            Expect.equal
                                { startSize = moved.columnResizing.startSize
                                , firstName = sizeOf moved "firstName"
                                , lastName = sizeOf moved "lastName"
                                }
                                { startSize = Just 300
                                , firstName = Just 225
                                , lastName = Just 225
                                }

                        [] ->
                            Expect.fail "no header for column name"
            , test "headerCanResize and headerIsResizing follow the header's column" <|
                \_ ->
                    onHeader config "firstName" <|
                        \header ->
                            Expect.equal
                                { canResize = Table.headerCanResize config header
                                , canResizeDisabled = Table.headerCanResize { config | enableColumnResizing = False } header
                                , isResizing = Table.headerIsResizing { state | columnResizing = resizingFirstName } header
                                , isNotResizing = Table.headerIsResizing state header
                                }
                                { canResize = True
                                , canResizeDisabled = False
                                , isResizing = True
                                , isNotResizing = False
                                }
            ]
        ]
