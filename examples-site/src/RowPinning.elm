module RowPinning exposing (main)

{-| Row Pinning.

Ports `examples/react/row-pinning/src/main.tsx` from TanStack Table: a
`pin` display column with ⬆️ / ⬇️ / ❌ buttons, nested sub-rows with an
expander, per column filters, pagination, and the four demo checkboxes
(keep pinned rows, include leaf rows, include parent rows, duplicate pinned
rows in the main table).

The React example's stress-test button builds 200,000 rows. `elm/random`
generates rows one at a time, so this page uses 2,000 top-level rows
instead.

-}

import Browser
import Html exposing (Html, button, div, input, label, option, pre, select, span, strong, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (checked, class, colspan, disabled, placeholder, selected, style, type_, value)
import Html.Events exposing (onCheck, onClick, onInput)
import Shared.People as People exposing (Person)
import Shared.StateJson as StateJson
import Table
import Table.FilterFn as FilterFn
import Table.Value as Value exposing (Value)



-- COLUMNS


config : Bool -> Table.Config Person
config keepPinnedRows =
    let
        base : Table.Config Person
        base =
            Table.config
                [ Table.display "pin"
                    |> Table.withHeader "Pin"
                , Table.column "firstName" (.firstName >> Value.String)
                    |> Table.withHeader "First Name"
                    |> Table.withFilterFn FilterFn.includesString
                , Table.column "lastName" (.lastName >> maybeString)
                    |> Table.withHeader "Last Name"
                    |> Table.withFilterFn FilterFn.includesString
                , Table.column "age" (.age >> toFloat >> Value.Number)
                    |> Table.withHeader "Age"
                    |> Table.withFilterFn FilterFn.inNumberRange
                    |> Table.withSize 50
                , Table.column "visits" (.visits >> maybeNumber)
                    |> Table.withHeader "Visits"
                    |> Table.withFilterFn FilterFn.inNumberRange
                    |> Table.withSize 50
                , Table.column "status" (.status >> People.statusToString >> Value.String)
                    |> Table.withHeader "Status"
                    |> Table.withFilterFn FilterFn.includesString
                , Table.column "progress" (.progress >> toFloat >> Value.Number)
                    |> Table.withHeader "Profile Progress"
                    |> Table.withFilterFn FilterFn.inNumberRange
                    |> Table.withSize 80
                ]
                |> Table.withGetRowId (\person _ _ -> person.id)
                |> Table.withSubRows People.subRowsOf
    in
    { base | keepPinnedRows = keepPinnedRows }


numericColumns : List String
numericColumns =
    [ "age", "visits", "progress" ]


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
    , keepPinnedRows : Bool
    , includeLeafRows : Bool
    , includeParentRows : Bool
    , copyPinnedRows : Bool
    }


type alias Stages =
    { core : Table.RowModel Person
    , prePaginated : Table.RowModel Person
    , paginated : Table.RowModel Person
    }


stages : Model -> Stages
stages model =
    let
        cfg : Table.Config Person
        cfg =
            config model.keepPinnedRows

        core : Table.RowModel Person
        core =
            Table.coreRowModelFromList cfg model.state model.data

        prePaginated : Table.RowModel Person
        prePaginated =
            Table.filteredRowModel cfg model.state core
                |> Table.prePaginationRowModel cfg model.state
    in
    { core = core
    , prePaginated = prePaginated
    , paginated = Table.paginatedRowModel cfg model.state prePaginated
    }


init : Model
init =
    { state = Table.setPageSize 20 Table.initialState
    , data = People.makeData 42 [ 2000, 2, 2 ]
    , seed = 42
    , keepPinnedRows = True
    , includeLeafRows = True
    , includeParentRows = False
    , copyPinnedRows = False
    }


type Msg
    = RegenerateData
    | StressTest
    | PinRow String Table.RowPinPosition
    | ToggleExpanded String
    | ToggleAllExpanded
    | FilterTyped String String
    | RangeTyped String Int String
    | FirstPage
    | PreviousPage
    | NextPage
    | LastPage
    | GoToPage String
    | SetPageSize String
    | SetKeepPinnedRows Bool
    | SetIncludeLeafRows Bool
    | SetIncludeParentRows Bool
    | SetCopyPinnedRows Bool


update : Msg -> Model -> Model
update msg model =
    let
        cfg : Table.Config Person
        cfg =
            config model.keepPinnedRows

        s : Stages
        s =
            stages model
    in
    case msg of
        RegenerateData ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 2000, 2, 2 ] }

        StressTest ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 5000, 2, 2 ] }

        PinRow rowId position ->
            case Table.findRow s.prePaginated rowId of
                Just row ->
                    { model
                        | state =
                            Table.pinRowWith position
                                { includeLeafRows = model.includeLeafRows
                                , includeParentRows = model.includeParentRows
                                }
                                s.prePaginated
                                row
                                model.state
                    }

                Nothing ->
                    model

        ToggleExpanded rowId ->
            case Table.findRow s.core rowId of
                Just row ->
                    { model | state = Table.toggleExpanded cfg s.core row Nothing model.state }

                Nothing ->
                    model

        ToggleAllExpanded ->
            { model | state = Table.toggleAllRowsExpanded cfg s.core Nothing model.state }

        FilterTyped columnId typed ->
            { model | state = Table.setColumnFilter cfg s.core columnId (Value.String typed) model.state }

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
            { model | state = Table.setColumnFilter cfg s.core columnId next model.state }

        FirstPage ->
            { model | state = Table.firstPage cfg model.state }

        PreviousPage ->
            { model | state = Table.previousPage cfg model.state }

        NextPage ->
            { model | state = Table.nextPage cfg model.state }

        LastPage ->
            { model | state = Table.lastPage cfg model.state s.prePaginated }

        GoToPage typed ->
            { model | state = Table.setPage cfg (Maybe.withDefault 1 (String.toInt typed) - 1) model.state }

        SetPageSize typed ->
            { model | state = Table.setPageSize (Maybe.withDefault 20 (String.toInt typed)) model.state }

        SetKeepPinnedRows on ->
            { model | keepPinnedRows = on }

        SetIncludeLeafRows on ->
            { model | includeLeafRows = on }

        SetIncludeParentRows on ->
            { model | includeParentRows = on }

        SetCopyPinnedRows on ->
            { model | copyPinnedRows = on }



-- VIEW


view : Model -> Html Msg
view model =
    let
        cfg : Table.Config Person
        cfg =
            config model.keepPinnedRows

        s : Stages
        s =
            stages model

        source : Table.PinnedRowsSource Person
        source =
            { prePaginated = s.prePaginated, current = s.paginated }

        top : List (Table.Row Person)
        top =
            Table.topRows cfg model.state source

        bottom : List (Table.Row Person)
        bottom =
            Table.bottomRows cfg model.state source

        middle : List (Table.Row Person)
        middle =
            if model.copyPinnedRows then
                s.paginated.rows

            else
                Table.centerRows model.state s.paginated
    in
    div []
        [ div [ class "demo-root" ]
            [ div [ class "button-row" ]
                [ button [ onClick RegenerateData ] [ text "Regenerate Data" ]
                , button [ onClick StressTest ] [ text "Stress Test (5k × 2 × 2 rows)" ]
                ]
            , div [ class "spacer-sm" ] []
            , table []
                [ thead [] (List.map (viewHeaderRow model cfg s) (Table.headerGroups cfg model.state))
                , tbody []
                    (List.map (viewPinnedRow model cfg source (List.length bottom)) top
                        ++ List.map (viewRow model cfg) middle
                        ++ List.map (viewPinnedRow model cfg source (List.length bottom)) bottom
                    )
                ]
            ]
        , div [ class "spacer-sm" ] []
        , div [ class "controls" ]
            [ button [ onClick FirstPage, disabled (not (Table.getCanPreviousPage model.state)) ] [ text "<<" ]
            , button [ onClick PreviousPage, disabled (not (Table.getCanPreviousPage model.state)) ] [ text "<" ]
            , button [ onClick NextPage, disabled (not (Table.getCanNextPage cfg model.state s.prePaginated)) ] [ text ">" ]
            , button [ onClick LastPage, disabled (not (Table.getCanLastPage cfg model.state s.prePaginated)) ] [ text ">>" ]
            , span []
                [ text "Page "
                , strong []
                    [ text
                        (String.fromInt (model.state.pagination.pageIndex + 1)
                            ++ " of "
                            ++ String.fromInt (Table.getPageCount cfg model.state s.prePaginated)
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
                            [ value (String.fromInt size)
                            , selected (size == model.state.pagination.pageSize)
                            ]
                            [ text ("Show " ++ String.fromInt size) ]
                    )
                    [ 10, 20, 30, 40, 50 ]
                )
            ]
        , div [ class "spacer-sm" ] []
        , Html.hr [] []
        , div [ class "checkbox-list" ]
            [ toggle model.keepPinnedRows SetKeepPinnedRows "Keep/Persist Pinned Rows across Pagination and Filtering"
            , toggle model.includeLeafRows SetIncludeLeafRows "Include Leaf Rows When Pinning Parent"
            , toggle model.includeParentRows SetIncludeParentRows "Include Parent Rows When Pinning Child"
            , toggle model.copyPinnedRows SetCopyPinnedRows "Duplicate/Keep Pinned Rows in main table"
            ]
        , pre [ class "state-dump" ] [ text (StateJson.dump model.state) ]
        ]


toggle : Bool -> (Bool -> Msg) -> String -> Html Msg
toggle isOn msg text_ =
    label []
        [ input [ type_ "checkbox", checked isOn, onCheck msg ] []
        , text (" " ++ text_)
        ]


viewHeaderRow : Model -> Table.Config Person -> Stages -> Table.HeaderGroup Person -> Html Msg
viewHeaderRow model cfg s group =
    tr [] (List.map (viewHeaderCell model cfg s) group.headers)


viewHeaderCell : Model -> Table.Config Person -> Stages -> Table.Header Person -> Html Msg
viewHeaderCell model cfg s header =
    let
        columnId : String
        columnId =
            Table.headerColumnId header
    in
    th [ colspan (Table.headerColSpan header) ]
        [ div []
            (if columnId == "firstName" then
                [ button [ onClick ToggleAllExpanded ]
                    [ text
                        (if Table.getIsAllRowsExpanded cfg model.state s.core then
                            "👇"

                         else
                            "👉"
                        )
                    ]
                , text (" " ++ headerLabel cfg header)
                ]

             else
                [ text (headerLabel cfg header) ]
            )
        , if Table.getCanFilter cfg columnId then
            viewFilter model.state columnId

          else
            text ""
        ]


viewFilter : Table.State -> String -> Html Msg
viewFilter state columnId =
    if List.member columnId numericColumns then
        let
            ( minText, maxText ) =
                rangeText state columnId
        in
        div [ class "filter-row" ]
            [ input [ type_ "number", class "filter", placeholder "Min", value minText, onInput (RangeTyped columnId 0) ] []
            , input [ type_ "number", class "filter", placeholder "Max", value maxText, onInput (RangeTyped columnId 1) ] []
            ]

    else
        input
            [ class "filter"
            , placeholder "Search..."
            , value (Table.getFilterValue state columnId |> Maybe.map Value.toString |> Maybe.withDefault "")
            , onInput (FilterTyped columnId)
            ]
            []


rangeText : Table.State -> String -> ( String, String )
rangeText state columnId =
    case Table.getFilterValue state columnId of
        Just (Value.List [ low, high ]) ->
            ( Value.toString low, Value.toString high )

        _ ->
            ( "", "" )


viewPinnedRow : Model -> Table.Config Person -> Table.PinnedRowsSource Person -> Int -> Table.Row Person -> Html Msg
viewPinnedRow model cfg source bottomCount row =
    let
        pinned : Table.RowPinPosition
        pinned =
            Table.getIsRowPinned model.state row

        index : Int
        index =
            Table.getRowPinnedIndex cfg model.state source row
    in
    tr
        [ class "pinned-row"
        , style "position" "sticky"
        , style "top"
            (if pinned == Table.pinnedTop then
                String.fromInt (index * 26 + 48) ++ "px"

             else
                "auto"
            )
        , style "bottom"
            (if pinned == Table.pinnedBottom then
                String.fromInt ((bottomCount - 1 - index) * 26) ++ "px"

             else
                "auto"
            )
        ]
        (List.map (viewCell model cfg row) (Table.getAllCells cfg model.state row))


viewRow : Model -> Table.Config Person -> Table.Row Person -> Html Msg
viewRow model cfg row =
    tr [] (List.map (viewCell model cfg row) (Table.getAllCells cfg model.state row))


viewCell : Model -> Table.Config Person -> Table.Row Person -> Table.Cell -> Html Msg
viewCell model cfg row cell =
    td []
        [ if cell.columnId == "pin" then
            viewPinButtons model row

          else if cell.columnId == "firstName" then
            div [ style "padding-left" (String.fromInt (Table.rowDepth row * 2) ++ "rem") ]
                [ if Table.getCanExpand cfg row then
                    button [ onClick (ToggleExpanded (Table.rowId row)) ]
                        [ text
                            (if Table.getIsExpanded cfg model.state row then
                                "👇"

                             else
                                "👉"
                            )
                        ]

                  else
                    text "🔵"
                , text (" " ++ Value.toString cell.value)
                ]

          else
            text (Value.toString cell.value)
        ]


viewPinButtons : Model -> Table.Row Person -> Html Msg
viewPinButtons model row =
    if Table.getIsRowPinned model.state row /= Table.rowUnpinned then
        button [ onClick (PinRow (Table.rowId row) Table.rowUnpinned) ] [ text "❌" ]

    else
        div [ class "pin-actions" ]
            [ button [ onClick (PinRow (Table.rowId row) Table.pinnedTop) ] [ text "⬆️" ]
            , button [ onClick (PinRow (Table.rowId row) Table.pinnedBottom) ] [ text "⬇️" ]
            ]


headerLabel : Table.Config Person -> Table.Header Person -> String
headerLabel cfg header =
    Table.findColumn cfg (Table.headerColumnId header)
        |> Maybe.andThen Table.columnHeader
        |> Maybe.withDefault (Table.headerColumnId header)


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
