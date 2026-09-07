module Pagination exposing (..)

import Html exposing (Html)
import Html.Attributes exposing (disabled, selected, value)
import Html.Events exposing (onClick, onInput)
import Shared.People exposing (Person, people)
import Table
import Table.Value as Value


columns : List (Table.Column Person)
columns =
    [ Table.column "firstName" (.firstName >> Value.String)
        |> Table.withHeader "First name"
    , Table.column "lastName" (.lastName >> Value.String)
        |> Table.withHeader "Last name"
    ]


config : Table.Config Person
config =
    Table.config columns
        |> Table.withGetRowId (\person _ _ -> person.id)


serverConfig : Int -> Table.Config Person
serverConfig totalRows =
    let
        base : Table.Config Person
        base =
            Table.config columns
    in
    { base | manualPagination = True, rowCount = Just totalRows }


startOnPageThree : Table.State
startOnPageThree =
    Table.setPagination { pageIndex = 2, pageSize = 25 } Table.initialState


showEveryRow : Table.State -> Table.State
showEveryRow =
    Table.setPageSize Table.unlimitedPageSize


prePagination : Table.State -> Table.RowModel Person
prePagination state =
    Table.coreRowModelFromList config state people
        |> Table.filteredRowModel config state
        |> Table.groupedRowModel config state
        |> Table.sortedRowModel config state
        |> Table.prePaginationRowModel config state


page : Table.State -> Table.RowModel Person
page state =
    Table.paginatedRowModel config state (prePagination state)


type Msg
    = FirstPageClicked
    | PreviousPageClicked
    | NextPageClicked
    | LastPageClicked
    | PageEntered String
    | PageSizeChanged String


update : Msg -> Table.State -> Table.State
update msg state =
    case msg of
        FirstPageClicked ->
            Table.firstPage config state

        PreviousPageClicked ->
            Table.previousPage config state

        NextPageClicked ->
            Table.nextPage config state

        LastPageClicked ->
            Table.lastPage config state (prePagination state)

        PageEntered typed ->
            case String.toInt typed of
                Just wanted ->
                    Table.setPage config (wanted - 1) state

                Nothing ->
                    state

        PageSizeChanged typed ->
            Table.setPageSize (Maybe.withDefault 10 (String.toInt typed)) state


viewPager : Table.State -> Html Msg
viewPager state =
    let
        before : Table.RowModel Person
        before =
            prePagination state
    in
    Html.div []
        [ Html.button
            [ onClick FirstPageClicked, disabled (not (Table.getCanPreviousPage state)) ]
            [ Html.text "<<" ]
        , Html.button
            [ onClick PreviousPageClicked, disabled (not (Table.getCanPreviousPage state)) ]
            [ Html.text "<" ]
        , Html.span []
            [ Html.text
                ("Page "
                    ++ String.fromInt (state.pagination.pageIndex + 1)
                    ++ " of "
                    ++ String.fromInt (Table.getPageCount config state before)
                )
            ]
        , Html.button
            [ onClick NextPageClicked, disabled (not (Table.getCanNextPage config state before)) ]
            [ Html.text ">" ]
        , Html.button
            [ onClick LastPageClicked, disabled (not (Table.getCanLastPage config state before)) ]
            [ Html.text ">>" ]
        , Html.input
            [ Html.Attributes.type_ "number"
            , value (String.fromInt (state.pagination.pageIndex + 1))
            , onInput PageEntered
            ]
            []
        , Html.select [ onInput PageSizeChanged ]
            (List.map (viewPageSizeOption state) [ 10, 20, 30, 40, 50 ])
        , Html.span []
            [ Html.text (String.fromInt (Table.getRowCount config before) ++ " rows") ]
        ]


viewPageSizeOption : Table.State -> Int -> Html Msg
viewPageSizeOption state size =
    Html.option
        [ value (String.fromInt size), selected (state.pagination.pageSize == size) ]
        [ Html.text (String.fromInt size ++ " per page") ]


viewPageJump : Table.State -> Html Msg
viewPageJump state =
    Html.select [ onInput PageEntered ]
        (List.map
            (\index ->
                Html.option
                    [ value (String.fromInt (index + 1))
                    , selected (index == state.pagination.pageIndex)
                    ]
                    [ Html.text (String.fromInt (index + 1)) ]
            )
            (Table.getPageOptions config state (prePagination state))
        )


displayPosition : Table.State -> Table.Row Person -> Int
displayPosition state row =
    Table.displayIndex config state (page state) row
