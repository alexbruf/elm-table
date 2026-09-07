module QuickStart exposing (Model, Msg(..), columns, config, init, main, rowModel, update, view, viewCell, viewHeader, viewRow)

import Browser
import Html exposing (Html, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)
import Shared.People exposing (Person, people)
import Table
import Table.Value as Value


columns : List (Table.Column Person)
columns =
    [ Table.column "firstName" (.firstName >> Value.String)
        |> Table.withHeader "First name"
    , Table.column "lastName" (.lastName >> Value.String)
        |> Table.withHeader "Last name"
    , Table.column "age" (.age >> toFloat >> Value.Number)
        |> Table.withHeader "Age"
    ]


config : Table.Config Person
config =
    Table.config columns
        |> Table.withGetRowId (\person _ _ -> person.id)


type alias Model =
    { state : Table.State }


init : Model
init =
    { state = Table.initialState }


rowModel : Table.State -> Table.RowModel Person
rowModel state =
    Table.rowsFromList config state people


type Msg
    = SortBy String


update : Msg -> Model -> Model
update msg model =
    case msg of
        SortBy columnId ->
            { model
                | state =
                    Table.toggleSort config
                        (rowModel model.state)
                        columnId
                        { desc = Nothing, multi = False }
                        model.state
            }


view : Model -> Html Msg
view model =
    let
        current =
            rowModel model.state
    in
    table []
        [ thead []
            [ tr [] (List.map (viewHeader model.state) (Table.visibleLeafColumns config model.state)) ]
        , tbody []
            (List.map (viewRow model.state) (Table.rowsInDisplayOrder config model.state current))
        ]


viewHeader : Table.State -> Table.Column Person -> Html Msg
viewHeader state column =
    let
        id =
            Table.columnId column

        arrow =
            case Table.getIsSorted state id of
                Nothing ->
                    ""

                Just dir ->
                    if dir == Table.sortAsc then
                        " ↑"

                    else
                        " ↓"
    in
    th [ onClick (SortBy id), style "cursor" "pointer" ]
        [ text (Maybe.withDefault id (Table.columnHeader column) ++ arrow) ]


viewRow : Table.State -> Table.Row Person -> Html Msg
viewRow state row =
    tr [] (List.map (viewCell row) (Table.visibleLeafColumns config state))


viewCell : Table.Row Person -> Table.Column Person -> Html Msg
viewCell row column =
    td [] [ text (Value.toString (Table.getValue config row (Table.columnId column))) ]


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
