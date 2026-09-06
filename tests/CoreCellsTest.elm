module CoreCellsTest exposing (suite)

{-| Ports `tests/unit/core/cells/constructCell.test.ts` and
`tests/unit/core/cells/coreCellsFeature.utils.test.ts`.

Excluded cases are listed in `reports/phase-2.md`.

-}

import Expect
import Table
import Table.Value as Value
import Test exposing (Test, describe, test)


type alias Person =
    { firstName : String
    , nickname : Maybe String
    }


config : Table.Config Person
config =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
        , Table.column "nickname"
            (.nickname >> Maybe.map Value.String >> Maybe.withDefault Value.Null)
        ]


cells : List Table.Cell
cells =
    Table.coreRowModelFromList config Table.initialState [ Person "Tanner" Nothing ]
        |> .rows
        |> List.head
        |> Maybe.map (Table.getAllCells config Table.initialState)
        |> Maybe.withDefault []


cell : String -> Maybe Table.Cell
cell columnId =
    cells |> List.filter (\c -> c.columnId == columnId) |> List.head


suite : Test
suite =
    describe "core cells"
        [ describe "constructCell"
            [ test "should populate the cell with all core cell APIs and properties" <|
                \_ ->
                    cell "firstName"
                        |> Expect.equal
                            (Just
                                { id = "0_firstName"
                                , columnId = "firstName"
                                , rowId = "0"
                                , value = Value.String "Tanner"
                                }
                            )
            ]
        , describe "cell_getValue"
            [ test "should read the accessor value for the cell" <|
                \_ ->
                    Expect.equal
                        ( Maybe.map .value (cell "firstName")
                        , Maybe.map .value (cell "nickname")
                        )
                        ( Just (Value.String "Tanner"), Just Value.Null )
            ]
        ]
