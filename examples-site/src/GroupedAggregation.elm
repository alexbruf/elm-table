module GroupedAggregation exposing (main)

{-| Ports `examples/react/grouped-aggregation/src/main.tsx`.

Grouping with an aggregation function per column: `median` for age, `sum` for
visits, `mean` for progress. A group row's cells carry the aggregate
(`Table.cellIsAggregated`), nested groups merge their children's results, and
the footer runs the same functions over the pre-grouped rows through
`Table.aggregationValue`.

-}

import Browser
import Html exposing (Html, button, div, table, tbody, td, text, tfoot, th, thead, tr)
import Html.Attributes exposing (class, classList, colspan)
import Html.Events exposing (onClick)
import Shared.Controls as Controls
import Shared.People as People exposing (Person)
import Table
import Table.AggregationFn as AggregationFn
import Table.Value as Value exposing (Value)



-- CONFIG


config : Table.Config Person
config =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First Name"
            |> Table.withFooter "Grand Total"
            -- override the value used for row grouping
            |> Table.withGetGroupingValue
                (\person _ ->
                    Value.String
                        (person.firstName ++ " " ++ Maybe.withDefault "" person.lastName)
                )
        , Table.column "lastName" (.lastName >> maybeString)
            |> Table.withHeader "Last Name"
        , Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
            |> Table.withAggregationFn AggregationFn.median
        , Table.column "visits" (.visits >> maybeNumber)
            |> Table.withHeader "Visits"
            |> Table.withAggregationFn AggregationFn.sum
        , Table.column "status" (.status >> People.statusToString >> Value.String)
            |> Table.withHeader "Status"
        , Table.column "progress" (.progress >> toFloat >> Value.Number)
            |> Table.withHeader "Profile Progress"
            |> Table.withAggregationFn AggregationFn.mean
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
    2000


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
    , preGrouped : Table.RowModel Person
    , prePaginated : Table.RowModel Person
    , paginated : Table.RowModel Person
    }


stages : Model -> Stages
stages model =
    let
        core : Table.RowModel Person
        core =
            Table.coreRowModelFromList config model.state model.data

        preGrouped : Table.RowModel Person
        preGrouped =
            Table.filteredRowModel config model.state core

        prePaginated : Table.RowModel Person
        prePaginated =
            preGrouped
                |> Table.groupedRowModel config model.state
                |> Table.sortedRowModel config model.state
                |> Table.expandedRowModel config model.state
    in
    { core = core
    , preGrouped = preGrouped
    , prePaginated = prePaginated
    , paginated = Table.paginatedRowModel config model.state prePaginated
    }



-- UPDATE


type Msg
    = RegenerateData
    | GroupingToggled String
    | ExpandToggled (Table.Row Person)
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

        GroupingToggled columnId ->
            { model | state = Table.toggleGrouping columnId model.state }

        ExpandToggled row ->
            { model
                | state =
                    Table.toggleExpanded config (stages model).prePaginated row Nothing model.state
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
                [ tr [] (List.map (viewHeaderCell state) (Table.flatHeaders config state)) ]
            , tbody [] (List.map (viewRow model current) current.paginated.rows)
            , tfoot []
                (List.map (viewFooterRow current) (Table.footerGroups config state))
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


viewHeaderCell : Table.State -> Table.Header Person -> Html Msg
viewHeaderCell state header =
    let
        columnId : String
        columnId =
            Table.headerColumnId header
    in
    th [ colspan (Table.headerColSpan header) ]
        [ div []
            [ if Table.getCanGroup config columnId then
                button [ class "small", onClick (GroupingToggled columnId) ]
                    [ text
                        (if Table.getIsGrouped state columnId then
                            "🛑(" ++ String.fromInt (Table.getGroupedIndex state columnId) ++ ") "

                         else
                            "👊 "
                        )
                    ]

              else
                text ""
            , text (" " ++ headerLabel columnId)
            ]
        ]


headerLabel : String -> String
headerLabel columnId =
    Table.findColumn config columnId
        |> Maybe.andThen Table.columnHeader
        |> Maybe.withDefault columnId


{-| The footer runs each column's aggregation function over the pre-grouped
rows, which is what `column.getAggregationValue()` with no arguments does.
-}
viewFooterRow : Stages -> Table.HeaderGroup Person -> Html Msg
viewFooterRow current group =
    tr [] (List.map (viewFooterCell current) group.headers)


viewFooterCell : Stages -> Table.Header Person -> Html Msg
viewFooterCell current header =
    let
        columnId : String
        columnId =
            Table.headerColumnId header
    in
    th [ colspan (Table.headerColSpan header) ]
        [ text
            (case Table.findColumn config columnId |> Maybe.andThen Table.columnFooter of
                Just footer ->
                    footer

                Nothing ->
                    aggregatedText columnId
                        (Table.aggregationValue config current.preGrouped columnId)
            )
        ]


viewRow : Model -> Stages -> Table.Row Person -> Html Msg
viewRow model current row =
    tr []
        (List.map (viewCell model current row) (Table.getAllCells config model.state row))


viewCell : Model -> Stages -> Table.Row Person -> Table.Cell -> Html Msg
viewCell model current row cell =
    let
        state : Table.State
        state =
            model.state

        isGrouped : Bool
        isGrouped =
            Table.cellIsGrouped state row cell.columnId

        isAggregated : Bool
        isAggregated =
            Table.cellIsAggregated config current.core state row cell.columnId

        isPlaceholder : Bool
        isPlaceholder =
            Table.cellIsPlaceholder state row cell.columnId
    in
    td
        [ classList
            [ ( "grouped", isGrouped )
            , ( "aggregated", isAggregated && not isGrouped )
            , ( "placeholder", isPlaceholder && not isGrouped && not isAggregated )
            ]
        ]
        [ if isGrouped then
            button [ class "sortable", onClick (ExpandToggled row) ]
                [ text
                    ((if Table.getIsExpanded config state row then
                        "👇 "

                      else
                        "👉 "
                     )
                        ++ cellText cell
                        ++ " ("
                        ++ Controls.formatInt (List.length (Table.rowSubRows row))
                        ++ ")"
                    )
                ]

          else if isAggregated then
            -- the aggregated renderer of the cell
            text (aggregatedText cell.columnId cell.value)

          else if isPlaceholder then
            text ""

          else
            text (cellText cell)
        ]


{-| `aggregatedCell` per column.
-}
aggregatedText : String -> Value -> String
aggregatedText columnId value =
    case ( columnId, value ) of
        ( _, Value.Null ) ->
            ""

        ( "age", _ ) ->
            Controls.round2 (Value.toNumber value)

        ( "visits", _ ) ->
            Controls.formatInt (round (Value.toNumber value))

        ( "progress", _ ) ->
            Controls.round2 (Value.toNumber value) ++ "%"

        _ ->
            Controls.valueToString value


cellText : Table.Cell -> String
cellText cell =
    if cell.columnId == "progress" then
        Controls.round2 (Value.toNumber cell.value) ++ "%"

    else
        Controls.valueToString cell.value


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
