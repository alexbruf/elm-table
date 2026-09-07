module Sorting exposing (..)

import Html exposing (Html, text, th)
import Html.Events exposing (onClick)
import Shared.People exposing (Person, people)
import Table
import Table.SortFn as SortFn
import Table.Value as Value


columns : List (Table.Column Person)
columns =
    [ Table.column "firstName" (.firstName >> Value.String)
        |> Table.withHeader "First name"
        |> Table.withSortFn SortFn.text
    , Table.column "lastName" (.lastName >> Value.String)
        |> Table.withHeader "Last name"
        |> Table.withSortFn SortFn.alphanumeric
    , Table.column "age" (.age >> toFloat >> Value.Number)
        |> Table.withHeader "Age"
        |> Table.withSortFn SortFn.basic
    , Table.column "id" (.id >> Value.String)
        |> Table.withHeader "ID"
        |> Table.withEnableSorting False
    ]


config : Table.Config Person
config =
    Table.config columns
        |> Table.withGetRowId (\person _ _ -> person.id)


sortedRows : Table.State -> Table.RowModel Person
sortedRows state =
    Table.coreRowModelFromList config state people
        |> Table.filteredRowModel config state
        |> Table.sortedRowModel config state


filteredRows : Table.State -> Table.RowModel Person
filteredRows state =
    Table.coreRowModelFromList config state people
        |> Table.filteredRowModel config state


sortLimitedConfig : Table.Config Person
sortLimitedConfig =
    let
        base : Table.Config Person
        base =
            Table.config columns
    in
    { base
        | maxMultiSortColCount = 3
        , enableSortingRemoval = False
        , sortDescFirst = Just True
    }


rankColumn : Table.Column Person
rankColumn =
    Table.column "rank" (.age >> toFloat >> Value.Number)
        |> Table.withHeader "Rank"
        |> Table.withInvertSorting True


nullableColumn : Table.Column Person
nullableColumn =
    Table.column "bonus"
        (\person ->
            if person.active then
                Value.Number person.salary

            else
                Value.Null
        )
        |> Table.withHeader "Bonus"
        |> Table.withSortUndefined Table.sortNullsLast


byLastNameColumn : Table.Column Person
byLastNameColumn =
    Table.column "fullName"
        (\person -> Value.String (person.firstName ++ " " ++ person.lastName))
        |> Table.withHeader "Name"
        |> Table.withCustomSort
            (\rowA rowB ->
                Basics.compare
                    (Table.rowOriginal rowA).lastName
                    (Table.rowOriginal rowB).lastName
            )


lastWord : SortFn.SortFn
lastWord =
    SortFn.custom (\a b -> Basics.compare (Value.toString a) (Value.toString b))
        |> SortFn.withResolveDataValue
            (\value ->
                Value.toString value
                    |> String.split " "
                    |> List.reverse
                    |> List.head
                    |> Maybe.withDefault ""
                    |> Value.String
            )


type Msg
    = HeaderClicked String Bool
    | SortCleared


update : Msg -> Table.State -> Table.State
update msg state =
    case msg of
        HeaderClicked columnId shiftHeld ->
            Table.toggleSort config
                (filteredRows state)
                columnId
                { desc = Nothing, multi = shiftHeld }
                state

        SortCleared ->
            Table.resetSorting state


viewSortHeader : Table.State -> Table.Column Person -> Html Msg
viewSortHeader state column =
    let
        id : String
        id =
            Table.columnId column

        label : String
        label =
            Maybe.withDefault id (Table.columnHeader column)

        arrow : String
        arrow =
            case Table.getIsSorted state id of
                Nothing ->
                    ""

                Just dir ->
                    if dir == Table.sortAsc then
                        " ↑"

                    else
                        " ↓"

        badge : String
        badge =
            if List.length state.sorting > 1 && Table.getSortIndex state id >= 0 then
                " " ++ String.fromInt (Table.getSortIndex state id + 1)

            else
                ""
    in
    if Table.getCanSort config id then
        th [ onClick (HeaderClicked id (Table.getCanMultiSort config id)) ]
            [ text (label ++ arrow ++ badge) ]

    else
        th [] [ text label ]


nextSortLabel : Table.State -> String -> String
nextSortLabel state columnId =
    case Table.getNextSortingOrder config (filteredRows state) state columnId False of
        Nothing ->
            "Clear sort"

        Just dir ->
            if dir == Table.sortAsc then
                "Sort ascending"

            else
                "Sort descending"
