module RowModels exposing (..)

import Array exposing (Array)
import Dict
import Shared.People exposing (Person, people)
import Table
import Table.FilterFn as FilterFn
import Table.Value as Value


type alias Model =
    { state : Table.State
    , data : List Person
    , rowModel : Table.RowModel Person
    }


type Msg
    = SortBy String


config : Table.Config Person
config =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First name"
            |> Table.withFilterFn FilterFn.includesString
        , Table.column "department" (.department >> Value.String)
            |> Table.withHeader "Department"
        , Table.column "salary" (.salary >> Value.Number)
            |> Table.withHeader "Salary"
        ]
        |> Table.withGetRowId (\person _ _ -> person.id)


wholePipeline : Table.State -> Table.RowModel Person
wholePipeline state =
    Table.rowsFromList config state people


wholePipelineFromArray : Table.State -> Array Person -> Table.RowModel Person
wholePipelineFromArray state data =
    Table.rows config state data


byHand : Table.State -> Table.RowModel Person
byHand state =
    Table.coreRowModelFromList config state people
        |> Table.filteredRowModel config state
        |> Table.groupedRowModel config state
        |> Table.sortedRowModel config state
        |> Table.expandedRowModel config state
        |> Table.paginatedRowModel config state


matchCount : Table.State -> Int
matchCount state =
    Table.coreRowModelFromList config state people
        |> Table.filteredRowModel config state
        |> .rows
        |> List.length


preGrouped : Table.State -> Table.RowModel Person
preGrouped state =
    Table.coreRowModelFromList config state people
        |> Table.preGroupedRowModel config state


preSorted : Table.State -> Table.RowModel Person
preSorted state =
    Table.coreRowModelFromList config state people
        |> Table.filteredRowModel config state
        |> Table.groupedRowModel config state


displayRows : Table.State -> List (Table.Row Person)
displayRows state =
    Table.rowsInDisplayOrder config state (Table.rowsFromList config state people)


rowModelOf : List (Table.Row Person) -> Table.RowModel Person
rowModelOf flat =
    { rows = flat
    , flatRows = flat
    , rowsById = Dict.fromList (List.map (\r -> ( Table.rowId r, r )) flat)
    }


isActive : Table.Row Person -> Bool
isActive row =
    (Table.rowOriginal row).active


withOwnStage : Table.State -> Table.RowModel Person
withOwnStage state =
    Table.coreRowModelFromList config state people
        |> Table.filteredRowModel config state
        |> (\model -> rowModelOf (List.filter isActive model.rows))
        |> Table.groupedRowModel config state
        |> Table.sortedRowModel config state
        |> Table.expandedRowModel config state
        |> Table.paginatedRowModel config state


departmentOptions : Table.State -> List ( Value.Value, Int )
departmentOptions state =
    Table.facetedUniqueValues config
        state
        (Table.coreRowModelFromList config state people)
        "department"


salaryRange : Table.State -> Maybe ( Float, Float )
salaryRange state =
    Table.facetedMinMax config
        state
        (Table.coreRowModelFromList config state people)
        "salary"


serverSideConfig : Table.Config Person
serverSideConfig =
    { config
        | manualFiltering = True
        , manualSorting = True
        , manualPagination = True
    }


refresh : Model -> Model
refresh model =
    { model | rowModel = Table.rowsFromList config model.state model.data }


update : Msg -> Model -> Model
update msg model =
    case msg of
        SortBy id ->
            refresh
                { model
                    | state =
                        Table.toggleSort config
                            model.rowModel
                            id
                            { desc = Nothing, multi = False }
                            model.state
                }
