module Grouping exposing (main)

{-| Ports `examples/react/grouping/src/main.tsx`.

Click 👊 in a header to group by that column; the grouped columns move to the
front (`groupedColumnMode: 'reorder'`, the default) and each group row gets an
expander with its child count. `firstName` overrides the value it groups by
with `Table.withGetGroupingValue`, so two people with the same first name but
different last names land in different groups.

-}

import Browser
import Html exposing (Html, button, div, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, classList, colspan)
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
            -- override the value used for row grouping (otherwise, defaults to
            -- the value derived from the accessor)
            |> Table.withGetGroupingValue
                (\person _ ->
                    Value.String
                        (person.firstName ++ " " ++ Maybe.withDefault "" person.lastName)
                )
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
            , text
                (" "
                    ++ (Table.findColumn config columnId
                            |> Maybe.andThen Table.columnHeader
                            |> Maybe.withDefault columnId
                       )
                )
            ]
        ]


viewRow : Model -> Table.Row Person -> Html Msg
viewRow model row =
    tr []
        (List.map (viewCell model row) (Table.getAllCells config model.state row))


viewCell : Model -> Table.Row Person -> Table.Cell -> Html Msg
viewCell model row cell =
    let
        state : Table.State
        state =
            model.state

        isGrouped : Bool
        isGrouped =
            Table.cellIsGrouped state row cell.columnId

        isPlaceholder : Bool
        isPlaceholder =
            Table.cellIsPlaceholder state row cell.columnId
    in
    td
        [ classList
            [ ( "grouped", isGrouped )
            , ( "placeholder", isPlaceholder )
            ]
        ]
        [ if isGrouped then
            -- If it's a grouped cell, add an expander and row count
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

          else if isPlaceholder || Table.rowIsGrouped row then
            -- For cells with repeated values, render nothing
            text ""

          else
            text (cellText cell)
        ]


cellText : Table.Cell -> String
cellText cell =
    if cell.columnId == "progress" then
        Controls.round2 (Value.toNumber cell.value) ++ "%"

    else
        Controls.valueToString cell.value


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
