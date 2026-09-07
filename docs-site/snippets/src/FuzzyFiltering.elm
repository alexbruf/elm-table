module FuzzyFiltering exposing (..)

import Shared.People exposing (Person, people)
import Table
import Table.FilterFn as FilterFn
import Table.SortFn as SortFn
import Table.Value as Value


fullName : Person -> String
fullName person =
    person.firstName ++ " " ++ person.lastName


fuzzySpan : String -> String -> Maybe Int
fuzzySpan needle haystack =
    consume 0
        (String.toList (String.toLower needle))
        (String.toList (String.toLower haystack))


consume : Int -> List Char -> List Char -> Maybe Int
consume at needle haystack =
    case needle of
        [] ->
            Just at

        wanted :: restNeedle ->
            case haystack of
                [] ->
                    Nothing

                next :: restHaystack ->
                    if wanted == next then
                        consume (at + 1) restNeedle restHaystack

                    else
                        consume (at + 1) needle restHaystack


fuzzyMatches : String -> String -> Bool
fuzzyMatches needle haystack =
    fuzzySpan needle haystack /= Nothing


fullNameColumn : Table.Column Person
fullNameColumn =
    Table.column "fullName" (fullName >> Value.String)
        |> Table.withHeader "Full name"
        |> Table.withCustomFilter
            (\row filterValue ->
                fuzzyMatches
                    (Value.toString filterValue)
                    (fullName (Table.rowOriginal row))
            )


fuzzyFilterFn : FilterFn.FilterFn
fuzzyFilterFn =
    FilterFn.custom
        (\dataValue filterValue ->
            fuzzyMatches (Value.toString filterValue) (Value.toString dataValue)
        )
        |> FilterFn.withAutoRemove (\filterValue -> Value.toString filterValue == "")


fuzzyGlobalConfig : Table.Config Person
fuzzyGlobalConfig =
    Table.config [ fullNameColumn ]
        |> Table.withGetRowId (\person _ _ -> person.id)
        |> Table.withGlobalFilterFn fuzzyFilterFn


rankOf : String -> Person -> Int
rankOf query person =
    fuzzySpan query (fullName person)
        |> Maybe.withDefault (String.length (fullName person) + 1)


rankedColumn : String -> Table.Column Person
rankedColumn query =
    fullNameColumn
        |> Table.withCustomSort
            (\rowA rowB ->
                let
                    personA : Person
                    personA =
                        Table.rowOriginal rowA

                    personB : Person
                    personB =
                        Table.rowOriginal rowB
                in
                case Basics.compare (rankOf query personA) (rankOf query personB) of
                    EQ ->
                        SortFn.compare SortFn.alphanumeric
                            (Value.String (fullName personA))
                            (Value.String (fullName personB))

                    order ->
                        order
            )


configFor : String -> Table.Config Person
configFor query =
    Table.config [ rankedColumn query ]
        |> Table.withGetRowId (\person _ _ -> person.id)


rankedRows : String -> Table.State -> Table.RowModel Person
rankedRows query state =
    let
        cfg : Table.Config Person
        cfg =
            configFor query
    in
    Table.coreRowModelFromList cfg state people
        |> Table.filteredRowModel cfg state
        |> Table.sortedRowModel cfg state
