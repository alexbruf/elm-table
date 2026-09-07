module Expanding exposing (..)

import Html exposing (Html)
import Html.Attributes exposing (colspan)
import Html.Events exposing (onClick)
import Set exposing (Set)
import Shared.People exposing (Person, people)
import Table
import Table.Value as Value


type Node
    = Node
        { id : String
        , name : String
        , salary : Float
        , children : List Node
        }


nodeFields : Node -> { id : String, name : String, salary : Float, children : List Node }
nodeFields (Node fields) =
    fields


nodes : List Node
nodes =
    [ Node
        { id = "eng"
        , name = "Engineering"
        , salary = 315000
        , children =
            [ Node { id = "eng-1", name = "Ada Lovelace", salary = 98000, children = [] }
            , Node { id = "eng-2", name = "Grace Hopper", salary = 112000, children = [] }
            ]
        }
    , Node
        { id = "design"
        , name = "Design"
        , salary = 219000
        , children =
            [ Node { id = "design-1", name = "Susan Kare", salary = 89000, children = [] } ]
        }
    ]


columns : List (Table.Column Node)
columns =
    [ Table.column "name" (nodeFields >> .name >> Value.String)
        |> Table.withHeader "Name"
    , Table.column "salary" (nodeFields >> .salary >> Value.Number)
        |> Table.withHeader "Salary"
    ]


config : Table.Config Node
config =
    Table.config columns
        |> Table.withSubRows (nodeFields >> .children)
        |> Table.withGetRowId (\node _ _ -> (nodeFields node).id)


type Msg
    = ExpandToggled String
    | AllExpandedToggled
    | ExpandedReset


update : Table.RowModel Node -> Msg -> Table.State -> Table.State
update model msg state =
    case msg of
        ExpandToggled rowId ->
            case Table.findRow model rowId of
                Just row ->
                    Table.toggleExpanded config model row Nothing state

                Nothing ->
                    state

        AllExpandedToggled ->
            Table.toggleAllRowsExpanded config model Nothing state

        ExpandedReset ->
            Table.resetExpanded state


preExpanded : Table.State -> Table.RowModel Node
preExpanded state =
    Table.coreRowModelFromList config state nodes
        |> Table.filteredRowModel config state
        |> Table.groupedRowModel config state
        |> Table.preExpandedRowModel config state


expandEverything : Table.State -> Table.State
expandEverything =
    Table.setExpanded Table.expandAll


expandOnly : List String -> Table.State -> Table.State
expandOnly rowIds =
    Table.setExpanded (Table.expandedIds (Set.fromList rowIds))


expandedRowIds : Table.State -> Maybe (Set String)
expandedRowIds state =
    Table.expandedIdsOf state.expanded


viewExpander : Table.State -> Table.Row Node -> Html Msg
viewExpander state row =
    if Table.getCanExpand config row then
        Html.button [ onClick (ExpandToggled (Table.rowId row)) ]
            [ Html.text
                (if Table.getIsExpanded config state row then
                    "-"

                 else
                    "+"
                )
            ]

    else
        Html.text ""


viewToolbar : Table.State -> Table.RowModel Node -> Html Msg
viewToolbar state model =
    Html.div []
        [ Html.button [ onClick AllExpandedToggled ]
            [ Html.text
                (if Table.getIsAllRowsExpanded config state model then
                    "Collapse all"

                 else
                    "Expand all"
                )
            ]
        , Html.button [ onClick ExpandedReset ] [ Html.text "Reset" ]
        , Html.text
            (String.fromInt (Table.getExpandedDepth config state model) ++ " levels open")
        ]


detailConfig : Table.Config Person
detailConfig =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
        , Table.column "lastName" (.lastName >> Value.String)
        ]
        |> Table.withGetRowId (\person _ _ -> person.id)
        |> Table.withRowCanExpand (\_ -> True)


viewWithDetailPanels : Table.State -> Html Msg
viewWithDetailPanels state =
    let
        model : Table.RowModel Person
        model =
            Table.rowsFromList detailConfig state people
    in
    Html.tbody []
        (List.concatMap (viewRowAndPanel state) (Table.rowsInDisplayOrder detailConfig state model))


viewRowAndPanel : Table.State -> Table.Row Person -> List (Html Msg)
viewRowAndPanel state row =
    let
        cells : List Table.Cell
        cells =
            Table.visibleCells detailConfig state row
    in
    Html.tr [ onClick (ExpandToggled (Table.rowId row)) ]
        (List.map (\cell -> Html.td [] [ Html.text (Value.toString cell.value) ]) cells)
        :: (if Table.getIsExpanded detailConfig state row then
                [ Html.tr []
                    [ Html.td [ colspan (List.length cells) ]
                        [ Html.text ("Anything you like about " ++ (Table.rowOriginal row).firstName) ]
                    ]
                ]

            else
                []
           )
