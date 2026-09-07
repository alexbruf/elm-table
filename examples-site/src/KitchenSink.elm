module KitchenSink exposing (main)

{-| Kitchen Sink (All Features).

Ports `examples/react/kitchen-sink/src/routes/index.tsx` from TanStack
Table: every feature on one table — a fuzzy global filter and per column
text / range / select filters, sorting (including a custom status order),
grouping with aggregation, expanding sub-rows, row selection, row pinning,
column visibility, column pinning (sticky), column ordering by drag and
drop, column sizing, cell spanning on Status, cell selection with keyboard
navigation, and pagination.

Differences from the React file, all of them outside the package:

  - `dnd-kit` becomes HTML5 drag and drop (`Shared.Drag`).
  - `match-sorter`'s ranked fuzzy filter becomes a plain subsequence match;
    there is no ranking, so the `fuzzySort` companion is not ported.
  - The drag resize handles are gone: resizing is not part of this package.
    Sizes still come from `getColumnSize` / `getHeaderSize` / `totalSize`.

-}

import Browser
import Dict
import Html exposing (Html, button, details, div, h1, input, label, option, pre, select, span, strong, summary, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (checked, class, classList, colspan, disabled, draggable, placeholder, property, rowspan, selected, style, tabindex, title, type_, value)
import Html.Events exposing (on, onCheck, onClick, onInput, onMouseEnter, onMouseUp, preventDefaultOn)
import Json.Decode as Decode
import Json.Encode as Encode
import Shared.Drag as Drag
import Shared.People as People exposing (Person)
import Shared.StateJson as StateJson
import Table
import Table.AggregationFn as AggregationFn
import Table.FilterFn as FilterFn exposing (FilterFn)
import Table.Value as Value exposing (Value)



-- FILTERS


{-| The stand-in for `match-sorter`'s `rankItem`: every character of the
query appears in the value, in order. No ranking, so no fuzzy sort.
-}
fuzzy : FilterFn
fuzzy =
    FilterFn.custom
        (\dataValue filterValue ->
            subsequence
                (String.toLower (Value.toString filterValue))
                (String.toLower (Value.toString dataValue))
        )


subsequence : String -> String -> Bool
subsequence needle haystack =
    case String.uncons needle of
        Nothing ->
            True

        Just ( char, rest ) ->
            case String.indexes (String.fromChar char) haystack of
                [] ->
                    False

                index :: _ ->
                    subsequence rest (String.dropLeft (index + 1) haystack)



-- COLUMNS


type FilterVariant
    = TextFilter
    | RangeFilter
    | SelectFilter
    | NoFilter


filterVariant : String -> FilterVariant
filterVariant columnId =
    case columnId of
        "firstName" ->
            TextFilter

        "lastName" ->
            TextFilter

        "age" ->
            RangeFilter

        "visits" ->
            RangeFilter

        "progress" ->
            RangeFilter

        "status" ->
            SelectFilter

        _ ->
            NoFilter


statusOrder : Person -> Int
statusOrder person =
    case person.status of
        People.Single ->
            0

        People.Complicated ->
            1

        People.Relationship ->
            2


config : Table.Config Person
config =
    let
        base : Table.Config Person
        base =
            Table.config
                [ Table.display "select"
                    |> Table.withSize 80
                    |> Table.withMinSize 80
                    |> Table.withMaxSize 80
                    |> Table.withEnableSorting False
                    |> Table.withEnableGrouping False
                    |> Table.withEnableHiding False
                    |> Table.withEnableCellSelection False
                    |> Table.withEnableCellSpanning False
                , Table.column "firstName" (.firstName >> Value.String)
                    |> Table.withHeader "First Name"
                    |> Table.withSize 200
                    |> Table.withFilterFn fuzzy
                    -- first + last combine as one group key
                    |> Table.withGetGroupingValue
                        (\person _ ->
                            Value.String (person.firstName ++ " " ++ Maybe.withDefault "" person.lastName)
                        )
                , Table.column "lastName" (.lastName >> maybeString)
                    |> Table.withHeader "Last Name"
                    |> Table.withSize 180
                    |> Table.withFilterFn FilterFn.includesString
                , Table.column "age" (.age >> toFloat >> Value.Number)
                    |> Table.withHeader "Age"
                    |> Table.withSize 200
                    |> Table.withFilterFn FilterFn.inNumberRange
                    |> Table.withAggregationFn AggregationFn.median
                , Table.column "visits" (.visits >> maybeNumber)
                    |> Table.withHeader "Visits"
                    |> Table.withSize 200
                    |> Table.withFilterFn FilterFn.inNumberRange
                    |> Table.withAggregationFn AggregationFn.sum
                , Table.column "status" (.status >> People.statusToString >> Value.String)
                    |> Table.withHeader "Status"
                    |> Table.withSize 200
                    |> Table.withFilterFn FilterFn.equalsString
                    |> Table.withCustomSort
                        (\a b ->
                            compare (statusOrder (Table.rowOriginal a)) (statusOrder (Table.rowOriginal b))
                        )
                    -- Adjacent equal statuses merge in the rendered rows.
                    -- Sort by Status to make it obvious.
                    |> Table.withSpanRows
                , Table.column "progress" (.progress >> toFloat >> Value.Number)
                    |> Table.withHeader "Profile Progress"
                    |> Table.withSize 200
                    |> Table.withFilterFn FilterFn.inNumberRange
                    |> Table.withAggregationFn AggregationFn.mean
                ]
                |> Table.withGetRowId (\person _ _ -> person.id)
                |> Table.withSubRows People.subRowsOf
                |> Table.withGlobalFilterFn fuzzy
                |> Table.withDefaultColumn { size = 150, minSize = 200, maxSize = 800 }
                |> Table.withCellSelection True
                |> Table.withCellSpanning True
    in
    { base | keepPinnedRows = True }


columnIds : List String
columnIds =
    List.map Table.columnId (Table.leafColumns config)


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
    , dragging : Maybe String
    , over : Maybe String
    , selecting : Bool
    }


type alias Stages =
    { core : Table.RowModel Person
    , filtered : Table.RowModel Person
    , prePaginated : Table.RowModel Person
    , paginated : Table.RowModel Person
    }


stages : Model -> Stages
stages model =
    let
        core : Table.RowModel Person
        core =
            Table.coreRowModelFromList config model.state model.data

        filtered : Table.RowModel Person
        filtered =
            Table.filteredRowModel config model.state core

        prePaginated : Table.RowModel Person
        prePaginated =
            Table.groupedRowModel config model.state filtered
                |> Table.sortedRowModel config model.state
                |> Table.expandedRowModel config model.state
    in
    { core = core
    , filtered = filtered
    , prePaginated = prePaginated
    , paginated = Table.paginatedRowModel config model.state prePaginated
    }


startState : Table.State
startState =
    Table.initialState
        |> Table.setColumnOrder columnIds
        |> Table.setColumnPinning { left = [ "select" ], right = [] }
        |> Table.setPageSize 20


init : Model
init =
    { state = startState
    , data = People.makeData 42 [ 100, 5, 3 ]
    , seed = 42
    , dragging = Nothing
    , over = Nothing
    , selecting = False
    }


type Msg
    = FlatData
    | NestedData
    | StressData
    | ResetTable
    | GlobalFilterTyped String
    | FilterTyped String String
    | RangeTyped String Int String
    | SortBy String
    | ToggleGrouping String
    | PinColumn String Table.ColumnPinPosition
    | ToggleColumn String Bool
    | ToggleAllColumns Bool
    | DragStarted String
    | DraggedOver String
    | Dropped String
    | DragEnded
    | ToggleExpandedRow String
    | ToggleRow String
    | ToggleAllPageRows
    | PinRow String
    | CellPressed Table.Cell Bool Bool
    | CellEntered Table.Cell
    | SelectionReleased
    | MoveCells Table.CellDirection
    | ExtendCells Table.CellDirection
    | SelectAllCells
    | ClearCells
    | FirstPage
    | PreviousPage
    | NextPage
    | LastPage
    | GoToPage String
    | SetPageSize String
    | Ignored


update : Msg -> Model -> Model
update msg model =
    let
        s : Stages
        s =
            stages model

        source : Table.SelectionRows Person
        source =
            { prePaginated = s.prePaginated, current = s.paginated }
    in
    case msg of
        FlatData ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 1000 ] }

        NestedData ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 100, 5, 3 ] }

        StressData ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 10000 ] }

        ResetTable ->
            { model | state = startState }

        GlobalFilterTyped typed ->
            { model | state = Table.setGlobalFilter (Value.String typed) model.state }

        FilterTyped columnId typed ->
            { model | state = Table.setColumnFilter config s.core columnId (Value.String typed) model.state }

        RangeTyped columnId index typed ->
            let
                ( minText, maxText ) =
                    rangeText model.state columnId

                next : Value
                next =
                    if index == 0 then
                        Value.List [ Value.String typed, Value.String maxText ]

                    else
                        Value.List [ Value.String minText, Value.String typed ]
            in
            { model | state = Table.setColumnFilter config s.core columnId next model.state }

        SortBy columnId ->
            { model | state = Table.toggleSort config s.core columnId { desc = Nothing, multi = False } model.state }

        ToggleGrouping columnId ->
            { model | state = Table.toggleGrouping columnId model.state }

        PinColumn columnId position ->
            case Table.findColumn config columnId of
                Just column ->
                    { model | state = Table.pinColumn position column model.state }

                Nothing ->
                    model

        ToggleColumn columnId visible ->
            case Table.findColumn config columnId of
                Just column ->
                    { model | state = Table.toggleColumnVisibility config column (Just visible) model.state }

                Nothing ->
                    model

        ToggleAllColumns visible ->
            { model | state = Table.toggleAllColumnsVisible config (Just visible) model.state }

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

        ToggleExpandedRow rowId ->
            case Table.findRow s.prePaginated rowId of
                Just row ->
                    { model | state = Table.toggleExpanded config s.prePaginated row Nothing model.state }

                Nothing ->
                    model

        ToggleRow rowId ->
            case Table.findRow s.prePaginated rowId of
                Just row ->
                    { model | state = Table.toggleRowSelected config s.core row Nothing model.state }

                Nothing ->
                    model

        ToggleAllPageRows ->
            { model | state = Table.toggleAllPageRowsSelected config s.paginated Nothing model.state }

        PinRow rowId ->
            case Table.findRow s.prePaginated rowId of
                Just row ->
                    { model
                        | state =
                            Table.pinRow
                                (if Table.getIsRowPinned model.state row == Table.pinnedTop then
                                    Table.rowUnpinned

                                 else
                                    Table.pinnedTop
                                )
                                row
                                model.state
                    }

                Nothing ->
                    model

        CellPressed cell withShift withMod ->
            { model
                | selecting = True
                , state =
                    if withMod then
                        Table.toggleCellSelection config source cell model.state

                    else if withShift then
                        Table.extendCellSelectionTo config cell model.state

                    else
                        Table.selectCell config cell model.state
            }

        CellEntered cell ->
            if model.selecting then
                { model | state = Table.extendCellSelectionTo config cell model.state }

            else
                model

        SelectionReleased ->
            { model | selecting = False }

        MoveCells direction ->
            { model | state = Table.moveCellSelection config source direction model.state }

        ExtendCells direction ->
            { model | state = Table.extendCellSelection config source direction model.state }

        SelectAllCells ->
            { model | state = Table.selectAllCells config source model.state }

        ClearCells ->
            { model | state = Table.clearCellSelection model.state }

        FirstPage ->
            { model | state = Table.firstPage config model.state }

        PreviousPage ->
            { model | state = Table.previousPage config model.state }

        NextPage ->
            { model | state = Table.nextPage config model.state }

        LastPage ->
            { model | state = Table.lastPage config model.state s.prePaginated }

        GoToPage typed ->
            { model | state = Table.setPage config (Maybe.withDefault 1 (String.toInt typed) - 1) model.state }

        SetPageSize typed ->
            { model | state = Table.setPageSize (Maybe.withDefault 20 (String.toInt typed)) model.state }

        Ignored ->
            model


rangeText : Table.State -> String -> ( String, String )
rangeText state columnId =
    case Table.getFilterValue state columnId of
        Just (Value.List [ low, high ]) ->
            ( Value.toString low, Value.toString high )

        _ ->
            ( "", "" )



-- VIEW


view : Model -> Html Msg
view model =
    let
        s : Stages
        s =
            stages model

        source : Table.SelectionRows Person
        source =
            { prePaginated = s.prePaginated, current = s.paginated }

        pinnedSource : Table.PinnedRowsSource Person
        pinnedSource =
            { prePaginated = s.prePaginated, current = s.paginated }

        spanIndex : Table.CellSpanIndex
        spanIndex =
            Table.cellSpanIndex config model.state s.paginated
    in
    div [ class "demo-root", onMouseUp SelectionReleased ]
        [ h1 [] [ text "Kitchen Sink — All Features" ]
        , viewToolbar model s source
        , div
            [ class "table-container"
            , tabindex 0
            , preventDefaultOn "keydown" keyDecoder
            ]
            [ table [ style "width" (px (Table.totalSize config model.state)) ]
                [ thead [] (List.map (viewHeaderRow model s) (Table.headerGroups config model.state))
                , tbody []
                    (List.map (viewRow model s source spanIndex True)
                        (Table.topRows config model.state pinnedSource)
                        ++ List.map (viewRow model s source spanIndex False)
                            (Table.centerRows model.state s.paginated)
                        ++ List.map (viewRow model s source spanIndex True)
                            (Table.bottomRows config model.state pinnedSource)
                    )
                ]
            ]
        , div [ class "spacer-sm" ] []
        , viewPagination model s
        , div [ class "spacer-sm" ] []
        , div []
            [ text
                (String.fromInt (List.length s.paginated.rows)
                    ++ " rows on this page ("
                    ++ String.fromInt (List.length s.filtered.rows)
                    ++ " filtered of "
                    ++ String.fromInt (List.length s.core.rows)
                    ++ " total)"
                )
            ]
        , div [ class "spacer-md" ] []
        , details []
            [ summary [] [ text "Table state (live)" ]
            , pre [ class "state-dump" ] [ text (StateJson.dump model.state) ]
            ]
        ]


viewToolbar : Model -> Stages -> Table.SelectionRows Person -> Html Msg
viewToolbar model s source =
    div [ class "toolbar" ]
        [ div [ class "button-row" ]
            [ input
                [ class "filter-wide"
                , placeholder "Fuzzy search all columns..."
                , value (Value.toString model.state.globalFilter)
                , onInput GlobalFilterTyped
                ]
                []
            ]
        , div [ class "button-row" ]
            [ button [ onClick FlatData ] [ text "Flat 1k" ]
            , button [ onClick NestedData ] [ text "Nested 100×5×3" ]
            , button [ onClick StressData ] [ text "Stress 10k (flat)" ]
            , button [ onClick ResetTable ] [ text "Reset Table" ]
            , span []
                [ text
                    (String.fromInt (List.length (Table.selectedRowIds model.state))
                        ++ " of "
                        ++ String.fromInt (List.length s.core.flatRows)
                        ++ " selected"
                    )
                ]
            , span []
                [ text (String.fromInt (Table.selectedCellCount config model.state source) ++ " cells selected") ]
            , button [ onClick ClearCells ] [ text "Clear cells" ]
            , button [ onClick SelectAllCells ] [ text "Select all cells" ]
            ]
        , details [ class "checkbox-list" ]
            [ summary [] [ text "Column visibility" ]
            , label []
                [ input
                    [ type_ "checkbox"
                    , checked (Table.isAllColumnsVisible config model.state)
                    , onCheck ToggleAllColumns
                    ]
                    []
                , text " Toggle All"
                ]
            , div []
                (List.map
                    (\column ->
                        label []
                            [ input
                                [ type_ "checkbox"
                                , checked (Table.columnIsVisible model.state column)
                                , disabled (not (Table.columnCanHide config column))
                                , onCheck (ToggleColumn (Table.columnId column))
                                ]
                                []
                            , text (" " ++ Table.columnId column)
                            ]
                    )
                    (Table.leafColumns config)
                )
            ]
        ]


viewPagination : Model -> Stages -> Html Msg
viewPagination model s =
    div [ class "controls" ]
        [ button [ onClick FirstPage, disabled (not (Table.getCanPreviousPage model.state)) ] [ text "<<" ]
        , button [ onClick PreviousPage, disabled (not (Table.getCanPreviousPage model.state)) ] [ text "<" ]
        , button [ onClick NextPage, disabled (not (Table.getCanNextPage config model.state s.prePaginated)) ] [ text ">" ]
        , button [ onClick LastPage, disabled (not (Table.getCanLastPage config model.state s.prePaginated)) ] [ text ">>" ]
        , span []
            [ text "Page "
            , strong []
                [ text
                    (String.fromInt (model.state.pagination.pageIndex + 1)
                        ++ " of "
                        ++ String.fromInt (Table.getPageCount config model.state s.prePaginated)
                    )
                ]
            ]
        , span []
            [ text "| Go to page: "
            , input
                [ type_ "number"
                , class "small"
                , value (String.fromInt (model.state.pagination.pageIndex + 1))
                , onInput GoToPage
                ]
                []
            ]
        , select [ onInput SetPageSize ]
            (List.map
                (\size ->
                    option
                        [ value (String.fromInt size), selected (size == model.state.pagination.pageSize) ]
                        [ text ("Show " ++ String.fromInt size) ]
                )
                [ 10, 20, 30, 50, 100 ]
                ++ [ option
                        [ value (String.fromInt Table.unlimitedPageSize)
                        , selected (model.state.pagination.pageSize == Table.unlimitedPageSize)
                        ]
                        [ text "Show All" ]
                   ]
            )
        ]



-- HEADERS


viewHeaderRow : Model -> Stages -> Table.HeaderGroup Person -> Html Msg
viewHeaderRow model s group =
    tr [] (List.map (viewHeaderCell model s) group.headers)


viewHeaderCell : Model -> Stages -> Table.Header Person -> Html Msg
viewHeaderCell model s header =
    let
        columnId : String
        columnId =
            Table.headerColumnId header
    in
    case Table.findColumn config columnId of
        Nothing ->
            th [ colspan (Table.headerColSpan header) ] []

        Just column ->
            th
                (colspan (Table.headerColSpan header)
                    :: classList
                        [ ( "dragging", model.dragging == Just columnId )
                        , ( "drop-target", model.over == Just columnId && model.dragging /= Just columnId )
                        ]
                    :: Drag.onDragOver (DraggedOver columnId)
                    :: Drag.onDrop (Dropped columnId)
                    :: pinningStyles model.state column
                )
                [ div [ class "header-row" ]
                    [ if columnId /= "select" then
                        button
                            [ class "drag-handle"
                            , draggable "true"
                            , title "Drag to reorder"
                            , Drag.onDragStart (DragStarted columnId)
                            , Drag.onDragEnd DragEnded
                            ]
                            [ text "⠿" ]

                      else
                        text ""
                    , div [ class "header-main" ]
                        [ div [ class "pin-actions" ]
                            (viewPinActions model.state column
                                ++ [ if Table.getCanGroup config columnId then
                                        button
                                            [ onClick (ToggleGrouping columnId)
                                            , title
                                                (if Table.getIsGrouped model.state columnId then
                                                    "Stop grouping by this column"

                                                 else
                                                    "Group by this column"
                                                )
                                            ]
                                            [ text
                                                (if Table.getIsGrouped model.state columnId then
                                                    "🛑(" ++ String.fromInt (Table.getGroupedIndex model.state columnId) ++ ")"

                                                 else
                                                    "👊"
                                                )
                                            ]

                                     else
                                        text ""
                                   ]
                            )
                        , if columnId == "select" then
                            checkbox
                                (Table.getIsAllPageRowsSelected config model.state s.paginated)
                                (Table.getIsSomePageRowsSelected config model.state s.paginated)
                                ToggleAllPageRows

                          else if Table.getCanSort config columnId then
                            button [ class "sortable", onClick (SortBy columnId) ]
                                [ text (headerLabel header ++ sortArrow model.state columnId) ]

                          else
                            text (headerLabel header)
                        , if Table.getCanFilter config columnId then
                            viewFilter model s columnId

                          else
                            text ""
                        ]
                    ]
                ]


viewPinActions : Table.State -> Table.Column Person -> List (Html Msg)
viewPinActions state column =
    if not (Table.columnCanPin config column) then
        []

    else
        let
            pinned : Table.ColumnPinPosition
            pinned =
                Table.columnIsPinned state column

            columnId : String
            columnId =
                Table.columnId column
        in
        [ if pinned /= Table.pinnedLeft then
            button [ onClick (PinColumn columnId Table.pinnedLeft), title "Pin left" ] [ text "←" ]

          else
            text ""
        , if pinned /= Table.columnUnpinned then
            button [ onClick (PinColumn columnId Table.columnUnpinned), title "Unpin" ] [ text "×" ]

          else
            text ""
        , if pinned /= Table.pinnedRight then
            button [ onClick (PinColumn columnId Table.pinnedRight), title "Pin right" ] [ text "→" ]

          else
            text ""
        ]


viewFilter : Model -> Stages -> String -> Html Msg
viewFilter model s columnId =
    let
        faceted : Table.RowModel Person
        faceted =
            Table.facetedRowModel config model.state s.core columnId
    in
    case filterVariant columnId of
        RangeFilter ->
            let
                ( minText, maxText ) =
                    rangeText model.state columnId

                bounds : Maybe ( Float, Float )
                bounds =
                    Table.facetedMinMax config model.state faceted columnId
            in
            div [ class "filter-row" ]
                [ input
                    [ type_ "number"
                    , class "filter"
                    , placeholder ("Min" ++ boundLabel (Maybe.map Tuple.first bounds))
                    , value minText
                    , onInput (RangeTyped columnId 0)
                    ]
                    []
                , input
                    [ type_ "number"
                    , class "filter"
                    , placeholder ("Max" ++ boundLabel (Maybe.map Tuple.second bounds))
                    , value maxText
                    , onInput (RangeTyped columnId 1)
                    ]
                    []
                ]

        SelectFilter ->
            select [ class "filter", onInput (FilterTyped columnId) ]
                (option [ value "", selected (filterText model.state columnId == "") ] [ text "All" ]
                    :: List.map
                        (\( facetValue, _ ) ->
                            let
                                label_ : String
                                label_ =
                                    Value.toString facetValue
                            in
                            option
                                [ value label_, selected (filterText model.state columnId == label_) ]
                                [ text label_ ]
                        )
                        (List.sortBy (Tuple.first >> Value.toString)
                            (Table.facetedUniqueValues config model.state faceted columnId)
                        )
                )

        _ ->
            input
                [ class "filter"
                , placeholder
                    ("Search ("
                        ++ String.fromInt (List.length (Table.facetedUniqueValues config model.state faceted columnId))
                        ++ ")"
                    )
                , value (filterText model.state columnId)
                , onInput (FilterTyped columnId)
                ]
                []


boundLabel : Maybe Float -> String
boundLabel bound =
    case bound of
        Nothing ->
            ""

        Just n ->
            " (" ++ String.fromFloat n ++ ")"


filterText : Table.State -> String -> String
filterText state columnId =
    Table.getFilterValue state columnId
        |> Maybe.map Value.toString
        |> Maybe.withDefault ""


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


headerLabel : Table.Header Person -> String
headerLabel header =
    Table.findColumn config (Table.headerColumnId header)
        |> Maybe.andThen Table.columnHeader
        |> Maybe.withDefault (Table.headerColumnId header)



-- BODY


viewRow : Model -> Stages -> Table.SelectionRows Person -> Table.CellSpanIndex -> Bool -> Table.Row Person -> Html Msg
viewRow model s source spanIndex isPinned row =
    tr [ classList [ ( "pinned-row", isPinned ) ] ]
        (List.filterMap (viewCell model s source spanIndex row)
            (Table.visibleCells config model.state row)
        )


viewCell : Model -> Stages -> Table.SelectionRows Person -> Table.CellSpanIndex -> Table.Row Person -> Table.Cell -> Maybe (Html Msg)
viewCell model s source spanIndex row cell =
    let
        rowSpan : Int
        rowSpan =
            Table.cellRowSpan spanIndex cell

        colSpan : Int
        colSpan =
            Table.cellColSpan spanIndex cell
    in
    -- A span of 0 marks a covered cell. Rendering rowspan="0" would mean
    -- "span to the end of the row group" in HTML, so it must be omitted.
    if rowSpan == 0 || colSpan == 0 then
        Nothing

    else
        let
            column : Maybe (Table.Column Person)
            column =
                Table.findColumn config cell.columnId

            groupingActive : Bool
            groupingActive =
                not (List.isEmpty model.state.grouping)

            canSelect : Bool
            canSelect =
                Table.cellCanSelect config cell

            edges : Table.CellSelectionEdges
            edges =
                Table.cellSelectionEdges config model.state source cell
        in
        Just
            (td
                (rowspan rowSpan
                    :: colspan colSpan
                    :: classList
                        [ ( "grouped", groupingActive && Table.cellIsGrouped model.state row cell.columnId )
                        , ( "aggregated"
                          , groupingActive
                                && Table.cellIsAggregated config s.core model.state row cell.columnId
                          )
                        , ( "placeholder", groupingActive && Table.cellIsPlaceholder model.state row cell.columnId )
                        , ( "cell-selected", canSelect && Table.cellIsSelected config model.state source cell )
                        , ( "cell-focused", canSelect && Table.cellIsFocused model.state cell )
                        , ( "edge-top", edges.top )
                        , ( "edge-right", edges.right )
                        , ( "edge-bottom", edges.bottom )
                        , ( "edge-left", edges.left )
                        ]
                    :: (if canSelect then
                            [ tabindex (Table.cellTabIndex model.state cell)
                            , on "mousedown" (mouseDecoder cell)
                            , onMouseEnter (CellEntered cell)
                            ]

                        else
                            []
                       )
                    ++ (case column of
                            Just col ->
                                pinningStyles model.state col

                            Nothing ->
                                []
                       )
                )
                (cellContent model row cell)
            )


cellContent : Model -> Table.Row Person -> Table.Cell -> List (Html Msg)
cellContent model row cell =
    if Table.cellIsGrouped model.state row cell.columnId then
        [ button [ onClick (ToggleExpandedRow (Table.rowId row)) ]
            [ text
                ((if Table.getIsExpanded config model.state row then
                    "👇 "

                  else
                    "👉 "
                 )
                    ++ Value.toString cell.value
                    ++ " ("
                    ++ String.fromInt (List.length (Table.rowSubRows row))
                    ++ ")"
                )
            ]
        ]

    else if Table.cellIsPlaceholder model.state row cell.columnId then
        []

    else if
        Table.rowIsGrouped row
            && not (Dict.member cell.columnId (Table.rowAggregatedValues row))
            && cell.columnId
            /= "select"
    then
        -- The React example's `aggregatedCell: () => null`: a column with no
        -- aggregation has nothing to show on a group row.
        []

    else if cell.columnId == "select" then
        [ div [ class "pin-actions" ]
            [ input
                [ type_ "checkbox"
                , checked (Table.getIsRowSelected model.state row)
                , disabled (not (Table.getCanSelect config row))
                , property "indeterminate"
                    (Encode.bool
                        (not (Table.getIsRowSelected model.state row)
                            && Table.getIsSomeSelected config model.state row
                        )
                    )
                , onClick (ToggleRow (Table.rowId row))
                ]
                []
            , button
                [ onClick (PinRow (Table.rowId row))
                , title
                    (if Table.getIsRowPinned model.state row == Table.pinnedTop then
                        "Unpin row"

                     else
                        "Pin row top"
                    )
                ]
                [ text
                    (if Table.getIsRowPinned model.state row == Table.pinnedTop then
                        "📌"

                     else
                        "📍"
                    )
                ]
            ]
        ]

    else if cell.columnId == "firstName" then
        [ div [ style "padding-left" (String.fromFloat (toFloat (Table.rowDepth row) * 1.5) ++ "rem") ]
            [ if Table.getCanExpand config row then
                button [ onClick (ToggleExpandedRow (Table.rowId row)) ]
                    [ text
                        (if Table.getIsExpanded config model.state row then
                            "👇"

                         else
                            "👉"
                        )
                    ]

              else
                span [] [ text "·" ]
            , text (" " ++ Value.toString cell.value)
            ]
        ]

    else if cell.columnId == "progress" then
        [ text (round2 cell.value ++ "%") ]

    else if cell.columnId == "age" then
        [ text (round2 cell.value) ]

    else
        [ text (Value.toString cell.value) ]


round2 : Value -> String
round2 value =
    case value of
        Value.Number n ->
            String.fromFloat (toFloat (round (n * 100)) / 100)

        _ ->
            Value.toString value


checkbox : Bool -> Bool -> Msg -> Html Msg
checkbox isChecked isIndeterminate msg =
    input
        [ type_ "checkbox"
        , checked isChecked
        , property "indeterminate" (Encode.bool (not isChecked && isIndeterminate))
        , onClick msg
        ]
        []



-- STICKY COLUMN PINNING


pinningStyles : Table.State -> Table.Column Person -> List (Html.Attribute Msg)
pinningStyles state column =
    let
        pinned : Table.ColumnPinPosition
        pinned =
            Table.columnIsPinned state column

        isLastLeft : Bool
        isLastLeft =
            pinned == Table.pinnedLeft && Table.columnIsLast config state Table.leftColumnsRegion column

        isFirstRight : Bool
        isFirstRight =
            pinned == Table.pinnedRight && Table.columnIsFirst config state Table.rightColumnsRegion column
    in
    [ classList
        [ ( "pinned-left", pinned == Table.pinnedLeft )
        , ( "pinned-right", pinned == Table.pinnedRight )
        ]
    , style "box-shadow"
        (if isLastLeft then
            "-4px 0 4px -4px gray inset"

         else if isFirstRight then
            "4px 0 4px -4px gray inset"

         else
            "none"
        )
    , style "left"
        (if pinned == Table.pinnedLeft then
            px (Table.getColumnStart config state Table.leftColumnsRegion column)

         else
            "auto"
        )
    , style "right"
        (if pinned == Table.pinnedRight then
            px (Table.getColumnAfter config state Table.rightColumnsRegion column)

         else
            "auto"
        )
    , style "width" (px (Table.getColumnSize config state column))
    ]


px : Float -> String
px n =
    String.fromFloat n ++ "px"



-- EVENTS


mouseDecoder : Table.Cell -> Decode.Decoder Msg
mouseDecoder cell =
    Decode.map3 (\withShift withCtrl withMeta -> CellPressed cell withShift (withCtrl || withMeta))
        (Decode.field "shiftKey" Decode.bool)
        (Decode.field "ctrlKey" Decode.bool)
        (Decode.field "metaKey" Decode.bool)


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
                ExtendCells direction

              else
                MoveCells direction
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
            ( ClearCells, True )

        "a" ->
            if withMod then
                ( SelectAllCells, True )

            else
                ( Ignored, False )

        "A" ->
            if withMod then
                ( SelectAllCells, True )

            else
                ( Ignored, False )

        _ ->
            ( Ignored, False )


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
