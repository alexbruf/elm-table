module CellSelection exposing (..)

import Html exposing (Html, td, text)
import Html.Attributes exposing (class, tabindex)
import Html.Events exposing (on)
import Json.Decode as Decode
import Shared.People exposing (Person, people)
import Table
import Table.Value as Value


columns : List (Table.Column Person)
columns =
    [ Table.column "firstName" (.firstName >> Value.String)
        |> Table.withHeader "First name"
    , Table.column "salary" (.salary >> Value.Number)
        |> Table.withHeader "Salary"
    , Table.display "actions"
        |> Table.withHeader "Actions"
        |> Table.withEnableCellSelection False
    ]


config : Table.Config Person
config =
    Table.config columns
        |> Table.withGetRowId (\person _ _ -> person.id)
        |> Table.withCellRangeSelection True
        |> Table.withMultiCellRangeSelection True


salaryColumnOnly : Table.Config Person
salaryColumnOnly =
    Table.withCellSelectionWhen (\cell -> cell.columnId == "salary") config


noCellSelection : Table.Config Person
noCellSelection =
    Table.withCellSelection False config


selectionRows : Table.State -> Table.SelectionRows Person
selectionRows state =
    let
        beforePaging : Table.RowModel Person
        beforePaging =
            Table.coreRowModelFromList config state people
                |> Table.filteredRowModel config state
                |> Table.sortedRowModel config state
                |> Table.expandedRowModel config state
    in
    { prePaginated = beforePaging
    , current = Table.paginatedRowModel config state beforePaging
    }


type alias Modifiers =
    { shift : Bool
    , multi : Bool
    }


type alias Model =
    { state : Table.State
    , dragging : Bool
    }


init : Model
init =
    { state = Table.initialState
    , dragging = False
    }


type Msg
    = MouseDownOnCell Modifiers Table.Cell
    | MouseEnteredCell Table.Cell
    | ReleasedMouse
    | PressedArrow Modifiers Table.CellDirection
    | PressedSelectAll
    | PressedEscape


update : Msg -> Model -> Model
update msg model =
    case msg of
        MouseDownOnCell modifiers cell ->
            { model | dragging = True, state = mouseDown modifiers cell model.state }

        MouseEnteredCell cell ->
            if model.dragging then
                { model | state = Table.extendCellSelectionTo config cell model.state }

            else
                model

        ReleasedMouse ->
            { model | dragging = False }

        PressedArrow modifiers direction ->
            { model | state = arrowKey modifiers direction model.state }

        PressedSelectAll ->
            { model | state = Table.selectAllCells config (selectionRows model.state) model.state }

        PressedEscape ->
            { model | state = Table.clearCellSelection model.state }


mouseDown : Modifiers -> Table.Cell -> Table.State -> Table.State
mouseDown modifiers cell state =
    if modifiers.shift then
        Table.extendCellSelectionTo config cell state

    else if modifiers.multi then
        Table.toggleCellSelection config (selectionRows state) cell state

    else
        Table.selectCell config cell state


arrowKey : Modifiers -> Table.CellDirection -> Table.State -> Table.State
arrowKey modifiers direction state =
    if modifiers.shift then
        Table.extendCellSelection config (selectionRows state) direction state

    else
        Table.moveCellSelection config (selectionRows state) direction state


viewCell : Table.State -> Table.Cell -> Html Msg
viewCell state cell =
    td
        [ class (cellClass state cell)
        , tabindex (Table.cellTabIndex state cell)
        , on "mousedown" (Decode.map (\m -> MouseDownOnCell m cell) modifiersDecoder)
        , on "mouseenter" (Decode.succeed (MouseEnteredCell cell))
        ]
        [ text (Value.toString cell.value) ]


modifiersDecoder : Decode.Decoder Modifiers
modifiersDecoder =
    Decode.map2 Modifiers
        (Decode.field "shiftKey" Decode.bool)
        (Decode.map2 (||)
            (Decode.field "ctrlKey" Decode.bool)
            (Decode.field "metaKey" Decode.bool)
        )


keyDecoder : Decode.Decoder Msg
keyDecoder =
    Decode.map2 Tuple.pair
        (Decode.field "key" Decode.string)
        modifiersDecoder
        |> Decode.andThen keyMsg


keyMsg : ( String, Modifiers ) -> Decode.Decoder Msg
keyMsg ( key, modifiers ) =
    case key of
        "ArrowUp" ->
            Decode.succeed (PressedArrow modifiers Table.cellUp)

        "ArrowDown" ->
            Decode.succeed (PressedArrow modifiers Table.cellDown)

        "ArrowLeft" ->
            Decode.succeed (PressedArrow modifiers Table.cellLeft)

        "ArrowRight" ->
            Decode.succeed (PressedArrow modifiers Table.cellRight)

        "Escape" ->
            Decode.succeed PressedEscape

        _ ->
            Decode.fail "not a navigation key"


cellClass : Table.State -> Table.Cell -> String
cellClass state cell =
    let
        source : Table.SelectionRows Person
        source =
            selectionRows state

        focus : List String
        focus =
            if Table.cellIsFocused state cell then
                [ "cell-focused" ]

            else
                []
    in
    if Table.cellIsSelected config state source cell then
        String.join " "
            (("cell" :: "cell-selected" :: focus)
                ++ edgeClasses (Table.cellSelectionEdges config state source cell)
            )

    else
        String.join " " ("cell" :: focus)


edgeClasses : Table.CellSelectionEdges -> List String
edgeClasses edges =
    List.filterMap identity
        [ edgeClass "edge-top" edges.top
        , edgeClass "edge-right" edges.right
        , edgeClass "edge-bottom" edges.bottom
        , edgeClass "edge-left" edges.left
        ]


edgeClass : String -> Bool -> Maybe String
edgeClass name isEdge =
    if isEdge then
        Just name

    else
        Nothing


selectAllOfOneColumn : Table.State -> Table.State
selectAllOfOneColumn state =
    Table.selectCellRangeWith Table.includeSelection
        (Table.cellRange "1" "salary" "6" "salary")
        state


selectionAsTsv : Table.State -> String
selectionAsTsv state =
    Table.selectedCellRangesData config state (selectionRows state)
        |> List.map gridToTsv
        |> String.join "\n\n"


gridToTsv : List (List Value.Value) -> String
gridToTsv grid =
    grid
        |> List.map (\row -> String.join "\t" (List.map Value.toString row))
        |> String.join "\n"


selectionSummary : Table.State -> String
selectionSummary state =
    let
        source : Table.SelectionRows Person
        source =
            selectionRows state
    in
    String.fromInt (Table.selectedCellCount config state source)
        ++ " cells across "
        ++ String.fromInt (List.length (Table.cellSelectionRowIds config state source))
        ++ " rows"
