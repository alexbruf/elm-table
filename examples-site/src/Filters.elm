module Filters exposing (main)

{-| Ports `examples/react/filters/src/main.tsx`.

One filter control per column, chosen by a `filterVariant` the column
carries: free text, a numeric range, a `<select>`, or a date range. Each one
writes `Table.setColumnFilter`, which drops the filter again as soon as its
value goes blank (`shouldAutoRemoveFilter`).

-}

import Browser
import Html exposing (Html, button, div, input, option, select, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, colspan, placeholder, selected, type_, value)
import Html.Events exposing (onClick, onInput)
import Shared.Controls as Controls
import Shared.People as People exposing (Person)
import Table
import Table.FilterFn as FilterFn
import Table.Value as Value exposing (Value)



-- CONFIG


{-| The React example hangs this off `columnDef.meta`; here it is a plain
lookup beside the config.
-}
type FilterVariant
    = TextFilter
    | RangeFilter
    | SelectFilter
    | DateRangeFilter


variantOf : String -> FilterVariant
variantOf columnId =
    case columnId of
        "age" ->
            RangeFilter

        "visits" ->
            RangeFilter

        "progress" ->
            RangeFilter

        "status" ->
            SelectFilter

        "createdAt" ->
            DateRangeFilter

        _ ->
            TextFilter


config : Table.Config Person
config =
    Table.config
        [ Table.display "rowNumber"
            |> Table.withHeader "#"
        , Table.column "firstName" (.firstName >> Value.String)
        , Table.column "lastName" (.lastName >> maybeString)
            |> Table.withHeader "Last Name"
        , Table.column "fullName" fullName
            |> Table.withHeader "Full Name"
        , Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
        , Table.column "visits" (.visits >> maybeNumber)
            |> Table.withHeader "Visits"
        , Table.column "status" (.status >> People.statusToString >> Value.String)
            |> Table.withHeader "Status"
            |> Table.withFilterFn FilterFn.equalsString
        , Table.column "progress" (.progress >> toFloat >> Value.Number)
            |> Table.withHeader "Profile Progress"
            |> Table.withFilterFn FilterFn.inNumberRange

        -- `Shared.People.Person` carries `createdAt` where the React example's
        -- `makeData` carries `birthDate`; the column is otherwise the same.
        , Table.column "createdAt" (.createdAt >> Value.Date)
            |> Table.withHeader "Created At"
            |> Table.withFilterFn FilterFn.inDateRange
        ]
        |> Table.withGetRowId (\person _ _ -> person.id)


fullName : Person -> Value
fullName person =
    Value.String (person.firstName ++ " " ++ Maybe.withDefault "" person.lastName)


maybeString : Maybe String -> Value
maybeString =
    Maybe.map Value.String >> Maybe.withDefault Value.Null


maybeNumber : Maybe Int -> Value
maybeNumber =
    Maybe.map (toFloat >> Value.Number) >> Maybe.withDefault Value.Null



-- MODEL


rowCount : Int
rowCount =
    5000


type alias Model =
    { state : Table.State
    , seed : Int
    , data : List Person
    }


init : Model
init =
    { state = Table.initialState
    , seed = 42
    , data = People.makeData 42 [ rowCount ]
    }


type alias Stages =
    { core : Table.RowModel Person
    , prePaginated : Table.RowModel Person
    , paginated : Table.RowModel Person
    }


stages : Model -> Stages
stages model =
    let
        core : Table.RowModel Person
        core =
            Table.coreRowModelFromList config model.state model.data

        prePaginated : Table.RowModel Person
        prePaginated =
            core
                |> Table.filteredRowModel config model.state
                |> Table.groupedRowModel config model.state
                |> Table.sortedRowModel config model.state
                |> Table.expandedRowModel config model.state
    in
    { core = core
    , prePaginated = prePaginated
    , paginated = Table.paginatedRowModel config model.state prePaginated
    }



-- UPDATE


type Msg
    = RegenerateData
    | FilterChanged String Value
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
            { model | seed = seed, data = People.makeData seed [ rowCount ] }

        FilterChanged columnId v ->
            { model
                | state =
                    Table.setColumnFilter config (stages model).core columnId v model.state
            }

        FirstPage ->
            { model | state = Table.firstPage config model.state }

        PreviousPage ->
            { model | state = Table.previousPage config model.state }

        NextPage ->
            { model | state = Table.nextPage config model.state }

        LastPage ->
            { model | state = Table.lastPage config model.state (stages model).prePaginated }

        GoToPage text ->
            { model
                | state =
                    Table.setPage config
                        (Maybe.withDefault 1 (String.toInt text) - 1)
                        model.state
            }

        SetPageSize text ->
            { model
                | state = Table.setPageSize (Maybe.withDefault 10 (String.toInt text)) model.state
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
        , table []
            [ thead []
                [ tr []
                    (List.map (viewHeaderCell model) (Table.flatHeaders config state))
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
        , div [] [ text (Controls.formatInt (List.length current.prePaginated.rows) ++ " Rows") ]
        , Controls.stateDump state
        ]


viewHeaderCell : Model -> Table.Header Person -> Html Msg
viewHeaderCell model header =
    let
        columnId : String
        columnId =
            Table.headerColumnId header
    in
    th [ colspan (Table.headerColSpan header) ]
        [ div []
            [ text
                (Table.findColumn config columnId
                    |> Maybe.andThen Table.columnHeader
                    |> Maybe.withDefault columnId
                )
            ]
        , if Table.getCanFilter config columnId then
            div [] [ viewFilter model columnId ]

          else
            text ""
        ]


viewFilter : Model -> String -> Html Msg
viewFilter model columnId =
    let
        filterValue : Value
        filterValue =
            Maybe.withDefault Value.Null (Table.getFilterValue model.state columnId)
    in
    case variantOf columnId of
        DateRangeFilter ->
            div [ class "filter-row" ]
                [ rangeInput "date" columnId filterValue 0 ""
                , rangeInput "date" columnId filterValue 1 ""
                ]

        RangeFilter ->
            div [ class "filter-row" ]
                [ rangeInput "number" columnId filterValue 0 "Min"
                , rangeInput "number" columnId filterValue 1 "Max"
                ]

        SelectFilter ->
            select
                [ onInput (Value.String >> FilterChanged columnId)
                , Controls.onChange (Value.String >> FilterChanged columnId)
                ]
                (List.map (filterOption (Value.toString filterValue))
                    [ ( "", "All" )
                    , ( "complicated", "complicated" )
                    , ( "relationship", "relationship" )
                    , ( "single", "single" )
                    ]
                )

        TextFilter ->
            input
                [ type_ "text"
                , class "filter"
                , placeholder "Search..."
                , value (Value.toString filterValue)
                , onInput (Value.String >> FilterChanged columnId)
                ]
                []


filterOption : String -> ( String, String ) -> Html Msg
filterOption current ( optionValue, label ) =
    option [ value optionValue, selected (current == optionValue) ] [ text label ]


{-| One end of a two-part range filter value, `Value.List [ min, max ]`.
-}
rangeInput : String -> String -> Value -> Int -> String -> Html Msg
rangeInput inputType columnId filterValue index hint =
    input
        [ type_ inputType
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
        (List.map (viewCell displayIndex) (Table.getAllCells config model.state row))


viewCell : Int -> Table.Cell -> Html Msg
viewCell displayIndex cell =
    td []
        [ if cell.columnId == "rowNumber" then
            text (String.fromInt (displayIndex + 1))

          else
            text (Controls.valueToString cell.value)
        ]


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
