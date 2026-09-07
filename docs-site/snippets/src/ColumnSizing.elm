module ColumnSizing exposing (..)

import Dict
import Html exposing (Html, table, text, th)
import Html.Attributes exposing (style)
import Shared.People exposing (Person)
import Table
import Table.Value as Value


config : Table.Config Person
config =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First name"
            |> Table.withSize 220
        , Table.column "lastName" (.lastName >> Value.String)
            |> Table.withHeader "Last name"
        , Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
            |> Table.withMinSize 60
            |> Table.withMaxSize 120
        ]
        |> Table.withDefaultColumn { size = 180, minSize = 40, maxSize = 600 }


type alias Model =
    { state : Table.State }


type Msg
    = SetSize String Float
    | ResetSize String
    | ResetAllSizes


update : Msg -> Model -> Model
update msg model =
    case msg of
        SetSize columnId width ->
            { model | state = Table.setColumnSize columnId width model.state }

        ResetSize columnId ->
            { model | state = Table.resetColumnSize columnId model.state }

        ResetAllSizes ->
            { model | state = Table.resetColumnSizing model.state }


startingWidths : Table.State
startingWidths =
    Table.setColumnSizing
        (Dict.fromList [ ( "firstName", 260 ), ( "age", 80 ) ])
        Table.initialState


px : Float -> String
px n =
    String.fromFloat n ++ "px"


viewHeaderCell : Table.State -> Table.Header Person -> Html Msg
viewHeaderCell state header =
    th
        [ style "width" (px (Table.getHeaderSize config state header)) ]
        [ text (Table.headerColumnId header) ]


viewTable : Table.State -> List (Html Msg) -> Html Msg
viewTable state children =
    table
        [ style "width" (px (Table.totalSize config state))
        , style "table-layout" "fixed"
        ]
        children


stickyLeft : Table.State -> Table.Column Person -> List (Html.Attribute Msg)
stickyLeft state column =
    [ style "position" "sticky"
    , style "left" (px (Table.getColumnStart config state Table.leftColumnsRegion column))
    , style "width" (px (Table.getColumnSize config state column))
    ]


stickyRight : Table.State -> Table.Column Person -> List (Html.Attribute Msg)
stickyRight state column =
    [ style "position" "sticky"
    , style "right" (px (Table.getColumnAfter config state Table.rightColumnsRegion column))
    , style "width" (px (Table.getColumnSize config state column))
    ]
