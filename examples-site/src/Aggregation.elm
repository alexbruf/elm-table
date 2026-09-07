module Aggregation exposing (main)

{-| Ports `examples/react/aggregation/src/main.tsx`.

Aggregation without grouping: the footers fold a column over a chosen set of
rows. The select picks which rows those are — the filtered ones (the
default), every core row, just this page, the filtered selection, or a
hand-picked three — and `Table.aggregationValueOf` takes that list.

`Amount` uses a scalar `sum`. `Score` is where the port differs: TanStack
lets one column carry several aggregation functions and returns a keyed
object, while `Table.withAggregationFn` takes one function, so the footer
folds `count`, `mean` and `extent` over the same rows itself with
`Table.AggregationFn`.

-}

import Aggregation.Sales as Sales exposing (Sale)
import Browser
import Html exposing (Html, button, div, h1, input, label, option, p, select, table, tbody, td, text, tfoot, th, thead, tr)
import Html.Attributes exposing (checked, class, colspan, selected, type_, value)
import Html.Events exposing (onClick, onInput)
import Shared.Controls as Controls
import Table
import Table.AggregationFn as AggregationFn exposing (AggregationFn)
import Table.FilterFn as FilterFn
import Table.Value as Value exposing (Value)



-- CONFIG


config : Table.Config Sale
config =
    Table.config
        [ Table.display "select"
        , Table.column "category" (.category >> Value.String)
            |> Table.withHeader "Category"
            |> Table.withFilterFn FilterFn.includesString
        , Table.column "item" (.item >> Value.String)
            |> Table.withHeader "Item"
        , Table.column "amount" (.amount >> Value.Number)
            |> Table.withHeader "Amount"
            |> Table.withAggregationFn AggregationFn.sum
        , Table.column "score" (.score >> Value.Number)
            |> Table.withHeader "Score"
            |> Table.withAggregationFn AggregationFn.mean
        ]
        |> Table.withGetRowId (\row _ _ -> row.id)



-- MODEL


rowCount : Int
rowCount =
    2000


{-| Which rows the footers aggregate.
-}
type RowSource
    = FilteredRows
    | AllRows
    | PageRows
    | SelectedRows
    | CustomRows


type alias Model =
    { state : Table.State
    , seed : Int
    , data : List Sale
    , rowSource : RowSource
    }


init : Model
init =
    let
        state : Table.State
        state =
            Table.initialState
    in
    { state = { state | pagination = { pageIndex = 0, pageSize = 10 } }
    , seed = 42
    , data = Sales.makeData 42 rowCount
    , rowSource = FilteredRows
    }


type alias Stages =
    { core : Table.RowModel Sale
    , filtered : Table.RowModel Sale
    , paginated : Table.RowModel Sale
    }


stages : Model -> Stages
stages model =
    let
        core : Table.RowModel Sale
        core =
            Table.coreRowModelFromList config model.state model.data

        filtered : Table.RowModel Sale
        filtered =
            Table.filteredRowModel config model.state core
    in
    { core = core
    , filtered = filtered
    , paginated = Table.paginatedRowModel config model.state filtered
    }


{-| `getAggregationRows`.
-}
aggregationRows : Model -> Stages -> List (Table.Row Sale)
aggregationRows model current =
    case model.rowSource of
        FilteredRows ->
            current.filtered.rows

        AllRows ->
            current.core.rows

        PageRows ->
            current.paginated.rows

        SelectedRows ->
            (Table.selectedRowModel model.state current.filtered).rows

        CustomRows ->
            List.take 3 current.core.rows


rowSourceLabel : RowSource -> String
rowSourceLabel source =
    case source of
        FilteredRows ->
            "Filtered rows"

        AllRows ->
            "All rows"

        PageRows ->
            "Visible page"

        SelectedRows ->
            "Filtered selected rows"

        CustomRows ->
            "First three core rows"


rowSourceKey : RowSource -> String
rowSourceKey source =
    case source of
        FilteredRows ->
            "filtered"

        AllRows ->
            "all"

        PageRows ->
            "page"

        SelectedRows ->
            "selected"

        CustomRows ->
            "custom"


rowSourceFromKey : String -> RowSource
rowSourceFromKey key =
    case key of
        "all" ->
            AllRows

        "page" ->
            PageRows

        "selected" ->
            SelectedRows

        "custom" ->
            CustomRows

        _ ->
            FilteredRows



-- UPDATE


type Msg
    = RegenerateData
    | RowSourcePicked String
    | CategoryFilterChanged String
    | RowSelectionToggled (Table.Row Sale)
    | AllPageRowsSelectionToggled
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
            { model | seed = seed, data = Sales.makeData seed rowCount }

        RowSourcePicked key ->
            { model | rowSource = rowSourceFromKey key }

        CategoryFilterChanged typed ->
            { model
                | state =
                    Table.setColumnFilter config
                        (stages model).core
                        "category"
                        (Value.String typed)
                        model.state
            }

        RowSelectionToggled row ->
            { model
                | state =
                    Table.toggleRowSelected config (stages model).core row Nothing model.state
            }

        AllPageRowsSelectionToggled ->
            { model
                | state =
                    Table.toggleAllPageRowsSelected config
                        (stages model).paginated
                        Nothing
                        model.state
            }

        FirstPage ->
            { model | state = Table.firstPage config model.state }

        PreviousPage ->
            { model | state = Table.previousPage config model.state }

        NextPage ->
            { model | state = Table.nextPage config model.state }

        LastPage ->
            { model | state = Table.lastPage config model.state (stages model).filtered }

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
        [ h1 [] [ text "Aggregation without grouping" ]
        , p [ class "muted" ]
            [ text "Amount uses a scalar sum. Score runs count, mean, and range over the same rows." ]
        , div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ] ]
        , div [ class "spacer-sm" ] []
        , div [ class "controls" ]
            [ label []
                [ text "Category filter: "
                , input
                    [ class "filter"
                    , value
                        (Table.getFilterValue state "category"
                            |> Maybe.map Value.toString
                            |> Maybe.withDefault ""
                        )
                    , onInput CategoryFilterChanged
                    ]
                    []
                ]
            , label []
                [ text "Total rows: "
                , select [ onInput RowSourcePicked, Controls.onChange RowSourcePicked ]
                    (List.map (rowSourceOption model)
                        [ FilteredRows, AllRows, PageRows, SelectedRows, CustomRows ]
                    )
                ]
            ]
        , div [ class "spacer-sm" ] []
        , table []
            [ thead []
                [ tr []
                    (List.map (viewHeaderCell model current) (Table.flatHeaders config state))
                ]
            , tbody [] (List.map (viewRow model) current.paginated.rows)
            , tfoot []
                (List.map (viewFooterRow model current) (Table.footerGroups config state))
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
            , canNext = Table.getCanNextPage config state current.filtered
            , canLast = Table.getCanLastPage config state current.filtered
            , pageIndex = state.pagination.pageIndex
            , pageCount = Table.getPageCount config state current.filtered
            , pageSize = state.pagination.pageSize
            , pageSizes = [ 10, 20, 30, 40, 50 ]
            , showAll = False
            }
        , div []
            [ text
                ("Showing "
                    ++ Controls.formatInt (List.length current.paginated.rows)
                    ++ " of "
                    ++ Controls.formatInt (Table.getRowCount config current.filtered)
                    ++ " Rows"
                )
            ]
        , Controls.stateDump state
        ]


rowSourceOption : Model -> RowSource -> Html Msg
rowSourceOption model source =
    option
        [ value (rowSourceKey source), selected (model.rowSource == source) ]
        [ text (rowSourceLabel source) ]


viewHeaderCell : Model -> Stages -> Table.Header Sale -> Html Msg
viewHeaderCell model current header =
    let
        columnId : String
        columnId =
            Table.headerColumnId header
    in
    th [ colspan (Table.headerColSpan header) ]
        [ if columnId == "select" then
            input
                [ type_ "checkbox"
                , checked (Table.getIsAllPageRowsSelected config model.state current.paginated)
                , onClick AllPageRowsSelectionToggled
                ]
                []

          else
            text
                (Table.findColumn config columnId
                    |> Maybe.andThen Table.columnHeader
                    |> Maybe.withDefault columnId
                )
        ]


viewFooterRow : Model -> Stages -> Table.HeaderGroup Sale -> Html Msg
viewFooterRow model current group =
    tr [] (List.map (viewFooterCell model current) group.headers)


viewFooterCell : Model -> Stages -> Table.Header Sale -> Html Msg
viewFooterCell model current header =
    let
        rows : List (Table.Row Sale)
        rows =
            aggregationRows model current
    in
    th [ colspan (Table.headerColSpan header) ]
        [ text
            (case Table.headerColumnId header of
                "item" ->
                    rowSourceKey model.rowSource ++ " total"

                "amount" ->
                    formatValue
                        (Table.aggregationValueOf config
                            current.core
                            "amount"
                            { maxDepth = 0, rows = rows }
                        )

                "score" ->
                    scoreSummary current rows

                _ ->
                    ""
            )
        ]


{-| The keyed object TanStack's multi-aggregation column returns, folded
here one function at a time.
-}
scoreSummary : Stages -> List (Table.Row Sale) -> String
scoreSummary current rows =
    let
        values : List Value
        values =
            List.map (\row -> Table.getValue config row "score") rows

        fold : AggregationFn -> String
        fold fn =
            formatValue (AggregationFn.aggregate fn values)
    in
    "count: "
        ++ fold AggregationFn.count
        ++ ", mean: "
        ++ fold AggregationFn.mean
        ++ ", range: "
        ++ fold AggregationFn.extent


{-| `formatValue`: an array prints as `a – b`, a number with at most two
decimals, and nothing at all as an em dash.
-}
formatValue : Value -> String
formatValue value =
    case value of
        Value.List items ->
            String.join " – " (List.map formatValue items)

        Value.Number n ->
            Controls.formatFloat n

        Value.Null ->
            "—"

        _ ->
            Value.toString value


viewRow : Model -> Table.Row Sale -> Html Msg
viewRow model row =
    tr [] (List.map (viewCell model row) (Table.getAllCells config model.state row))


viewCell : Model -> Table.Row Sale -> Table.Cell -> Html Msg
viewCell model row cell =
    td []
        [ case cell.columnId of
            "select" ->
                input
                    [ type_ "checkbox"
                    , checked (Table.getIsRowSelected model.state row)
                    , onClick (RowSelectionToggled row)
                    ]
                    []

            "amount" ->
                text (Controls.formatInt (round (Value.toNumber cell.value)))

            _ ->
                text (Controls.valueToString cell.value)
        ]


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
