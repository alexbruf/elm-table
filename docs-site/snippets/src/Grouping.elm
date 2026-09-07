module Grouping exposing (..)

import Html exposing (Html)
import Html.Events exposing (onClick)
import Shared.People exposing (Person, people)
import Table
import Table.AggregationFn as AggregationFn
import Table.Value as Value


columns : List (Table.Column Person)
columns =
    [ Table.column "department" (.department >> Value.String)
        |> Table.withHeader "Department"
    , Table.column "lastName" (.lastName >> Value.String)
        |> Table.withHeader "Last name"
        |> Table.withEnableGrouping False
    , Table.column "salary" (.salary >> Value.Number)
        |> Table.withHeader "Salary"
        |> Table.withAggregationFn AggregationFn.sum
    , Table.column "age" (.age >> toFloat >> Value.Number)
        |> Table.withHeader "Age"
        |> Table.withAggregationFn AggregationFn.mean
    ]


config : Table.Config Person
config =
    let
        base : Table.Config Person
        base =
            Table.config columns
                |> Table.withGetRowId (\person _ _ -> person.id)
    in
    { base | groupedColumnMode = Table.groupedColumnsReorder }


ageBand : Table.Column Person
ageBand =
    Table.column "age" (.age >> toFloat >> Value.Number)
        |> Table.withHeader "Age"
        |> Table.withGetGroupingValue
            (\person _ -> Value.String (String.fromInt (person.age // 10 * 10) ++ "s"))


type Msg
    = GroupToggled String
    | GroupingCleared
    | ExpandToggled String


update : Table.RowModel Person -> Msg -> Table.State -> Table.State
update model msg state =
    case msg of
        GroupToggled columnId ->
            if Table.getCanGroup config columnId then
                Table.toggleGrouping columnId state

            else
                state

        GroupingCleared ->
            Table.resetGrouping state

        ExpandToggled rowId ->
            case Table.findRow model rowId of
                Just row ->
                    Table.toggleExpanded config model row Nothing state

                Nothing ->
                    state


groupByDepartmentThenAge : Table.State -> Table.State
groupByDepartmentThenAge =
    Table.setGrouping [ "department", "age" ]


viewBody : Table.State -> Table.RowModel Person -> Html Msg
viewBody state model =
    Html.tbody []
        (List.map (viewRow state) (Table.rowsInDisplayOrder config state model))


viewRow : Table.State -> Table.Row Person -> Html Msg
viewRow state row =
    Html.tr []
        (List.map (viewCell state row) (Table.visibleLeafColumns config state))


viewCell : Table.State -> Table.Row Person -> Table.Column Person -> Html Msg
viewCell state row column =
    let
        columnId : String
        columnId =
            Table.columnId column
    in
    if Table.cellIsGrouped state row columnId then
        Html.td []
            [ Html.button [ onClick (ExpandToggled (Table.rowId row)) ]
                [ Html.text
                    (if Table.getIsExpanded config state row then
                        "-"

                     else
                        "+"
                    )
                ]
            , Html.text (Value.toString (Table.rowGroupingValue row))
            , Html.text (" (" ++ String.fromInt (List.length (Table.rowLeafRows row)) ++ ")")
            ]

    else if Table.cellIsPlaceholder state row columnId then
        Html.td [] []

    else
        Html.td [] [ Html.text (Value.toString (Table.getValue config row columnId)) ]


groupedModel : Table.State -> Table.RowModel Person
groupedModel state =
    Table.preGroupedRowModel config state (Table.coreRowModelFromList config state people)
        |> Table.groupedRowModel config state


headerColumns : Table.State -> List (Table.Column Person)
headerColumns state =
    Table.orderGroupedColumns config state (Table.leafColumns config)
