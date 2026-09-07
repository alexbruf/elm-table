-- This file is embedded byte-for-byte in the README. If you change it here,
-- copy it into the matching code block in README.md, and the other way
-- around.


module Main exposing (main)

import Browser
import Dict
import Html exposing (Html, button, div, input, label, p, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (checked, disabled, style, type_, value)
import Html.Events exposing (onClick, onInput)
import Table
import Table.AggregationFn as AggregationFn
import Table.FilterFn as FilterFn
import Table.Value as Value


type alias Person =
    { id : String
    , firstName : String
    , lastName : String
    , department : String
    , age : Int
    , salary : Float
    }


people : List Person
people =
    [ Person "1" "Ada" "Lovelace" "Engineering" 36 98000
    , Person "2" "Grace" "Hopper" "Engineering" 45 112000
    , Person "3" "Katherine" "Johnson" "Engineering" 41 105000
    , Person "4" "Margaret" "Hamilton" "Engineering" 38 108000
    , Person "5" "Radia" "Perlman" "Engineering" 50 121000
    , Person "6" "Susan" "Kare" "Design" 34 89000
    , Person "7" "Jony" "Ive" "Design" 47 130000
    , Person "8" "Don" "Norman" "Design" 55 99000
    , Person "9" "Julie" "Zhuo" "Design" 29 95000
    , Person "10" "Dieter" "Rams" "Design" 60 88000
    , Person "11" "Mary" "Barra" "Sales" 44 91000
    , Person "12" "Zig" "Ziglar" "Sales" 52 87000
    , Person "13" "Brian" "Tracy" "Sales" 58 93000
    , Person "14" "Grant" "Cardone" "Sales" 39 97000
    , Person "15" "Jill" "Konrath" "Sales" 42 85000
    , Person "16" "Tony" "Hsieh" "Support" 33 72000
    , Person "17" "Shep" "Hyken" "Support" 48 75000
    , Person "18" "Blake" "Morgan" "Support" 31 71000
    , Person "19" "Micah" "Solomon" "Support" 37 74000
    , Person "20" "Jeff" "Toister" "Support" 45 76000
    ]


config : Table.Config Person
config =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First name"
            |> Table.withFilterFn FilterFn.includesString
        , Table.column "lastName" (.lastName >> Value.String)
            |> Table.withHeader "Last name"
        , Table.column "department" (.department >> Value.String)
            |> Table.withHeader "Department"
        , Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
        , Table.column "salary" (.salary >> Value.Number)
            |> Table.withHeader "Salary"
            |> Table.withAggregationFn AggregationFn.sum
        ]
        |> Table.withGetRowId (\person _ _ -> person.id)


type alias Model =
    { state : Table.State
    }


init : Model
init =
    { state = Table.initialState }


{-| The row model for the current state. A real app computes this once in
`update` and stores it in the model instead of rebuilding it here and again
in `update` below; this README keeps the two separate so each function stays
a one-liner.
-}
rowModel : Table.State -> Table.RowModel Person
rowModel state =
    Table.rowsFromList config state people


type Msg
    = SortBy String
    | FilterFirstName String
    | ToggleGroupByDepartment
    | ToggleExpandRow (Table.Row Person)
    | GoToPreviousPage
    | GoToNextPage


update : Msg -> Model -> Model
update msg model =
    case msg of
        SortBy columnId ->
            { model
                | state =
                    Table.toggleSort config
                        (rowModel model.state)
                        columnId
                        { desc = Nothing, multi = False }
                        model.state
            }

        FilterFirstName text ->
            { model
                | state =
                    Table.setColumnFilter config
                        (rowModel model.state)
                        "firstName"
                        (Value.String text)
                        model.state
            }

        ToggleGroupByDepartment ->
            { model | state = Table.toggleGrouping "department" model.state }

        ToggleExpandRow row ->
            { model
                | state =
                    Table.toggleExpanded config (rowModel model.state) row Nothing model.state
            }

        GoToPreviousPage ->
            { model | state = Table.previousPage config model.state }

        GoToNextPage ->
            { model | state = Table.nextPage config model.state }


view : Model -> Html Msg
view model =
    let
        model_ =
            rowModel model.state

        columns_ =
            Table.visibleLeafColumns config model.state

        visibleRows =
            Table.rowsInDisplayOrder config model.state model_
    in
    div []
        [ p []
            [ label []
                [ text "Filter first name: "
                , input [ value (currentFilterText model.state), onInput FilterFirstName ] []
                ]
            ]
        , p []
            [ label []
                [ input
                    [ type_ "checkbox"
                    , checked (Table.getIsGrouped model.state "department")
                    , onClick ToggleGroupByDepartment
                    ]
                    []
                , text " Group by department"
                ]
            ]
        , table []
            [ thead [] [ tr [] (List.map (viewHeaderCell model.state) columns_) ]
            , tbody [] (List.map (viewRow model.state) visibleRows)
            ]
        , p []
            [ button
                [ onClick GoToPreviousPage
                , disabled (not (Table.getCanPreviousPage model.state))
                ]
                [ text "Previous" ]
            , text
                (" Page "
                    ++ String.fromInt (model.state.pagination.pageIndex + 1)
                    ++ " of "
                    ++ String.fromInt (Table.getPageCount config model.state model_)
                    ++ " "
                )
            , button
                [ onClick GoToNextPage
                , disabled (not (Table.getCanNextPage config model.state model_))
                ]
                [ text "Next" ]
            ]
        ]


currentFilterText : Table.State -> String
currentFilterText state =
    Table.getFilterValue state "firstName"
        |> Maybe.map Value.toString
        |> Maybe.withDefault ""


viewHeaderCell : Table.State -> Table.Column Person -> Html Msg
viewHeaderCell state col =
    let
        columnId =
            Table.columnId col

        label_ =
            Maybe.withDefault columnId (Table.columnHeader col)
    in
    th
        [ onClick (SortBy columnId), style "cursor" "pointer" ]
        [ text (label_ ++ sortIndicator state columnId) ]


sortIndicator : Table.State -> String -> String
sortIndicator state columnId =
    case Table.getIsSorted state columnId of
        Nothing ->
            ""

        Just dir ->
            if dir == Table.sortAsc then
                " (asc)"

            else
                " (desc)"


viewRow : Table.State -> Table.Row Person -> Html Msg
viewRow state row =
    tr [] (List.map (viewCell state row) (Table.visibleLeafColumns config state))


viewCell : Table.State -> Table.Row Person -> Table.Column Person -> Html Msg
viewCell state row col =
    let
        columnId =
            Table.columnId col
    in
    if Table.cellIsGrouped state row columnId then
        td [] [ button [ onClick (ToggleExpandRow row) ] [ text (groupLabel state row) ] ]

    else if Table.rowIsGrouped row then
        if Dict.member columnId (Table.rowAggregatedValues row) then
            td [] [ text (Value.toString (Table.getValue config row columnId)) ]

        else
            td [] []

    else
        td [] [ text (Value.toString (Table.getValue config row columnId)) ]


groupLabel : Table.State -> Table.Row Person -> String
groupLabel state row =
    (if Table.getIsExpanded config state row then
        "- "

     else
        "+ "
    )
        ++ Value.toString (Table.rowGroupingValue row)
        ++ " ("
        ++ String.fromInt (List.length (Table.rowLeafRows row))
        ++ ")"


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
