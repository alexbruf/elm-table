module SubComponents exposing (main)

{-| Ports `examples/react/sub-components/src/main.tsx`.

Expanding without sub-rows: `Table.withRowCanExpand (always True)` makes
every row expandable, and an expanded row gets a second `<tr>` under it whose
single cell spans the table and shows the original datum.

-}

import Browser
import Html exposing (Html, button, code, div, pre, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, colspan, style)
import Html.Events exposing (onClick)
import Json.Encode as Encode
import Shared.Controls as Controls
import Shared.People as People exposing (Person)
import Table
import Table.Value as Value exposing (Value)



-- CONFIG


config : Table.Config Person
config =
    Table.config
        [ Table.display "expander"
        , Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First Name"
            |> Table.withFooter "firstName"
        , Table.column "lastName" (.lastName >> maybeString)
            |> Table.withHeader "Last Name"
            |> Table.withFooter "lastName"
        , Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
            |> Table.withFooter "age"
        , Table.column "visits" (.visits >> maybeNumber)
            |> Table.withHeader "Visits"
            |> Table.withFooter "visits"
        , Table.column "status" (.status >> People.statusToString >> Value.String)
            |> Table.withHeader "Status"
            |> Table.withFooter "status"
        , Table.column "progress" (.progress >> toFloat >> Value.Number)
            |> Table.withHeader "Profile Progress"
            |> Table.withFooter "progress"
        ]
        -- `getRowCanExpand: () => true`
        |> Table.withRowCanExpand (always True)
        |> Table.withGetRowId (\person _ _ -> person.id)


maybeString : Maybe String -> Value
maybeString =
    Maybe.map Value.String >> Maybe.withDefault Value.Null


maybeNumber : Maybe Int -> Value
maybeNumber =
    Maybe.map (toFloat >> Value.Number) >> Maybe.withDefault Value.Null



-- MODEL


rowCount : Int
rowCount =
    10


type alias Model =
    { state : Table.State
    , seed : Int
    , data : List Person
    }


init : Model
init =
    { state = Table.initialState
    , seed = 42
    , data = People.makeData 42 [ rowCount ]
    }


rowModel : Model -> Table.RowModel Person
rowModel model =
    Table.rowsFromList config model.state model.data



-- UPDATE


type Msg
    = RegenerateData
    | ExpandToggled (Table.Row Person)


update : Msg -> Model -> Model
update msg model =
    case msg of
        RegenerateData ->
            let
                seed : Int
                seed =
                    model.seed + 1
            in
            { model | seed = seed, data = People.makeData seed [ rowCount ] }

        ExpandToggled row ->
            { model
                | state = Table.toggleExpanded config (rowModel model) row Nothing model.state
            }



-- VIEW


view : Model -> Html Msg
view model =
    let
        current : Table.RowModel Person
        current =
            rowModel model
    in
    div [ class "demo-root" ]
        [ div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ] ]
        , div [ class "demo-root" ]
            [ div [ class "spacer-sm" ] []
            , table []
                [ thead []
                    [ tr [] (List.map viewHeaderCell (Table.flatHeaders config model.state)) ]
                , tbody [] (List.concatMap (viewRow model) current.rows)
                ]
            , div [ class "spacer-sm" ] []
            , div [] [ text (Controls.formatInt (List.length current.rows) ++ " Rows") ]
            ]
        ]


viewHeaderCell : Table.Header Person -> Html Msg
viewHeaderCell header =
    let
        columnId : String
        columnId =
            Table.headerColumnId header
    in
    th [ colspan (Table.headerColSpan header) ]
        [ div []
            [ text
                (Table.findColumn config columnId
                    |> Maybe.andThen Table.columnHeader
                    |> Maybe.withDefault ""
                )
            ]
        ]


viewRow : Model -> Table.Row Person -> List (Html Msg)
viewRow model row =
    let
        cells : List Table.Cell
        cells =
            Table.getAllCells config model.state row
    in
    tr [] (List.map (viewCell model row) cells)
        :: (if Table.getIsExpanded config model.state row then
                -- 2nd row is a custom 1 cell row
                [ tr []
                    [ td [ colspan (List.length cells) ]
                        [ viewSubComponent row ]
                    ]
                ]

            else
                []
           )


viewCell : Model -> Table.Row Person -> Table.Cell -> Html Msg
viewCell model row cell =
    if cell.columnId == "expander" then
        td []
            [ if Table.getCanExpand config row then
                button [ class "sortable", onClick (ExpandToggled row) ]
                    [ text
                        (if Table.getIsExpanded config model.state row then
                            "👇"

                         else
                            "👉"
                        )
                    ]

              else
                text "🔵"
            ]

    else if cell.columnId == "firstName" then
        td []
            [ div
                [ class "indent"
                , style "padding-left" (String.fromInt (2 * Table.rowDepth row) ++ "rem")
                ]
                [ text (Value.toString cell.value) ]
            ]

    else
        td [] [ text (Controls.valueToString cell.value) ]


{-| `renderSubComponent`: the row's own datum as JSON.
-}
viewSubComponent : Table.Row Person -> Html Msg
viewSubComponent row =
    let
        person : Person
        person =
            Table.rowOriginal row
    in
    pre [ style "font-size" "10px" ]
        [ code []
            [ text
                (Encode.encode 2
                    (Encode.object
                        [ ( "id", Encode.string person.id )
                        , ( "firstName", Encode.string person.firstName )
                        , ( "lastName"
                          , case person.lastName of
                                Just name ->
                                    Encode.string name

                                Nothing ->
                                    Encode.null
                          )
                        , ( "email", Encode.string person.email )
                        , ( "age", Encode.int person.age )
                        , ( "visits"
                          , case person.visits of
                                Just visits ->
                                    Encode.int visits

                                Nothing ->
                                    Encode.null
                          )
                        , ( "progress", Encode.int person.progress )
                        , ( "status", Encode.string (People.statusToString person.status) )
                        , ( "rank", Encode.int person.rank )
                        , ( "createdAt", Encode.string (Controls.isoDate person.createdAt) )
                        ]
                    )
                )
            ]
        ]


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
