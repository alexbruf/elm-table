module Table.Internal.ColumnVisibility exposing
    ( canHide
    , isAllColumnsVisible
    , isSomeColumnsVisible
    , isVisible
    , resetColumnVisibility
    , setColumnVisibility
    , toggleAllColumnsVisible
    , toggleVisibility
    , visibleCellsOf
    , visibleFlatColumns
    , visibleLeafColumns
    )

{-| Column visibility.

Ports `features/column-visibility/columnVisibilityFeature.utils.ts`.

The pin-aware cell lists live in `Table.Internal.ColumnPinning`, which imports
this module; TanStack's `row_getVisibleCells` applies the pin order on top of
the plain visibility filter `visibleCellsOf` does.

-}

import Dict exposing (Dict)
import Table.Internal.Column as Column
import Table.Internal.Row as Row
import Table.Internal.Types exposing (Cell, Column, Config, Row, State)


{-| Is this column visible? A group column is visible when any of its leaf
columns is. Ports `column_getIsVisible`.
-}
isVisible : State -> Column row -> Bool
isVisible =
    Column.isVisible


{-| Can this column be hidden? Both the column flag and `Config.enableHiding`
have to allow it. Ports `column_getCanHide`.
-}
canHide : Config row -> Column row -> Bool
canHide cfg col =
    (Column.fields col).enableHiding && cfg.enableHiding


{-| Show or hide one column. `Nothing` flips the column's current visibility.
Visibility is keyed by leaf column id, so a group column writes every one of
its hideable leaves. Ports `column_toggleVisibility`.
-}
toggleVisibility : Config row -> Column row -> Maybe Bool -> State -> State
toggleVisibility cfg col value state =
    if not (canHide cfg col) then
        state

    else
        let
            next : Bool
            next =
                case value of
                    Just wanted ->
                        wanted

                    Nothing ->
                        not (isVisible state col)

            write : Column row -> Dict String Bool -> Dict String Bool
            write leaf acc =
                if canHide cfg leaf then
                    Dict.insert (Column.id leaf) next acc

                else
                    acc
        in
        { state
            | columnVisibility =
                List.foldl write state.columnVisibility (Column.leafColumnsOf col)
        }


{-| Replace the whole visibility map. Ports `table_setColumnVisibility`.
-}
setColumnVisibility : Dict String Bool -> State -> State
setColumnVisibility visibility state =
    { state | columnVisibility = visibility }


{-| Clear the visibility map, which makes every column visible. Ports
`table_resetColumnVisibility(table, true)`.
-}
resetColumnVisibility : State -> State
resetColumnVisibility state =
    { state | columnVisibility = Dict.empty }


{-| Show or hide every leaf column. `Nothing` flips the current state.
Columns that cannot hide stay visible. Ports
`table_toggleAllColumnsVisible`.
-}
toggleAllColumnsVisible : Config row -> Maybe Bool -> State -> State
toggleAllColumnsVisible cfg value state =
    let
        next : Bool
        next =
            case value of
                Just wanted ->
                    wanted

                Nothing ->
                    not (isAllColumnsVisible cfg state)

        entry : Column row -> ( String, Bool )
        entry col =
            ( Column.id col
            , if next then
                True

              else
                not (canHide cfg col)
            )
    in
    { state
        | columnVisibility =
            Column.leafColumns cfg
                |> List.map entry
                |> Dict.fromList
    }


{-| Is every leaf column visible? Ports `table_getIsAllColumnsVisible`.
-}
isAllColumnsVisible : Config row -> State -> Bool
isAllColumnsVisible cfg state =
    List.all (isVisible state) (Column.leafColumns cfg)


{-| Is at least one leaf column visible? Ports
`table_getIsSomeColumnsVisible`.
-}
isSomeColumnsVisible : Config row -> State -> Bool
isSomeColumnsVisible cfg state =
    List.any (isVisible state) (Column.leafColumns cfg)


{-| Every column of the table, group columns included, minus the hidden ones.
Ports `table_getVisibleFlatColumns`.
-}
visibleFlatColumns : Config row -> State -> List (Column row)
visibleFlatColumns cfg state =
    List.filter (isVisible state) (Column.flatColumns cfg)


{-| The visible leaf columns in table order. Ports
`table_getVisibleLeafColumns`.
-}
visibleLeafColumns : Config row -> State -> List (Column row)
visibleLeafColumns =
    Column.visibleLeafColumns


{-| The cells of one row whose column is visible, in table order and without
any pin partitioning.
-}
visibleCellsOf : Config row -> State -> Row row -> List Cell
visibleCellsOf cfg state row =
    let
        visibleIds : List String
        visibleIds =
            List.map Column.id (visibleLeafColumns cfg state)
    in
    Row.getAllCells cfg state row
        |> List.filter (\cell -> List.member cell.columnId visibleIds)
