module Rows exposing (..)

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
        |> Table.withGetRowId (\person _ _ -> person.id)


lookupRow : Table.State -> String -> Maybe (Table.Row Person)
lookupRow state wanted =
    Table.findRow (Table.rowsFromList config state people) wanted


firstNameOf : Table.Row Person -> String
firstNameOf row =
    Value.toString (Table.getValue config row "firstName")


originalOf : Table.Row Person -> String
originalOf row =
    (Table.rowOriginal row).firstName


rowNumber : Table.State -> Table.RowModel Person -> Table.Row Person -> String
rowNumber state model row =
    let
        position : Int
        position =
            Table.displayIndex config state model row
    in
    if position < 0 then
        ""

    else
        String.fromInt (position + 1)


ancestorIds : Table.RowModel Person -> Table.Row Person -> List String
ancestorIds model row =
    List.map Table.rowId (Table.getParentRows model row)


indent : Table.Row Person -> String
indent row =
    String.repeat (Table.rowDepth row) "    "


groupLabel : Table.Row Person -> String
groupLabel row =
    if Table.rowIsGrouped row then
        Value.toString (Table.rowGroupingValue row)
            ++ " ("
            ++ String.fromInt (List.length (Table.rowLeafRows row))
            ++ ")"

    else
        ""


deepestRow : Table.State -> Int
deepestRow state =
    Table.maxSubRowDepth (Table.coreRowModelFromList config state people)


departmentValues : Table.Row Person -> List Value.Value
departmentValues row =
    Table.getUniqueValues config row "department"
