module Table.Internal.RowPinning exposing
    ( bottomRows
    , canPin
    , centerRows
    , isPinned
    , isSomeRowsPinned
    , isSomeRowsPinnedBottom
    , isSomeRowsPinnedTop
    , pinRowWith
    , pinnedIndex
    , resetRowPinning
    , setRowPinning
    , topRows
    )

{-| Row pinning: which rows stick to the top or the bottom of the table.

Ports `features/row-pinning/rowPinningFeature.utils.ts`.

-}

import Dict
import Set exposing (Set)
import Table.Internal.Row as Row
import Table.Internal.Types
    exposing
        ( Config
        , Expanded(..)
        , PinRowOptions
        , PinnedRowsSource
        , Row
        , RowModel
        , RowPinPosition(..)
        , RowPinning
        , State
        )


{-| Nothing pinned at either edge. Ports `getDefaultRowPinningState`.
-}
defaultRowPinning : RowPinning
defaultRowPinning =
    { top = [], bottom = [] }



-- STATE


{-| Replace the row pinning state. Ports `table_setRowPinning`.
-}
setRowPinning : RowPinning -> State -> State
setRowPinning pinning state =
    { state | rowPinning = pinning }


{-| Unpin every row. Ports `table_resetRowPinning(table, true)`.
-}
resetRowPinning : State -> State
resetRowPinning state =
    { state | rowPinning = defaultRowPinning }


{-| Is any row pinned at either edge? Ports `table_getIsSomeRowsPinned`.
-}
isSomeRowsPinned : State -> Bool
isSomeRowsPinned state =
    isSomeRowsPinnedTop state || isSomeRowsPinnedBottom state


{-| Is any row pinned to the top? Ports `table_getIsSomeRowsPinned(table,
'top')`.
-}
isSomeRowsPinnedTop : State -> Bool
isSomeRowsPinnedTop state =
    not (List.isEmpty state.rowPinning.top)


{-| Is any row pinned to the bottom? Ports `table_getIsSomeRowsPinned(table,
'bottom')`.
-}
isSomeRowsPinnedBottom : State -> Bool
isSomeRowsPinnedBottom state =
    not (List.isEmpty state.rowPinning.bottom)



-- ROWS


{-| Can this row be pinned? Ports `row_getCanPin`.
-}
canPin : Config row -> Row row -> Bool
canPin cfg row =
    cfg.enableRowPinning row


{-| Where is this row pinned? Ports `row_getIsPinned`.
-}
isPinned : State -> Row row -> RowPinPosition
isPinned state row =
    if List.member (Row.id row) state.rowPinning.top then
        PinnedTop

    else if List.member (Row.id row) state.rowPinning.bottom then
        PinnedBottom

    else
        RowUnpinned


{-| The row's position among the pinned rows that are actually shown, or `-1`
when it is not pinned. Ports `row_getPinnedIndex`.
-}
pinnedIndex : Config row -> State -> PinnedRowsSource row -> Row row -> Int
pinnedIndex cfg state source row =
    let
        indexIn : List (Row row) -> Int
        indexIn rows =
            rows
                |> List.indexedMap (\i r -> ( i, Row.id r ))
                |> List.filter (\( _, rid ) -> rid == Row.id row)
                |> List.head
                |> Maybe.map Tuple.first
                |> Maybe.withDefault -1
    in
    case isPinned state row of
        PinnedTop ->
            indexIn (topRows cfg state source)

        PinnedBottom ->
            indexIn (bottomRows cfg state source)

        RowUnpinned ->
            -1


{-| Pin one row, or unpin it with `RowUnpinned`. The options add the row's
leaf rows and its ancestors to the same edge. Ports `row_pin`.
-}
pinRowWith : RowPinPosition -> PinRowOptions -> RowModel row -> Row row -> State -> State
pinRowWith position opts model row state =
    let
        leafIds : List String
        leafIds =
            if opts.includeLeafRows then
                List.map Row.id (Row.getLeafRows row)

            else
                []

        parentIds : List String
        parentIds =
            if opts.includeParentRows then
                List.map Row.id (Row.getParentRows model row)

            else
                []

        ids : List String
        ids =
            dedupe (parentIds ++ [ Row.id row ] ++ leafIds) Set.empty []

        without : List String -> List String
        without =
            List.filter (\rid -> not (List.member rid ids))

        pinning : RowPinning
        pinning =
            case position of
                PinnedTop ->
                    { top = without state.rowPinning.top ++ ids
                    , bottom = without state.rowPinning.bottom
                    }

                PinnedBottom ->
                    { top = without state.rowPinning.top
                    , bottom = without state.rowPinning.bottom ++ ids
                    }

                RowUnpinned ->
                    { top = without state.rowPinning.top
                    , bottom = without state.rowPinning.bottom
                    }
    in
    { state | rowPinning = pinning }


dedupe : List String -> Set String -> List String -> List String
dedupe ids seen acc =
    case ids of
        [] ->
            List.reverse acc

        first :: rest ->
            if Set.member first seen then
                dedupe rest seen acc

            else
                dedupe rest (Set.insert first seen) (first :: acc)



-- ROW LISTS


{-| The rows pinned to the top, in pinning-state order. With
`Config.keepPinnedRows` on they come from the pre-pagination model as long as
their parents are expanded; with it off, only rows of the current page are
kept. Ports `table_getTopRows`.
-}
topRows : Config row -> State -> PinnedRowsSource row -> List (Row row)
topRows cfg state source =
    pinnedRows cfg state source state.rowPinning.top


{-| The rows pinned to the bottom. Ports `table_getBottomRows`.
-}
bottomRows : Config row -> State -> PinnedRowsSource row -> List (Row row)
bottomRows cfg state source =
    pinnedRows cfg state source state.rowPinning.bottom


pinnedRows : Config row -> State -> PinnedRowsSource row -> List String -> List (Row row)
pinnedRows cfg state source ids =
    let
        pick : String -> Maybe (Row row)
        pick rowId =
            if cfg.keepPinnedRows then
                Dict.get rowId source.prePaginated.rowsById
                    |> Maybe.andThen
                        (\row ->
                            if allParentsExpanded state source.prePaginated row then
                                Just row

                            else
                                Nothing
                        )

            else
                source.current.rows
                    |> List.filter (\row -> Row.id row == rowId)
                    |> List.head
    in
    List.filterMap pick ids


{-| The rows of the current page that are not pinned. Ports
`table_getCenterRows`.
-}
centerRows : State -> RowModel row -> List (Row row)
centerRows state model =
    let
        pinnedIds : Set String
        pinnedIds =
            Set.fromList (state.rowPinning.top ++ state.rowPinning.bottom)
    in
    List.filter (\row -> not (Set.member (Row.id row) pinnedIds)) model.rows


{-| Is every ancestor of this row expanded? Ports
`row_getIsAllParentsExpanded`; the expanded row model itself is another
feature's job.
-}
allParentsExpanded : State -> RowModel row -> Row row -> Bool
allParentsExpanded state model row =
    case state.expanded of
        ExpandAll ->
            True

        ExpandedIds expanded ->
            case Maybe.andThen (\pid -> Dict.get pid model.rowsById) (Row.parentId row) of
                Nothing ->
                    True

                Just parent ->
                    Set.member (Row.id parent) expanded
                        && allParentsExpanded state model parent
