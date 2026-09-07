module Cells exposing (..)

import Dict
import Html exposing (Html, td, text, tr)
import Html.Attributes exposing (class)
import Shared.People exposing (Person)
import Table
import Table.Value as Value


config : Table.Config Person
config =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First name"
        , Table.column "salary" (.salary >> Value.Number)
            |> Table.withHeader "Salary"
        , Table.column "active" (.active >> Value.Bool)
            |> Table.withHeader "Active"
        ]
        |> Table.withGetRowId (\person _ _ -> person.id)


viewRow : Table.State -> Table.Row Person -> Html msg
viewRow state row =
    tr [] (List.map viewCell (Table.visibleCells config state row))


viewCell : Table.Cell -> Html msg
viewCell cell =
    td [ class ("cell-" ++ cell.columnId) ] [ text (Value.toString cell.value) ]


viewTypedCell : Table.Cell -> Html msg
viewTypedCell cell =
    case cell.value of
        Value.Number n ->
            td [ class "numeric" ] [ text (String.fromFloat n) ]

        Value.Bool True ->
            td [] [ text "yes" ]

        Value.Bool False ->
            td [] [ text "no" ]

        other ->
            td [] [ text (Value.toString other) ]


salaryCell : Table.State -> Table.Row Person -> Maybe Table.Cell
salaryCell state row =
    Dict.get "salary" (Table.visibleCellsByColumnId config state row)


allCellIds : Table.State -> Table.Row Person -> List String
allCellIds state row =
    List.map .id (Table.getAllCells config state row)


viewPinnedRow : Table.State -> Table.Row Person -> Html msg
viewPinnedRow state row =
    tr []
        (List.map viewCell (Table.leftVisibleCells config state row)
            ++ List.map viewCell (Table.centerVisibleCells config state row)
            ++ List.map viewCell (Table.rightVisibleCells config state row)
        )
