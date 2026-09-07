module ColumnPinning exposing (..)

import Html exposing (Html, button, span, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class)
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
        , Table.column "department" (.department >> Value.String)
            |> Table.withHeader "Department"
        , Table.column "actions" (\_ -> Value.Null)
            |> Table.withHeader "Actions"
            |> Table.withEnablePinning False
        ]


type alias Model =
    { state : Table.State }


type Msg
    = Pin Table.ColumnPinPosition (Table.Column Person)
    | ClearPinning


update : Msg -> Model -> Model
update msg model =
    case msg of
        Pin position column ->
            { model | state = Table.pinColumn position column model.state }

        ClearPinning ->
            { model | state = Table.resetColumnPinning model.state }


pinnedByDefault : Table.State
pinnedByDefault =
    Table.setColumnPinning
        { left = [ "firstName" ], right = [ "actions" ] }
        Table.initialState


pinControls : Table.State -> Table.Column Person -> Html Msg
pinControls state column =
    if not (Table.columnCanPin config column) then
        text ""

    else if Table.columnIsPinned state column == Table.columnUnpinned then
        span []
            [ button [ onClick (Pin Table.pinnedLeft column) ] [ text "Pin left" ]
            , button [ onClick (Pin Table.pinnedRight column) ] [ text "Pin right" ]
            ]

    else
        button [ onClick (Pin Table.columnUnpinned column) ] [ text "Unpin" ]


viewRow : Table.State -> Table.Row Person -> Html Msg
viewRow state row =
    tr []
        (List.map (viewCell "pinned-left") (Table.leftVisibleCells config state row)
            ++ List.map (viewCell "unpinned") (Table.centerVisibleCells config state row)
            ++ List.map (viewCell "pinned-right") (Table.rightVisibleCells config state row)
        )


viewCell : String -> Table.Cell -> Html Msg
viewCell region cell =
    td [ class region ] [ text (Value.toString cell.value) ]


viewLeftTable : Table.State -> Table.RowModel Person -> Html Msg
viewLeftTable state model =
    table []
        [ thead []
            (List.map viewHeaderRow (Table.leftHeaderGroups config state))
        , tbody []
            (List.map
                (\row -> tr [] (List.map (viewCell "pinned-left") (Table.leftVisibleCells config state row)))
                (Table.rowsInDisplayOrder config state model)
            )
        ]


viewHeaderRow : Table.HeaderGroup Person -> Html Msg
viewHeaderRow group =
    tr [] (List.map (\header -> th [] [ text (Table.headerColumnId header) ]) group.headers)
