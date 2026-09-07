module Expanding exposing (main)

{-| Ports `examples/react/expanding/src/main.tsx`.

`Table.withSubRows` hands the pipeline the nested rows, `expandedRowModel`
flattens the expanded branches into the row list, and each row indents itself
by `Table.rowDepth`. Selection rides along: toggling a parent selects its
sub-rows, and a parent whose children are all selected renders checked.

-}

import Browser
import Html exposing (Html, button, div, input, span, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (checked, class, colspan, placeholder, property, style, type_, value)
import Html.Events exposing (onClick, onInput)
import Json.Encode as Encode
import Shared.Controls as Controls
import Shared.People as People exposing (Person)
import Table
import Table.FilterFn as FilterFn
import Table.Value as Value exposing (Value)



-- CONFIG


config : Table.Config Person
config =
    Table.config
        [ Table.display "rowNumber"
            |> Table.withHeader "#"
        , Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First Name"
        , Table.column "lastName" (.lastName >> maybeString)
            |> Table.withHeader "Last Name"
            |> Table.withFooter "lastName"
        , Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
            |> Table.withFilterFn FilterFn.between
        , Table.column "visits" (.visits >> maybeNumber)
            |> Table.withHeader "Visits"
        , Table.column "status" (.status >> People.statusToString >> Value.String)
            |> Table.withHeader "Status"
        , Table.column "progress" (.progress >> toFloat >> Value.Number)
            |> Table.withHeader "Profile Progress"
        ]
        -- tell the table where nested rows live
        |> Table.withSubRows People.subRowsOf
        |> Table.withGetRowId (\person _ _ -> person.id)


maybeString : Maybe String -> Value
maybeString =
    Maybe.map Value.String >> Maybe.withDefault Value.Null


maybeNumber : Maybe Int -> Value
maybeNumber =
    Maybe.map (toFloat >> Value.Number) >> Maybe.withDefault Value.Null


{-| The columns whose filter is a numeric range, decided the way the React
example decides it: from the first row's value.
-}
isNumericColumn : String -> Bool
isNumericColumn columnId =
    List.member columnId [ "age", "visits", "progress" ]



-- MODEL


lengths : List Int
lengths =
    [ 100, 5, 3 ]


type alias Model =
    { state : Table.State
    , seed : Int
    , data : List Person
    }


init : Model
init =
    { state = Table.initialState
    , seed = 42
    , data = People.makeData 42 lengths
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
            filtered
                |> Table.groupedRowModel config model.state
                |> Table.sortedRowModel config model.state
                |> Table.expandedRowModel config model.state
    in
    { core = core
    , filtered = filtered
    , prePaginated = prePaginated
    , paginated = Table.paginatedRowModel config model.state prePaginated
    }



-- UPDATE


type Msg
    = RegenerateData
    | FilterChanged String Value
    | ExpandToggled (Table.Row Person)
    | AllRowsExpandToggled
    | RowSelectionToggled (Table.Row Person)
    | AllRowsSelectionToggled
    | FirstPage
    | PreviousPage
    | NextPage
    | LastPage
    | GoToPage String
    | SetPageSize String


update : Msg -> Model -> Model
update msg model =
    case msg of
        RegenerateData ->
            let
                seed : Int
                seed =
                    model.seed + 1
            in
            { model | seed = seed, data = People.makeData seed lengths }

        FilterChanged columnId v ->
            { model
                | state =
                    Table.setColumnFilter config (stages model).core columnId v model.state
            }

        ExpandToggled row ->
            { model
                | state =
                    Table.toggleExpanded config (stages model).prePaginated row Nothing model.state
            }

        AllRowsExpandToggled ->
            { model
                | state =
                    Table.toggleAllRowsExpanded config
                        (stages model).prePaginated
                        Nothing
                        model.state
            }

        RowSelectionToggled row ->
            { model
                | state =
                    Table.toggleRowSelected config (stages model).core row Nothing model.state
            }

        AllRowsSelectionToggled ->
            { model
                | state =
                    Table.toggleAllRowsSelected config (stages model).filtered Nothing model.state
            }

        FirstPage ->
            { model | state = Table.firstPage config model.state }

        PreviousPage ->
            { model | state = Table.previousPage config model.state }

        NextPage ->
            { model | state = Table.nextPage config model.state }

        LastPage ->
            { model | state = Table.lastPage config model.state (stages model).prePaginated }

        GoToPage typed ->
            { model
                | state =
                    Table.setPage config
                        (Maybe.withDefault 1 (String.toInt typed) - 1)
                        model.state
            }

        SetPageSize typed ->
            { model
                | state = Table.setPageSize (Maybe.withDefault 10 (String.toInt typed)) model.state
            }



-- VIEW


view : Model -> Html Msg
view model =
    let
        current : Stages
        current =
            stages model

        state : Table.State
        state =
            model.state
    in
    div [ class "demo-root" ]
        [ div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ] ]
        , div [ class "spacer-sm" ] []
        , table []
            [ thead []
                [ tr []
                    (List.map (viewHeaderCell model current) (Table.flatHeaders config state))
                ]
            , tbody [] (List.map (viewRow model current) current.paginated.rows)
            ]
        , div [ class "spacer-sm" ] []
        , Controls.pager
            { first = FirstPage
            , previous = PreviousPage
            , next = NextPage
            , last = LastPage
            , goToPage = GoToPage
            , setPageSize = SetPageSize
            , canPrevious = Table.getCanPreviousPage state
            , canNext = Table.getCanNextPage config state current.prePaginated
            , canLast = Table.getCanLastPage config state current.prePaginated
            , pageIndex = state.pagination.pageIndex
            , pageCount = Table.getPageCount config state current.prePaginated
            , pageSize = state.pagination.pageSize
            , pageSizes = [ 10, 20, 30, 40, 50 ]
            , showAll = False
            }
        , div [] [ text (Controls.formatInt (List.length current.paginated.rows) ++ " Rows") ]
        , Controls.stateDump state
        ]


viewHeaderCell : Model -> Stages -> Table.Header Person -> Html Msg
viewHeaderCell model current header =
    let
        columnId : String
        columnId =
            Table.headerColumnId header

        label : String
        label =
            Table.findColumn config columnId
                |> Maybe.andThen Table.columnHeader
                |> Maybe.withDefault columnId
    in
    th [ colspan (Table.headerColSpan header) ]
        [ div []
            [ if columnId == "firstName" then
                span []
                    [ checkbox
                        (Table.getIsAllRowsSelected config model.state current.filtered)
                        (Table.getIsSomeRowsSelected model.state)
                        AllRowsSelectionToggled
                    , text " "
                    , button [ onClick AllRowsExpandToggled ]
                        [ text
                            (if Table.getIsAllRowsExpanded config model.state current.prePaginated then
                                "👇"

                             else
                                "👉"
                            )
                        ]
                    , text (" " ++ label)
                    ]

              else
                text label
            , if Table.getCanFilter config columnId then
                div [] [ viewFilter model columnId ]

              else
                text ""
            ]
        ]


viewFilter : Model -> String -> Html Msg
viewFilter model columnId =
    let
        filterValue : Value
        filterValue =
            Maybe.withDefault Value.Null (Table.getFilterValue model.state columnId)
    in
    if isNumericColumn columnId then
        div [ class "filter-row" ]
            [ rangeInput columnId filterValue 0 "Min"
            , rangeInput columnId filterValue 1 "Max"
            ]

    else
        input
            [ type_ "text"
            , class "filter"
            , placeholder "Search..."
            , value (Value.toString filterValue)
            , onInput (Value.String >> FilterChanged columnId)
            ]
            []


rangeInput : String -> Value -> Int -> String -> Html Msg
rangeInput columnId filterValue index hint =
    input
        [ type_ "number"
        , class "filter"
        , placeholder hint
        , value (rangeEnd index filterValue)
        , onInput (\typed -> FilterChanged columnId (setRangeEnd index typed filterValue))
        ]
        []


rangeEnd : Int -> Value -> String
rangeEnd index v =
    case v of
        Value.List items ->
            List.drop index items
                |> List.head
                |> Maybe.map Value.toString
                |> Maybe.withDefault ""

        _ ->
            ""


setRangeEnd : Int -> String -> Value -> Value
setRangeEnd index typed v =
    let
        other : String
        other =
            rangeEnd (1 - index) v
    in
    if index == 0 then
        Value.List [ Value.String typed, Value.String other ]

    else
        Value.List [ Value.String other, Value.String typed ]


viewRow : Model -> Stages -> Table.Row Person -> Html Msg
viewRow model current row =
    let
        displayIndex : Int
        displayIndex =
            Table.displayIndex config model.state current.prePaginated row
    in
    tr []
        (List.map (viewCell model row displayIndex)
            (Table.getAllCells config model.state row)
        )


viewCell : Model -> Table.Row Person -> Int -> Table.Cell -> Html Msg
viewCell model row displayIndex cell =
    if cell.columnId == "rowNumber" then
        td [] [ text (String.fromInt (displayIndex + 1)) ]

    else if cell.columnId == "firstName" then
        td []
            [ div
                [ class "indent"
                , style "padding-left" (String.fromInt (2 * Table.rowDepth row) ++ "rem")
                ]
                [ checkbox
                    (Table.getIsRowSelected model.state row
                        || (Table.getCanSelectSubRows config row
                                && Table.getIsAllSubRowsSelected config model.state row
                           )
                    )
                    (Table.getIsSomeSelected config model.state row)
                    (RowSelectionToggled row)
                , text " "
                , if Table.getCanExpand config row then
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
                , text (" " ++ Value.toString cell.value)
                ]
            ]

    else
        td [] [ text (Controls.valueToString cell.value) ]


{-| `<IndeterminateCheckbox>`: `indeterminate` is a DOM property, not an
attribute, so it is set with `Html.Attributes.property`.
-}
checkbox : Bool -> Bool -> Msg -> Html Msg
checkbox isChecked isIndeterminate msg =
    input
        [ type_ "checkbox"
        , checked isChecked
        , property "indeterminate" (Encode.bool (isIndeterminate && not isChecked))
        , onClick msg
        ]
        []


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
