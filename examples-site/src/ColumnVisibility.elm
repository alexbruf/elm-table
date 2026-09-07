module ColumnVisibility exposing (main)

{-| Column Visibility.

Ports `examples/react/column-visibility/src/main.tsx` from TanStack Table:
the grouped header/footer table with a "Toggle All" panel and one checkbox
per leaf column.

-}

import Browser
import Html exposing (Html, button, div, input, label, pre, span, table, tbody, td, text, tfoot, th, thead, tr)
import Html.Attributes exposing (checked, class, colspan, type_)
import Html.Events exposing (onCheck, onClick)
import Shared.People as People exposing (Person)
import Shared.StateJson as StateJson
import Table
import Table.Value as Value



-- COLUMNS


config : Table.Config Person
config =
    Table.config
        [ Table.group "Name"
            [ Table.column "firstName" (.firstName >> Value.String)
                |> Table.withFooter "firstName"
            , Table.column "lastName" (.lastName >> maybeString)
                |> Table.withHeader "Last Name"
                |> Table.withFooter "lastName"
            ]
            |> Table.withHeader "Name"
            |> Table.withFooter "Name"
        , Table.group "Info"
            [ Table.column "age" (.age >> toFloat >> Value.Number)
                |> Table.withHeader "Age"
                |> Table.withFooter "age"
            , Table.group "More Info"
                [ Table.column "visits" (.visits >> maybeNumber)
                    |> Table.withHeader "Visits"
                    |> Table.withFooter "visits"
                , Table.column "status" (.status >> People.statusToString >> Value.String)
                    |> Table.withHeader "Status"
                    |> Table.withFooter "status"
                , Table.column "progress" (.progress >> toFloat >> Value.Number)
                    |> Table.withHeader "Profile Progress"
                    |> Table.withFooter "progress"
                ]
                |> Table.withHeader "More Info"
            ]
            |> Table.withHeader "Info"
            |> Table.withFooter "Info"
        ]
        |> Table.withGetRowId (\person _ _ -> person.id)


maybeString : Maybe String -> Value.Value
maybeString =
    Maybe.map Value.String >> Maybe.withDefault Value.Null


maybeNumber : Maybe Int -> Value.Value
maybeNumber =
    Maybe.map (toFloat >> Value.Number) >> Maybe.withDefault Value.Null



-- MODEL


type alias Model =
    { state : Table.State
    , data : List Person
    , seed : Int
    }


init : Model
init =
    { state = Table.initialState
    , data = People.makeData 42 [ 20 ]
    , seed = 42
    }


type Msg
    = RegenerateData
    | StressTest
    | ToggleColumn String Bool
    | ToggleAllColumns Bool


update : Msg -> Model -> Model
update msg model =
    case msg of
        RegenerateData ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 20 ] }

        StressTest ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 1000 ] }

        ToggleColumn columnId visible ->
            case Table.findColumn config columnId of
                Just column ->
                    { model | state = Table.toggleColumnVisibility config column (Just visible) model.state }

                Nothing ->
                    model

        ToggleAllColumns visible ->
            { model | state = Table.toggleAllColumnsVisible config (Just visible) model.state }



-- VIEW


view : Model -> Html Msg
view model =
    let
        rowModel : Table.RowModel Person
        rowModel =
            Table.coreRowModelFromList config model.state model.data
    in
    div [ class "demo-root" ]
        [ div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ]
            , button [ onClick StressTest ] [ text "Stress Test (1k rows)" ]
            ]
        , div [ class "spacer-md" ] []
        , viewColumnToggles model.state
        , div [ class "spacer-md" ] []
        , table []
            [ thead [] (List.map (viewHeaderRow model.state) (Table.headerGroups config model.state))
            , tbody [] (List.map (viewRow model.state) rowModel.rows)
            , tfoot [] (List.map (viewFooterRow model.state) (Table.footerGroups config model.state))
            ]
        , div [ class "spacer-md" ] []
        , div [ class "spacer-md" ] []
        , pre [ class "state-dump" ] [ text (StateJson.dump model.state) ]
        ]


viewColumnToggles : Table.State -> Html Msg
viewColumnToggles state =
    div [ class "checkbox-list" ]
        (label []
            [ input
                [ type_ "checkbox"
                , checked (Table.isAllColumnsVisible config state)
                , onCheck ToggleAllColumns
                ]
                []
            , text " Toggle All"
            ]
            :: List.map
                (\column ->
                    label []
                        [ input
                            [ type_ "checkbox"
                            , checked (Table.columnIsVisible state column)
                            , onCheck (ToggleColumn (Table.columnId column))
                            ]
                            []
                        , text (" " ++ Table.columnId column)
                        ]
                )
                (Table.leafColumns config)
        )


viewHeaderRow : Table.State -> Table.HeaderGroup Person -> Html Msg
viewHeaderRow _ group =
    tr [] (List.map viewHeaderCell group.headers)


viewHeaderCell : Table.Header Person -> Html Msg
viewHeaderCell header =
    th [ colspan (Table.headerColSpan header) ]
        [ if Table.headerIsPlaceholder header then
            text ""

          else
            span [] [ text (headerLabel header) ]
        ]


viewFooterRow : Table.State -> Table.HeaderGroup Person -> Html Msg
viewFooterRow _ group =
    tr [] (List.map viewFooterCell group.headers)


viewFooterCell : Table.Header Person -> Html Msg
viewFooterCell header =
    th [ colspan (Table.headerColSpan header) ]
        [ if Table.headerIsPlaceholder header then
            text ""

          else
            text (footerLabel header)
        ]


headerLabel : Table.Header Person -> String
headerLabel header =
    Table.findColumn config (Table.headerColumnId header)
        |> Maybe.andThen Table.columnHeader
        |> Maybe.withDefault (Table.headerColumnId header)


footerLabel : Table.Header Person -> String
footerLabel header =
    Table.findColumn config (Table.headerColumnId header)
        |> Maybe.andThen Table.columnFooter
        |> Maybe.withDefault ""


viewRow : Table.State -> Table.Row Person -> Html Msg
viewRow state row =
    tr [] (List.map viewCell (Table.visibleCells config state row))


viewCell : Table.Cell -> Html Msg
viewCell cell =
    td [] [ text (Value.toString cell.value) ]


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
