module BasicExternalState exposing (main)

{-| Ports `examples/react/basic-external-state/src/main.tsx`.

The React example lifts `sorting` and `pagination` into React state and
passes them back down. In Elm every table's state is external already: the
whole `Table.State` lives in the model below, the pipeline reads it, and
nothing else holds a copy. So the page shows the state, dumps it as JSON,
and drives it from outside the table with the buttons above the table.

-}

import Browser
import Html exposing (Html, button, div, h2, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, colspan)
import Html.Events exposing (onClick)
import Shared.Controls as Controls
import Shared.People as People exposing (Person)
import Table
import Table.Value as Value exposing (Value)



-- CONFIG


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
    , seed : Int
    , data : List Person
    }


rowCount : Int
rowCount =
    1000


init : Model
init =
    let
        state : Table.State
        state =
            Table.initialState
    in
    { state = { state | pagination = { pageIndex = 0, pageSize = 10 } }
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
    | SortClicked String
    | FirstPage
    | PreviousPage
    | NextPage
    | LastPage
    | GoToPage String
    | SetPageSize String
    | SortAgeDescending
    | ClearSorting
    | JumpToPageFive
    | ResetState


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

        SortClicked columnId ->
            { model
                | state =
                    Table.toggleSort config
                        (stages model).core
                        columnId
                        { desc = Nothing, multi = False }
                        model.state
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

        -- The three buttons below write state from outside the table, which
        -- is what `setSorting` / `setPagination` do in the React example.
        SortAgeDescending ->
            { model | state = Table.setSorting [ { id = "age", desc = True } ] model.state }

        ClearSorting ->
            { model | state = Table.resetSorting model.state }

        JumpToPageFive ->
            { model | state = Table.setPagination { pageIndex = 4, pageSize = 25 } model.state }

        ResetState ->
            { model | state = init.state }



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
        , h2 [] [ text "Write the state from outside the table" ]
        , div [ class "button-row" ]
            [ button [ onClick SortAgeDescending ] [ text "setSorting age desc" ]
            , button [ onClick ClearSorting ] [ text "resetSorting" ]
            , button [ onClick JumpToPageFive ] [ text "setPagination page 5, size 25" ]
            , button [ onClick ResetState ] [ text "Reset state" ]
            ]
        , div [ class "spacer-md" ] []
        , table []
            [ thead [] (List.map (viewHeaderRow state) (Table.headerGroups config state))
            , tbody [] (List.map (viewRow state) current.paginated.rows)
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
        , div [ class "spacer-md" ] []
        , h2 [] [ text "Table.State in the model" ]
        , Controls.stateDump state
        ]


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
    th
        [ colspan (Table.headerColSpan header)
        , class "sortable"
        , onClick (SortClicked columnId)
        ]
        [ text (headerLabel columnId ++ Controls.sortArrow (Table.getIsSorted state columnId)) ]


headerLabel : String -> String
headerLabel columnId =
    Table.findColumn config columnId
        |> Maybe.andThen Table.columnHeader
        |> Maybe.withDefault columnId


viewRow : Table.State -> Table.Row Person -> Html Msg
viewRow state row =
    tr [] (List.map viewCell (Table.getAllCells config state row))


viewCell : Table.Cell -> Html Msg
viewCell cell =
    td [] [ text (Controls.valueToString cell.value) ]


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
