module ColumnFiltering exposing (..)

import Html exposing (Html, input, text)
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
        |> Table.withFilterFn FilterFn.includesString
    , Table.column "department" (.department >> Value.String)
        |> Table.withHeader "Department"
        |> Table.withFilterFn FilterFn.equalsString
    , Table.column "age" (.age >> toFloat >> Value.Number)
        |> Table.withHeader "Age"
        |> Table.withFilterFn FilterFn.inNumberRange
    , Table.column "tags" (.tags >> List.map Value.String >> Value.List)
        |> Table.withHeader "Tags"
        |> Table.withFilterFn FilterFn.arrIncludesSome
    , Table.column "id" (.id >> Value.String)
        |> Table.withHeader "ID"
        |> Table.withEnableColumnFilter False
    ]


config : Table.Config Person
config =
    Table.config columns
        |> Table.withGetRowId (\person _ _ -> person.id)


unfilteredRows : Table.State -> Table.RowModel Person
unfilteredRows state =
    Table.coreRowModelFromList config state people


filteredRows : Table.State -> Table.RowModel Person
filteredRows state =
    Table.filteredRowModel config state (unfilteredRows state)


leafFilteringConfig : Table.Config Person
leafFilteringConfig =
    let
        base : Table.Config Person
        base =
            Table.config columns
    in
    { base
        | filterFromLeafRows = True
        , maxLeafRowFilterDepth = 1
    }


startsWithTrimmed : FilterFn.FilterFn
startsWithTrimmed =
    FilterFn.custom
        (\dataValue filterValue ->
            String.startsWith (Value.toString filterValue) (Value.toString dataValue)
        )
        |> FilterFn.withResolveFilterValue
            (Value.toString >> String.toLower >> String.trim >> Value.String)
        |> FilterFn.withResolveDataValue
            (Value.toString >> String.toLower >> Value.String)
        |> FilterFn.withAutoRemove (\filterValue -> Value.toString filterValue == "")


activeDepartmentColumn : Table.Column Person
activeDepartmentColumn =
    Table.column "department" (.department >> Value.String)
        |> Table.withHeader "Department"
        |> Table.withCustomFilter
            (\row filterValue ->
                let
                    person : Person
                    person =
                        Table.rowOriginal row
                in
                person.active
                    && String.contains
                        (String.toLower (Value.toString filterValue))
                        (String.toLower person.department)
            )


type Msg
    = FilterTyped String String
    | FiltersCleared


update : Msg -> Table.State -> Table.State
update msg state =
    case msg of
        FilterTyped columnId typed ->
            Table.setColumnFilter config
                (unfilteredRows state)
                columnId
                (Value.String typed)
                state

        FiltersCleared ->
            Table.resetColumnFilters state


viewFilterInput : Table.State -> Table.Column Person -> Html Msg
viewFilterInput state column =
    let
        id : String
        id =
            Table.columnId column

        current : String
        current =
            Table.getFilterValue state id
                |> Maybe.map Value.toString
                |> Maybe.withDefault ""
    in
    if Table.getCanFilter config id then
        input
            [ value current
            , placeholder ("Filter " ++ Maybe.withDefault id (Table.columnHeader column))
            , onInput (FilterTyped id)
            ]
            []

    else
        text ""


activeFilterCount : Table.State -> Int
activeFilterCount state =
    Table.leafColumns config
        |> List.filter (\column -> Table.getIsFiltered state (Table.columnId column))
        |> List.length
