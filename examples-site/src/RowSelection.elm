module RowSelection exposing (main)

{-| Row Selection.

Ports `examples/react/row-selection/src/main.tsx` from TanStack Table: a
`select` display column with an indeterminate header checkbox, per-row
checkboxes, shift-click range selection through `Table.selectRange`, per
column filters, a global filter, pagination, a page-rows checkbox in the
footer, the selected-row count, and a dump of the selection.

The React example's stress-test button builds 1,000,000 rows. `elm/random`
generates rows one at a time, so this page uses 10,000 instead. The React
example's "Log getSelectedRowModel().flatRows" button becomes the selected
rows dump below the table, since Elm has no `console.info`.

-}

import Browser
import Html exposing (Html, button, div, input, option, p, pre, select, span, strong, table, tbody, td, text, tfoot, th, thead, tr)
import Html.Attributes exposing (checked, class, classList, colspan, disabled, placeholder, property, selected, type_, value)
import Html.Events exposing (on, onClick, onInput)
import Json.Decode as Decode
import Json.Encode as Encode
import Shared.People as People exposing (Person)
import Shared.StateJson as StateJson
import Table
import Table.FilterFn as FilterFn
import Table.Value as Value exposing (Value)



-- COLUMNS


config : Table.Config Person
config =
    Table.config
        [ Table.display "select"
        , Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First Name"
            |> Table.withFilterFn FilterFn.includesString
        , Table.column "lastName" (.lastName >> maybeString)
            |> Table.withHeader "Last Name"
            |> Table.withFilterFn FilterFn.includesString
        , Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
            |> Table.withFilterFn FilterFn.inNumberRange
        , Table.column "visits" (.visits >> maybeNumber)
            |> Table.withHeader "Visits"
            |> Table.withFilterFn FilterFn.inNumberRange
        , Table.column "status" (.status >> People.statusToString >> Value.String)
            |> Table.withHeader "Status"
            |> Table.withFilterFn FilterFn.includesString
        , Table.column "progress" (.progress >> toFloat >> Value.Number)
            |> Table.withHeader "Profile Progress"
            |> Table.withFilterFn FilterFn.inNumberRange
        ]
        |> Table.withGetRowId (\person _ _ -> person.id)
        |> Table.withGlobalFilterFn FilterFn.includesString


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
    , lastSelected : Maybe String
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
            Table.prePaginationRowModel config model.state filtered
    in
    { core = core
    , filtered = filtered
    , prePaginated = prePaginated
    , paginated = Table.paginatedRowModel config model.state prePaginated
    }


init : Model
init =
    { state = Table.initialState
    , data = People.makeData 42 [ 1000 ]
    , seed = 42
    , lastSelected = Nothing
    }


type Msg
    = RegenerateData
    | StressTest
    | GlobalFilterTyped String
    | FilterTyped String String
    | RangeTyped String Int String
    | ToggleRow String Bool
    | ToggleAllRows
    | ToggleAllPageRows
    | FirstPage
    | PreviousPage
    | NextPage
    | LastPage
    | GoToPage String
    | SetPageSize String


update : Msg -> Model -> Model
update msg model =
    let
        s : Stages
        s =
            stages model
    in
    case msg of
        RegenerateData ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 1000 ] }

        StressTest ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 10000 ] }

        GlobalFilterTyped typed ->
            { model | state = Table.setGlobalFilter (Value.String typed) model.state }

        FilterTyped columnId typed ->
            { model | state = Table.setColumnFilter config s.core columnId (Value.String typed) model.state }

        RangeTyped columnId index typed ->
            let
                current : ( String, String )
                current =
                    rangeText model.state columnId

                next : Value
                next =
                    if index == 0 then
                        Value.List [ Value.String typed, Value.String (Tuple.second current) ]

                    else
                        Value.List [ Value.String (Tuple.first current), Value.String typed ]
            in
            { model | state = Table.setColumnFilter config s.core columnId next model.state }

        ToggleRow rowId withShift ->
            case Table.findRow s.prePaginated rowId of
                Just row ->
                    let
                        nextValue : Bool
                        nextValue =
                            not (Table.getIsRowSelected model.state row)
                    in
                    case ( withShift, model.lastSelected ) of
                        ( True, Just anchor ) ->
                            { model
                                | state = Table.selectRange config s.prePaginated anchor row nextValue model.state
                                , lastSelected = Just rowId
                            }

                        _ ->
                            { model
                                | state = Table.toggleRowSelected config s.core row Nothing model.state
                                , lastSelected = Just rowId
                            }

                Nothing ->
                    model

        ToggleAllRows ->
            { model | state = Table.toggleAllRowsSelected config s.filtered Nothing model.state }

        ToggleAllPageRows ->
            { model | state = Table.toggleAllPageRowsSelected config s.paginated Nothing model.state }

        FirstPage ->
            { model | state = Table.firstPage config model.state }

        PreviousPage ->
            { model | state = Table.previousPage config model.state }

        NextPage ->
            { model | state = Table.nextPage config model.state }

        LastPage ->
            { model | state = Table.lastPage config model.state s.prePaginated }

        GoToPage typed ->
            { model
                | state =
                    Table.setPage config
                        (Maybe.withDefault 1 (String.toInt typed) - 1)
                        model.state
            }

        SetPageSize typed ->
            { model | state = Table.setPageSize (Maybe.withDefault 10 (String.toInt typed)) model.state }



-- VIEW


view : Model -> Html Msg
view model =
    let
        s : Stages
        s =
            stages model

        pageCount : Int
        pageCount =
            Table.getPageCount config model.state s.prePaginated
    in
    div [ class "demo-root" ]
        [ div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ]
            , button [ onClick StressTest ] [ text "Stress Test (10k rows)" ]
            ]
        , div []
            [ input
                [ class "filter-wide"
                , placeholder "Search all columns..."
                , value (Value.toString model.state.globalFilter)
                , onInput GlobalFilterTyped
                ]
                []
            ]
        , div [ class "spacer-sm" ] []
        , p [] [ text "Hold Shift while selecting rows to select or deselect a range." ]
        , table []
            [ thead [] (List.map (viewHeaderRow model s) (Table.headerGroups config model.state))
            , tbody [] (List.map (viewRow model) s.paginated.rows)
            , tfoot []
                [ tr []
                    [ td []
                        [ checkbox
                            (Table.getIsAllPageRowsSelected config model.state s.paginated)
                            (Table.getIsSomePageRowsSelected config model.state s.paginated)
                            ToggleAllPageRows
                        ]
                    , td [ colspan 20 ]
                        [ text ("Page Rows (" ++ String.fromInt (List.length s.paginated.rows) ++ ")") ]
                    ]
                ]
            ]
        , div [ class "spacer-sm" ] []
        , div [ class "controls" ]
            [ button [ onClick FirstPage, disabled (not (Table.getCanPreviousPage model.state)) ] [ text "<<" ]
            , button [ onClick PreviousPage, disabled (not (Table.getCanPreviousPage model.state)) ] [ text "<" ]
            , button [ onClick NextPage, disabled (not (Table.getCanNextPage config model.state s.prePaginated)) ] [ text ">" ]
            , button [ onClick LastPage, disabled (not (Table.getCanLastPage config model.state s.prePaginated)) ] [ text ">>" ]
            , span []
                [ text "Page "
                , strong []
                    [ text (String.fromInt (model.state.pagination.pageIndex + 1) ++ " of " ++ String.fromInt pageCount) ]
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
        , div []
            [ text
                (String.fromInt (List.length (Table.selectedRowIds model.state))
                    ++ " of "
                    ++ String.fromInt (List.length s.core.rows)
                    ++ " Total Rows Selected"
                )
            ]
        , div [ class "spacer-sm" ] []
        , Html.details []
            [ Html.summary [] [ text "Selected rows" ]
            , pre [ class "state-dump" ] [ text (selectionDump model s) ]
            ]
        , div [ class "spacer-sm" ] []
        , div []
            [ Html.label [] [ text "State:" ]
            , pre [ class "state-dump" ] [ text (StateJson.dump model.state) ]
            ]
        ]


selectionDump : Model -> Stages -> String
selectionDump model s =
    let
        selected : Table.RowModel Person
        selected =
            Table.selectedRowModel model.state s.filtered
    in
    "[\n"
        ++ String.join ",\n"
            (List.map
                (\row ->
                    "  { \"id\": \""
                        ++ Table.rowId row
                        ++ "\", \"firstName\": \""
                        ++ (Table.rowOriginal row).firstName
                        ++ "\", \"age\": "
                        ++ String.fromInt (Table.rowOriginal row).age
                        ++ " }"
                )
                selected.flatRows
            )
        ++ "\n]"


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
    th [ colspan (Table.headerColSpan header) ]
        (if columnId == "select" then
            [ checkbox
                (Table.getIsAllRowsSelected config model.state s.filtered)
                (Table.getIsSomeRowsSelected model.state)
                ToggleAllRows
            ]

         else
            [ div [] [ text (headerLabel header) ]
            , if Table.getCanFilter config columnId then
                viewFilter model.state columnId

              else
                text ""
            ]
        )


viewFilter : Table.State -> String -> Html Msg
viewFilter state columnId =
    if List.member columnId numericColumns then
        let
            ( minText, maxText ) =
                rangeText state columnId
        in
        div [ class "filter-row" ]
            [ input
                [ type_ "number"
                , class "filter"
                , placeholder "Min"
                , value minText
                , onInput (RangeTyped columnId 0)
                ]
                []
            , input
                [ type_ "number"
                , class "filter"
                , placeholder "Max"
                , value maxText
                , onInput (RangeTyped columnId 1)
                ]
                []
            ]

    else
        input
            [ class "filter"
            , placeholder "Search..."
            , value
                (Table.getFilterValue state columnId
                    |> Maybe.map Value.toString
                    |> Maybe.withDefault ""
                )
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


viewRow : Model -> Table.Row Person -> Html Msg
viewRow model row =
    tr [ classList [ ( "selected", Table.getIsRowSelected model.state row ) ] ]
        (List.map (viewCell model row) (Table.getAllCells config model.state row))


viewCell : Model -> Table.Row Person -> Table.Cell -> Html Msg
viewCell model row cell =
    td []
        [ if cell.columnId == "select" then
            input
                [ type_ "checkbox"
                , checked (Table.getIsRowSelected model.state row)
                , disabled (not (Table.getCanSelect config row))
                , property "indeterminate"
                    (Encode.bool
                        (not (Table.getIsRowSelected model.state row)
                            && Table.getIsSomeSelected config model.state row
                        )
                    )
                , on "click" (Decode.map (ToggleRow (Table.rowId row)) (Decode.field "shiftKey" Decode.bool))
                ]
                []

          else
            text (Value.toString cell.value)
        ]


checkbox : Bool -> Bool -> Msg -> Html Msg
checkbox isChecked isIndeterminate msg =
    input
        [ type_ "checkbox"
        , checked isChecked
        , property "indeterminate" (Encode.bool (not isChecked && isIndeterminate))
        , onClick msg
        ]
        []


headerLabel : Table.Header Person -> String
headerLabel header =
    Table.findColumn config (Table.headerColumnId header)
        |> Maybe.andThen Table.columnHeader
        |> Maybe.withDefault (Table.headerColumnId header)


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
