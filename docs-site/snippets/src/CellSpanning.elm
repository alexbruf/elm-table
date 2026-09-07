module CellSpanning exposing (..)

import Dict
import Html exposing (Html, tbody, td, text, tr)
import Html.Attributes exposing (colspan, rowspan)
import Shared.People exposing (Person, people)
import Table
import Table.Value as Value


columns : List (Table.Column Person)
columns =
    [ Table.column "department" (.department >> Value.String)
        |> Table.withHeader "Department"
        |> Table.withSpanRows
    , Table.column "firstName" (.firstName >> Value.String)
        |> Table.withHeader "First name"
        |> Table.withSpanColumns summarySpan
    , Table.column "salary" (.salary >> Value.Number)
        |> Table.withHeader "Salary"
        |> Table.withEnableCellSpanning False
    ]


summarySpan : Table.Row Person -> Int
summarySpan row =
    if (Table.rowOriginal row).department == "Summary" then
        Table.spanAllColumns

    else
        1


salaryBandColumn : Table.Column Person
salaryBandColumn =
    Table.column "salary" (.salary >> Value.Number)
        |> Table.withHeader "Salary"
        |> Table.withSpanRowsWhen sameSalaryBand


sameSalaryBand : Table.RowSpanContext Person -> Bool
sameSalaryBand context =
    band context.anchorValue == band context.value


band : Value.Value -> Int
band value =
    floor (Value.toNumber value / 25000)


config : Table.Config Person
config =
    Table.config columns
        |> Table.withGetRowId (\person _ _ -> person.id)


spanningOff : Table.Config Person
spanningOff =
    Table.withCellSpanning False config


viewBody : Table.State -> Html msg
viewBody state =
    let
        rendered : Table.RowModel Person
        rendered =
            Table.rowsFromList config state people

        index : Table.CellSpanIndex
        index =
            Table.cellSpanIndex config state rendered
    in
    tbody [] (List.map (viewRow state index) rendered.rows)


viewRow : Table.State -> Table.CellSpanIndex -> Table.Row Person -> Html msg
viewRow state index row =
    tr [] (List.filterMap (viewCell index) (Table.visibleCells config state row))


viewCell : Table.CellSpanIndex -> Table.Cell -> Maybe (Html msg)
viewCell index cell =
    if Table.cellIsCovered index cell then
        Nothing

    else
        Just
            (td
                [ rowspan (Table.cellRowSpan index cell)
                , colspan (Table.cellColSpan index cell)
                ]
                [ text (Value.toString cell.value) ]
            )


spanningColumnIds : Table.State -> List String
spanningColumnIds state =
    Table.rowsFromList config state people
        |> Table.cellSpanIndex config state
        |> Table.cellSpanIndexRowSpans
        |> Dict.keys
