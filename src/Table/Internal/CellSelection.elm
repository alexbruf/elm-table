module Table.Internal.CellSelection exposing
    ( canSelect
    , cellRange
    , clearCellSelection
    , columnIds
    , columnIndexes
    , edges
    , extendSelection
    , extendSelectionTo
    , focusedCell
    , isFocused
    , isSelected
    , mergeBounds
    , moveSelection
    , rowIds
    , selectAll
    , selectCell
    , selectRange
    , selectRangeWith
    , selectedCellCount
    , selectedCellIds
    , selectedRangesData
    , selectionBounds
    , setCellSelection
    , setFocusedCell
    , tabIndex
    , toggleSelection
    )

{-| Cell selection: rectangular selections stored as their two corners, the
include and exclude algebra over them, keyboard navigation, and the derived
reads a renderer needs.

Ports `features/cell-selection/cellSelectionFeature.utils.ts`. The DOM
handlers (`cell_getSelectionStartHandler`, `cell_getSelectionExtendHandler`)
have no counterpart here; the state transitions they drive are
[`selectCell`](#selectCell), [`extendSelectionTo`](#extendSelectionTo), and
[`toggleSelection`](#toggleSelection).

Every read takes a `SelectionRows`, because a range resolves against the
pre-pagination display order while spanning and keyboard navigation work on
the page a caller renders.

-}

import Array
import Dict exposing (Dict)
import Set exposing (Set)
import Table.Internal.CellSelectionGeometry as Geometry
import Table.Internal.CellSpanning as CellSpanning
import Table.Internal.Column as Column
import Table.Internal.Pagination as Pagination
import Table.Internal.Row as Row
import Table.Internal.Types
    exposing
        ( Cell
        , CellDirection(..)
        , CellSelectionBounds
        , CellSelectionEdges
        , CellSelectionMode(..)
        , CellSelectionOperation(..)
        , CellSelectionRange
        , CellSpanIndex
        , CellSpanIndexFields
        , Column
        , Config
        , Row
        , SelectionRows
        , State
        )
import Table.Value exposing (Value)



-- RANGES AND STATE


{-| A range from its two corners, taken as an inclusion. Corners are given in
the order `anchorRowId`, `anchorColumnId`, `focusRowId`, `focusColumnId`.
-}
cellRange : String -> String -> String -> String -> CellSelectionRange
cellRange anchorRowId anchorColumnId focusRowId focusColumnId =
    { anchorRowId = anchorRowId
    , anchorColumnId = anchorColumnId
    , focusRowId = focusRowId
    , focusColumnId = focusColumnId
    , operation = IncludeCells
    }


{-| Replace the whole selection. Ports `table_setCellSelection`.
-}
setCellSelection : List CellSelectionRange -> State -> State
setCellSelection ranges state =
    { state | cellSelection = ranges }


{-| Drop every range. Ports `table_resetCellSelection(table, true)`.
-}
clearCellSelection : State -> State
clearCellSelection state =
    { state | cellSelection = [] }


{-| Select a rectangle, replacing the selection. Ports
`table_selectCellRange` with no options.
-}
selectRange : CellSelectionRange -> State -> State
selectRange range state =
    selectRangeWith ReplaceSelection range state


{-| Select a rectangle with replace, include, or exclude semantics. Ports
`table_selectCellRange` with `opts.mode`.
-}
selectRangeWith : CellSelectionMode -> CellSelectionRange -> State -> State
selectRangeWith mode range state =
    let
        next : CellSelectionRange
        next =
            case mode of
                ExcludeSelection ->
                    { range | operation = ExcludeCells }

                _ ->
                    { range | operation = IncludeCells }
    in
    case mode of
        ReplaceSelection ->
            { state | cellSelection = [ next ] }

        _ ->
            { state | cellSelection = state.cellSelection ++ [ next ] }


activeRange : State -> Maybe CellSelectionRange
activeRange state =
    List.head (List.reverse state.cellSelection)


replaceActive : CellSelectionRange -> State -> State
replaceActive range state =
    { state
        | cellSelection =
            List.take (List.length state.cellSelection - 1) state.cellSelection ++ [ range ]
    }



-- COLUMNS


{-| The render-order index of every visible column id. Ports
`table_getCellSelectionColumnIndexes`.
-}
columnIndexes : Config row -> State -> Dict String Int
columnIndexes cfg state =
    CellSpanning.displayOrderedColumns cfg state
        |> List.map Column.id
        |> indexesOf


indexesOf : List String -> Dict String Int
indexesOf ids =
    List.foldl (\id ( i, acc ) -> ( i + 1, Dict.insert id i acc )) ( 0, Dict.empty ) ids
        |> Tuple.second


{-| Is cell selection switched off for the whole table? A per-cell predicate
counts as on, exactly like TanStack's `enableCellSelection === false` check.
-}
selectionDisabled : Config row -> Bool
selectionDisabled cfg =
    case cfg.cellSelectionFilter of
        Just _ ->
            False

        Nothing ->
            not cfg.enableCellSelection


hasPredicate : Config row -> Bool
hasPredicate cfg =
    case cfg.cellSelectionFilter of
        Just _ ->
            True

        Nothing ->
            False


columnAllows : Config row -> String -> Bool
columnAllows cfg columnId =
    case Column.findColumn cfg columnId of
        Just col ->
            (Column.fields col).enableCellSelection

        Nothing ->
            True


{-| The visible leaf columns that permit selection, in render order. A
column-level opt-out is enough; the per-cell predicate is not consulted.
Ports `getSelectableColumns`.
-}
selectableColumns : Config row -> State -> List (Column row)
selectableColumns cfg state =
    if selectionDisabled cfg then
        []

    else
        CellSpanning.displayOrderedColumns cfg state
            |> List.filter (\col -> (Column.fields col).enableCellSelection)


{-| Can this cell currently be selected? Ports `cell_getCanSelect`.
-}
canSelect : Config row -> Cell -> Bool
canSelect cfg cell =
    columnAllows cfg cell.columnId
        && (case cfg.cellSelectionFilter of
                Just predicate ->
                    predicate cell

                Nothing ->
                    cfg.enableCellSelection
           )



-- ROWS


displayRows : Config row -> State -> SelectionRows row -> List (Row row)
displayRows cfg state rows =
    Pagination.rowsInDisplayOrder cfg state rows.prePaginated


displayIndexes : Config row -> State -> SelectionRows row -> Dict String Int
displayIndexes cfg state rows =
    displayRows cfg state rows
        |> List.map Row.id
        |> indexesOf



-- MERGE BOUNDS


{-| The merged-cell rectangles of the rendered rows, in selection's
display-order index space. Empty when nothing spans. Ports
`table_getCellSelectionMergeBounds`.
-}
mergeBounds : Config row -> State -> SelectionRows row -> List CellSelectionBounds
mergeBounds cfg state rows =
    let
        index : CellSpanIndexFields
        index =
            CellSpanning.fields (CellSpanning.spanIndex cfg state rows.current)

        selectionColumns : Dict String Int
        selectionColumns =
            columnIndexes cfg state

        displays : Dict String Int
        displays =
            displayIndexes cfg state rows

        displayOf : Int -> Int
        displayOf position =
            case List.head (List.drop position index.rowIds) of
                Just rowId ->
                    Maybe.withDefault -1 (Dict.get rowId displays)

                Nothing ->
                    -1
    in
    verticalMerges index selectionColumns displayOf
        ++ horizontalMerges index selectionColumns displayOf


verticalMerges :
    CellSpanIndexFields
    -> Dict String Int
    -> (Int -> Int)
    -> List CellSelectionBounds
verticalMerges index selectionColumns displayOf =
    Dict.toList index.rowSpans
        |> List.concatMap
            (\( columnId, spans ) ->
                case Dict.get columnId selectionColumns of
                    Nothing ->
                        []

                    Just columnIndex ->
                        Array.toList spans
                            |> List.indexedMap Tuple.pair
                            |> List.filterMap (verticalMerge index columnId columnIndex displayOf)
            )


verticalMerge :
    CellSpanIndexFields
    -> String
    -> Int
    -> (Int -> Int)
    -> ( Int, Int )
    -> Maybe CellSelectionBounds
verticalMerge index columnId columnIndex displayOf ( position, span ) =
    if span <= 1 then
        Nothing

    else
        let
            startRow : Int
            startRow =
                displayOf position

            endRow : Int
            endRow =
                displayOf (position + span - 1)
        in
        if startRow < 0 || endRow - startRow /= span - 1 then
            Nothing

        else
            let
                colSpan : Int
                colSpan =
                    case Dict.get columnId index.columnIndexes of
                        Nothing ->
                            1

                        Just spanColumnIndex ->
                            Dict.get position index.colSpans
                                |> Maybe.andThen (Array.get spanColumnIndex)
                                |> Maybe.withDefault 1
                                |> Basics.max 1
            in
            Just
                { minRowIndex = startRow
                , maxRowIndex = endRow
                , minColumnIndex = columnIndex
                , maxColumnIndex = columnIndex + colSpan - 1
                }


horizontalMerges :
    CellSpanIndexFields
    -> Dict String Int
    -> (Int -> Int)
    -> List CellSelectionBounds
horizontalMerges index selectionColumns displayOf =
    Dict.toList index.colSpans
        |> List.concatMap
            (\( position, spans ) ->
                let
                    displayRow : Int
                    displayRow =
                        displayOf position
                in
                if displayRow < 0 then
                    []

                else
                    Array.toList spans
                        |> List.indexedMap Tuple.pair
                        |> List.filterMap
                            (horizontalMerge index selectionColumns position displayRow)
            )


horizontalMerge :
    CellSpanIndexFields
    -> Dict String Int
    -> Int
    -> Int
    -> ( Int, Int )
    -> Maybe CellSelectionBounds
horizontalMerge index selectionColumns position displayRow ( c, span ) =
    if span <= 1 then
        Nothing

    else
        case List.head (List.drop c index.columnIds) of
            Nothing ->
                Nothing

            Just columnId ->
                let
                    coveredByVertical : Bool
                    coveredByVertical =
                        case Dict.get columnId index.rowSpans of
                            Nothing ->
                                False

                            Just vertical ->
                                Array.get position vertical /= Just 1
                in
                if coveredByVertical then
                    Nothing

                else
                    Dict.get columnId selectionColumns
                        |> Maybe.map
                            (\columnIndex ->
                                { minRowIndex = displayRow
                                , maxRowIndex = displayRow
                                , minColumnIndex = columnIndex
                                , maxColumnIndex = columnIndex + span - 1
                                }
                            )



-- BOUNDS


{-| The final positive selection as disjoint, inclusive display-order index
rectangles. A range whose corners no longer resolve is omitted rather than
clamped. Ports `table_getCellSelectionBounds`.
-}
selectionBounds : Config row -> State -> SelectionRows row -> List CellSelectionBounds
selectionBounds cfg state rows =
    if List.isEmpty state.cellSelection then
        []

    else
        let
            displays : Dict String Int
            displays =
                displayIndexes cfg state rows

            columns : Dict String Int
            columns =
                columnIndexes cfg state

            merges : List CellSelectionBounds
            merges =
                mergeBounds cfg state rows

            resolve : CellSelectionRange -> Maybe ( CellSelectionOperation, CellSelectionBounds )
            resolve range =
                Maybe.map4
                    (\anchorRow focusRow anchorColumn focusColumn ->
                        ( range.operation
                        , { minRowIndex = Basics.min anchorRow focusRow
                          , maxRowIndex = Basics.max anchorRow focusRow
                          , minColumnIndex = Basics.min anchorColumn focusColumn
                          , maxColumnIndex = Basics.max anchorColumn focusColumn
                          }
                        )
                    )
                    (Dict.get range.anchorRowId displays)
                    (Dict.get range.focusRowId displays)
                    (Dict.get range.anchorColumnId columns)
                    (Dict.get range.focusColumnId columns)
        in
        List.filterMap resolve state.cellSelection
            |> List.map
                (\( operation, bounds ) ->
                    if List.isEmpty merges then
                        ( operation, bounds )

                    else
                        ( operation, Geometry.expand bounds merges )
                )
            |> Geometry.applyOperations


isWithin : List CellSelectionBounds -> Int -> Int -> Bool
isWithin bounds rowIndex columnIndex =
    List.any (Geometry.contains rowIndex columnIndex) bounds


{-| The bounds plus the cell's own coordinates, or `Nothing` when the cell
cannot take part in a selection at all. Ports `resolveCellPosition`.
-}
cellPosition :
    Config row
    -> State
    -> SelectionRows row
    -> Cell
    -> Maybe { bounds : List CellSelectionBounds, rowIndex : Int, columnIndex : Int }
cellPosition cfg state rows cell =
    let
        bounds : List CellSelectionBounds
        bounds =
            selectionBounds cfg state rows
    in
    if List.isEmpty bounds || not (canSelect cfg cell) then
        Nothing

    else
        Maybe.map2
            (\rowIndex columnIndex -> { bounds = bounds, rowIndex = rowIndex, columnIndex = columnIndex })
            (Dict.get cell.rowId (displayIndexes cfg state rows))
            (Dict.get cell.columnId (columnIndexes cfg state))


{-| Does this cell fall inside the final positive selection? Ports
`cell_getIsSelected`.
-}
isSelected : Config row -> State -> SelectionRows row -> Cell -> Bool
isSelected cfg state rows cell =
    case cellPosition cfg state rows cell of
        Nothing ->
            False

        Just position ->
            isWithin position.bounds position.rowIndex position.columnIndex


{-| Which sides of this cell sit on the outer boundary of the selection.
Ports `cell_getSelectionEdges`.
-}
edges : Config row -> State -> SelectionRows row -> Cell -> CellSelectionEdges
edges cfg state rows cell =
    let
        none : CellSelectionEdges
        none =
            { top = False, right = False, bottom = False, left = False }
    in
    case cellPosition cfg state rows cell of
        Nothing ->
            none

        Just { bounds, rowIndex, columnIndex } ->
            if not (isWithin bounds rowIndex columnIndex) then
                none

            else
                let
                    merges : List CellSelectionBounds
                    merges =
                        mergeBounds cfg state rows
                in
                case Geometry.findAt merges rowIndex columnIndex of
                    Nothing ->
                        { top = not (isWithin bounds (rowIndex - 1) columnIndex)
                        , right = not (isWithin bounds rowIndex (columnIndex + 1))
                        , bottom = not (isWithin bounds (rowIndex + 1) columnIndex)
                        , left = not (isWithin bounds rowIndex (columnIndex - 1))
                        }

                    Just merge ->
                        { top = stripOutside bounds True (merge.minRowIndex - 1) merge.minColumnIndex merge.maxColumnIndex
                        , right = stripOutside bounds False (merge.maxColumnIndex + 1) merge.minRowIndex merge.maxRowIndex
                        , bottom = stripOutside bounds True (merge.maxRowIndex + 1) merge.minColumnIndex merge.maxColumnIndex
                        , left = stripOutside bounds False (merge.minColumnIndex - 1) merge.minRowIndex merge.maxRowIndex
                        }


stripOutside : List CellSelectionBounds -> Bool -> Int -> Int -> Int -> Bool
stripOutside bounds fixedIsRow fixedIndex from to =
    List.range from to
        |> List.any
            (\i ->
                if fixedIsRow then
                    not (isWithin bounds fixedIndex i)

                else
                    not (isWithin bounds i fixedIndex)
            )



-- FOCUS


{-| The active cell: the anchor of the most recent operation. An exclusion's
active cell is focused even though it is not selected. Ports
`table_getFocusedCell`.
-}
focusedCell : Config row -> State -> SelectionRows row -> Maybe Cell
focusedCell cfg state rows =
    activeRange state
        |> Maybe.andThen
            (\active ->
                case Dict.get active.anchorRowId rows.prePaginated.rowsById of
                    Just row ->
                        cellOf cfg state row active.anchorColumnId

                    Nothing ->
                        Dict.get active.anchorRowId rows.current.rowsById
                            |> Maybe.andThen (\row -> cellOf cfg state row active.anchorColumnId)
            )


cellOf : Config row -> State -> Row row -> String -> Maybe Cell
cellOf cfg state row columnId =
    Row.getAllCells cfg state row
        |> List.filter (\cell -> cell.columnId == columnId)
        |> List.head


{-| Is this cell the anchor of the active range? Ports `cell_getIsFocused`.
-}
isFocused : State -> Cell -> Bool
isFocused state cell =
    case activeRange state of
        Nothing ->
            False

        Just active ->
            active.anchorRowId == cell.rowId && active.anchorColumnId == cell.columnId


{-| `0` for the focused cell and `-1` otherwise, for roving tabindex. Ports
`cell_getTabIndex`.
-}
tabIndex : State -> Cell -> Int
tabIndex state cell =
    if isFocused state cell then
        0

    else
        -1


{-| Collapse the selection to one cell. Ports `table_setFocusedCell`.
-}
setFocusedCell : String -> String -> State -> State
setFocusedCell rowId columnId state =
    selectRange (cellRange rowId columnId rowId columnId) state



-- POINTER TRANSITIONS


{-| Start a selection at one cell, replacing whatever was selected. The state
half of a plain `mousedown`.
-}
selectCell : Config row -> Cell -> State -> State
selectCell cfg cell state =
    if not (canSelect cfg cell) then
        state

    else
        selectRange (cellRange cell.rowId cell.columnId cell.rowId cell.columnId) state


{-| Move the active range's focus corner to this cell, keeping its anchor and
its operation. The state half of a shift-`mousedown` and of a drag's
`mouseenter`. Falls back to [`selectCell`](#selectCell) when there is no
active range or `Config.enableCellRangeSelection` is off.
-}
extendSelectionTo : Config row -> Cell -> State -> State
extendSelectionTo cfg cell state =
    if not (canSelect cfg cell) then
        state

    else if not cfg.enableCellRangeSelection then
        selectCell cfg cell state

    else
        case activeRange state of
            Nothing ->
                selectCell cfg cell state

            Just active ->
                replaceActive { active | focusRowId = cell.rowId, focusColumnId = cell.columnId } state


{-| Add a rectangle at this cell alongside the existing ranges, subtracting
instead when the cell is already selected. The state half of a
ctrl- or meta-`mousedown`. Falls back to [`selectCell`](#selectCell) when
`Config.enableMultiCellRangeSelection` is off.
-}
toggleSelection : Config row -> SelectionRows row -> Cell -> State -> State
toggleSelection cfg rows cell state =
    if not (canSelect cfg cell) then
        state

    else if not cfg.enableMultiCellRangeSelection then
        selectCell cfg cell state

    else
        let
            mode : CellSelectionMode
            mode =
                if isSelected cfg state rows cell then
                    ExcludeSelection

                else
                    IncludeSelection
        in
        selectRangeWith mode (cellRange cell.rowId cell.columnId cell.rowId cell.columnId) state


{-| Select every selectable cell as one range. Ports `table_selectAllCells`.
-}
selectAll : Config row -> SelectionRows row -> State -> State
selectAll cfg rows state =
    let
        rendered : List (Row row)
        rendered =
            displayRows cfg state rows

        columns : List (Column row)
        columns =
            selectableColumns cfg state
    in
    case ( ( List.head rendered, List.head (List.reverse rendered) ), ( List.head columns, List.head (List.reverse columns) ) ) of
        ( ( Just firstRow, Just lastRow ), ( Just firstColumn, Just lastColumn ) ) ->
            selectRange
                (cellRange (Row.id firstRow) (Column.id firstColumn) (Row.id lastRow) (Column.id lastColumn))
                state

        _ ->
            state



-- KEYBOARD NAVIGATION


delta : CellDirection -> ( Int, Int )
delta direction =
    case direction of
        CellUp ->
            ( -1, 0 )

        CellDown ->
            ( 1, 0 )

        CellLeft ->
            ( 0, -1 )

        CellRight ->
            ( 0, 1 )


{-| One step from a coordinate, skipping columns that cannot be selected and
treating a merged cell as a single stop. Ports `stepCoordinate`.
-}
step : Config row -> State -> SelectionRows row -> String -> String -> CellDirection -> Maybe ( String, String )
step cfg state rows rowId columnId direction =
    let
        pageRows : List (Row row)
        pageRows =
            rows.current.rows

        columns : List (Column row)
        columns =
            CellSpanning.displayOrderedColumns cfg state

        rowIndex : Int
        rowIndex =
            positionOf (\row -> Row.id row == rowId) pageRows

        columnIndex : Int
        columnIndex =
            positionOf (\col -> Column.id col == columnId) columns

        selectableIds : Set String
        selectableIds =
            selectableColumns cfg state
                |> List.map Column.id
                |> Set.fromList
    in
    if List.isEmpty pageRows || List.isEmpty columns || rowIndex < 0 || columnIndex < 0 || Set.isEmpty selectableIds then
        Nothing

    else
        let
            displays : Dict String Int
            displays =
                displayIndexes cfg state rows

            displayOf : Row row -> Int
            displayOf row =
                Maybe.withDefault -1 (Dict.get (Row.id row) displays)

            ( rowDelta, columnDelta ) =
                delta direction

            merges : List CellSelectionBounds
            merges =
                mergeBounds cfg state rows

            ownDisplayIndex : Int
            ownDisplayIndex =
                itemAt rowIndex pageRows |> Maybe.map displayOf |> Maybe.withDefault -1

            startMerge : Maybe CellSelectionBounds
            startMerge =
                Geometry.findAt merges rowIndex columnIndex

            fromRowIndex : Int
            fromRowIndex =
                case startMerge of
                    Just merge ->
                        if rowDelta > 0 then
                            merge.maxRowIndex

                        else if rowDelta < 0 then
                            merge.minRowIndex

                        else
                            ownDisplayIndex

                    Nothing ->
                        ownDisplayIndex

            nextRowIndex : Maybe Int
            nextRowIndex =
                if rowDelta /= 0 && fromRowIndex /= ownDisplayIndex then
                    let
                        edgeRowIndex : Int
                        edgeRowIndex =
                            positionOf (\row -> displayOf row == fromRowIndex) pageRows
                    in
                    if edgeRowIndex < 0 then
                        Nothing

                    else
                        Just (edgeRowIndex + rowDelta)

                else
                    Just (rowIndex + rowDelta)
        in
        case nextRowIndex of
            Nothing ->
                Nothing

            Just nextRow ->
                if nextRow < 0 || nextRow >= List.length pageRows then
                    Nothing

                else
                    let
                        fromColumnIndex : Int
                        fromColumnIndex =
                            case startMerge of
                                Just merge ->
                                    if columnDelta > 0 then
                                        merge.maxColumnIndex

                                    else if columnDelta < 0 then
                                        merge.minColumnIndex

                                    else
                                        columnIndex

                                Nothing ->
                                    columnIndex
                    in
                    landing pageRows
                        columns
                        merges
                        displays
                        selectableIds
                        { nextRow = nextRow
                        , nextColumn =
                            nextColumn columns selectableIds columnIndex fromColumnIndex columnDelta columnId
                        }


nextColumn : List (Column row) -> Set String -> Int -> Int -> Int -> String -> Int
nextColumn columns selectableIds columnIndex fromColumnIndex columnDelta columnId =
    if columnDelta /= 0 then
        stepColumn columns selectableIds (fromColumnIndex + columnDelta) columnDelta

    else if not (Set.member columnId selectableIds) then
        nearestSelectable columns selectableIds columnIndex 1

    else
        fromColumnIndex


stepColumn : List (Column row) -> Set String -> Int -> Int -> Int
stepColumn columns selectableIds candidate columnDelta =
    case itemAt candidate columns of
        Nothing ->
            candidate

        Just col ->
            if Set.member (Column.id col) selectableIds then
                candidate

            else
                stepColumn columns selectableIds (candidate + columnDelta) columnDelta


nearestSelectable : List (Column row) -> Set String -> Int -> Int -> Int
nearestSelectable columns selectableIds columnIndex distance =
    if distance >= List.length columns then
        columnIndex

    else
        let
            allows : Int -> Bool
            allows position =
                itemAt position columns
                    |> Maybe.map (\col -> Set.member (Column.id col) selectableIds)
                    |> Maybe.withDefault False
        in
        if allows (columnIndex - distance) then
            columnIndex - distance

        else if allows (columnIndex + distance) then
            columnIndex + distance

        else
            nearestSelectable columns selectableIds columnIndex (distance + 1)


landing :
    List (Row row)
    -> List (Column row)
    -> List CellSelectionBounds
    -> Dict String Int
    -> Set String
    -> { nextRow : Int, nextColumn : Int }
    -> Maybe ( String, String )
landing pageRows columns merges displays selectableIds next =
    let
        displayOf : Row row -> Int
        displayOf row =
            Maybe.withDefault -1 (Dict.get (Row.id row) displays)

        columnAllowed : Bool
        columnAllowed =
            itemAt next.nextColumn columns
                |> Maybe.map (\col -> Set.member (Column.id col) selectableIds)
                |> Maybe.withDefault False
    in
    if next.nextColumn < 0 || next.nextColumn >= List.length columns || not columnAllowed then
        Nothing

    else
        let
            landingMerge : Maybe CellSelectionBounds
            landingMerge =
                if List.isEmpty merges then
                    Nothing

                else
                    itemAt next.nextRow pageRows
                        |> Maybe.andThen
                            (\row -> Geometry.findAt merges (displayOf row) next.nextColumn)

            resolved : Maybe ( Int, Int )
            resolved =
                case landingMerge of
                    Nothing ->
                        Just ( next.nextRow, next.nextColumn )

                    Just merge ->
                        let
                            anchorRowIndex : Int
                            anchorRowIndex =
                                positionOf (\row -> displayOf row == merge.minRowIndex) pageRows
                        in
                        if anchorRowIndex < 0 then
                            Nothing

                        else
                            Just ( anchorRowIndex, merge.minColumnIndex )
        in
        resolved
            |> Maybe.andThen
                (\( landingRow, landingColumn ) ->
                    Maybe.map2 (\row col -> ( Row.id row, Column.id col ))
                        (itemAt landingRow pageRows)
                        (itemAt landingColumn columns)
                )


{-| Move the selection one step, collapsing it to a single cell. With nothing
selected this selects the first selectable cell. Ports
`table_moveCellSelection`.
-}
moveSelection : Config row -> SelectionRows row -> CellDirection -> State -> State
moveSelection cfg rows direction state =
    case activeRange state of
        Nothing ->
            case ( List.head rows.current.rows, List.head (selectableColumns cfg state) ) of
                ( Just row, Just col ) ->
                    setFocusedCell (Row.id row) (Column.id col) state

                _ ->
                    state

        Just active ->
            case step cfg state rows active.anchorRowId active.anchorColumnId direction of
                Nothing ->
                    state

                Just ( rowId, columnId ) ->
                    setFocusedCell rowId columnId state


{-| Extend the active range one step, keeping its anchor fixed. Ports
`table_extendCellSelection`.
-}
extendSelection : Config row -> SelectionRows row -> CellDirection -> State -> State
extendSelection cfg rows direction state =
    case activeRange state of
        Nothing ->
            moveSelection cfg rows direction state

        Just active ->
            case step cfg state rows active.focusRowId active.focusColumnId direction of
                Nothing ->
                    state

                Just ( rowId, columnId ) ->
                    replaceActive { active | focusRowId = rowId, focusColumnId = columnId } state



-- DERIVED DATA


type alias SelectedCell =
    { rangeIndex : Int
    , rowOffset : Int
    , cell : Cell
    }


{-| Every selectable cell of every final positive region, in row-major order.
Ports `forEachSelectedCell`.
-}
selectedCells : Config row -> State -> SelectionRows row -> Bool -> List SelectedCell
selectedCells cfg state rows skipCovered =
    let
        bounds : List CellSelectionBounds
        bounds =
            selectionBounds cfg state rows
    in
    if List.isEmpty bounds then
        []

    else
        let
            rendered : List (Row row)
            rendered =
                displayRows cfg state rows

            columns : List (Column row)
            columns =
                CellSpanning.displayOrderedColumns cfg state

            index : CellSpanIndex
            index =
                CellSpanning.spanIndex cfg state rows.current

            keep : Cell -> Bool
            keep cell =
                canSelect cfg cell
                    && not (skipCovered && CellSpanning.cellIsCovered index cell)
        in
        bounds
            |> List.indexedMap
                (\rangeIndex bound ->
                    List.range bound.minRowIndex bound.maxRowIndex
                        |> List.concatMap
                            (\rowIndex ->
                                case itemAt rowIndex rendered of
                                    Nothing ->
                                        []

                                    Just row ->
                                        let
                                            cells : Dict String Cell
                                            cells =
                                                Row.getAllCells cfg state row
                                                    |> List.foldl (\cell acc -> Dict.insert cell.columnId cell acc) Dict.empty
                                        in
                                        List.range bound.minColumnIndex bound.maxColumnIndex
                                            |> List.filterMap
                                                (\columnIndex ->
                                                    itemAt columnIndex columns
                                                        |> Maybe.andThen (\col -> Dict.get (Column.id col) cells)
                                                        |> Maybe.andThen
                                                            (\cell ->
                                                                if keep cell then
                                                                    Just
                                                                        { rangeIndex = rangeIndex
                                                                        , rowOffset = rowIndex - bound.minRowIndex
                                                                        , cell = cell
                                                                        }

                                                                else
                                                                    Nothing
                                                            )
                                                )
                            )
                )
            |> List.concat


{-| The unique ids of all selected cells, in row-major order. Cells another
cell's span covers are skipped. Ports `table_getSelectedCellIds`.
-}
selectedCellIds : Config row -> State -> SelectionRows row -> List String
selectedCellIds cfg state rows =
    selectedCells cfg state rows True
        |> List.map (.cell >> .id)
        |> dedupe Set.empty []


dedupe : Set String -> List String -> List String -> List String
dedupe seen acc ids =
    case ids of
        [] ->
            List.reverse acc

        id :: rest ->
            if Set.member id seen then
                dedupe seen acc rest

            else
                dedupe (Set.insert id seen) (id :: acc) rest


{-| Each final positive region's values as a row-major grid, indexed as
region, then row, then column. Ports `table_getSelectedCellRangesData`.
-}
selectedRangesData : Config row -> State -> SelectionRows row -> List (List (List Value))
selectedRangesData cfg state rows =
    selectedCells cfg state rows False
        |> groupBy .rangeIndex
        |> List.map (\cells -> groupBy .rowOffset cells |> List.map (List.map (.cell >> .value)))


groupBy : (SelectedCell -> Int) -> List SelectedCell -> List (List SelectedCell)
groupBy key cells =
    let
        keys : List Int
        keys =
            List.map key cells
                |> List.foldl
                    (\k acc ->
                        if List.member k acc then
                            acc

                        else
                            acc ++ [ k ]
                    )
                    []
    in
    List.map (\k -> List.filter (\cell -> key cell == k) cells) keys


{-| How many cells are selected. Ports `table_getSelectedCellCount`.
-}
selectedCellCount : Config row -> State -> SelectionRows row -> Int
selectedCellCount cfg state rows =
    if selectionDisabled cfg then
        0

    else
        let
            bounds : List CellSelectionBounds
            bounds =
                selectionBounds cfg state rows
        in
        if List.isEmpty bounds then
            0

        else if hasPredicate cfg || not (List.isEmpty (mergeBounds cfg state rows)) then
            List.length (selectedCellIds cfg state rows)

        else
            let
                columns : List (Column row)
                columns =
                    CellSpanning.displayOrderedColumns cfg state
            in
            bounds
                |> List.map
                    (\bound ->
                        let
                            selectableCount : Int
                            selectableCount =
                                List.range bound.minColumnIndex bound.maxColumnIndex
                                    |> List.filterMap (\columnIndex -> itemAt columnIndex columns)
                                    |> List.filter (\col -> (Column.fields col).enableCellSelection)
                                    |> List.length
                        in
                        (bound.maxRowIndex - bound.minRowIndex + 1) * selectableCount
                    )
                |> List.sum


{-| The ids of all rows the selection intersects. Ports
`table_getCellSelectionRowIds`.
-}
rowIds : Config row -> State -> SelectionRows row -> List String
rowIds cfg state rows =
    let
        bounds : List CellSelectionBounds
        bounds =
            selectionBounds cfg state rows

        rendered : List (Row row)
        rendered =
            displayRows cfg state rows
    in
    bounds
        |> List.concatMap
            (\bound ->
                List.range bound.minRowIndex bound.maxRowIndex
                    |> List.filterMap (\rowIndex -> itemAt rowIndex rendered)
                    |> List.map Row.id
            )
        |> dedupe Set.empty []


{-| The ids of all columns the selection intersects. Ports
`table_getCellSelectionColumnIds`.
-}
columnIds : Config row -> State -> SelectionRows row -> List String
columnIds cfg state rows =
    let
        bounds : List CellSelectionBounds
        bounds =
            selectionBounds cfg state rows

        columns : List (Column row)
        columns =
            CellSpanning.displayOrderedColumns cfg state
    in
    bounds
        |> List.concatMap
            (\bound ->
                List.range bound.minColumnIndex bound.maxColumnIndex
                    |> List.filterMap (\columnIndex -> itemAt columnIndex columns)
                    |> List.filter (\col -> (Column.fields col).enableCellSelection)
                    |> List.map Column.id
            )
        |> dedupe Set.empty []



-- LIST HELPERS


itemAt : Int -> List a -> Maybe a
itemAt position items =
    if position < 0 then
        Nothing

    else
        List.head (List.drop position items)


positionOf : (a -> Bool) -> List a -> Int
positionOf predicate items =
    positionHelp predicate 0 items


positionHelp : (a -> Bool) -> Int -> List a -> Int
positionHelp predicate position items =
    case items of
        [] ->
            -1

        item :: rest ->
            if predicate item then
                position

            else
                positionHelp predicate (position + 1) rest
