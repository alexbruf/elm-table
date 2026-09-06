module Table.Internal.ColumnPinning exposing
    ( canPin
    , centerLeafColumns
    , centerVisibleCells
    , centerVisibleLeafColumns
    , isPinned
    , isSomeColumnsPinned
    , isSomeColumnsPinnedLeft
    , isSomeColumnsPinnedRight
    , leftLeafColumns
    , leftVisibleCells
    , leftVisibleLeafColumns
    , pinColumn
    , pinnedColumns
    , pinnedIndex
    , pinnedLeafColumns
    , pinnedVisibleLeafColumns
    , resetColumnPinning
    , rightLeafColumns
    , rightVisibleCells
    , rightVisibleLeafColumns
    , setColumnPinning
    , visibleCells
    , visibleCellsByColumnId
    )

{-| Column pinning: which columns stick to the left or the right edge, and the
left / center / right partitions of the column and cell lists.

Ports `features/column-pinning/columnPinningFeature.utils.ts`. TanStack calls
the two regions `start` and `end`; this port keeps phase 2's `left` and
`right` names for the same lists.

-}

import Dict exposing (Dict)
import Table.Internal.Column as Column
import Table.Internal.ColumnVisibility as Visibility
import Table.Internal.Types
    exposing
        ( Cell
        , Column
        , ColumnPinPosition(..)
        , ColumnPinning
        , ColumnRegion(..)
        , Config
        , PinnedColumns
        , Row
        , State
        )


{-| Nothing pinned on either side. Ports `getDefaultColumnPinningState`.
-}
defaultColumnPinning : ColumnPinning
defaultColumnPinning =
    { left = [], right = [] }



-- COLUMNS


{-| Pin one column, or unpin it with `ColumnUnpinned`. A group column pins
every leaf below it. Ports `column_pin`.
-}
pinColumn : ColumnPinPosition -> Column row -> State -> State
pinColumn position col state =
    let
        ids : List String
        ids =
            Column.leafColumnsOf col
                |> List.map Column.id
                |> List.filter (\cid -> cid /= "")

        without : List String -> List String
        without =
            List.filter (\cid -> not (List.member cid ids))

        pinning : ColumnPinning
        pinning =
            case position of
                PinnedLeft ->
                    { left = without state.columnPinning.left ++ ids
                    , right = without state.columnPinning.right
                    }

                PinnedRight ->
                    { left = without state.columnPinning.left
                    , right = without state.columnPinning.right ++ ids
                    }

                ColumnUnpinned ->
                    { left = without state.columnPinning.left
                    , right = without state.columnPinning.right
                    }
    in
    { state | columnPinning = pinning }


{-| Can this column be pinned? At least one leaf column has to allow it, and
`Config.enableColumnPinning` has to be on. Ports `column_getCanPin`.
-}
canPin : Config row -> Column row -> Bool
canPin cfg col =
    List.any
        (\leaf -> (Column.fields leaf).enablePinning && cfg.enableColumnPinning)
        (Column.leafColumnsOf col)


{-| Where is this column pinned? A group column reports the region of its
first pinned leaf, left before right. Ports `column_getIsPinned`.
-}
isPinned : State -> Column row -> ColumnPinPosition
isPinned state col =
    let
        ids : List String
        ids =
            List.map Column.id (Column.leafColumnsOf col)
    in
    if List.any (\cid -> List.member cid state.columnPinning.left) ids then
        PinnedLeft

    else if List.any (\cid -> List.member cid state.columnPinning.right) ids then
        PinnedRight

    else
        ColumnUnpinned


{-| The column's position inside its pinned region. Unpinned columns give
`0`, exactly like TanStack. Ports `column_getPinnedIndex`.
-}
pinnedIndex : State -> Column row -> Int
pinnedIndex state col =
    let
        indexIn : List String -> Int
        indexIn ids =
            ids
                |> List.indexedMap (\i cid -> ( i, cid ))
                |> List.filter (\( _, cid ) -> cid == Column.id col)
                |> List.head
                |> Maybe.map Tuple.first
                |> Maybe.withDefault -1
    in
    case isPinned state col of
        PinnedLeft ->
            indexIn state.columnPinning.left

        PinnedRight ->
            indexIn state.columnPinning.right

        ColumnUnpinned ->
            0



-- STATE


{-| Replace the pinning state. Ports `table_setColumnPinning`.
-}
setColumnPinning : ColumnPinning -> State -> State
setColumnPinning pinning state =
    { state | columnPinning = pinning }


{-| Unpin every column. Ports `table_resetColumnPinning(table, true)`.
-}
resetColumnPinning : State -> State
resetColumnPinning state =
    { state | columnPinning = defaultColumnPinning }


{-| Is any column pinned on either side? Ports
`table_getIsSomeColumnsPinned`.
-}
isSomeColumnsPinned : State -> Bool
isSomeColumnsPinned state =
    isSomeColumnsPinnedLeft state || isSomeColumnsPinnedRight state


{-| Is any column pinned left? Ports `table_getIsSomeColumnsPinned(table,
'start')`.
-}
isSomeColumnsPinnedLeft : State -> Bool
isSomeColumnsPinnedLeft state =
    not (List.isEmpty state.columnPinning.left)


{-| Is any column pinned right? Ports `table_getIsSomeColumnsPinned(table,
'end')`.
-}
isSomeColumnsPinnedRight : State -> Bool
isSomeColumnsPinnedRight state =
    not (List.isEmpty state.columnPinning.right)



-- LEAF COLUMN PARTITIONS


leafColumnsById : Config row -> State -> Dict String (Column row)
leafColumnsById cfg state =
    Column.orderedLeafColumns cfg state
        |> List.foldl (\c acc -> Dict.insert (Column.id c) c acc) Dict.empty


pinnedSide : Config row -> State -> List String -> List (Column row)
pinnedSide cfg state ids =
    let
        byId : Dict String (Column row)
        byId =
            leafColumnsById cfg state
    in
    List.filterMap (\cid -> Dict.get cid byId) ids


{-| The leaf columns pinned left, in pinning-state order. Ports
`table_getStartLeafColumns`.
-}
leftLeafColumns : Config row -> State -> List (Column row)
leftLeafColumns cfg state =
    pinnedSide cfg state state.columnPinning.left


{-| The leaf columns pinned right, in pinning-state order. Ports
`table_getEndLeafColumns`.
-}
rightLeafColumns : Config row -> State -> List (Column row)
rightLeafColumns cfg state =
    pinnedSide cfg state state.columnPinning.right


{-| The leaf columns that are not pinned, in table order. Ports
`table_getCenterLeafColumns`.
-}
centerLeafColumns : Config row -> State -> List (Column row)
centerLeafColumns cfg state =
    Column.orderedLeafColumns cfg state
        |> List.filter (\c -> not (isPinnedId state (Column.id c)))


isPinnedId : State -> String -> Bool
isPinnedId state cid =
    List.member cid state.columnPinning.left
        || List.member cid state.columnPinning.right


{-| The leaf columns of one region. `AllColumns` gives the whole table-ordered
list. Ports `table_getPinnedLeafColumns`.
-}
pinnedLeafColumns : Config row -> State -> ColumnRegion -> List (Column row)
pinnedLeafColumns cfg state region =
    case region of
        AllColumns ->
            Column.orderedLeafColumns cfg state

        LeftColumns ->
            leftLeafColumns cfg state

        CenterColumns ->
            centerLeafColumns cfg state

        RightColumns ->
            rightLeafColumns cfg state


{-| The visible leaf columns pinned left. Ports
`table_getStartVisibleLeafColumns`.
-}
leftVisibleLeafColumns : Config row -> State -> List (Column row)
leftVisibleLeafColumns cfg state =
    List.filter (Visibility.isVisible state) (leftLeafColumns cfg state)


{-| The visible leaf columns pinned right. Ports
`table_getEndVisibleLeafColumns`.
-}
rightVisibleLeafColumns : Config row -> State -> List (Column row)
rightVisibleLeafColumns cfg state =
    List.filter (Visibility.isVisible state) (rightLeafColumns cfg state)


{-| The visible leaf columns that are not pinned. Ports
`table_getCenterVisibleLeafColumns`.
-}
centerVisibleLeafColumns : Config row -> State -> List (Column row)
centerVisibleLeafColumns cfg state =
    List.filter (Visibility.isVisible state) (centerLeafColumns cfg state)


{-| The visible leaf columns of one region. `AllColumns` gives the whole
visible list in table order, with no pin partitioning, exactly like
`table_getPinnedVisibleLeafColumns` with no position.
-}
pinnedVisibleLeafColumns : Config row -> State -> ColumnRegion -> List (Column row)
pinnedVisibleLeafColumns cfg state region =
    case region of
        AllColumns ->
            Visibility.visibleLeafColumns cfg state

        LeftColumns ->
            leftVisibleLeafColumns cfg state

        CenterColumns ->
            centerVisibleLeafColumns cfg state

        RightColumns ->
            rightVisibleLeafColumns cfg state


{-| The three visible column slices at once, in render order.
-}
pinnedColumns : Config row -> State -> PinnedColumns row
pinnedColumns cfg state =
    { left = leftVisibleLeafColumns cfg state
    , center = centerVisibleLeafColumns cfg state
    , right = rightVisibleLeafColumns cfg state
    }



-- CELLS


{-| The visible cells of one row: left-pinned cells first, then the center
cells in table order, then the right-pinned cells. Ports
`row_getVisibleCells`.
-}
visibleCells : Config row -> State -> Row row -> List Cell
visibleCells cfg state row =
    let
        cells : List Cell
        cells =
            Visibility.visibleCellsOf cfg state row
    in
    if List.isEmpty state.columnPinning.left && List.isEmpty state.columnPinning.right then
        cells

    else
        let
            byId : Dict String Cell
            byId =
                cellsById cells
        in
        List.filterMap (\cid -> Dict.get cid byId) state.columnPinning.left
            ++ List.filter (\cell -> not (isPinnedId state cell.columnId)) cells
            ++ List.filterMap (\cid -> Dict.get cid byId) state.columnPinning.right


cellsById : List Cell -> Dict String Cell
cellsById =
    List.foldl (\cell acc -> Dict.insert cell.columnId cell acc) Dict.empty


{-| The visible cells of one row keyed by column id. Ports
`row_getVisibleCellsByColumnId`.
-}
visibleCellsByColumnId : Config row -> State -> Row row -> Dict String Cell
visibleCellsByColumnId cfg state row =
    cellsById (Visibility.visibleCellsOf cfg state row)


{-| The visible cells whose column is not pinned. Ports
`row_getCenterVisibleCells`.
-}
centerVisibleCells : Config row -> State -> Row row -> List Cell
centerVisibleCells cfg state row =
    visibleCells cfg state row
        |> List.filter (\cell -> not (isPinnedId state cell.columnId))


{-| The visible cells pinned left, in pinning-state order. Ports
`row_getStartVisibleCells`.
-}
leftVisibleCells : Config row -> State -> Row row -> List Cell
leftVisibleCells cfg state row =
    sideCells state.columnPinning.left cfg state row


{-| The visible cells pinned right, in pinning-state order. Ports
`row_getEndVisibleCells`.
-}
rightVisibleCells : Config row -> State -> Row row -> List Cell
rightVisibleCells cfg state row =
    sideCells state.columnPinning.right cfg state row


sideCells : List String -> Config row -> State -> Row row -> List Cell
sideCells ids cfg state row =
    if List.isEmpty ids then
        []

    else
        let
            byId : Dict String Cell
            byId =
                visibleCellsByColumnId cfg state row
        in
        List.filterMap (\cid -> Dict.get cid byId) ids
