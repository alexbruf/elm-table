module ColumnOrdering exposing (..)

import Html exposing (Html, text, th)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)
import Shared.People exposing (Person)
import Table
import Table.Value as Value


config : Table.Config Person
config =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First name"
        , Table.column "lastName" (.lastName >> Value.String)
            |> Table.withHeader "Last name"
        , Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
        ]


type alias Model =
    { state : Table.State }


type Msg
    = SetOrder (List String)
    | ResetOrder
    | MoveEarlier String


update : Msg -> Model -> Model
update msg model =
    case msg of
        SetOrder order ->
            { model | state = Table.setColumnOrder order model.state }

        ResetOrder ->
            { model | state = Table.resetColumnOrder model.state }

        MoveEarlier columnId ->
            { model
                | state =
                    Table.setColumnOrder
                        (swapEarlier columnId (renderedOrder model.state))
                        model.state
            }


renderedOrder : Table.State -> List String
renderedOrder state =
    Table.orderColumns config state (Table.allColumns config)
        |> List.map Table.columnId


swapEarlier : String -> List String -> List String
swapEarlier columnId order =
    case order of
        first :: second :: rest ->
            if second == columnId then
                second :: first :: rest

            else
                first :: swapEarlier columnId (second :: rest)

        _ ->
            order


viewHeaderCell : Table.State -> Table.Column Person -> Html Msg
viewHeaderCell state column =
    let
        id : String
        id =
            Table.columnId column
    in
    th
        [ onClick (MoveEarlier id)
        , style "border-left"
            (if Table.columnIsFirst config state Table.allColumnsRegion column then
                "none"

             else
                "1px solid #ddd"
            )
        ]
        [ text (Maybe.withDefault id (Table.columnHeader column)) ]


positionLabel : Table.State -> Table.Column Person -> String
positionLabel state column =
    String.fromInt (Table.columnIndex config state Table.centerColumnsRegion column)
        ++ (if Table.columnIsLast config state Table.centerColumnsRegion column then
                " (last)"

            else
                ""
           )
