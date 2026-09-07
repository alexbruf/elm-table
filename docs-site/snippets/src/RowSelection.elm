module RowSelection exposing (..)

import Html exposing (Html, input, td, th)
import Html.Attributes exposing (checked, disabled, property, type_)
import Html.Events exposing (on, onCheck)
import Json.Decode as Decode
import Json.Encode as Encode
import Shared.People exposing (Person, people)
import Table
import Table.Value as Value


columns : List (Table.Column Person)
columns =
    [ Table.column "firstName" (.firstName >> Value.String)
        |> Table.withHeader "First name"
    , Table.column "department" (.department >> Value.String)
        |> Table.withHeader "Department"
    ]


config : Table.Config Person
config =
    Table.config columns
        |> Table.withGetRowId (\person _ _ -> person.id)


activeRowsOnly : Table.Config Person
activeRowsOnly =
    Table.withRowSelection (\row -> (Table.rowOriginal row).active) config


singleRowSelection : Table.Config Person
singleRowSelection =
    { config | enableMultiRowSelection = always False }


noSubRowSelection : Table.Config Person
noSubRowSelection =
    { config | enableSubRowSelection = always False }


prePaginated : Table.State -> Table.RowModel Person
prePaginated state =
    Table.coreRowModelFromList config state people
        |> Table.filteredRowModel config state
        |> Table.groupedRowModel config state
        |> Table.sortedRowModel config state
        |> Table.expandedRowModel config state


currentPage : Table.State -> Table.RowModel Person
currentPage state =
    Table.paginatedRowModel config state (prePaginated state)


type alias Model =
    { state : Table.State
    , selectionAnchor : Maybe String
    }


init : Model
init =
    { state = Table.initialState
    , selectionAnchor = Nothing
    }


type alias RowClick =
    { row : Table.Row Person
    , value : Bool
    , shift : Bool
    }


type Msg
    = ClickedRow RowClick
    | ClickedSelectAll Bool


update : Msg -> Model -> Model
update msg model =
    case msg of
        ClickedSelectAll value ->
            { model
                | state =
                    Table.toggleAllRowsSelected config
                        (prePaginated model.state)
                        (Just value)
                        model.state
                , selectionAnchor = Nothing
            }

        ClickedRow click ->
            { model
                | state = applyRowClick model click
                , selectionAnchor = Just (Table.rowId click.row)
            }


applyRowClick : Model -> RowClick -> Table.State
applyRowClick model click =
    let
        rowModel : Table.RowModel Person
        rowModel =
            prePaginated model.state

        anchorId : String
        anchorId =
            Maybe.withDefault "" model.selectionAnchor
    in
    if click.shift && Table.canSelectRange config model.state rowModel anchorId click.row then
        Table.selectRange config rowModel anchorId click.row click.value model.state

    else
        Table.toggleRowSelected config rowModel click.row (Just click.value) model.state


pruneParents : Model -> RowClick -> Table.State
pruneParents model click =
    Table.toggleRowSelectedWith config
        { selectChildren = True, deselectParents = True }
        (prePaginated model.state)
        click.row
        (Just click.value)
        model.state


viewSelectAllHeader : Model -> Html Msg
viewSelectAllHeader model =
    let
        allSelected : Bool
        allSelected =
            Table.getIsAllRowsSelected config model.state (prePaginated model.state)
    in
    th []
        [ input
            [ type_ "checkbox"
            , checked allSelected
            , indeterminate (not allSelected && Table.getIsSomeRowsSelected model.state)
            , onCheck ClickedSelectAll
            ]
            []
        ]


indeterminate : Bool -> Html.Attribute msg
indeterminate value =
    property "indeterminate" (Encode.bool value)


viewRowCheckbox : Table.State -> Table.Row Person -> Html Msg
viewRowCheckbox state row =
    td []
        [ input
            [ type_ "checkbox"
            , checked (rowIsChecked state row)
            , disabled (not (Table.getCanSelect config row))
            , indeterminate (Table.getIsSomeSelected config state row)
            , on "click" (rowClickDecoder row)
            ]
            []
        ]


rowIsChecked : Table.State -> Table.Row Person -> Bool
rowIsChecked state row =
    Table.getIsRowSelected state row
        || (Table.getCanSelectSubRows config row
                && Table.getIsAllSubRowsSelected config state row
           )


rowClickDecoder : Table.Row Person -> Decode.Decoder Msg
rowClickDecoder row =
    Decode.map2
        (\shift value -> ClickedRow { row = row, value = value, shift = shift })
        (Decode.field "shiftKey" Decode.bool)
        (Decode.at [ "target", "checked" ] Decode.bool)


selectedPeople : Table.State -> List Person
selectedPeople state =
    Table.selectedRowModel state (prePaginated state)
        |> .rows
        |> List.map Table.rowOriginal


subTreeLabel : Table.State -> Table.Row Person -> String
subTreeLabel state row =
    let
        selection : Table.SubRowSelection
        selection =
            Table.subRowSelection config state row
    in
    if selection == Table.allSubRowsSelected then
        "all"

    else if selection == Table.someSubRowsSelected then
        "some"

    else
        "none"
