module FiltersFaceted exposing (main)

{-| Ports `examples/react/filters-faceted/src/main.tsx`.

The same per-column filters as the plain filters example, except that the
controls are built from the data: `Table.facetedMinMax` fills the range
placeholders and `Table.facetedUniqueValues` fills the `<select>` options and
the `<datalist>` suggestions. Both read the pre-filtered row model with every
_other_ column's filter applied, so the options track what is still
reachable.

-}

import Browser
import Html exposing (Html, button, datalist, div, input, option, select, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, colspan, id, list, placeholder, selected, type_, value)
import Html.Events exposing (onClick, onInput)
import Shared.Controls as Controls
import Shared.People as People exposing (Person)
import Table
import Table.FilterFn as FilterFn
import Table.Value as Value exposing (Value)



-- CONFIG


type FilterVariant
    = TextFilter
    | RangeFilter
    | SelectFilter


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

        _ ->
            TextFilter


config : Table.Config Person
config =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
        , Table.column "lastName" (.lastName >> maybeString)
            |> Table.withHeader "Last Name"
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
        ]
        |> Table.withGetRowId (\person _ _ -> person.id)


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
                    (List.map (viewHeaderCell model current) (Table.flatHeaders config state))
                ]
            , tbody [] (List.map (viewRow model) current.paginated.rows)
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


viewHeaderCell : Model -> Stages -> Table.Header Person -> Html Msg
viewHeaderCell model current header =
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
            div [] [ viewFilter model current columnId ]

          else
            text ""
        ]


viewFilter : Model -> Stages -> String -> Html Msg
viewFilter model current columnId =
    let
        filterValue : Value
        filterValue =
            Maybe.withDefault Value.Null (Table.getFilterValue model.state columnId)

        variant : FilterVariant
        variant =
            variantOf columnId

        uniqueValues : List String
        uniqueValues =
            if variant == RangeFilter then
                []

            else
                Table.facetedUniqueValues config model.state current.core columnId
                    |> List.map (Tuple.first >> Value.toString)
                    |> List.sort
                    |> List.take 5000
    in
    case variant of
        RangeFilter ->
            let
                minMax : Maybe ( Float, Float )
                minMax =
                    Table.facetedMinMax config model.state current.core columnId
            in
            div [ class "filter-row" ]
                [ rangeInput columnId filterValue 0 (bound "Min" (Maybe.map Tuple.first minMax))
                , rangeInput columnId filterValue 1 (bound "Max" (Maybe.map Tuple.second minMax))
                ]

        SelectFilter ->
            select
                [ onInput (Value.String >> FilterChanged columnId)
                , Controls.onChange (Value.String >> FilterChanged columnId)
                ]
                (option [ value "", selected (Value.toString filterValue == "") ] [ text "All" ]
                    :: List.map
                        (\v ->
                            option [ value v, selected (Value.toString filterValue == v) ]
                                [ text v ]
                        )
                        uniqueValues
                )

        TextFilter ->
            div []
                [ datalist [ id (columnId ++ "list") ]
                    (List.map (\v -> option [ value v ] []) uniqueValues)
                , input
                    [ type_ "text"
                    , class "filter"
                    , list (columnId ++ "list")
                    , value (Value.toString filterValue)
                    , placeholder
                        ("Search... (" ++ String.fromInt (List.length uniqueValues) ++ ")")
                    , onInput (Value.String >> FilterChanged columnId)
                    ]
                    []
                ]


bound : String -> Maybe Float -> String
bound name limit =
    case limit of
        Nothing ->
            name

        Just n ->
            name ++ " (" ++ Controls.round2 n ++ ")"


{-| One end of a two-part range filter value, `Value.List [ min, max ]`.
-}
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


viewRow : Model -> Table.Row Person -> Html Msg
viewRow model row =
    tr []
        (List.map (\cell -> td [] [ text (Controls.valueToString cell.value) ])
            (Table.getAllCells config model.state row)
        )


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
