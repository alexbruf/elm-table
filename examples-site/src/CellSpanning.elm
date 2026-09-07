module CellSpanning exposing (main)

{-| Cell Spanning.

Ports `examples/react/cell-spanning/src/main.tsx` from TanStack Table: three
panels over one shift roster — the spanning table, the same rows rendered
flat as a reference, and a summary table whose subtotal rows use a column
span. Spans come from `Table.cellSpanIndex` / `cellRowSpan` / `cellColSpan`,
and covered cells are skipped rather than rendered with a span of `0`.

`region` and `team` merge on equal values (`withSpanRows`); `shift` uses the
predicate form (`withSpanRowsWhen`) and only merges while the table is
sorted by the shift column, so the predicate is visibly reactive.

Cells are selectable, as in the React example: click, shift-click, and drag
extend the selection, and a merged cell is always selected as a whole.

-}

import Browser
import CellSpanning.Data as Data exposing (Shift, SummaryRow)
import Html exposing (Html, button, div, h2, input, label, option, pre, section, select, span, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (checked, class, classList, colspan, disabled, placeholder, rowspan, selected, type_, value)
import Html.Events exposing (on, onCheck, onClick, onInput, onMouseEnter, onMouseUp)
import Json.Decode as Decode
import Shared.StateJson as StateJson
import Table
import Table.FilterFn as FilterFn
import Table.SortFn as SortFn
import Table.Value as Value



-- COLUMNS


config : Bool -> Bool -> Table.Config Shift
config spanningEnabled shiftSorted =
    Table.config
        [ Table.column "region" (.region >> Value.String)
            |> Table.withHeader "Region"
            |> Table.withSortFn SortFn.alphanumeric
            -- Adjacent rows that share a region merge into one vertically
            -- spanning cell.
            |> Table.withSpanRows
        , Table.column "team" (.team >> Value.String)
            |> Table.withHeader "Team"
            |> Table.withSortFn SortFn.alphanumeric
            |> Table.withSpanRows
        , Table.column "shift" (.shift >> Value.String)
            |> Table.withHeader "Shift"
            |> Table.withSortFn SortFn.alphanumeric
            -- The predicate form: shifts only merge while the table is
            -- sorted by the shift column.
            |> Table.withSpanRowsWhen (\ctx -> shiftSorted && ctx.value == ctx.anchorValue)
        , Table.column "employee" (.employee >> Value.String)
            |> Table.withHeader "Employee"
            |> Table.withSortFn SortFn.alphanumeric
            |> Table.withFilterFn FilterFn.includesString
        , Table.column "hours" (.hours >> toFloat >> Value.Number)
            |> Table.withHeader "Hours"
            |> Table.withSortFn SortFn.basic
        , Table.column "status" (.status >> Value.String)
            |> Table.withHeader "Status"
            |> Table.withSortFn SortFn.alphanumeric
            |> Table.withFilterFn FilterFn.includesString
        ]
        |> Table.withGetRowId (\shift _ _ -> shift.id)
        |> Table.withCellSpanning spanningEnabled


summaryConfig : Table.Config SummaryRow
summaryConfig =
    Table.config
        [ Table.column "label" (.label >> Value.String)
            |> Table.withHeader "Shift"
            -- Subtotal rows render one label cell covering every column but
            -- the total.
            |> Table.withSpanColumns
                (\row ->
                    if (Table.rowOriginal row).kind == Data.Subtotal then
                        Table.spanAllColumns

                    else
                        1
                )
        , Table.column "region" (.region >> Value.String)
            |> Table.withHeader "Region"
        , Table.column "hours" (.hours >> toFloat >> Value.Number)
            |> Table.withHeader "Hours"
        ]
        |> Table.withGetRowId (\row _ _ -> row.id)



-- MODEL


type alias Model =
    { state : Table.State
    , summaryState : Table.State
    , data : List Shift
    , summaryData : List SummaryRow
    , seed : Int
    , spanningEnabled : Bool
    , dragging : Bool
    }


init : Model
init =
    { state = Table.setPageSize 12 Table.initialState
    , summaryState = Table.initialState
    , data = Data.makeData 42
    , summaryData = Data.makeSummaryData 42
    , seed = 42
    , spanningEnabled = True
    , dragging = False
    }


currentConfig : Model -> Table.Config Shift
currentConfig model =
    config model.spanningEnabled (Table.getIsSorted model.state "shift" /= Nothing)


type alias Stages =
    { core : Table.RowModel Shift
    , prePaginated : Table.RowModel Shift
    , paginated : Table.RowModel Shift
    }


stages : Model -> Stages
stages model =
    let
        cfg : Table.Config Shift
        cfg =
            currentConfig model

        core : Table.RowModel Shift
        core =
            Table.coreRowModelFromList cfg model.state model.data

        prePaginated : Table.RowModel Shift
        prePaginated =
            Table.filteredRowModel cfg model.state core
                |> Table.sortedRowModel cfg model.state
                |> Table.prePaginationRowModel cfg model.state
    in
    { core = core
    , prePaginated = prePaginated
    , paginated = Table.paginatedRowModel cfg model.state prePaginated
    }


type Msg
    = RegenerateData
    | SetSpanning Bool
    | ToggleColumn String Bool
    | StatusPicked String
    | EmployeeTyped String
    | SortBy String
    | PreviousPage
    | NextPage
    | SetPageSize String
    | CellPressed Table.Cell Bool
    | CellEntered Table.Cell
    | DragReleased


update : Msg -> Model -> Model
update msg model =
    let
        cfg : Table.Config Shift
        cfg =
            currentConfig model

        s : Stages
        s =
            stages model
    in
    case msg of
        RegenerateData ->
            { model
                | seed = model.seed + 1
                , data = Data.makeData (model.seed + 1)
                , summaryData = Data.makeSummaryData (model.seed + 1)
            }

        SetSpanning on ->
            { model | spanningEnabled = on }

        ToggleColumn columnId visible ->
            case Table.findColumn cfg columnId of
                Just column ->
                    { model | state = Table.toggleColumnVisibility cfg column (Just visible) model.state }

                Nothing ->
                    model

        StatusPicked picked ->
            { model | state = Table.setColumnFilter cfg s.core "status" (Value.String picked) model.state }

        EmployeeTyped typed ->
            { model | state = Table.setColumnFilter cfg s.core "employee" (Value.String typed) model.state }

        SortBy columnId ->
            { model | state = Table.toggleSort cfg s.core columnId { desc = Nothing, multi = False } model.state }

        PreviousPage ->
            { model | state = Table.previousPage cfg model.state }

        NextPage ->
            { model | state = Table.nextPage cfg model.state }

        SetPageSize typed ->
            { model | state = Table.setPageSize (Maybe.withDefault 12 (String.toInt typed)) model.state }

        CellPressed cell withShift ->
            { model
                | dragging = True
                , state =
                    if withShift then
                        Table.extendCellSelectionTo cfg cell model.state

                    else
                        Table.selectCell cfg cell model.state
            }

        CellEntered cell ->
            if model.dragging then
                { model | state = Table.extendCellSelectionTo cfg cell model.state }

            else
                model

        DragReleased ->
            { model | dragging = False }



-- VIEW


view : Model -> Html Msg
view model =
    let
        cfg : Table.Config Shift
        cfg =
            currentConfig model

        s : Stages
        s =
            stages model

        selectionRows : Table.SelectionRows Shift
        selectionRows =
            { prePaginated = s.prePaginated, current = s.paginated }

        spanIndex : Table.CellSpanIndex
        spanIndex =
            Table.cellSpanIndex cfg model.state s.paginated
    in
    div [ class "demo-root", onMouseUp DragReleased ]
        [ div [ class "controls" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ]
            , label []
                [ input [ type_ "checkbox", checked model.spanningEnabled, onCheck SetSpanning ] []
                , text " Row spanning"
                ]
            , viewColumnToggle model cfg "team" "Team"
            , viewColumnToggle model cfg "shift" "Shift"
            , select [ onInput StatusPicked ]
                (option [ value "", selected (filterText model.state "status" == "") ] [ text "All statuses" ]
                    :: List.map
                        (\status ->
                            option
                                [ value status, selected (filterText model.state "status" == status) ]
                                [ text status ]
                        )
                        Data.statuses
                )
            , input
                [ class "filter"
                , placeholder "Filter employees..."
                , value (filterText model.state "employee")
                , onInput EmployeeTyped
                ]
                []
            ]
        , div [ class "spacer-sm" ] []
        , div [ class "controls" ]
            [ button [ onClick PreviousPage, disabled (not (Table.getCanPreviousPage model.state)) ] [ text "<" ]
            , button [ onClick NextPage, disabled (not (Table.getCanNextPage cfg model.state s.prePaginated)) ] [ text ">" ]
            , span []
                [ text
                    ("Page "
                        ++ String.fromInt (model.state.pagination.pageIndex + 1)
                        ++ " of "
                        ++ String.fromInt (Table.getPageCount cfg model.state s.prePaginated)
                    )
                ]
            , select [ onInput SetPageSize ]
                (List.map
                    (\size ->
                        option
                            [ value (String.fromInt size), selected (size == model.state.pagination.pageSize) ]
                            [ text ("Show " ++ String.fromInt size) ]
                    )
                    [ 10, 12, 36 ]
                )
            , span []
                [ text ("Visible columns: " ++ String.fromInt (List.length (Table.visibleLeafColumns cfg model.state))) ]
            , span []
                [ text ("Selected cells: " ++ String.fromInt (Table.selectedCellCount cfg model.state selectionRows)) ]
            ]
        , div [ class "spacer-md" ] []
        , div [ class "example-grid" ]
            [ section [ class "example-panel" ]
                [ h2 [] [ text "Row Spanning" ]
                , table []
                    [ viewHead model cfg
                    , tbody []
                        (List.map (viewSpanRow model cfg selectionRows spanIndex) s.paginated.rows)
                    ]
                ]
            , section [ class "example-panel" ]
                [ h2 [] [ text "Reference (no spanning)" ]
                , table []
                    [ viewHead model cfg
                    , tbody []
                        (List.map
                            (\row ->
                                tr []
                                    (List.map
                                        (\cell -> td [] [ text (Value.toString cell.value) ])
                                        (Table.visibleCells cfg model.state row)
                                    )
                            )
                            s.paginated.rows
                        )
                    ]
                ]
            , section [ class "example-panel" ]
                [ h2 [] [ text "Summary Rows (colSpan)" ]
                , viewSummaryTable model
                ]
            ]
        , div [ class "spacer-md" ] []
        , pre [ class "state-dump" ] [ text (StateJson.dump model.state) ]
        ]


viewColumnToggle : Model -> Table.Config Shift -> String -> String -> Html Msg
viewColumnToggle model cfg columnId title =
    case Table.findColumn cfg columnId of
        Nothing ->
            text ""

        Just column ->
            label []
                [ input
                    [ type_ "checkbox"
                    , checked (Table.columnIsVisible model.state column)
                    , onCheck (ToggleColumn columnId)
                    ]
                    []
                , text (" " ++ title)
                ]


filterText : Table.State -> String -> String
filterText state columnId =
    Table.getFilterValue state columnId
        |> Maybe.map Value.toString
        |> Maybe.withDefault ""


viewHead : Model -> Table.Config Shift -> Html Msg
viewHead model cfg =
    thead []
        (List.map
            (\group ->
                tr []
                    (List.map
                        (\header ->
                            th [ colspan (Table.headerColSpan header), class "sortable" ]
                                [ button [ onClick (SortBy (Table.headerColumnId header)) ]
                                    [ text (headerLabel cfg header ++ sortArrow model.state (Table.headerColumnId header)) ]
                                ]
                        )
                        group.headers
                    )
            )
            (Table.headerGroups cfg model.state)
        )


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


viewSpanRow : Model -> Table.Config Shift -> Table.SelectionRows Shift -> Table.CellSpanIndex -> Table.Row Shift -> Html Msg
viewSpanRow model cfg selectionRows spanIndex row =
    tr []
        (List.filterMap (viewSpanCell model cfg selectionRows spanIndex)
            (Table.visibleCells cfg model.state row)
        )


viewSpanCell : Model -> Table.Config Shift -> Table.SelectionRows Shift -> Table.CellSpanIndex -> Table.Cell -> Maybe (Html Msg)
viewSpanCell model cfg selectionRows spanIndex cell =
    let
        rowSpan : Int
        rowSpan =
            Table.cellRowSpan spanIndex cell

        colSpan : Int
        colSpan =
            Table.cellColSpan spanIndex cell
    in
    -- A span of 0 means this cell is covered by a cell above or to its left.
    -- Never render `rowspan="0"`: in HTML that means "span to the end of the
    -- row group".
    if rowSpan == 0 || colSpan == 0 then
        Nothing

    else
        let
            isSelected : Bool
            isSelected =
                Table.cellIsSelected cfg model.state selectionRows cell

            edges : Table.CellSelectionEdges
            edges =
                Table.cellSelectionEdges cfg model.state selectionRows cell
        in
        Just
            (td
                [ rowspan rowSpan
                , colspan colSpan
                , classList
                    [ ( "span-cell", rowSpan > 1 )
                    , ( "cell-selected", isSelected )
                    , ( "cell-focused", Table.cellIsFocused model.state cell )
                    , ( "edge-top", edges.top )
                    , ( "edge-right", edges.right )
                    , ( "edge-bottom", edges.bottom )
                    , ( "edge-left", edges.left )
                    ]
                , on "mousedown" (Decode.map (CellPressed cell) (Decode.field "shiftKey" Decode.bool))
                , onMouseEnter (CellEntered cell)
                ]
                [ text (Value.toString cell.value) ]
            )


viewSummaryTable : Model -> Html Msg
viewSummaryTable model =
    let
        rowModel : Table.RowModel SummaryRow
        rowModel =
            Table.coreRowModelFromList summaryConfig model.summaryState model.summaryData

        spanIndex : Table.CellSpanIndex
        spanIndex =
            Table.cellSpanIndex summaryConfig model.summaryState rowModel
    in
    table []
        [ thead []
            (List.map
                (\group ->
                    tr []
                        (List.map
                            (\header ->
                                th [ colspan (Table.headerColSpan header) ]
                                    [ text
                                        (Table.findColumn summaryConfig (Table.headerColumnId header)
                                            |> Maybe.andThen Table.columnHeader
                                            |> Maybe.withDefault (Table.headerColumnId header)
                                        )
                                    ]
                            )
                            group.headers
                        )
                )
                (Table.headerGroups summaryConfig model.summaryState)
            )
        , tbody []
            (List.map
                (\row ->
                    tr
                        [ classList
                            [ ( "subtotal-row", (Table.rowOriginal row).kind == Data.Subtotal ) ]
                        ]
                        (List.filterMap
                            (\cell ->
                                let
                                    rowSpan : Int
                                    rowSpan =
                                        Table.cellRowSpan spanIndex cell

                                    colSpan : Int
                                    colSpan =
                                        Table.cellColSpan spanIndex cell
                                in
                                if rowSpan == 0 || colSpan == 0 then
                                    Nothing

                                else
                                    Just
                                        (td [ rowspan rowSpan, colspan colSpan ]
                                            [ text (Value.toString cell.value) ]
                                        )
                            )
                            (Table.visibleCells summaryConfig model.summaryState row)
                        )
                )
                rowModel.rows
            )
        ]


headerLabel : Table.Config Shift -> Table.Header Shift -> String
headerLabel cfg header =
    Table.findColumn cfg (Table.headerColumnId header)
        |> Maybe.andThen Table.columnHeader
        |> Maybe.withDefault (Table.headerColumnId header)


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
