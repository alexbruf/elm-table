module Headers exposing (..)

import Html exposing (Html, text, th, tr)
import Html.Attributes exposing (colspan, style)
import Shared.People exposing (Person)
import Table
import Table.Value as Value


config : Table.Config Person
config =
    Table.config
        [ Table.group "name"
            [ Table.column "firstName" (.firstName >> Value.String)
                |> Table.withHeader "First"
            , Table.column "lastName" (.lastName >> Value.String)
                |> Table.withHeader "Last"
            ]
            |> Table.withHeader "Name"
        , Table.column "salary" (.salary >> Value.Number)
            |> Table.withHeader "Salary"
        ]


headerColumn : Table.Header Person -> Maybe (Table.Column Person)
headerColumn header =
    Table.findColumn config (Table.headerColumnId header)


headerLabel : Table.Header Person -> String
headerLabel header =
    headerColumn header
        |> Maybe.andThen Table.columnHeader
        |> Maybe.withDefault (Table.headerColumnId header)


viewHeaderCell : Table.State -> Table.Header Person -> Html msg
viewHeaderCell state header =
    th
        [ colspan (Table.headerColSpan header)
        , style "width" (String.fromFloat (Table.getHeaderSize config state header) ++ "px")
        ]
        [ text (headerLabel header) ]


viewStickyHeaderRow : Table.State -> Table.HeaderGroup Person -> Html msg
viewStickyHeaderRow state headerGroup =
    tr []
        (List.map
            (\header ->
                th
                    [ style "position" "sticky"
                    , style "left" (offsetPx state headerGroup.headers header)
                    ]
                    [ text (headerLabel header) ]
            )
            headerGroup.headers
        )


offsetPx : Table.State -> List (Table.Header Person) -> Table.Header Person -> String
offsetPx state headerRow header =
    String.fromFloat (Table.getHeaderStart config state headerRow header) ++ "px"


flatHeaderIds : Table.State -> List String
flatHeaderIds state =
    List.map Table.headerId (Table.flatHeaders config state)


leafHeaderIds : Table.State -> List String
leafHeaderIds state =
    List.map Table.headerColumnId (Table.leafHeaders config state)


coveredColumns : Table.Header Person -> List String
coveredColumns header =
    List.map Table.headerColumnId (Table.getLeafHeaders header)


childIds : Table.Header Person -> List String
childIds header =
    List.map Table.headerId (Table.headerSubHeaders header)


placeholderReport : Table.Header Person -> String
placeholderReport header =
    if Table.headerIsPlaceholder header then
        Table.headerColumnId header
            ++ " placeholder "
            ++ Maybe.withDefault "0" (Table.headerPlaceholderId header)
            ++ " at depth "
            ++ String.fromInt (Table.headerDepth header)
            ++ ", position "
            ++ String.fromInt (Table.headerIndex header)

    else
        Table.headerId header
