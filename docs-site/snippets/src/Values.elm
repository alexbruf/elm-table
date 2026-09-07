module Values exposing (..)

import Shared.People exposing (Person)
import Table
import Table.FilterFn as FilterFn
import Table.SortFn as SortFn
import Table.Value as Value
import Time


type alias Event =
    { name : String
    , startsAt : Time.Posix
    }


personColumns : List (Table.Column Person)
personColumns =
    [ Table.column "firstName" (.firstName >> Value.String)
    , Table.column "age" (.age >> toFloat >> Value.Number)
    , Table.column "salary" (.salary >> Value.Number)
    , Table.column "active" (.active >> Value.Bool)
    , Table.column "tags" (.tags >> List.map Value.String >> Value.List)
    ]


eventColumns : List (Table.Column Event)
eventColumns =
    [ Table.column "name" (.name >> Value.String)
    , Table.column "startsAt" (.startsAt >> Value.Date)
        |> Table.withSortFn SortFn.datetime
    ]


maybeString : (row -> Maybe String) -> row -> Value.Value
maybeString get row =
    case get row of
        Just text ->
            Value.String text

        Nothing ->
            Value.Null


tagsColumn : Table.Column Person
tagsColumn =
    Table.column "tags" (.tags >> List.map Value.String >> Value.List)
        |> Table.withHeader "Tags"
        |> Table.withFilterFn FilterFn.arrIncludes


formatCell : Value.Value -> String
formatCell value =
    case value of
        Value.String text ->
            text

        Value.Number n ->
            String.fromFloat n

        Value.Bool True ->
            "yes"

        Value.Bool False ->
            "no"

        Value.Date posix ->
            String.fromInt (Time.posixToMillis posix)

        Value.List items ->
            String.join ", " (List.map formatCell items)

        Value.Null ->
            "-"


fullName : Person -> String
fullName person =
    person.firstName ++ " " ++ person.lastName


fullNameColumn : Table.Column Person
fullNameColumn =
    Table.column "lastName" (.lastName >> Value.String)
        |> Table.withHeader "Last name"
        |> Table.withCustomSort
            (\a b ->
                compare (fullName (Table.rowOriginal a)) (fullName (Table.rowOriginal b))
            )
        |> Table.withCustomFilter
            (\row filterValue ->
                String.contains
                    (String.toLower (Value.toString filterValue))
                    (String.toLower (fullName (Table.rowOriginal row)))
            )
