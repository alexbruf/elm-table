module ColumnVisibility exposing (..)

import Dict
import Html exposing (Html, div, input, label, td, text, tr)
import Html.Attributes exposing (checked, disabled, type_)
import Html.Events exposing (onClick)
import Shared.People exposing (Person)
import Table
import Table.Value as Value


config : Table.Config Person
config =
    Table.config
        [ Table.column "id" (.id >> Value.String)
            |> Table.withHeader "ID"
            |> Table.withEnableHiding False
        , Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First name"
        , Table.column "lastName" (.lastName >> Value.String)
            |> Table.withHeader "Last name"
        , Table.column "department" (.department >> Value.String)
            |> Table.withHeader "Department"
        ]


type alias Model =
    { state : Table.State }


type Msg
    = ToggleColumn (Table.Column Person)
    | ToggleAll Bool
    | ResetVisibility


update : Msg -> Model -> Model
update msg model =
    case msg of
        ToggleColumn column ->
            { model | state = Table.toggleColumnVisibility config column Nothing model.state }

        ToggleAll visible ->
            { model | state = Table.toggleAllColumnsVisible config (Just visible) model.state }

        ResetVisibility ->
            { model | state = Table.resetColumnVisibility model.state }


startHidden : Table.State
startHidden =
    Table.setColumnVisibility
        (Dict.fromList [ ( "department", False ) ])
        Table.initialState


viewToggles : Table.State -> Html Msg
viewToggles state =
    div []
        (viewToggleAll state :: List.map (viewToggle state) (Table.allColumns config))


viewToggleAll : Table.State -> Html Msg
viewToggleAll state =
    label []
        [ input
            [ type_ "checkbox"
            , checked (Table.isAllColumnsVisible config state)
            , onClick (ToggleAll (not (Table.isSomeColumnsVisible config state)))
            ]
            []
        , text "Toggle all"
        ]


viewToggle : Table.State -> Table.Column Person -> Html Msg
viewToggle state column =
    label []
        [ input
            [ type_ "checkbox"
            , checked (Table.columnIsVisible state column)
            , disabled (not (Table.columnCanHide config column))
            , onClick (ToggleColumn column)
            ]
            []
        , text (Maybe.withDefault (Table.columnId column) (Table.columnHeader column))
        ]


viewRow : Table.State -> Table.Row Person -> Html Msg
viewRow state row =
    tr []
        (List.map
            (\cell -> td [] [ text (Value.toString cell.value) ])
            (Table.visibleCells config state row)
        )
