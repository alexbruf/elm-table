module GlobalFiltering exposing (..)

import Html exposing (Html, input)
import Html.Attributes exposing (placeholder, value)
import Html.Events exposing (onInput)
import Shared.People exposing (Person, people)
import Table
import Table.FilterFn as FilterFn
import Table.Value as Value


columns : List (Table.Column Person)
columns =
    [ Table.column "firstName" (.firstName >> Value.String)
        |> Table.withHeader "First name"
    , Table.column "lastName" (.lastName >> Value.String)
        |> Table.withHeader "Last name"
    , Table.column "department" (.department >> Value.String)
        |> Table.withHeader "Department"
    , Table.column "id" (.id >> Value.String)
        |> Table.withHeader "ID"
        |> Table.withEnableGlobalFilter False
    ]


config : Table.Config Person
config =
    Table.config columns
        |> Table.withGetRowId (\person _ _ -> person.id)
        |> Table.withGlobalFilterFn FilterFn.includesString


unfilteredRows : Table.State -> Table.RowModel Person
unfilteredRows state =
    Table.coreRowModelFromList config state people


filteredRows : Table.State -> Table.RowModel Person
filteredRows state =
    Table.filteredRowModel config state (unfilteredRows state)


namesOnlyConfig : Table.Config Person
namesOnlyConfig =
    let
        base : Table.Config Person
        base =
            Table.config columns
    in
    { base
        | getColumnCanGlobalFilter =
            Just
                (\column ->
                    List.member (Table.columnId column) [ "firstName", "lastName" ]
                )
    }


type Msg
    = SearchTyped String
    | SearchCleared


update : Msg -> Table.State -> Table.State
update msg state =
    case msg of
        SearchTyped typed ->
            Table.setGlobalFilter (Value.String typed) state

        SearchCleared ->
            Table.resetGlobalFilter state


viewSearchInput : Table.State -> Html Msg
viewSearchInput state =
    input
        [ value (Value.toString state.globalFilter)
        , placeholder "Search"
        , onInput SearchTyped
        ]
        []


searchedColumnIds : Table.State -> List String
searchedColumnIds state =
    Table.leafColumns config
        |> List.map Table.columnId
        |> List.filter (Table.getCanGlobalFilter config (unfilteredRows state))
