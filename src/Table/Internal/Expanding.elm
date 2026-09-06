module Table.Internal.Expanding exposing
    ( expandList
    , expandedRowModel
    , getCanSomeRowsExpand
    , getExpandedDepth
    , getIsAllParentsExpanded
    , getIsAllRowsExpanded
    , getIsSomeRowsExpanded
    , resetExpanded
    , rowCanExpand
    , rowIsExpanded
    , setExpanded
    , toggleAllRowsExpanded
    , toggleExpanded
    )

{-| Expansion: ports `row-expanding/createExpandedRowModel.ts` and
`row-expanding/rowExpandingFeature.utils.ts`.

`expandList` is the single `expandRows` of the port: the expanded row model
uses it, and so does `Table.Internal.Pagination` when
`Config.paginateExpandedRows` is `False` and the expansion has to happen
after the page slice instead of before it.

-}

import Dict
import Set exposing (Set)
import Table.Internal.Row as Row
import Table.Internal.Types exposing (Config, Expanded(..), Row(..), RowModel, State)



-- THE ROW MODEL


{-| Splice the sub-rows of every expanded row into the row list.

Nothing happens when the row model is empty or `State.expanded` names no row,
nor when `Config.paginateExpandedRows` is `False` and pagination is not
manual: in that case the paginator expands the page rows itself so the
children never take a page slot.

`flatRows` and `rowsById` pass through untouched, exactly as `expandRows`
leaves them.

-}
expandedRowModel : Config row -> State -> RowModel row -> RowModel row
expandedRowModel cfg state model =
    if List.isEmpty model.rows || not (getIsSomeRowsExpanded state) then
        model

    else if not cfg.paginateExpandedRows && not cfg.manualPagination then
        model

    else
        { rows = expandList cfg state model.rows
        , flatRows = model.flatRows
        , rowsById = model.rowsById
        }


{-| `expandRows`, on a plain row list: every row, followed by the sub-rows of
the expanded ones, depth first.
-}
expandList : Config row -> State -> List (Row row) -> List (Row row)
expandList cfg state rows =
    List.concatMap (expandOne cfg state) rows


expandOne : Config row -> State -> Row row -> List (Row row)
expandOne cfg state (Row f) =
    if not (List.isEmpty f.subRows) && rowIsExpanded cfg state (Row f) then
        Row f :: expandList cfg state f.subRows

    else
        [ Row f ]



-- EXPANDED STATE


{-| `row_getIsExpanded`: `Config.getIsRowExpanded` wins outright, otherwise
the row id is looked up in `State.expanded`.
-}
rowIsExpanded : Config row -> State -> Row row -> Bool
rowIsExpanded cfg state row =
    case cfg.getIsRowExpanded of
        Just fn ->
            fn row

        Nothing ->
            case state.expanded of
                ExpandAll ->
                    True

                ExpandedIds ids ->
                    Set.member (Row.id row) ids


{-| `row_getCanExpand`: `Config.getRowCanExpand` wins, otherwise expanding
must be enabled and the row must have sub-rows.
-}
rowCanExpand : Config row -> Row row -> Bool
rowCanExpand cfg row =
    case cfg.getRowCanExpand of
        Just fn ->
            fn row

        Nothing ->
            cfg.enableExpanding && not (List.isEmpty (Row.subRows row))


{-| `table_setExpanded`.
-}
setExpanded : Expanded -> State -> State
setExpanded expanded state =
    { state | expanded = expanded }


{-| `table_resetExpanded table true`.
-}
resetExpanded : State -> State
resetExpanded state =
    setExpanded (ExpandedIds Set.empty) state


{-| `row_toggleExpanded`. `Nothing` toggles, `Just` sets outright. Expanding
a row that cannot expand and any request that matches the current state are
no-ops; collapsing is always allowed so a stale id can be cleaned up.

The expanded-all state is materialised into the ids of the rows of the row
model that can expand before the change is applied, which is where the
`RowModel row` is needed.

-}
toggleExpanded : Config row -> RowModel row -> Row row -> Maybe Bool -> State -> State
toggleExpanded cfg model row wanted state =
    let
        rowId : String
        rowId =
            Row.id row

        exists : Bool
        exists =
            case state.expanded of
                ExpandAll ->
                    True

                ExpandedIds ids ->
                    Set.member rowId ids

        target : Bool
        target =
            Maybe.withDefault (not exists) wanted
    in
    if target == exists then
        state

    else if target && not (rowCanExpand cfg row) then
        state

    else
        let
            base : Set String
            base =
                case state.expanded of
                    ExpandAll ->
                        expandableIds cfg model

                    ExpandedIds ids ->
                        ids
        in
        setExpanded
            (ExpandedIds
                (if target then
                    Set.insert rowId base

                 else
                    Set.remove rowId base
                )
            )
            state


{-| `table_toggleAllRowsExpanded`. `Nothing` toggles on
[`getIsAllRowsExpanded`](#getIsAllRowsExpanded).
-}
toggleAllRowsExpanded : Config row -> RowModel row -> Maybe Bool -> State -> State
toggleAllRowsExpanded cfg model wanted state =
    let
        target : Bool
        target =
            Maybe.withDefault (not (getIsAllRowsExpanded cfg state model)) wanted
    in
    if target then
        case state.expanded of
            ExpandAll ->
                state

            ExpandedIds _ ->
                if getCanSomeRowsExpand cfg model then
                    setExpanded ExpandAll state

                else
                    state

    else
        case state.expanded of
            ExpandAll ->
                resetExpanded state

            ExpandedIds ids ->
                if Set.isEmpty ids then
                    state

                else
                    resetExpanded state


{-| `table_getCanSomeRowsExpand`, over the pre-pagination row model.
-}
getCanSomeRowsExpand : Config row -> RowModel row -> Bool
getCanSomeRowsExpand cfg model =
    List.any (rowCanExpand cfg) model.flatRows


{-| `table_getIsSomeRowsExpanded`. The expanded-all state counts.
-}
getIsSomeRowsExpanded : State -> Bool
getIsSomeRowsExpanded state =
    case state.expanded of
        ExpandAll ->
            True

        ExpandedIds ids ->
            not (Set.isEmpty ids)


{-| `table_getIsAllRowsExpanded`: every row of the row model that can expand
is expanded. An empty expanded state is `False`, and so is a state whose ids
no longer match any expandable row.
-}
getIsAllRowsExpanded : Config row -> State -> RowModel row -> Bool
getIsAllRowsExpanded cfg state model =
    case state.expanded of
        ExpandAll ->
            True

        ExpandedIds ids ->
            if Set.isEmpty ids then
                False

            else
                let
                    expandable : List (Row row)
                    expandable =
                        List.filter (rowCanExpand cfg) model.flatRows
                in
                not (List.isEmpty expandable)
                    && List.all (rowIsExpanded cfg state) expandable


{-| `table_getExpandedDepth`: the deepest expanded row id, counted in
`.`-separated segments.
-}
getExpandedDepth : Config row -> State -> RowModel row -> Int
getExpandedDepth cfg state model =
    let
        ids : List String
        ids =
            case state.expanded of
                ExpandAll ->
                    Set.toList (expandableIds cfg model)

                ExpandedIds expanded ->
                    Set.toList expanded
    in
    List.foldl (\rowId acc -> max acc (List.length (String.split "." rowId))) 0 ids


{-| `row_getIsAllParentsExpanded`: the row itself is not considered.
-}
getIsAllParentsExpanded : Config row -> State -> RowModel row -> Row row -> Bool
getIsAllParentsExpanded cfg state model row =
    case Row.getParentRow model row of
        Nothing ->
            True

        Just parent ->
            rowIsExpanded cfg state parent
                && getIsAllParentsExpanded cfg state model parent


expandableIds : Config row -> RowModel row -> Set String
expandableIds cfg model =
    Dict.foldl
        (\rowId row acc ->
            if rowCanExpand cfg row then
                Set.insert rowId acc

            else
                acc
        )
        Set.empty
        model.rowsById
