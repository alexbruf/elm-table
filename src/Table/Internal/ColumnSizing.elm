module Table.Internal.ColumnSizing exposing
    ( centerTotalSize
    , getAfter
    , getSize
    , getStart
    , headerSize
    , headerStart
    , leftTotalSize
    , resetColumnSize
    , resetColumnSizing
    , rightTotalSize
    , setColumnSize
    , setColumnSizing
    , totalSize
    )

{-| Column sizing: the committed sizes in `State.columnSizing`, the clamped
size of a column, and the offsets that follow from them.

Ports `features/column-sizing/columnSizingFeature.utils.ts`. Drag to resize
(`columnResizingFeature`) is out of scope, so there is no `columnSizingInfo`
and no resize handler.

-}

import Dict exposing (Dict)
import Table.Internal.Column as Column
import Table.Internal.ColumnPinning as Pinning
import Table.Internal.Header as Header
import Table.Internal.Types exposing (Column, ColumnRegion, Config, Header, HeaderGroup, State)



-- STATE


{-| Commit one column's size. Ports `table_setColumnSizing` for a single
column.
-}
setColumnSize : String -> Float -> State -> State
setColumnSize columnId px state =
    { state | columnSizing = Dict.insert columnId px state.columnSizing }


{-| Replace the whole sizing map. Ports `table_setColumnSizing`.
-}
setColumnSizing : Dict String Float -> State -> State
setColumnSizing sizing state =
    { state | columnSizing = sizing }


{-| Drop one column's committed size, leaving the rest alone. Ports
`column_resetSize`.
-}
resetColumnSize : String -> State -> State
resetColumnSize columnId state =
    { state | columnSizing = Dict.remove columnId state.columnSizing }


{-| Drop every committed size. Ports `table_resetColumnSizing(table, true)`.
-}
resetColumnSizing : State -> State
resetColumnSizing state =
    { state | columnSizing = Dict.empty }



-- SIZES


{-| The rendered width of a column: the committed size when there is one,
otherwise the column's own size, then the configured default, clamped between
`minSize` and `maxSize`. Ports `column_getSize`.
-}
getSize : Config row -> State -> Column row -> Float
getSize cfg state col =
    let
        wanted : Float
        wanted =
            case Dict.get (Column.id col) state.columnSizing of
                Just committed ->
                    committed

                Nothing ->
                    Maybe.withDefault cfg.defaultColumn.size (Column.fields col).size
    in
    Basics.min
        (Basics.max (Column.minSize cfg col) wanted)
        (Column.maxSize cfg col)


{-| How far from the start of its region a column begins: the sum of the
sizes of the visible columns before it. Ports `column_getStart`.
-}
getStart : Config row -> State -> ColumnRegion -> Column row -> Float
getStart cfg state region col =
    Pinning.pinnedVisibleLeafColumns cfg state region
        |> takeUntil (Column.id col)
        |> List.map (getSize cfg state)
        |> List.sum


{-| How far from the end of its region a column ends: the sum of the sizes of
the visible columns after it. Ports `column_getAfter`.
-}
getAfter : Config row -> State -> ColumnRegion -> Column row -> Float
getAfter cfg state region col =
    Pinning.pinnedVisibleLeafColumns cfg state region
        |> List.reverse
        |> takeUntil (Column.id col)
        |> List.map (getSize cfg state)
        |> List.sum


takeUntil : String -> List (Column row) -> List (Column row)
takeUntil columnId columns =
    case columns of
        [] ->
            []

        first :: rest ->
            if Column.id first == columnId then
                []

            else
                first :: takeUntil columnId rest



-- HEADERS


{-| The width of a header: its column's size for a leaf header, the sum of
the sub-header sizes for a parent header. Ports `header_getSize`.
-}
headerSize : Config row -> State -> Header row -> Float
headerSize cfg state header =
    case Header.subHeaders header of
        [] ->
            Column.findColumn cfg (Header.columnId header)
                |> Maybe.map (getSize cfg state)
                |> Maybe.withDefault 0

        subs ->
            List.sum (List.map (headerSize cfg state) subs)


{-| How far from the start of its header row a header begins: the sum of the
widths of its preceding siblings. Ports `header_getStart`.
-}
headerStart : Config row -> State -> List (Header row) -> Header row -> Float
headerStart cfg state headerRow header =
    headerRow
        |> List.filter (\h -> Header.index h < Header.index header)
        |> List.map (headerSize cfg state)
        |> List.sum



-- TOTALS


totalOf : Config row -> State -> List (HeaderGroup row) -> Float
totalOf cfg state groups =
    case groups of
        [] ->
            0

        top :: _ ->
            List.sum (List.map (headerSize cfg state) top.headers)


{-| The width of the whole table: the sum of the top header row. Ports
`table_getTotalSize`.
-}
totalSize : Config row -> State -> Float
totalSize cfg state =
    totalOf cfg state (Header.headerGroups cfg state)


{-| The width of the left-pinned region. Ports `table_getStartTotalSize`.
-}
leftTotalSize : Config row -> State -> Float
leftTotalSize cfg state =
    totalOf cfg state (Header.leftHeaderGroups cfg state)


{-| The width of the unpinned region. Ports `table_getCenterTotalSize`.
-}
centerTotalSize : Config row -> State -> Float
centerTotalSize cfg state =
    totalOf cfg state (Header.centerHeaderGroups cfg state)


{-| The width of the right-pinned region. Ports `table_getEndTotalSize`.
-}
rightTotalSize : Config row -> State -> Float
rightTotalSize cfg state =
    totalOf cfg state (Header.rightHeaderGroups cfg state)
