module Pagination exposing (main)

{-| Ports `examples/react/pagination/src/main.tsx`.

Client-side pagination: `Table.paginatedRowModel` slices the pre-pagination
row model, and every control below reads or writes `State.pagination`. The
React example keeps its manual-pagination options commented out, so this one
does too.

-}

import Browser
import Html exposing (Html, button, div, table, tbody, td, text, th, thead, tr)
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
        [ Table.display "rowNumber"
            |> Table.withHeader "#"
        , Table.column "firstName" (.firstName >> Value.String)
            |> Table.withFooter "firstName"
        , Table.column "lastName" (.lastName >> maybeString)
            |> Table.withHeader "Last Name"
            |> Table.withFooter "lastName"
        , Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
            |> Table.withFooter "age"
        , Table.column "visits" (.visits >> maybeNumber)
            |> Table.withHeader "Visits"
            |> Table.withFooter "visits"
        , Table.column "status" (.status >> People.statusToString >> Value.String)
            |> Table.withHeader "Status"
            |> Table.withFooter "status"
        , Table.column "progress" (.progress >> toFloat >> Value.Number)
            |> Table.withHeader "Profile Progress"
            |> Table.withFooter "progress"
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
    1000


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
    { prePaginated : Table.RowModel Person
    , paginated : Table.RowModel Person
    }


stages : Model -> Stages
stages model =
    let
        prePaginated : Table.RowModel Person
        prePaginated =
            Table.coreRowModelFromList config model.state model.data
                |> Table.filteredRowModel config model.state
                |> Table.groupedRowModel config model.state
                |> Table.sortedRowModel config model.state
                |> Table.expandedRowModel config model.state
    in
    { prePaginated = prePaginated
    , paginated = Table.paginatedRowModel config model.state prePaginated
    }



-- UPDATE


type Msg
    = RegenerateData
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
    div []
        [ div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ] ]
        , div [ class "demo-root" ]
            [ div [ class "spacer-sm" ] []
            , table []
                [ thead [] (List.map viewHeaderRow (Table.headerGroups config state))
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
                , showAll = True
                }
            , div []
                [ text
                    ("Showing "
                        ++ Controls.formatInt (List.length current.paginated.rows)
                        ++ " of "
                        ++ Controls.formatInt (Table.getRowCount config current.prePaginated)
                        ++ " Rows"
                    )
                ]
            , Controls.stateDump state
            ]
        ]


viewHeaderRow : Table.HeaderGroup Person -> Html Msg
viewHeaderRow group =
    tr [] (List.map viewHeaderCell group.headers)


viewHeaderCell : Table.Header Person -> Html Msg
viewHeaderCell header =
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
        ]


viewRow : Model -> Stages -> Table.Row Person -> Html Msg
viewRow model current row =
    let
        -- `row.getDisplayIndex()`: the row's place in the pre-pagination row
        -- model, so the numbering runs on across pages.
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
