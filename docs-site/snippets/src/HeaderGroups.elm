module HeaderGroups exposing (..)

import Html exposing (Html, table, text, tfoot, th, thead, tr)
import Html.Attributes exposing (colspan, rowspan)
import Shared.People exposing (Person)
import Table
import Table.Value as Value


config : Table.Config Person
config =
    Table.config
        [ Table.column "id" (.id >> Value.String)
            |> Table.withHeader "#"
        , Table.group "name"
            [ Table.column "firstName" (.firstName >> Value.String)
                |> Table.withHeader "First"
            , Table.column "lastName" (.lastName >> Value.String)
                |> Table.withHeader "Last"
            ]
            |> Table.withHeader "Name"
        , Table.group "work"
            [ Table.column "department" (.department >> Value.String)
                |> Table.withHeader "Department"
            , Table.column "salary" (.salary >> Value.Number)
                |> Table.withHeader "Salary"
                |> Table.withFooter "Total"
            ]
            |> Table.withHeader "Work"
        ]


headerLabel : Table.Header Person -> String
headerLabel header =
    let
        id : String
        id =
            Table.headerColumnId header
    in
    Table.findColumn config id
        |> Maybe.andThen Table.columnHeader
        |> Maybe.withDefault id


viewHead : Table.State -> Html msg
viewHead state =
    thead [] (List.map viewHeaderRow (Table.headerGroups config state))


viewHeaderRow : Table.HeaderGroup Person -> Html msg
viewHeaderRow headerGroup =
    tr [] (List.filterMap viewHeaderCell headerGroup.headers)


viewHeaderCell : Table.Header Person -> Maybe (Html msg)
viewHeaderCell header =
    if Table.headerRowSpan header == 0 then
        Nothing

    else
        Just
            (th
                [ colspan (Table.headerColSpan header)
                , rowspan (Table.headerRowSpan header)
                ]
                [ text (headerLabel header) ]
            )


viewFoot : Table.State -> Html msg
viewFoot state =
    tfoot [] (List.map viewFooterRow (Table.footerGroups config state))


viewFooterRow : Table.HeaderGroup Person -> Html msg
viewFooterRow headerGroup =
    tr [] (List.map viewFooterCell headerGroup.headers)


viewFooterCell : Table.Header Person -> Html msg
viewFooterCell header =
    if Table.headerIsPlaceholder header then
        th [] []

    else
        th [ colspan (Table.headerColSpan header) ]
            [ text (footerLabel header) ]


footerLabel : Table.Header Person -> String
footerLabel header =
    Table.findColumn config (Table.headerColumnId header)
        |> Maybe.andThen Table.columnFooter
        |> Maybe.withDefault ""


viewPinnedHead : Table.State -> Html msg
viewPinnedHead state =
    let
        rowsOf : List (Table.HeaderGroup Person) -> List (List (Table.Header Person))
        rowsOf groups =
            List.map .headers groups
    in
    thead []
        (List.map3
            (\left center right -> tr [] (List.filterMap viewHeaderCell (left ++ center ++ right)))
            (rowsOf (Table.leftHeaderGroups config state))
            (rowsOf (Table.centerHeaderGroups config state))
            (rowsOf (Table.rightHeaderGroups config state))
        )


viewTable : Table.State -> Html msg
viewTable state =
    table [] [ viewHead state, viewFoot state ]
