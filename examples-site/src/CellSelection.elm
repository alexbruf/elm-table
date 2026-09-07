module CellSelection exposing (main)

{-| Cell Selection.

Ports `examples/react/cell-selection/src/main.tsx` from TanStack Table:
click, shift-click and drag to select rectangles of cells, ctrl/cmd-click to
add or subtract one, arrow keys to move, shift+arrows to extend, Mod+A to
select everything and Escape to clear — all of it running through
`selectCell`, `extendCellSelectionTo`, `toggleCellSelection`,
`moveCellSelection`, `extendCellSelection`, `selectAllCells` and
`clearCellSelection`. Each cell draws only the sides `cellSelectionEdges`
reports, so a union of rectangles gets one continuous outline.

Hiding, reordering, pinning and sorting keep working underneath; like the
React example, the selection is cleared whenever the column layout changes.

Elm cannot reach `navigator.clipboard`, so the React example's "Copy
Selection" button becomes the TSV panel under the table: the same
`selectedCellRangesData` grid, serialized the same way.

-}

import Browser
import Html exposing (Html, button, div, hr, input, label, p, pre, span, table, tbody, td, text, textarea, tfoot, th, thead, tr)
import Html.Attributes exposing (checked, class, classList, colspan, disabled, placeholder, rows, tabindex, type_)
import Html.Events exposing (on, onCheck, onClick, onMouseEnter, onMouseUp, preventDefaultOn)
import Json.Decode as Decode
import Random
import Shared.People as People exposing (Person)
import Shared.PersonExtra as PersonExtra
import Shared.StateJson as StateJson
import Table
import Table.Value as Value exposing (Value)



-- COLUMNS


config : Table.Config Person
config =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First Name"
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
        , Table.column "email" (.email >> Value.String)
            |> Table.withHeader "Email"
        , Table.column "phone" (PersonExtra.phone >> Value.String)
            |> Table.withHeader "Phone"
        , Table.column "city" (PersonExtra.city >> Value.String)
            |> Table.withHeader "City"
        , Table.column "country" (PersonExtra.country >> Value.String)
            |> Table.withHeader "Country"
        , Table.column "department" (PersonExtra.department >> Value.String)
            |> Table.withHeader "Department"
        , Table.column "salary" (PersonExtra.salary >> toFloat >> Value.Number)
            |> Table.withHeader "Salary"
        ]
        |> Table.withGetRowId (\person _ _ -> person.id)


maybeString : Maybe String -> Value
maybeString =
    Maybe.map Value.String >> Maybe.withDefault Value.Null


maybeNumber : Maybe Int -> Value
maybeNumber =
    Maybe.map (toFloat >> Value.Number) >> Maybe.withDefault Value.Null



-- MODEL


type alias Model =
    { state : Table.State
    , data : List Person
    , seed : Int
    , shuffleSeed : Random.Seed
    , dragging : Bool
    }


init : Model
init =
    { state = Table.initialState
    , data = People.makeData 42 [ 20 ]
    , seed = 42
    , shuffleSeed = Random.initialSeed 42
    , dragging = False
    }


{-| The row models cell selection reads: ranges resolve against the
pre-pagination model, and the current page bounds keyboard movement. This
example does not paginate, so both are the sorted row model.
-}
selectionRows : Model -> Table.SelectionRows Person
selectionRows model =
    let
        model_ : Table.RowModel Person
        model_ =
            Table.coreRowModelFromList config model.state model.data
                |> Table.sortedRowModel config model.state
                |> Table.prePaginationRowModel config model.state
    in
    { prePaginated = model_, current = model_ }


type Msg
    = RegenerateData
    | StressTest
    | ToggleColumn String Bool
    | ToggleAllColumns Bool
    | ShuffleColumns
    | ReverseColumnOrder
    | ResetColumnOrder
    | ResetPinning
    | ResetVisibility
    | SortBy String
    | PinColumn String Table.ColumnPinPosition
    | CellPressed Table.Cell Bool Bool
    | CellEntered Table.Cell
    | DragReleased
    | Move Table.CellDirection
    | Extend Table.CellDirection
    | SelectAll
    | ClearSelection
    | Ignored


update : Msg -> Model -> Model
update msg model =
    let
        source : Table.SelectionRows Person
        source =
            selectionRows model
    in
    case msg of
        RegenerateData ->
            { model
                | seed = model.seed + 1
                , data = People.makeData (model.seed + 1) [ 20 ]
                , state = Table.clearCellSelection model.state
            }

        StressTest ->
            { model
                | seed = model.seed + 1
                , data = People.makeData (model.seed + 1) [ 1000 ]
                , state = Table.clearCellSelection model.state
            }

        ToggleColumn columnId visible ->
            case Table.findColumn config columnId of
                Just column ->
                    layoutChanged model (Table.toggleColumnVisibility config column (Just visible) model.state)

                Nothing ->
                    model

        ToggleAllColumns visible ->
            layoutChanged model (Table.toggleAllColumnsVisible config (Just visible) model.state)

        ShuffleColumns ->
            let
                ( order, nextSeed ) =
                    shuffle model.shuffleSeed (List.map Table.columnId (Table.leafColumns config))
            in
            layoutChanged { model | shuffleSeed = nextSeed } (Table.setColumnOrder order model.state)

        ReverseColumnOrder ->
            layoutChanged model
                (Table.setColumnOrder
                    (List.reverse (List.map Table.columnId (Table.leafColumns config)))
                    model.state
                )

        ResetColumnOrder ->
            layoutChanged model (Table.resetColumnOrder model.state)

        ResetPinning ->
            layoutChanged model (Table.resetColumnPinning model.state)

        ResetVisibility ->
            layoutChanged model (Table.resetColumnVisibility model.state)

        SortBy columnId ->
            layoutChanged model
                (Table.toggleSort config source.prePaginated columnId { desc = Nothing, multi = False } model.state)

        PinColumn columnId position ->
            case Table.findColumn config columnId of
                Just column ->
                    layoutChanged model (Table.pinColumn position column model.state)

                Nothing ->
                    model

        CellPressed cell withShift withMod ->
            { model
                | dragging = True
                , state =
                    if withMod then
                        Table.toggleCellSelection config source cell model.state

                    else if withShift then
                        Table.extendCellSelectionTo config cell model.state

                    else
                        Table.selectCell config cell model.state
            }

        CellEntered cell ->
            if model.dragging then
                { model | state = Table.extendCellSelectionTo config cell model.state }

            else
                model

        DragReleased ->
            { model | dragging = False }

        Move direction ->
            { model | state = Table.moveCellSelection config source direction model.state }

        Extend direction ->
            { model | state = Table.extendCellSelection config source direction model.state }

        SelectAll ->
            { model | state = Table.selectAllCells config source model.state }

        ClearSelection ->
            { model | state = Table.clearCellSelection model.state }

        Ignored ->
            model


{-| The React example resets the selection whenever the column layout or the
sorting changes.
-}
layoutChanged : Model -> Table.State -> Model
layoutChanged model state =
    { model | state = Table.clearCellSelection state }


shuffle : Random.Seed -> List a -> ( List a, Random.Seed )
shuffle seed items =
    Random.step (Random.list (List.length items) (Random.int 0 1000000)) seed
        |> Tuple.mapFirst
            (\keys ->
                List.map2 Tuple.pair keys items
                    |> List.sortBy Tuple.first
                    |> List.map Tuple.second
            )



-- VIEW


view : Model -> Html Msg
view model =
    let
        source : Table.SelectionRows Person
        source =
            selectionRows model
    in
    div [ class "demo-root", onMouseUp DragReleased ]
        [ div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ]
            , button [ onClick StressTest ] [ text "Stress Test (1k rows)" ]
            ]
        , div [ class "spacer-sm" ] []
        , p []
            [ text "Click and drag to select a range of cells. Hold Shift while clicking to extend the selection, or Ctrl/Cmd to add or subtract a rectangle. Arrow keys move the selection, Shift+Arrow extends it, Mod+A selects all, and Escape clears. Click the grid first so it has focus." ]
        , p [ class "muted" ]
            [ text "Hiding, reordering, and pinning columns all keep a live selection anchored to the same cell ids. Ranges are indexed in render order, so a pinned column moves the rectangle with it rather than splitting it." ]
        , viewColumnToggles model.state
        , div [ class "spacer-sm" ] []
        , div [ class "button-row" ]
            [ button [ onClick ShuffleColumns ] [ text "Shuffle Columns" ]
            , button [ onClick ReverseColumnOrder ] [ text "Reverse Column Order" ]
            , button [ onClick ResetColumnOrder ] [ text "Reset Column Order" ]
            , button [ onClick ResetPinning ] [ text "Reset Pinning" ]
            , button [ onClick ResetVisibility ] [ text "Reset Visibility" ]
            ]
        , div [ class "spacer-sm" ] []
        , div []
            [ text
                (String.fromInt (Table.selectedCellCount config model.state source)
                    ++ " cells selected across "
                    ++ String.fromInt (List.length (Table.cellSelectionRowIds config model.state source))
                    ++ " rows and "
                    ++ String.fromInt (List.length (Table.cellSelectionColumnIds config model.state source))
                    ++ " columns"
                )
            ]
        , div [ class "spacer-sm" ] []
        , div
            [ tabindex 0
            , class "grid-focus"
            , preventDefaultOn "keydown" keyDecoder
            ]
            [ table []
                [ thead [] (List.map (viewHeaderRow model.state) (Table.headerGroups config model.state))
                , tbody [] (List.map (viewRow model source) source.current.rows)
                , tfoot []
                    [ tr []
                        [ td [ colspan 20 ]
                            [ text ("Rows (" ++ String.fromInt (List.length source.current.rows) ++ ")") ]
                        ]
                    ]
                ]
            ]
        , div [ class "spacer-sm" ] []
        , div [ class "button-row" ]
            [ button [ onClick SelectAll ] [ text "Select All Cells" ]
            , button [ onClick ClearSelection ] [ text "Clear Selection" ]
            ]
        , hr [] []
        , div []
            [ label [] [ text "Selection (tab separated):" ]
            , pre [ class "state-dump" ] [ text (toTsv (Table.selectedCellRangesData config model.state source)) ]
            ]
        , div []
            [ label [] [ text "State:" ]
            , pre [ class "state-dump" ] [ text (StateJson.dump model.state) ]
            ]
        , div []
            [ label [] [ text "Paste Test:" ]
            , textarea
                [ class "filter-wide"
                , rows 8
                , placeholder "Copy a selection out of the panel above, then paste here to check the tab-separated shape..."
                ]
                []
            ]
        ]


keyDecoder : Decode.Decoder ( Msg, Bool )
keyDecoder =
    Decode.map4 keyToMsg
        (Decode.field "key" Decode.string)
        (Decode.field "shiftKey" Decode.bool)
        (Decode.field "ctrlKey" Decode.bool)
        (Decode.field "metaKey" Decode.bool)


keyToMsg : String -> Bool -> Bool -> Bool -> ( Msg, Bool )
keyToMsg key withShift withCtrl withMeta =
    let
        withMod : Bool
        withMod =
            withCtrl || withMeta

        step : Table.CellDirection -> ( Msg, Bool )
        step direction =
            ( if withShift then
                Extend direction

              else
                Move direction
            , True
            )
    in
    case key of
        "ArrowUp" ->
            step Table.cellUp

        "ArrowDown" ->
            step Table.cellDown

        "ArrowLeft" ->
            step Table.cellLeft

        "ArrowRight" ->
            step Table.cellRight

        "Escape" ->
            ( ClearSelection, True )

        "a" ->
            if withMod then
                ( SelectAll, True )

            else
                ( Ignored, False )

        "A" ->
            if withMod then
                ( SelectAll, True )

            else
                ( Ignored, False )

        _ ->
            ( Ignored, False )


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
viewHeaderRow state group =
    tr [] (List.map (viewHeaderCell state) group.headers)


viewHeaderCell : Table.State -> Table.Header Person -> Html Msg
viewHeaderCell state header =
    let
        columnId : String
        columnId =
            Table.headerColumnId header
    in
    th [ colspan (Table.headerColSpan header) ]
        [ button
            [ disabled (not (Table.getCanSort config columnId))
            , onClick (SortBy columnId)
            ]
            [ text (headerLabel header ++ sortArrow state columnId) ]
        , case Table.findColumn config columnId of
            Just column ->
                if Table.columnCanPin config column then
                    viewPinActions state column

                else
                    text ""

            Nothing ->
                text ""
        ]


viewPinActions : Table.State -> Table.Column Person -> Html Msg
viewPinActions state column =
    let
        pinned : Table.ColumnPinPosition
        pinned =
            Table.columnIsPinned state column

        columnId : String
        columnId =
            Table.columnId column
    in
    div [ class "pin-actions" ]
        [ if pinned /= Table.pinnedLeft then
            button [ onClick (PinColumn columnId Table.pinnedLeft) ] [ text "<=" ]

          else
            text ""
        , if pinned /= Table.columnUnpinned then
            button [ onClick (PinColumn columnId Table.columnUnpinned) ] [ text "X" ]

          else
            text ""
        , if pinned /= Table.pinnedRight then
            button [ onClick (PinColumn columnId Table.pinnedRight) ] [ text "=>" ]

          else
            text ""
        ]


sortArrow : Table.State -> String -> String
sortArrow state columnId =
    case Table.getIsSorted state columnId of
        Nothing ->
            ""

        Just dir ->
            if dir == Table.sortAsc then
                " 🔼"

            else
                " 🔽"


viewRow : Model -> Table.SelectionRows Person -> Table.Row Person -> Html Msg
viewRow model source row =
    tr [] (List.map (viewCell model source) (Table.visibleCells config model.state row))


viewCell : Model -> Table.SelectionRows Person -> Table.Cell -> Html Msg
viewCell model source cell =
    if Table.cellCanSelect config cell then
        let
            isSelected : Bool
            isSelected =
                Table.cellIsSelected config model.state source cell

            edges : Table.CellSelectionEdges
            edges =
                Table.cellSelectionEdges config model.state source cell
        in
        td
            [ classList
                [ ( "cell-selected", isSelected )
                , ( "cell-focused", Table.cellIsFocused model.state cell )
                , ( "edge-top", edges.top )
                , ( "edge-right", edges.right )
                , ( "edge-bottom", edges.bottom )
                , ( "edge-left", edges.left )
                ]
            , tabindex (Table.cellTabIndex model.state cell)
            , on "mousedown" (mouseDecoder cell)
            , onMouseEnter (CellEntered cell)
            ]
            [ text (Value.toString cell.value) ]

    else
        td [] [ text (Value.toString cell.value) ]


{-| `mousedown` with the two modifier keys the example reads.
-}
mouseDecoder : Table.Cell -> Decode.Decoder Msg
mouseDecoder cell =
    Decode.map3 (\withShift withCtrl withMeta -> CellPressed cell withShift (withCtrl || withMeta))
        (Decode.field "shiftKey" Decode.bool)
        (Decode.field "ctrlKey" Decode.bool)
        (Decode.field "metaKey" Decode.bool)


headerLabel : Table.Header Person -> String
headerLabel header =
    Table.findColumn config (Table.headerColumnId header)
        |> Maybe.andThen Table.columnHeader
        |> Maybe.withDefault (Table.headerColumnId header)



-- TSV


{-| The spreadsheet-flavored serialization from the React example: fields are
quoted once they contain a delimiter, a newline, or a quote, inner quotes are
doubled, and a blank line separates the selected regions.
-}
toTsv : List (List (List Value)) -> String
toTsv ranges =
    ranges
        |> List.map
            (\grid ->
                grid
                    |> List.map (\row -> String.join "\t" (List.map escapeTsv row))
                    |> String.join "\n"
            )
        |> String.join "\n\n"


escapeTsv : Value -> String
escapeTsv value =
    let
        raw : String
        raw =
            Value.toString value

        safe : String
        safe =
            if List.any (\prefix -> String.startsWith prefix (String.trimLeft raw)) [ "=", "+", "@", "-" ] then
                "'" ++ raw

            else
                raw
    in
    if String.any (\char -> char == '"' || char == '\t' || char == '\n' || char == '\u{000D}') safe then
        "\"" ++ String.replace "\"" "\"\"" safe ++ "\""

    else
        safe


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
