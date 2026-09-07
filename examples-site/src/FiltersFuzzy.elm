module FiltersFuzzy exposing (main)

{-| Ports `examples/react/filters-fuzzy/src/main.tsx`.

`Shared.Fuzzy` replaces `@tanstack/match-sorter-utils`: `rankItem` scores a
value against the search text and `compareRankings` orders two scores.

The `fullName` column filters with that ranking through
`Table.withCustomFilter` and sorts with it through `Table.withCustomSort`,
falling back to `SortFn.alphanumeric` when two ranks tie. The search box at
the top is the global filter, which runs the same ranking over every column.

There is no `columnFiltersMeta` in this port, so the sort cannot read a rank
that filtering left behind: the config is a function of the current search
text instead, and the comparison re-ranks. Like the React example's effect,
typing in the `fullName` filter switches the sort to `fullName`.

-}

import Browser
import Html exposing (Html, button, div, input, span, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, colspan, placeholder, type_, value)
import Html.Events exposing (onClick, onInput)
import Shared.Controls as Controls
import Shared.Fuzzy as Fuzzy
import Shared.People as People exposing (Person)
import Table
import Table.FilterFn as FilterFn exposing (FilterFn)
import Table.SortFn as SortFn
import Table.Value as Value exposing (Value)



-- CONFIG


{-| The column list depends on the current `fullName` search, because the
fuzzy sort has to rank against it.
-}
config : String -> Table.Config Person
config search =
    Table.config
        [ Table.column "id" (.id >> Value.String)
            -- normal non-fuzzy filter column: exact match required
            |> Table.withFilterFn FilterFn.equalsString
        , Table.column "firstName" (.firstName >> Value.String)
            -- normal non-fuzzy filter column: case sensitive
            |> Table.withFilterFn FilterFn.includesStringSensitive
        , Table.column "lastName" (.lastName >> maybeString)
            |> Table.withHeader "Last Name"
            -- normal non-fuzzy filter column: case insensitive
            |> Table.withFilterFn FilterFn.includesString
        , Table.column "fullName" (fullName >> Value.String)
            |> Table.withHeader "Full Name"
            |> Table.withCustomFilter fuzzyFilter
            |> Table.withCustomSort (fuzzySort search)
        ]
        |> Table.withGlobalFilterFn fuzzyGlobalFilter
        |> Table.withGetRowId (\person _ _ -> person.id)


fullName : Person -> String
fullName person =
    person.firstName ++ " " ++ Maybe.withDefault "" person.lastName


{-| `fuzzyFilter`: keep the row when the ranking passes.
-}
fuzzyFilter : Table.Row Person -> Value -> Bool
fuzzyFilter row filterValue =
    (Fuzzy.rankItem (fullName (Table.rowOriginal row)) (Value.toString filterValue)).passed


{-| The same ranking as a `FilterFn`, which is what a global filter takes.
-}
fuzzyGlobalFilter : FilterFn
fuzzyGlobalFilter =
    FilterFn.custom
        (\dataValue filterValue ->
            (Fuzzy.rankItem (Value.toString dataValue) (Value.toString filterValue)).passed
        )


{-| `fuzzySort`: rank first, alphanumeric as the tie-break.
-}
fuzzySort : String -> Table.Row Person -> Table.Row Person -> Order
fuzzySort search rowA rowB =
    let
        nameA : String
        nameA =
            fullName (Table.rowOriginal rowA)

        nameB : String
        nameB =
            fullName (Table.rowOriginal rowB)
    in
    case Fuzzy.compareRankings (Fuzzy.rankItem nameA search) (Fuzzy.rankItem nameB search) of
        EQ ->
            SortFn.compare SortFn.alphanumeric (Value.String nameA) (Value.String nameB)

        order ->
            order


maybeString : Maybe String -> Value
maybeString =
    Maybe.map Value.String >> Maybe.withDefault Value.Null



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


{-| The `fullName` filter text the fuzzy sort ranks against.
-}
searchOf : Model -> String
searchOf model =
    Table.getFilterValue model.state "fullName"
        |> Maybe.map Value.toString
        |> Maybe.withDefault ""


configOf : Model -> Table.Config Person
configOf model =
    config (searchOf model)


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
            configOf model

        core : Table.RowModel Person
        core =
            Table.coreRowModelFromList cfg model.state model.data

        prePaginated : Table.RowModel Person
        prePaginated =
            core
                |> Table.filteredRowModel cfg model.state
                |> Table.groupedRowModel cfg model.state
                |> Table.sortedRowModel cfg model.state
                |> Table.expandedRowModel cfg model.state
    in
    { core = core
    , prePaginated = prePaginated
    , paginated = Table.paginatedRowModel cfg model.state prePaginated
    }



-- UPDATE


type Msg
    = RegenerateData
    | GlobalFilterChanged String
    | FilterChanged String String
    | SortClicked String Bool
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

        GlobalFilterChanged typed ->
            { model | state = Table.setGlobalFilter (Value.String typed) model.state }

        FilterChanged columnId typed ->
            let
                filtered : Table.State
                filtered =
                    Table.setColumnFilter (configOf model)
                        (stages model).core
                        columnId
                        (Value.String typed)
                        model.state
            in
            -- The React example's effect: filtering by fullName sorts by it.
            { model
                | state =
                    if columnId == "fullName" && typed /= "" then
                        Table.setSorting [ { id = "fullName", desc = False } ] filtered

                    else
                        filtered
            }

        SortClicked columnId multi ->
            { model
                | state =
                    Table.toggleSort (configOf model)
                        (stages model).core
                        columnId
                        { desc = Nothing, multi = multi }
                        model.state
            }

        FirstPage ->
            { model | state = Table.firstPage (configOf model) model.state }

        PreviousPage ->
            { model | state = Table.previousPage (configOf model) model.state }

        NextPage ->
            { model | state = Table.nextPage (configOf model) model.state }

        LastPage ->
            { model
                | state =
                    Table.lastPage (configOf model) model.state (stages model).prePaginated
            }

        GoToPage typed ->
            { model
                | state =
                    Table.setPage (configOf model)
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
        cfg : Table.Config Person
        cfg =
            configOf model

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
        , div []
            [ input
                [ type_ "text"
                , class "filter-wide"
                , placeholder "Search all columns..."
                , value (Value.toString state.globalFilter)
                , onInput GlobalFilterChanged
                ]
                []
            ]
        , div [ class "spacer-sm" ] []
        , table []
            [ thead []
                [ tr [] (List.map (viewHeaderCell model cfg) (Table.flatHeaders cfg state)) ]
            , tbody [] (List.map (viewRow cfg state) current.paginated.rows)
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
            , canNext = Table.getCanNextPage cfg state current.prePaginated
            , canLast = Table.getCanLastPage cfg state current.prePaginated
            , pageIndex = state.pagination.pageIndex
            , pageCount = Table.getPageCount cfg state current.prePaginated
            , pageSize = state.pagination.pageSize
            , pageSizes = [ 10, 20, 30, 40, 50 ]
            , showAll = False
            }
        , div [] [ text (Controls.formatInt (List.length current.prePaginated.rows) ++ " Rows") ]
        , Controls.stateDump state
        ]


viewHeaderCell : Model -> Table.Config Person -> Table.Header Person -> Html Msg
viewHeaderCell model cfg header =
    let
        columnId : String
        columnId =
            Table.headerColumnId header
    in
    th [ colspan (Table.headerColSpan header) ]
        [ span
            [ class "sortable", Controls.onClickShift (SortClicked columnId) ]
            [ text
                ((Table.findColumn cfg columnId
                    |> Maybe.andThen Table.columnHeader
                    |> Maybe.withDefault columnId
                 )
                    ++ Controls.sortArrow (Table.getIsSorted model.state columnId)
                )
            ]
        , div []
            [ input
                [ type_ "text"
                , class "filter"
                , placeholder "Search..."
                , value
                    (Table.getFilterValue model.state columnId
                        |> Maybe.map Value.toString
                        |> Maybe.withDefault ""
                    )
                , onInput (FilterChanged columnId)
                ]
                []
            ]
        ]


viewRow : Table.Config Person -> Table.State -> Table.Row Person -> Html Msg
viewRow cfg state row =
    tr []
        (List.map (\cell -> td [] [ text (Controls.valueToString cell.value) ])
            (Table.getAllCells cfg state row)
        )


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
