module View exposing (view)

{-| The page. Everything it draws comes from the row models `Main` measured
and from the package's `State`; no stage runs here.
-}

import Data exposing (Keyword)
import Html exposing (Html, button, div, h1, input, option, p, select, span, table, tbody, td, text, th, thead, tr)
import Html.Attributes as Attr exposing (attribute, class, classList, disabled, placeholder, selected, step, style, title, type_, value)
import Html.Events exposing (on, onClick, onInput, targetValue)
import Json.Decode as Decode
import Json.Encode as Encode
import Report exposing (Bound(..), Model, Msg(..))
import Table exposing (Cell, Row)
import Table.Value as Value exposing (Value)
import Timing


view : Model -> Html Msg
view model =
    div [ class "page" ]
        [ viewMasthead model
        , viewToolbar model
        , viewTable model
        , viewPager model
        , viewTimings model
        ]



-- MASTHEAD


viewMasthead : Model -> Html Msg
viewMasthead model =
    div [ class "masthead" ]
        [ h1 [ class "title" ] [ text "Keyword report" ]
        , p [ class "sub" ]
            [ text (Report.formatInt Data.rowCount ++ " keywords, generated in the browser from seed " ++ String.fromInt model.seed ++ ".")
            ]
        ]



-- TOOLBAR


viewToolbar : Model -> Html Msg
viewToolbar model =
    div [ class "toolbar" ]
        [ toolGroup "Search"
            [ input
                [ type_ "search"
                , class "search"
                , placeholder "Any column"
                , value (globalFilterText model)
                , onInput GlobalFilterTyped
                ]
                []
            ]
        , toolGroup "Group by"
            (List.map (groupToggle model) Report.groupableColumns)
        , toolGroup "Sub-rows"
            [ toggleButton (Table.getIsSomeRowsExpanded model.state)
                AllRowsExpandToggled
                (if Table.getIsAllRowsExpanded Report.config model.state model.stages.expanded then
                    "Collapse all"

                 else
                    "Expand all"
                )
            ]
        , toolGroup "Rows per page"
            [ select [ class "picker", onInput PageSizePicked, onChangeValue PageSizePicked ]
                (List.map (pageSizeOption model) [ 10, 25, 50, 100 ])
            ]
        , toolGroup "Columns"
            (List.map (columnToggle model) (hideableColumnIds model))
        , toolGroup "Keyword column"
            [ toggleButton (keywordIsPinned model) KeywordPinToggled "Pin left" ]
        , toolGroup "Seed"
            [ input
                [ type_ "number"
                , class "seed"
                , value model.seedField
                , onInput SeedTyped
                ]
                []
            , button [ class "action", onClick RegenerateClicked ] [ text "Regenerate" ]
            ]
        , toolGroup "Filters"
            [ button [ class "action", onClick FiltersCleared ] [ text "Clear filters" ] ]
        ]


toolGroup : String -> List (Html Msg) -> Html Msg
toolGroup name controls =
    div [ class "tool" ]
        [ span [ class "tool-label" ] [ text name ]
        , div [ class "tool-body" ] controls
        ]


groupToggle : Model -> String -> Html Msg
groupToggle model id =
    toggleButton (Table.getIsGrouped model.state id) (GroupToggled id) (Report.columnLabel id)


columnToggle : Model -> String -> Html Msg
columnToggle model id =
    case Table.findColumn Report.config id of
        Just column ->
            let
                shown : Bool
                shown =
                    Table.columnIsVisible model.state column
            in
            button
                [ classList [ ( "chip", True ), ( "off", not shown ) ]
                , attribute "aria-pressed"
                    (if shown then
                        "true"

                     else
                        "false"
                    )
                , onClick (ColumnVisibilityToggled id)
                ]
                [ text (Report.columnLabel id) ]

        Nothing ->
            text ""


onChangeValue : (String -> Msg) -> Html.Attribute Msg
onChangeValue toMsg =
    on "change" (Decode.map toMsg targetValue)


toggleButton : Bool -> Msg -> String -> Html Msg
toggleButton isOn msg name =
    button
        [ classList [ ( "toggle", True ), ( "on", isOn ) ]
        , attribute "aria-pressed"
            (if isOn then
                "true"

             else
                "false"
            )
        , onClick msg
        ]
        [ text name ]


pageSizeOption : Model -> Int -> Html Msg
pageSizeOption model size =
    option
        [ value (String.fromInt size)
        , selected (model.state.pagination.pageSize == size)
        ]
        [ text (String.fromInt size) ]


hideableColumnIds : Model -> List String
hideableColumnIds _ =
    Table.leafColumns Report.config
        |> List.filter (Table.columnCanHide Report.config)
        |> List.map Table.columnId


keywordIsPinned : Model -> Bool
keywordIsPinned model =
    Table.findColumn Report.config "keyword"
        |> Maybe.map (\column -> Table.columnIsPinned model.state column == Table.pinnedLeft)
        |> Maybe.withDefault False


globalFilterText : Model -> String
globalFilterText model =
    case model.state.globalFilter of
        Value.String text ->
            text

        _ ->
            ""



-- TABLE


viewTable : Model -> Html Msg
viewTable model =
    div [ class "tablewrap" ]
        [ table [ class "report" ]
            [ thead []
                [ viewHeaderRow model
                , viewFilterRow model
                ]
            , tbody [] (List.map (viewRow model) model.stages.paginated.rows)
            ]
        ]


{-| The header cells of the left-pinned region followed by the unpinned one.
-}
viewHeaderRow : Model -> Html Msg
viewHeaderRow model =
    let
        headersOf : (Table.Config Keyword -> Table.State -> List (Table.HeaderGroup Keyword)) -> List (Table.Header Keyword)
        headersOf groups =
            List.concatMap .headers (groups Report.config model.state)
    in
    tr [ class "headrow" ]
        (th [ class "cell-select stick" ] [ viewSelectAll model ]
            :: List.map (viewHeader model True) (headersOf Table.leftHeaderGroups)
            ++ List.map (viewHeader model False) (headersOf Table.centerHeaderGroups)
        )


viewHeader : Model -> Bool -> Table.Header Keyword -> Html Msg
viewHeader model pinned header =
    let
        id : String
        id =
            Table.headerColumnId header

        sorted : Maybe Table.SortDir
        sorted =
            Table.getIsSorted model.state id

        index : Int
        index =
            Table.getSortIndex model.state id
    in
    th
        [ classList
            [ ( "head", True )
            , ( "pinned", pinned )
            , ( "num", isNumeric id )
            , ( "sorted", sorted /= Nothing )
            ]
        ]
        [ button
            [ class "headbutton"
            , title "Click to sort, shift-click to add a level"
            , on "click" (Decode.map (HeaderClicked id) (Decode.field "shiftKey" Decode.bool))
            ]
            [ span [ class "headlabel" ] [ text (Report.columnLabel id) ]
            , span [ class "arrow" ] [ text (arrowFor sorted) ]
            , if index >= 0 && List.length model.state.sorting > 1 then
                span [ class "badge" ] [ text (String.fromInt (index + 1)) ]

              else
                text ""
            ]
        ]


arrowFor : Maybe Table.SortDir -> String
arrowFor sorted =
    case sorted of
        Nothing ->
            ""

        Just dir ->
            if dir == Table.sortAsc then
                "↑"

            else
                "↓"


viewSelectAll : Model -> Html Msg
viewSelectAll model =
    let
        allSelected : Bool
        allSelected =
            Table.getIsAllPageRowsSelected Report.config model.state model.stages.paginated

        someSelected : Bool
        someSelected =
            Table.getIsSomePageRowsSelected Report.config model.state model.stages.paginated
    in
    input
        [ type_ "checkbox"
        , Attr.checked allSelected
        , Attr.property "indeterminate" (Encode.bool (someSelected && not allSelected))
        , attribute "aria-label" "Select the rows on this page"
        , onClick PageRowsSelectToggled
        ]
        []



-- FILTER ROW


viewFilterRow : Model -> Html Msg
viewFilterRow model =
    let
        columnsOf : (Table.Config Keyword -> Table.State -> List (Table.Column Keyword)) -> List (Table.Column Keyword)
        columnsOf source =
            source Report.config model.state
    in
    tr [ class "filterrow" ]
        (td [ class "cell-select stick" ] []
            :: List.map (viewFilterCell model True) (columnsOf Table.leftVisibleLeafColumns)
            ++ List.map (viewFilterCell model False) (columnsOf Table.centerVisibleLeafColumns)
        )


viewFilterCell : Model -> Bool -> Table.Column Keyword -> Html Msg
viewFilterCell model pinned column =
    let
        id : String
        id =
            Table.columnId column
    in
    td [ classList [ ( "filtercell", True ), ( "pinned", pinned ) ] ]
        [ case id of
            "keyword" ->
                textFilterInput model id

            "cluster" ->
                textFilterInput model id

            "intent" ->
                intentFilterSelect model id

            "volume" ->
                rangeInputs model id

            "difficulty" ->
                rangeInputs model id

            "position" ->
                rangeInputs model id

            "crawled" ->
                dateInputs model id

            _ ->
                text ""
        ]


textFilterInput : Model -> String -> Html Msg
textFilterInput model id =
    input
        [ type_ "text"
        , class "filterfield"
        , placeholder "contains"
        , attribute "aria-label" (Report.columnLabel id ++ " contains")
        , value (Report.textFilter model.state id)
        , onInput (TextFilterTyped id)
        ]
        []


intentFilterSelect : Model -> String -> Html Msg
intentFilterSelect model id =
    let
        current : String
        current =
            Report.textFilter model.state id
    in
    select
        [ class "filterfield"
        , attribute "aria-label" "Intent"
        , onInput (EnumFilterPicked id)
        , onChangeValue (EnumFilterPicked id)
        ]
        (option [ value "", selected (current == "") ] [ text "any" ]
            :: List.map
                (\intent ->
                    let
                        name : String
                        name =
                            Data.intentLabel intent
                    in
                    option [ value name, selected (current == name) ] [ text name ]
                )
                Data.allIntents
        )


rangeInputs : Model -> String -> Html Msg
rangeInputs model id =
    div [ class "range" ]
        [ rangeInput model id Lower "min"
        , rangeInput model id Upper "max"
        ]


rangeInput : Model -> String -> Bound -> String -> Html Msg
rangeInput model id bound hint =
    input
        [ type_ "number"
        , class "filterfield small"
        , placeholder hint
        , step "1"
        , attribute "aria-label" (Report.columnLabel id ++ " " ++ hint)
        , value (Report.rangeBound model.state id bound)
        , onInput (RangeTyped id bound)
        ]
        []


dateInputs : Model -> String -> Html Msg
dateInputs model id =
    div [ class "range" ]
        [ dateInput model id Lower "from"
        , dateInput model id Upper "to"
        ]


dateInput : Model -> String -> Bound -> String -> Html Msg
dateInput model id bound hint =
    input
        [ type_ "date"
        , class "filterfield date"
        , attribute "aria-label" (Report.columnLabel id ++ " " ++ hint)
        , value (Report.dateBound model.state id bound)
        , onInput (DateTyped id bound)
        ]
        []



-- BODY


viewRow : Model -> Row Keyword -> Html Msg
viewRow model row =
    let
        left : List Cell
        left =
            Table.leftVisibleCells Report.config model.state row

        center : List Cell
        center =
            Table.centerVisibleCells Report.config model.state row

        leadingId : String
        leadingId =
            List.head (left ++ center)
                |> Maybe.map .columnId
                |> Maybe.withDefault ""
    in
    tr
        [ classList
            [ ( "row", True )
            , ( "grouprow", Table.rowIsGrouped row )
            , ( "subrow", Table.rowDepth row > 0 && not (Table.rowIsGrouped row) )
            , ( "picked", Table.getIsRowSelected model.state row )
            ]
        ]
        (td [ class "cell-select stick" ] [ viewSelect model row ]
            :: List.map (viewCell model row leadingId True) left
            ++ List.map (viewCell model row leadingId False) center
        )


viewSelect : Model -> Row Keyword -> Html Msg
viewSelect model row =
    if Table.getCanSelect Report.config row then
        input
            [ type_ "checkbox"
            , Attr.checked (Table.getIsRowSelected model.state row)
            , Attr.property "indeterminate"
                (Encode.bool
                    (not (Table.getIsRowSelected model.state row)
                        && Table.getIsSomeSelected Report.config model.state row
                    )
                )
            , attribute "aria-label" "Select this row"
            , onClick (RowSelectToggled (Table.rowId row))
            ]
            []

    else
        text ""


viewCell : Model -> Row Keyword -> String -> Bool -> Cell -> Html Msg
viewCell model row leadingId pinned cell =
    let
        isLeading : Bool
        isLeading =
            cell.columnId == leadingId
    in
    td
        [ classList
            [ ( "cell", True )
            , ( "pinned", pinned )
            , ( "num", isNumeric cell.columnId )
            , ( "path", cell.columnId == "url" )
            ]
        ]
        [ if isLeading then
            div
                [ class "leading"
                , style "padding-left" (String.fromInt (Table.rowDepth row * 18) ++ "px")
                ]
                [ viewExpander model row
                , span [] [ cellContent row cell True ]
                ]

          else
            cellContent row cell False
        ]


viewExpander : Model -> Row Keyword -> Html Msg
viewExpander model row =
    if Table.getCanExpand Report.config row then
        button
            [ classList
                [ ( "expander", True )
                , ( "open", Table.getIsExpanded Report.config model.state row )
                ]
            , attribute "aria-label" "Show the rows below this one"
            , onClick (RowExpandToggled (Table.rowId row))
            ]
            [ text "›" ]

    else
        span [ class "expander empty" ] []


cellContent : Row Keyword -> Cell -> Bool -> Html Msg
cellContent row cell isLeading =
    if Table.rowIsGrouped row && isLeading then
        span []
            [ text (Value.toString (Table.rowGroupingValue row))
            , span [ class "count" ] [ text (Report.formatInt (List.length (Table.rowLeafRows row))) ]
            ]

    else if Table.rowIsGrouped row && Value.isNull cell.value then
        text ""

    else if cell.columnId == "change" then
        viewChange cell.value

    else
        text (cellText cell)


viewChange : Value -> Html Msg
viewChange value =
    case value of
        Value.Number n ->
            if n > 0 then
                span [ class "up" ] [ text ("+" ++ formatNumber n) ]

            else if n < 0 then
                span [] [ text (formatNumber n) ]

            else
                span [ class "count" ] [ text "0" ]

        _ ->
            text ""


cellText : Cell -> String
cellText cell =
    case cell.columnId of
        "url" ->
            String.replace "https://example.com" "" (Value.toString cell.value)

        "crawled" ->
            dateText cell.value

        _ ->
            case cell.value of
                Value.Number n ->
                    if cell.columnId == "volume" then
                        Report.formatInt (round n)

                    else
                        formatNumber n

                _ ->
                    Value.toString cell.value


dateText : Value -> String
dateText value =
    case value of
        Value.Date posix ->
            Report.formatDate posix

        Value.List items ->
            items
                |> List.filterMap
                    (\item ->
                        case item of
                            Value.Date posix ->
                                Just (Report.formatDate posix)

                            _ ->
                                Nothing
                    )
                |> String.join " to "

        _ ->
            ""


formatNumber : Float -> String
formatNumber n =
    if n == toFloat (round n) then
        String.fromInt (round n)

    else
        String.fromFloat (toFloat (round (n * 10)) / 10)


isNumeric : String -> Bool
isNumeric id =
    List.member id [ "volume", "difficulty", "position", "previous", "change" ]



-- PAGER


viewPager : Model -> Html Msg
viewPager model =
    let
        total : Int
        total =
            Table.getRowCount Report.config model.stages.expanded

        onPage : Int
        onPage =
            List.length model.stages.paginated.rows

        first : Int
        first =
            model.state.pagination.pageIndex * model.state.pagination.pageSize + 1

        pageCount : Int
        pageCount =
            Table.getPageCount Report.config model.state model.stages.expanded

        selected : Int
        selected =
            List.length (Table.selectedRowIds model.state)
    in
    div [ class "pager" ]
        [ span [ class "readout" ]
            [ text
                (if total == 0 then
                    "No rows match these filters"

                 else
                    "Rows "
                        ++ Report.formatInt first
                        ++ "–"
                        ++ Report.formatInt (first + onPage - 1)
                        ++ " of "
                        ++ Report.formatInt total
                )
            ]
        , div [ class "pagenav" ]
            [ button
                [ class "action"
                , disabled (not (Table.getCanPreviousPage model.state))
                , onClick PrevPageClicked
                ]
                [ text "Previous" ]
            , span [ class "readout" ]
                [ text ("Page " ++ Report.formatInt (model.state.pagination.pageIndex + 1) ++ " of " ++ Report.formatInt (Basics.max 1 pageCount)) ]
            , button
                [ class "action"
                , disabled (not (Table.getCanNextPage Report.config model.state model.stages.expanded))
                , onClick NextPageClicked
                ]
                [ text "Next" ]
            ]
        , div [ class "selection" ]
            [ span [ class "readout" ] [ text (Report.formatInt selected ++ " selected") ]
            , if selected > 0 then
                button [ class "action quiet", onClick SelectionCleared ] [ text "Clear" ]

              else
                text ""
            ]
        ]



-- TIMINGS


viewTimings : Model -> Html Msg
viewTimings model =
    let
        t : Timing.Timings
        t =
            model.timings

        total : Int
        total =
            t.core + t.filtered + t.grouped + t.sorted + t.expanded + t.paginated
    in
    div [ class "timings" ]
        [ span [ class "tool-label" ] [ text "Last recompute" ]
        , div [ class "timinglist" ]
            [ stat "core" t.core
            , stat "filtered" t.filtered
            , stat "grouped" t.grouped
            , stat "sorted" t.sorted
            , stat "expanded" t.expanded
            , stat "paginated" t.paginated
            , stat "total" total
            ]
        ]


stat : String -> Int -> Html Msg
stat name millis =
    span [ class "stat" ]
        [ span [ class "statname" ] [ text name ]
        , span [ class "statvalue" ] [ text (String.fromInt millis ++ " ms") ]
        ]
