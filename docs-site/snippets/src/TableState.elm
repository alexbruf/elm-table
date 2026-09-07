module TableState exposing (..)

import Set
import Shared.People exposing (Person, people)
import Table
import Table.Value as Value


type alias Model =
    { data : List Person
    , state : Table.State
    , rowModel : Table.RowModel Person
    }


type Msg
    = GoToPage Int
    | SortBy String
    | BackToStartState


config : Table.Config Person
config =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First name"
        , Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
        ]
        |> Table.withGetRowId (\person _ _ -> person.id)


startState : Table.State
startState =
    let
        base : Table.State
        base =
            Table.initialState
    in
    { base
        | sorting = [ { id = "age", desc = True } ]
        , pagination = { pageIndex = 0, pageSize = 25 }
    }


startStateFromTransitions : Table.State
startStateFromTransitions =
    Table.initialState
        |> Table.setSorting [ { id = "age", desc = True } ]
        |> Table.setPageSize 25


init : Model
init =
    { data = people
    , state = startState
    , rowModel = Table.rowsFromList config startState people
    }


update : Msg -> Model -> Model
update msg model =
    case msg of
        GoToPage index ->
            withState (Table.setPage config index model.state) model

        SortBy columnId ->
            withState
                (Table.toggleSort config
                    model.rowModel
                    columnId
                    { desc = Nothing, multi = False }
                    model.state
                )
                model

        BackToStartState ->
            withState (Table.setSorting startState.sorting model.state) model


withState : Table.State -> Model -> Model
withState state model =
    { model
        | state = state
        , rowModel = Table.rowsFromList config state model.data
    }


coreOnly : Table.State -> List Person -> Table.RowModel Person
coreOnly state data =
    Table.coreRowModelFromList config state data


preSorted : Table.State -> List Person -> Table.RowModel Person
preSorted state data =
    Table.coreRowModelFromList config state data
        |> Table.filteredRowModel config state
        |> Table.groupedRowModel config state


preExpanded : Table.State -> List Person -> Table.RowModel Person
preExpanded state data =
    preSorted state data
        |> Table.preExpandedRowModel config state


sortingParam : Table.State -> String
sortingParam state =
    state.sorting
        |> List.map
            (\column ->
                if column.desc then
                    "-" ++ column.id

                else
                    column.id
            )
        |> String.join ","


sortingFromParam : String -> List Table.SortColumn
sortingFromParam param =
    param
        |> String.split ","
        |> List.filter (\part -> part /= "")
        |> List.map
            (\part ->
                case String.uncons part of
                    Just ( '-', id ) ->
                        { id = id, desc = True }

                    _ ->
                        { id = part, desc = False }
            )


stateFromParams : String -> Table.State
stateFromParams sortParam =
    Table.setSorting (sortingFromParam sortParam) Table.initialState


expandedParam : Table.State -> List String
expandedParam state =
    Table.expandedIdsOf state.expanded
        |> Maybe.map Set.toList
        |> Maybe.withDefault []
