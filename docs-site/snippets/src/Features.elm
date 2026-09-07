module Features exposing (..)

import Shared.People exposing (Person, people)
import Table
import Table.Value as Value


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


rowModel : Table.State -> Table.RowModel Person
rowModel state =
    Table.rowsFromList config state people


sortedOnly : Table.State -> Table.RowModel Person
sortedOnly state =
    Table.coreRowModelFromList config state people
        |> Table.sortedRowModel config state
