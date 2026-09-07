module Aggregation exposing (..)

import Html exposing (Html)
import Shared.People exposing (Person, people)
import Table
import Table.AggregationFn as AggregationFn exposing (AggregationFn)
import Table.Value as Value exposing (Value)


columns : List (Table.Column Person)
columns =
    [ Table.column "department" (.department >> Value.String)
        |> Table.withHeader "Department"
    , Table.column "salary" (.salary >> Value.Number)
        |> Table.withHeader "Salary"
        |> Table.withAggregationFn AggregationFn.sum
    , Table.column "age" (.age >> toFloat >> Value.Number)
        |> Table.withHeader "Age"
    , Table.column "active" (.active >> Value.Bool)
        |> Table.withHeader "Active"
        |> Table.withAggregationFn AggregationFn.count
    ]


config : Table.Config Person
config =
    Table.config columns
        |> Table.withGetRowId (\person _ _ -> person.id)


tagList : AggregationFn
tagList =
    AggregationFn.custom
        (\values -> Value.String (String.join ", " (List.map Value.toString values)))


runningTotal : AggregationFn
runningTotal =
    AggregationFn.custom (\values -> Value.Number (sumOf values))
        |> AggregationFn.withMerge (\subResults -> Value.Number (sumOf subResults))


sumOf : List Value -> Float
sumOf values =
    List.sum (List.map Value.toNumber values)


deepestOnly : Table.Column Person
deepestOnly =
    Table.column "salary" (.salary >> Value.Number)
        |> Table.withAggregationFn AggregationFn.sum
        |> Table.withMaxAggregationDepth 1


salaryTotalOfList : List Value -> Value
salaryTotalOfList =
    AggregationFn.aggregate AggregationFn.sum


preGrouped : Table.State -> Table.RowModel Person
preGrouped state =
    Table.preGroupedRowModel config state (Table.coreRowModelFromList config state people)


viewFooter : Table.State -> Html msg
viewFooter state =
    Html.tfoot []
        [ Html.tr []
            (List.map (viewFooterCell (preGrouped state))
                (Table.visibleLeafColumns config state)
            )
        ]


viewFooterCell : Table.RowModel Person -> Table.Column Person -> Html msg
viewFooterCell model column =
    let
        columnId : String
        columnId =
            Table.columnId column
    in
    case Table.getAggregationFn config model columnId of
        Just _ ->
            Html.td [] [ Html.text (Value.toString (Table.aggregationValue config model columnId)) ]

        Nothing ->
            Html.td [] []


selectedTotal : Table.State -> Table.RowModel Person -> Value
selectedTotal state model =
    Table.aggregationValueOf config
        model
        "salary"
        { maxDepth = 0, rows = (Table.selectedRowModel state model).rows }


viewCell : Table.State -> Table.RowModel Person -> Table.Row Person -> String -> Html msg
viewCell state model row columnId =
    if Table.cellIsAggregated config model state row columnId then
        Html.td []
            [ Html.text (Value.toString (Table.getValue config row columnId) ++ " (total)") ]

    else
        Html.td [] [ Html.text (Value.toString (Table.getValue config row columnId)) ]
