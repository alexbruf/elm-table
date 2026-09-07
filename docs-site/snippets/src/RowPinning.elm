module RowPinning exposing (..)

import Html exposing (Html, button, td, text)
import Html.Attributes exposing (disabled)
import Html.Events exposing (onClick)
import Shared.People exposing (Person, people)
import Table
import Table.Value as Value


columns : List (Table.Column Person)
columns =
    [ Table.column "firstName" (.firstName >> Value.String)
        |> Table.withHeader "First name"
    , Table.column "department" (.department >> Value.String)
        |> Table.withHeader "Department"
    ]


config : Table.Config Person
config =
    Table.config columns
        |> Table.withGetRowId (\person _ _ -> person.id)


activeRowsOnly : Table.Config Person
activeRowsOnly =
    { config | enableRowPinning = \row -> (Table.rowOriginal row).active }


dropFilteredOutPins : Table.Config Person
dropFilteredOutPins =
    { config | keepPinnedRows = False }


pinnedSource : Table.State -> Table.PinnedRowsSource Person
pinnedSource state =
    let
        beforePaging : Table.RowModel Person
        beforePaging =
            Table.coreRowModelFromList config state people
                |> Table.filteredRowModel config state
                |> Table.sortedRowModel config state
                |> Table.expandedRowModel config state
    in
    { prePaginated = beforePaging
    , current = Table.paginatedRowModel config state beforePaging
    }


displayRows : Table.State -> List (Table.Row Person)
displayRows state =
    let
        source : Table.PinnedRowsSource Person
        source =
            pinnedSource state
    in
    Table.topRows config state source
        ++ Table.centerRows state source.current
        ++ Table.bottomRows config state source


type Msg
    = ClickedPin Table.RowPinPosition (Table.Row Person)


update : Msg -> Table.State -> Table.State
update msg state =
    case msg of
        ClickedPin position row ->
            Table.pinRow position row state


pinWithLeafRows : Table.Row Person -> Table.State -> Table.State
pinWithLeafRows row state =
    Table.pinRowWith Table.pinnedTop
        { includeLeafRows = True, includeParentRows = False }
        (pinnedSource state).prePaginated
        row
        state


viewPinControls : Table.State -> Table.Row Person -> Html Msg
viewPinControls state row =
    if Table.getCanPinRow config row then
        td []
            [ pinButton "Top" Table.pinnedTop state row
            , pinButton "Center" Table.rowUnpinned state row
            , pinButton "Bottom" Table.pinnedBottom state row
            ]

    else
        td [] []


pinButton : String -> Table.RowPinPosition -> Table.State -> Table.Row Person -> Html Msg
pinButton label position state row =
    button
        [ onClick (ClickedPin position row)
        , disabled (Table.getIsRowPinned state row == position)
        ]
        [ text label ]


pinnedRowLabel : Table.State -> Table.Row Person -> String
pinnedRowLabel state row =
    let
        index : Int
        index =
            Table.getRowPinnedIndex config state (pinnedSource state) row
    in
    if index < 0 then
        ""

    else
        "pinned #" ++ String.fromInt (index + 1)
