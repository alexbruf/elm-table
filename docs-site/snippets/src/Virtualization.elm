module Virtualization exposing (..)

import Shared.People exposing (Person, people)
import Table
import Table.Value as Value


config : Table.Config Person
config =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First name"
            |> Table.withSize 200
        , Table.column "department" (.department >> Value.String)
            |> Table.withHeader "Department"
            |> Table.withSize 160
        ]
        |> Table.withGetRowId (\person _ _ -> person.id)


everyRow : Table.State
everyRow =
    Table.setPageSize Table.unlimitedPageSize Table.initialState


rowsToVirtualize : Table.State -> List (Table.Row Person)
rowsToVirtualize state =
    Table.rowsInDisplayOrder config state (Table.rowsFromList config state people)


rowKeys : Table.State -> List String
rowKeys state =
    List.map Table.rowId (rowsToVirtualize state)


columnWidths : Table.State -> List ( String, Float )
columnWidths state =
    Table.visibleLeafColumns config state
        |> List.map (\column -> ( Table.columnId column, Table.getColumnSize config state column ))
