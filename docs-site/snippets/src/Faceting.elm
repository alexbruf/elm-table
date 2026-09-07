module Faceting exposing (..)

import Html exposing (Html, input, label, text)
import Html.Attributes exposing (checked, type_)
import Html.Events exposing (onClick)
import Shared.People exposing (Person, people)
import Table
import Table.FilterFn as FilterFn
import Table.Value as Value


columns : List (Table.Column Person)
columns =
    [ Table.column "department" (.department >> Value.String)
        |> Table.withHeader "Department"
        |> Table.withFilterFn FilterFn.equalsString
    , Table.column "salary" (.salary >> Value.Number)
        |> Table.withHeader "Salary"
        |> Table.withFilterFn FilterFn.inNumberRange
    , Table.column "tags" (.tags >> List.map Value.String >> Value.List)
        |> Table.withHeader "Tags"
        |> Table.withGetUniqueValues (.tags >> List.map Value.String)
        |> Table.withFilterFn FilterFn.arrIncludesSome
    ]


config : Table.Config Person
config =
    Table.config columns
        |> Table.withGetRowId (\person _ _ -> person.id)


prefilteredRows : Table.State -> Table.RowModel Person
prefilteredRows state =
    Table.coreRowModelFromList config state people


departmentOptions : Table.State -> List ( Value.Value, Int )
departmentOptions state =
    Table.facetedUniqueValues config state (prefilteredRows state) "department"
        |> List.sortBy (Tuple.first >> Value.toString)


salaryRange : Table.State -> ( Float, Float )
salaryRange state =
    Table.facetedMinMax config state (prefilteredRows state) "salary"
        |> Maybe.withDefault ( 0, 1 )


searchSuggestions : Table.State -> List String
searchSuggestions state =
    Table.facetedUniqueValues config state (prefilteredRows state) Table.globalFacetKey
        |> List.map (Tuple.first >> Value.toString)
        |> List.take 10


departmentFacetRows : Table.State -> List (Table.Row Person)
departmentFacetRows state =
    let
        model : Table.RowModel Person
        model =
            Table.facetedRowModel config state (prefilteredRows state) "department"
    in
    model.flatRows


salaryBucket : Float -> String
salaryBucket salary =
    if salary < 90000 then
        "under 90k"

    else if salary < 110000 then
        "90k to 110k"

    else
        "110k and up"


salaryBucketFilter : FilterFn.FilterFn
salaryBucketFilter =
    FilterFn.custom
        (\dataValue filterValue ->
            case filterValue of
                Value.List selected ->
                    List.member dataValue selected

                _ ->
                    False
        )
        |> FilterFn.withResolveDataValue
            (Value.toNumber >> salaryBucket >> Value.String)
        |> FilterFn.withAutoRemove
            (\filterValue ->
                case filterValue of
                    Value.List selected ->
                        List.isEmpty selected

                    _ ->
                        True
            )


salaryBucketColumn : Table.Column Person
salaryBucketColumn =
    Table.column "salary" (.salary >> Value.Number)
        |> Table.withHeader "Salary"
        |> Table.withGetUniqueValues
            (\person -> [ Value.String (salaryBucket person.salary) ])
        |> Table.withFilterFn salaryBucketFilter


type Msg
    = DepartmentPicked String


viewDepartmentFacet : Table.State -> List (Html Msg)
viewDepartmentFacet state =
    departmentOptions state
        |> List.map
            (\( facetValue, count ) ->
                let
                    name : String
                    name =
                        Value.toString facetValue
                in
                label []
                    [ input
                        [ type_ "checkbox"
                        , checked (Table.getFilterValue state "department" == Just facetValue)
                        , onClick (DepartmentPicked name)
                        ]
                        []
                    , text (name ++ " (" ++ String.fromInt count ++ ")")
                    ]
            )
