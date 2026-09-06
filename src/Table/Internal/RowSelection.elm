module Table.Internal.RowSelection exposing
    ( canMultiSelect
    , canSelect
    , canSelectRange
    , canSelectSubRows
    , defaultSelectOptions
    , deselectAllRows
    , isAllPageRowsSelected
    , isAllRowsSelected
    , isAllSubRowsSelected
    , isRowSelected
    , isSomePageRowsSelected
    , isSomeRowsSelected
    , isSomeSelected
    , resetRowSelection
    , selectRangeWith
    , selectedRowIds
    , selectedRowModel
    , setRowSelection
    , subRowSelection
    , toggleAllPageRowsSelected
    , toggleAllRowsSelected
    , toggleRowSelectedWith
    )

{-| Row selection.

Ports `features/row-selection/rowSelectionFeature.utils.ts`. The DOM half of
`row_getToggleSelectedHandler` is out of scope; its state half is
[`toggleRowSelectedWith`](#toggleRowSelectedWith) plus
[`selectRangeWith`](#selectRangeWith), which is the shift-click range.

-}

import Dict
import Set exposing (Set)
import Table.Internal.Row as Row
import Table.Internal.Types
    exposing
        ( Config
        , Row(..)
        , RowModel
        , SelectOptions
        , State
        , SubRowSelection(..)
        )


{-| `selectChildren` on, `deselectParents` off, matching TanStack's defaults
for `ToggleSelectedOptions`.
-}
defaultSelectOptions : SelectOptions
defaultSelectOptions =
    { selectChildren = True
    , deselectParents = False
    }



-- FLAGS


{-| Can this row be selected? Ports `row_getCanSelect`.
-}
canSelect : Config row -> Row row -> Bool
canSelect cfg row =
    cfg.enableRowSelection row


{-| Can selecting this row select its sub-rows? Ports
`row_getCanSelectSubRows`.
-}
canSelectSubRows : Config row -> Row row -> Bool
canSelectSubRows cfg row =
    cfg.enableSubRowSelection row


{-| Can this row take part in a multi-row selection? Ports
`row_getCanMultiSelect`.
-}
canMultiSelect : Config row -> Row row -> Bool
canMultiSelect cfg row =
    cfg.enableMultiRowSelection row



-- QUERIES


{-| Is this row selected? Ports `row_getIsSelected` and `isRowSelected`.
-}
isRowSelected : State -> Row row -> Bool
isRowSelected state row =
    Set.member (Row.id row) state.rowSelection


{-| The selected row ids. Ports `table_getSelectedRowIds`.
-}
selectedRowIds : State -> List String
selectedRowIds state =
    Set.toList state.rowSelection


{-| Is anything selected at all? Ports `table_getIsSomeRowsSelected`.
-}
isSomeRowsSelected : State -> Bool
isSomeRowsSelected state =
    not (Set.isEmpty state.rowSelection)


{-| How much of this row's sub-tree is selected. Ports `isSubRowSelected`.
-}
subRowSelection : Config row -> State -> Row row -> SubRowSelection
subRowSelection cfg state row =
    if List.isEmpty (Row.subRows row) then
        NoSubRowsSelected

    else
        let
            start : { someSelected : Bool, allChildren : Bool, someSelectable : Bool }
            start =
                { someSelected = False, allChildren = True, someSelectable = False }

            step :
                Row row
                -> { someSelected : Bool, allChildren : Bool, someSelectable : Bool }
                -> { someSelected : Bool, allChildren : Bool, someSelectable : Bool }
            step subRow acc =
                let
                    direct : { someSelected : Bool, allChildren : Bool, someSelectable : Bool }
                    direct =
                        if canSelect cfg subRow then
                            if isRowSelected state subRow then
                                { acc | someSelected = True, someSelectable = True }

                            else
                                { acc | allChildren = False, someSelectable = True }

                        else
                            acc
                in
                if List.isEmpty (Row.subRows subRow) then
                    direct

                else
                    case subRowSelection cfg state subRow of
                        AllSubRowsSelected ->
                            { direct | someSelected = True, someSelectable = True }

                        SomeSubRowsSelected ->
                            { direct | someSelected = True, allChildren = False, someSelectable = True }

                        NoSubRowsSelected ->
                            { direct | allChildren = False }

            result : { someSelected : Bool, allChildren : Bool, someSelectable : Bool }
            result =
                List.foldl step start (Row.subRows row)
        in
        if not result.someSelectable then
            NoSubRowsSelected

        else if result.allChildren then
            AllSubRowsSelected

        else if result.someSelected then
            SomeSubRowsSelected

        else
            NoSubRowsSelected


{-| Is part, but not all, of this row's sub-tree selected? Ports
`row_getIsSomeSelected`.
-}
isSomeSelected : Config row -> State -> Row row -> Bool
isSomeSelected cfg state row =
    subRowSelection cfg state row == SomeSubRowsSelected


{-| Is this row's whole sub-tree selected? Ports
`row_getIsAllSubRowsSelected`.
-}
isAllSubRowsSelected : Config row -> State -> Row row -> Bool
isAllSubRowsSelected cfg state row =
    subRowSelection cfg state row == AllSubRowsSelected


{-| Would a select-all reach this row? The row itself has to be selectable
and every ancestor has to allow sub-row selection. Ports
`isRowSelectableInSelectAll`.
-}
selectableInSelectAll : Config row -> RowModel row -> Row row -> Bool
selectableInSelectAll cfg model row =
    canSelect cfg row && ancestorsAllow cfg model (Row.parentId row)


ancestorsAllow : Config row -> RowModel row -> Maybe String -> Bool
ancestorsAllow cfg model parentId =
    case Maybe.andThen (\pid -> Dict.get pid model.rowsById) parentId of
        Nothing ->
            True

        Just parent ->
            canSelectSubRows cfg parent && ancestorsAllow cfg model (Row.parentId parent)


{-| Is every selectable row of the pre-grouped (filtered) model selected?
Ports `table_getIsAllRowsSelected`.
-}
isAllRowsSelected : Config row -> State -> RowModel row -> Bool
isAllRowsSelected cfg state model =
    not (List.isEmpty model.flatRows)
        && isSomeRowsSelected state
        && not
            (List.any
                (\row -> not (isRowSelected state row) && selectableInSelectAll cfg model row)
                model.flatRows
            )


{-| Is every selectable row of the current page selected? Ports
`table_getIsAllPageRowsSelected`.
-}
isAllPageRowsSelected : Config row -> State -> RowModel row -> Bool
isAllPageRowsSelected cfg state model =
    if
        List.any
            (\row -> not (isRowSelected state row) && selectableInSelectAll cfg model row)
            model.flatRows
    then
        False

    else
        List.any
            (\row -> isRowSelected state row && selectableInSelectAll cfg model row)
            model.flatRows


{-| Is any row of the current page selected, or partly selected? Ports
`table_getIsSomePageRowsSelected`.
-}
isSomePageRowsSelected : Config row -> State -> RowModel row -> Bool
isSomePageRowsSelected cfg state model =
    model.flatRows
        |> List.filter (canSelect cfg)
        |> List.any (\row -> isRowSelected state row || isSomeSelected cfg state row)



-- TRANSITIONS


{-| Replace the selection. Ports `table_setRowSelection`.
-}
setRowSelection : Set String -> State -> State
setRowSelection selection state =
    { state | rowSelection = selection }


{-| Clear the selection. Ports `table_resetRowSelection(table, true)`.
-}
resetRowSelection : State -> State
resetRowSelection state =
    { state | rowSelection = Set.empty }


{-| Clear the selection including ids of rows that cannot be selected. Ports
`table_toggleAllRowsSelected(table, false, { deselectAll: true })`.
-}
deselectAllRows : State -> State
deselectAllRows =
    resetRowSelection


{-| Select or deselect one row. `Nothing` flips it. Ports
`row_toggleSelected`.
-}
toggleRowSelectedWith : Config row -> SelectOptions -> RowModel row -> Row row -> Maybe Bool -> State -> State
toggleRowSelectedWith cfg opts model row value state =
    let
        wanted : Bool
        wanted =
            case value of
                Just v ->
                    v

                Nothing ->
                    not (isRowSelected state row)

        selection : Set String
        selection =
            mutate cfg
                { value = wanted
                , includeChildren = opts.selectChildren && canMultiSelect cfg row
                , respectCanSelectOnDeselect = False
                }
                row
                state.rowSelection
    in
    { state
        | rowSelection =
            if not wanted && opts.deselectParents then
                pruneAncestors model row selection

            else
                selection
    }


{-| Select or deselect every row of the pre-grouped (filtered) model.
`Nothing` flips on the current all-selected state. Ports
`table_toggleAllRowsSelected`.
-}
toggleAllRowsSelected : Config row -> RowModel row -> Maybe Bool -> State -> State
toggleAllRowsSelected cfg model value state =
    let
        wanted : Bool
        wanted =
            case value of
                Just v ->
                    v

                Nothing ->
                    not (isAllRowsSelected cfg state model)

        step : Row row -> Set String -> Set String
        step row acc =
            if wanted then
                if selectableInSelectAll cfg model row then
                    Set.insert (Row.id row) acc

                else
                    acc

            else if canSelect cfg row then
                Set.remove (Row.id row) acc

            else
                acc
    in
    { state | rowSelection = List.foldl step state.rowSelection model.flatRows }


{-| Select or deselect every row of the current page. Ports
`table_toggleAllPageRowsSelected`.
-}
toggleAllPageRowsSelected : Config row -> RowModel row -> Maybe Bool -> State -> State
toggleAllPageRowsSelected cfg model value state =
    let
        wanted : Bool
        wanted =
            case value of
                Just v ->
                    v

                Nothing ->
                    not (isAllPageRowsSelected cfg state model)

        step : Row row -> Set String -> Set String
        step row acc =
            mutate cfg
                { value = wanted
                , includeChildren = True
                , respectCanSelectOnDeselect = True
                }
                row
                acc
    in
    { state | rowSelection = List.foldl step state.rowSelection model.rows }


{-| Write one row, and optionally its sub-tree, into a selection set. Ports
`mutateRowIsSelected`.
-}
mutate :
    Config row
    -> { value : Bool, includeChildren : Bool, respectCanSelectOnDeselect : Bool }
    -> Row row
    -> Set String
    -> Set String
mutate cfg opts row selection =
    let
        here : Set String
        here =
            if opts.value then
                let
                    cleared : Set String
                    cleared =
                        if canMultiSelect cfg row then
                            selection

                        else
                            Set.empty
                in
                if canSelect cfg row then
                    Set.insert (Row.id row) cleared

                else
                    cleared

            else if not opts.respectCanSelectOnDeselect || canSelect cfg row then
                Set.remove (Row.id row) selection

            else
                selection
    in
    if opts.includeChildren && not (List.isEmpty (Row.subRows row)) && canSelectSubRows cfg row then
        List.foldl (mutate cfg opts) here (Row.subRows row)

    else
        here


{-| Drop every ancestor id of a row from a selection set. Ports
`pruneAncestorRowIds`.
-}
pruneAncestors : RowModel row -> Row row -> Set String -> Set String
pruneAncestors model row selection =
    case Maybe.andThen (\pid -> Dict.get pid model.rowsById) (Row.parentId row) of
        Nothing ->
            case Row.parentId row of
                Just pid ->
                    Set.remove pid selection

                Nothing ->
                    selection

        Just parent ->
            pruneAncestors model parent (Set.remove (Row.id parent) selection)



-- RANGES


{-| Can a shift-click from `anchorId` to this row select a range? Both
endpoints have to be in the display order and allow multi-selection. Ports
the guard half of `selectRowRange`.
-}
canSelectRange : Config row -> RowModel row -> String -> Row row -> Bool
canSelectRange cfg model anchorId row =
    case ( Dict.get anchorId model.rowsById, displayIndex model anchorId, displayIndex model (Row.id row) ) of
        ( Just anchor, Just _, Just _ ) ->
            canMultiSelect cfg anchor && canMultiSelect cfg row

        _ ->
            False


displayIndex : RowModel row -> String -> Maybe Int
displayIndex model rowId =
    model.rows
        |> List.indexedMap (\i row -> ( i, Row.id row ))
        |> List.filter (\( _, cid ) -> cid == rowId)
        |> List.head
        |> Maybe.map Tuple.first


{-| Select or deselect every row between the anchor and this row in display
order. Falls back to an ordinary toggle when the range is not usable, exactly
like the handler in TanStack. Ports `selectRowRange`.
-}
selectRangeWith : Config row -> SelectOptions -> RowModel row -> String -> Row row -> Bool -> State -> State
selectRangeWith cfg opts model anchorId row value state =
    case ( canSelectRange cfg model anchorId row, displayIndex model anchorId, displayIndex model (Row.id row) ) of
        ( True, Just anchorIndex, Just rowIndex ) ->
            let
                from : Int
                from =
                    Basics.min anchorIndex rowIndex

                to : Int
                to =
                    Basics.max anchorIndex rowIndex

                step : Row row -> Set String -> Set String
                step rangeRow acc =
                    if not (canSelect cfg rangeRow) || not (canMultiSelect cfg rangeRow) then
                        acc

                    else
                        let
                            written : Set String
                            written =
                                mutate cfg
                                    { value = value
                                    , includeChildren = opts.selectChildren
                                    , respectCanSelectOnDeselect = False
                                    }
                                    rangeRow
                                    acc
                        in
                        if not value && opts.deselectParents then
                            pruneAncestors model rangeRow written

                        else
                            written
            in
            { state
                | rowSelection =
                    model.rows
                        |> List.drop from
                        |> List.take (to - from + 1)
                        |> List.foldl step state.rowSelection
            }

        _ ->
            toggleRowSelectedWith cfg opts model row (Just value) state



-- SELECTED ROW MODEL


{-| Keep only the selected rows of a row model. Selected descendants of
unselected parents stay in `flatRows` and `rowsById` but not in `rows`, which
is what TanStack's `selectRowsFn` does.
-}
selectedRowModel : State -> RowModel row -> RowModel row
selectedRowModel state model =
    let
        ( rows, flat ) =
            selectRows state.rowSelection model.rows
    in
    { rows = rows
    , flatRows = flat
    , rowsById = List.foldl (\row acc -> Dict.insert (Row.id row) row acc) Dict.empty flat
    }


selectRows : Set String -> List (Row row) -> ( List (Row row), List (Row row) )
selectRows selection rows =
    case rows of
        [] ->
            ( [], [] )

        (Row f) :: rest ->
            let
                selected : Bool
                selected =
                    Set.member f.id selection

                ( childRows, childFlat ) =
                    selectRows selection f.subRows

                ( restRows, restFlat ) =
                    selectRows selection rest
            in
            if selected then
                ( Row { f | subRows = childRows } :: restRows
                , (Row f :: childFlat) ++ restFlat
                )

            else
                ( restRows, childFlat ++ restFlat )
