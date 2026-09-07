module Migrating exposing (..)

import Dict
import Shared.People exposing (Person, people)
import Table
import Table.AggregationFn as AggregationFn
import Table.FilterFn as FilterFn
import Table.SortFn as SortFn
import Table.Value as Value


config : Table.Config Person
config =
    Table.config columns
        |> Table.withGetRowId (\person _ _ -> person.id)


columns : List (Table.Column Person)
columns =
    [ Table.column "firstName" (.firstName >> Value.String)
        |> Table.withHeader "First name"
        |> Table.withSortFn SortFn.text
        |> Table.withFilterFn FilterFn.includesString
    , Table.column "salary" (.salary >> Value.Number)
        |> Table.withHeader "Salary"
        |> Table.withAggregationFn AggregationFn.sum
    ]


nullsLastColumn : Table.Column Person
nullsLastColumn =
    Table.column "department" (.department >> Value.String)
        |> Table.withSortUndefined Table.sortNullsLast


sortByAge : Table.State -> Table.State
sortByAge state =
    Table.toggleSort config
        (Table.coreRowModelFromList config state people)
        "age"
        { desc = Nothing, multi = False }
        state


stopAfterSorting : Table.State -> Table.RowModel Person
stopAfterSorting state =
    Table.coreRowModelFromList config state people
        |> Table.filteredRowModel config state
        |> Table.groupedRowModel config state
        |> Table.sortedRowModel config state


backToMyStartSorting : Table.State -> Table.State
backToMyStartSorting state =
    Table.setSorting [ { id = "age", desc = True } ] state


everythingOnOnePage : Table.State -> Table.State
everythingOnOnePage state =
    Table.setPageSize Table.unlimitedPageSize state


expandEverything : Table.State -> Table.State
expandEverything state =
    Table.setExpanded Table.expandAll state


compareAges : Table.RowModel Person -> Value.Value -> Value.Value -> Order
compareAges model =
    SortFn.compare (Table.getSortFn config model "age")


leftPinnedColumns : Table.State -> List (Table.Column Person)
leftPinnedColumns state =
    Table.pinnedVisibleLeafColumns config state Table.leftColumnsRegion


selectTo : Table.RowModel Person -> String -> Table.Row Person -> Table.State -> Table.State
selectTo model anchorRowId row state =
    if Table.canSelectRange config state model anchorRowId row then
        Table.selectRange config model anchorRowId row True state

    else
        Table.toggleRowSelected config model row Nothing state


hasAggregatedValue : Table.Row Person -> String -> Bool
hasAggregatedValue row columnId =
    case Dict.get columnId (Table.rowAggregatedValues row) of
        Just Value.Null ->
            False

        Just _ ->
            True

        Nothing ->
            False
