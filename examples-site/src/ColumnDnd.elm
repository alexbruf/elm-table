module ColumnDnd exposing (main)

{-| Column Ordering (DnD).

Ports `examples/react/column-dnd/src/main.tsx` from TanStack Table. The
React example drives `dnd-kit`; this one uses plain HTML5 drag and drop
(`Shared.Drag`) and ends in the same place: `Table.setColumnOrder` with the
dragged column moved to the drop target's slot.

Drag the 🟰 handle in a header onto another header to reorder the columns.

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
        [ Table.column "firstName" (.firstName >> Value.String)
            |> Table.withSize 150
        , Table.column "lastName" (.lastName >> maybeString)
            |> Table.withHeader "Last Name"
            |> Table.withSize 150
        , Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
            |> Table.withSize 120
        , Table.column "visits" (.visits >> maybeNumber)
            |> Table.withHeader "Visits"
            |> Table.withSize 120
        , Table.column "status" (.status >> People.statusToString >> Value.String)
            |> Table.withHeader "Status"
            |> Table.withSize 150
        , Table.column "progress" (.progress >> toFloat >> Value.Number)
            |> Table.withHeader "Profile Progress"
            |> Table.withSize 180
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
    , dragging : Maybe String
    , over : Maybe String
    }


init : Model
init =
    { -- `initialState: { columnOrder: columns.map(c => c.id) }` in the React
      -- example: the DnD order has to start out explicit.
      state =
        Table.setColumnOrder
            (List.map Table.columnId (Table.leafColumns config))
            Table.initialState
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

        DragStarted columnId ->
            { model | dragging = Just columnId, over = Nothing }

        DraggedOver columnId ->
            { model | over = Just columnId }

        Dropped columnId ->
            case model.dragging of
                Just from ->
                    { model
                        | state = Table.setColumnOrder (Drag.move from columnId model.state.columnOrder) model.state
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
            [ thead [] (List.map (viewHeaderRow model) (Table.headerGroups config model.state))
            , tbody [] (List.map (viewRow model) rowModel.rows)
            ]
        , pre [ class "state-dump" ] [ text (StateJson.dump model.state) ]
        ]


viewHeaderRow : Model -> Table.HeaderGroup Person -> Html Msg
viewHeaderRow model group =
    tr [] (List.map (viewHeaderCell model) group.headers)


viewHeaderCell : Model -> Table.Header Person -> Html Msg
viewHeaderCell model header =
    let
        columnId : String
        columnId =
            Table.headerColumnId header
    in
    th
        [ colspan (Table.headerColSpan header)
        , classList
            [ ( "dragging", model.dragging == Just columnId )
            , ( "drop-target", model.over == Just columnId && model.dragging /= Just columnId )
            ]
        , style "width" (px (columnSize model.state columnId))
        , style "white-space" "nowrap"
        , Drag.onDragOver (DraggedOver columnId)
        , Drag.onDrop (Dropped columnId)
        ]
        [ span [] [ text (headerLabel header) ]
        , button
            [ draggable "true"
            , title "Drag to reorder"
            , Drag.onDragStart (DragStarted columnId)
            , Drag.onDragEnd DragEnded
            ]
            [ text "🟰" ]
        ]


viewRow : Model -> Table.Row Person -> Html Msg
viewRow model row =
    tr [] (List.map (viewCell model) (Table.getAllCells config model.state row))


viewCell : Model -> Table.Cell -> Html Msg
viewCell model cell =
    td
        [ classList [ ( "dragging", model.dragging == Just cell.columnId ) ]
        , style "width" (px (columnSize model.state cell.columnId))
        ]
        [ text (Value.toString cell.value) ]


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
