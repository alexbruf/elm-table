module ConfigState exposing (..)

import Shared.People exposing (Person, people)
import Table
import Table.FilterFn as FilterFn
import Table.Value as Value


type alias Model =
    { state : Table.State
    , rowModel : Table.RowModel Person
    }


type Msg
    = SortBy String
    | GoToNextPage


config : Table.Config Person
config =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First name"
        , Table.column "department" (.department >> Value.String)
            |> Table.withHeader "Department"
        , Table.column "salary" (.salary >> Value.Number)
            |> Table.withHeader "Salary"
        ]
        |> Table.withGetRowId (\person _ _ -> person.id)
        |> Table.withGlobalFilterFn FilterFn.includesString


noGlobalFilter : Table.Config Person
noGlobalFilter =
    { config | enableGlobalFilter = False, maxMultiSortColCount = 2 }


init : Model
init =
    { state = Table.initialState
    , rowModel = Table.rowsFromList config Table.initialState people
    }


update : Msg -> Model -> Model
update msg model =
    case msg of
        SortBy columnId ->
            recompute
                (Table.toggleSort config
                    model.rowModel
                    columnId
                    { desc = Nothing, multi = False }
                    model.state
                )

        GoToNextPage ->
            recompute (Table.nextPage config model.state)


recompute : Table.State -> Model
recompute state =
    { state = state
    , rowModel = Table.rowsFromList config state people
    }


startingState : Table.State
startingState =
    let
        base : Table.State
        base =
            Table.initialState
    in
    { base
        | pagination = { pageIndex = 0, pageSize = 25 }
        , sorting = [ { id = "salary", desc = True } ]
    }
