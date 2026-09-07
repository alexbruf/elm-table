module ColumnResizing exposing (..)

import Browser.Events
import Html exposing (Html, div)
import Html.Attributes exposing (style)
import Html.Events
import Json.Decode as Decode
import Shared.People exposing (Person)
import Table
import Table.Value as Value


config : Table.Config Person
config =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First name"
            |> Table.withMinSize 60
        , Table.column "lastName" (.lastName >> Value.String)
            |> Table.withHeader "Last name"
            |> Table.withMinSize 60
        ]


type alias Drag =
    { columnId : String
    , startX : Float
    , startWidth : Float
    }


type alias Model =
    { state : Table.State
    , drag : Maybe Drag
    }


type Msg
    = ResizeStarted String Float
    | ResizeMoved Float
    | ResizeEnded


update : Msg -> Model -> Model
update msg model =
    case ( msg, model.drag ) of
        ( ResizeStarted columnId x, _ ) ->
            { model
                | drag =
                    Just
                        { columnId = columnId
                        , startX = x
                        , startWidth = currentWidth model.state columnId
                        }
            }

        ( ResizeMoved x, Just drag ) ->
            { model
                | state =
                    Table.setColumnSize drag.columnId
                        (drag.startWidth + x - drag.startX)
                        model.state
            }

        ( ResizeMoved _, Nothing ) ->
            model

        ( ResizeEnded, _ ) ->
            { model | drag = Nothing }


currentWidth : Table.State -> String -> Float
currentWidth state columnId =
    Table.allColumns config
        |> List.filter (\column -> Table.columnId column == columnId)
        |> List.head
        |> Maybe.map (Table.getColumnSize config state)
        |> Maybe.withDefault 0


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.drag of
        Nothing ->
            Sub.none

        Just _ ->
            Sub.batch
                [ Browser.Events.onMouseMove (Decode.map ResizeMoved clientX)
                , Browser.Events.onMouseUp (Decode.succeed ResizeEnded)
                ]


clientX : Decode.Decoder Float
clientX =
    Decode.field "clientX" Decode.float


resizeHandle : String -> Html Msg
resizeHandle columnId =
    div
        [ style "position" "absolute"
        , style "right" "0"
        , style "top" "0"
        , style "height" "100%"
        , style "width" "5px"
        , style "cursor" "col-resize"
        , Html.Events.on "mousedown" (Decode.map (ResizeStarted columnId) clientX)
        ]
        []
