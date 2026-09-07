module ColumnDefs exposing (..)

import Shared.People exposing (Person)
import Table
import Table.AggregationFn as AggregationFn
import Table.FilterFn as FilterFn
import Table.SortFn as SortFn
import Table.Value as Value


accessorColumns : List (Table.Column Person)
accessorColumns =
    [ Table.column "firstName" (.firstName >> Value.String)
        |> Table.withHeader "First name"
    , Table.column "age" (.age >> toFloat >> Value.Number)
        |> Table.withHeader "Age"
    , Table.column "active" (.active >> Value.Bool)
        |> Table.withHeader "Active"
    , Table.column "tags" (.tags >> List.map Value.String >> Value.List)
        |> Table.withHeader "Tags"
    ]


fullNameColumn : Table.Column Person
fullNameColumn =
    Table.column "fullName"
        (\person -> Value.String (person.firstName ++ " " ++ person.lastName))
        |> Table.withHeader "Name"


selectColumn : Table.Column Person
selectColumn =
    Table.display "select"
        |> Table.withSize 40
        |> Table.withEnableHiding False


groupedColumns : List (Table.Column Person)
groupedColumns =
    [ Table.group "name"
        [ Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First"
        , Table.column "lastName" (.lastName >> Value.String)
            |> Table.withHeader "Last"
        ]
        |> Table.withHeader "Name"
    , Table.group "employment"
        [ Table.column "department" (.department >> Value.String)
            |> Table.withHeader "Department"
        , Table.column "salary" (.salary >> Value.Number)
            |> Table.withHeader "Salary"
        ]
        |> Table.withHeader "Employment"
    ]


salaryColumn : Table.Column Person
salaryColumn =
    Table.column "salary" (.salary >> Value.Number)
        |> Table.withHeader "Salary"
        |> Table.withFooter "Total"
        |> Table.withSortFn SortFn.basic
        |> Table.withSortDescFirst True
        |> Table.withFilterFn FilterFn.inNumberRange
        |> Table.withAggregationFn AggregationFn.sum


headerText : Table.Column Person -> String
headerText col =
    Maybe.withDefault (Table.columnId col) (Table.columnHeader col)
