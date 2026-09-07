module RowDnd exposing (main)

{-| Row DnD.

Ports `examples/react/row-dnd/src/main.tsx` from TanStack Table. The React
example drives `dnd-kit`; this one uses plain HTML5 drag and drop
(`Shared.Drag`). As in the React version the table state is untouched: the
drop reorders the underlying data list, and `withGetRowId` keeps row ids
stable while the row indexes change.

Drag the 🟰 handle in the "Move" column onto another row.

-}

import Browser
import Html exposing (Html, button, div, pre, span, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, classList, colspan, draggable, style, title)
import Html.Events exposing (onClick)
import Shared.Drag as Drag
import Shared.People as People exposing (Person)
import Shared.StateJson as StateJson
import Table
import Table.Value as Value



-- COLUMNS


config : Table.Config Person
config =
    Table.config
        [ -- A dedicated drag handle column, as in the React example.
          Table.display "drag-handle"
            |> Table.withHeader "Move"
            |> Table.withSize 60
        , Table.column "firstName" (.firstName >> Value.String)
        , Table.column "lastName" (.lastName >> maybeString)
            |> Table.withHeader "Last Name"
        , Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
        , Table.column "visits" (.visits >> maybeNumber)
            |> Table.withHeader "Visits"
        , Table.column "status" (.status >> People.statusToString >> Value.String)
            |> Table.withHeader "Status"
        , Table.column "progress" (.progress >> toFloat >> Value.Number)
            |> Table.withHeader "Profile Progress"
        ]
        -- required, because the row indexes change on every drop
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
    , dragging : Maybe String
    , over : Maybe String
    }


init : Model
init =
    { state = Table.initialState
    , data = People.makeData 42 [ 20 ]
    , seed = 42
    , dragging = Nothing
    , over = Nothing
    }


type Msg
    = RegenerateData
    | StressTest
    | DragStarted String
    | DraggedOver String
    | Dropped String
    | DragEnded


update : Msg -> Model -> Model
update msg model =
    case msg of
        RegenerateData ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 20 ] }

        StressTest ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 1000 ] }

        DragStarted rowId ->
            { model | dragging = Just rowId, over = Nothing }

        DraggedOver rowId ->
            { model | over = Just rowId }

        Dropped rowId ->
            case model.dragging of
                Just from ->
                    { model
                        | data = Drag.moveBy .id from rowId model.data
                        , dragging = Nothing
                        , over = Nothing
                    }

                Nothing ->
                    { model | over = Nothing }

        DragEnded ->
            { model | dragging = Nothing, over = Nothing }



-- VIEW


view : Model -> Html Msg
view model =
    let
        rowModel : Table.RowModel Person
        rowModel =
            Table.coreRowModelFromList config model.state model.data
    in
    div [ class "demo-root" ]
        [ div [ class "spacer-md" ] []
        , div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ]
            , button [ onClick StressTest ] [ text "Stress Test (1k rows)" ]
            ]
        , div [ class "spacer-md" ] []
        , table []
            [ thead [] (List.map (viewHeaderRow model.state) (Table.headerGroups config model.state))
            , tbody [] (List.map (viewRow model) rowModel.rows)
            ]
        , pre [ class "state-dump" ] [ text (StateJson.dump model.state) ]
        ]


viewHeaderRow : Table.State -> Table.HeaderGroup Person -> Html Msg
viewHeaderRow _ group =
    tr []
        (List.map
            (\header ->
                th [ colspan (Table.headerColSpan header) ]
                    [ span [] [ text (headerLabel header) ] ]
            )
            group.headers
        )


viewRow : Model -> Table.Row Person -> Html Msg
viewRow model row =
    let
        rowId : String
        rowId =
            Table.rowId row
    in
    tr
        [ classList
            [ ( "dragging", model.dragging == Just rowId )
            , ( "drop-target", model.over == Just rowId && model.dragging /= Just rowId )
            ]
        , Drag.onDragOver (DraggedOver rowId)
        , Drag.onDrop (Dropped rowId)
        ]
        (List.map (viewCell model.state rowId) (Table.getAllCells config model.state row))


viewCell : Table.State -> String -> Table.Cell -> Html Msg
viewCell state rowId cell =
    td [ style "width" (px (columnSize state cell.columnId)) ]
        [ if cell.columnId == "drag-handle" then
            button
                [ draggable "true"
                , title "Drag to reorder"
                , Drag.onDragStart (DragStarted rowId)
                , Drag.onDragEnd DragEnded
                ]
                [ text "🟰" ]

          else
            text (Value.toString cell.value)
        ]


columnSize : Table.State -> String -> Float
columnSize state columnId =
    Table.findColumn config columnId
        |> Maybe.map (Table.getColumnSize config state)
        |> Maybe.withDefault 0


px : Float -> String
px n =
    String.fromFloat n ++ "px"


headerLabel : Table.Header Person -> String
headerLabel header =
    Table.findColumn config (Table.headerColumnId header)
        |> Maybe.andThen Table.columnHeader
        |> Maybe.withDefault (Table.headerColumnId header)


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
