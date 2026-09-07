module Columns exposing (..)

import Html exposing (Html, input, label, li, text, ul)
import Html.Attributes exposing (checked, type_)
import Html.Events exposing (onClick)
import Shared.People exposing (Person)
import Table
import Table.Value as Value


type Msg
    = ToggleColumn (Table.Column Person)


config : Table.Config Person
config =
    Table.config
        [ Table.display "select"
        , Table.group "name"
            [ Table.column "firstName" (.firstName >> Value.String)
                |> Table.withHeader "First"
            , Table.column "lastName" (.lastName >> Value.String)
                |> Table.withHeader "Last"
            ]
            |> Table.withHeader "Name"
        , Table.column "salary" (.salary >> Value.Number)
            |> Table.withHeader "Salary"
            |> Table.withSize 120
        ]


columnLabel : Table.Column Person -> String
columnLabel col =
    Maybe.withDefault (Table.columnId col) (Table.columnHeader col)


columnTree : List String
columnTree =
    Table.allColumns config
        |> List.map (\col -> String.repeat (Table.columnDepth col) "  " ++ columnLabel col)


leafIds : List String
leafIds =
    List.map Table.columnId (Table.leafColumns config)


renderedColumns : Table.State -> List (Table.Column Person)
renderedColumns state =
    Table.visibleLeafColumns config state


childLabels : Table.Column Person -> List String
childLabels col =
    List.map columnLabel (Table.columnColumns col)


coveredLeafIds : Table.Column Person -> List String
coveredLeafIds col =
    List.map Table.columnId (Table.columnLeafColumns col)


salaryWidth : Float
salaryWidth =
    Table.findColumn config "salary"
        |> Maybe.map (Table.columnSize config)
        |> Maybe.withDefault 0


hasAccessor : Table.Column Person -> Bool
hasAccessor col =
    Table.columnAccessor col /= Nothing


parentLabel : Table.Column Person -> String
parentLabel col =
    Table.columnParentId col
        |> Maybe.andThen (Table.findColumn config)
        |> Maybe.map columnLabel
        |> Maybe.withDefault "(top level)"


orderedLeafColumns : Table.State -> List (Table.Column Person)
orderedLeafColumns state =
    Table.leafColumns config
        |> Table.orderColumns config state


groupedFirst : Table.State -> List (Table.Column Person)
groupedFirst state =
    Table.leafColumns config
        |> Table.orderGroupedColumns config state


viewColumnMenu : Table.State -> Html Msg
viewColumnMenu state =
    ul []
        (Table.allColumns config
            |> List.map
                (\col ->
                    li []
                        [ label []
                            [ input
                                [ type_ "checkbox"
                                , checked (Table.columnIsVisible state col)
                                , onClick (ToggleColumn col)
                                ]
                                []
                            , text (columnLabel col)
                            ]
                        ]
                )
        )
