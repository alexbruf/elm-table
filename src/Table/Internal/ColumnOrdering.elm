module Table.Internal.ColumnOrdering exposing
    ( columnIndex
    , isFirstColumn
    , isLastColumn
    , orderColumns
    , orderGroupedColumns
    , resetColumnOrder
    , setColumnOrder
    )

{-| Column order.

Ports `features/column-ordering/columnOrderingFeature.utils.ts`. The ordering
itself lives in `Table.Internal.Column` because every leaf column list goes
through it; this module holds the state transitions and the position queries.

-}

import Table.Internal.Column as Column
import Table.Internal.ColumnPinning as Pinning
import Table.Internal.Types exposing (Column, ColumnRegion, Config, State)


{-| Replace `State.columnOrder`. Ports `table_setColumnOrder`.
-}
setColumnOrder : List String -> State -> State
setColumnOrder order state =
    { state | columnOrder = order }


{-| Drop `State.columnOrder`, which restores definition order. Ports
`table_resetColumnOrder(table, true)`.
-}
resetColumnOrder : State -> State
resetColumnOrder state =
    { state | columnOrder = [] }


{-| Put a column list in table order: `State.columnOrder` first, then the
grouped-column rules. Ports `table_getOrderColumnsFn`.
-}
orderColumns : Config row -> State -> List (Column row) -> List (Column row)
orderColumns =
    Column.orderColumns


{-| Apply `Config.groupedColumnMode` to a leaf column list. Ports
`orderColumns`.
-}
orderGroupedColumns : Config row -> State -> List (Column row) -> List (Column row)
orderGroupedColumns =
    Column.orderGroupedColumns


{-| Where this column sits in one region of the visible leaf columns, or `-1`
when it is not there. Ports `column_getIndex`.
-}
columnIndex : Config row -> State -> ColumnRegion -> Column row -> Int
columnIndex cfg state region col =
    Pinning.pinnedVisibleLeafColumns cfg state region
        |> List.indexedMap (\i c -> ( i, Column.id c ))
        |> List.filter (\( _, cid ) -> cid == Column.id col)
        |> List.head
        |> Maybe.map Tuple.first
        |> Maybe.withDefault -1


{-| Is this the first visible column of the region? Ports
`column_getIsFirstColumn`.
-}
isFirstColumn : Config row -> State -> ColumnRegion -> Column row -> Bool
isFirstColumn cfg state region col =
    List.head (Pinning.pinnedVisibleLeafColumns cfg state region)
        |> Maybe.map (\first -> Column.id first == Column.id col)
        |> Maybe.withDefault False


{-| Is this the last visible column of the region? Ports
`column_getIsLastColumn`.
-}
isLastColumn : Config row -> State -> ColumnRegion -> Column row -> Bool
isLastColumn cfg state region col =
    Pinning.pinnedVisibleLeafColumns cfg state region
        |> List.reverse
        |> List.head
        |> Maybe.map (\last -> Column.id last == Column.id col)
        |> Maybe.withDefault False
