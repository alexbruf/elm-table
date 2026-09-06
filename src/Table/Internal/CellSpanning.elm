module Table.Internal.CellSpanning exposing
    ( canSpan
    , cellColSpan
    , cellIsCovered
    , cellRowSpan
    , displayOrderedColumns
    , fields
    , spanAllColumns
    , spanIndex
    , spanIndexRowIds
    , spanIndexRowSpans
    )

{-| Cell spanning: adjacent rows that share a value merge into one
row-spanning cell, and a column def may declare column-spanning cells per
row.

Ports `features/cell-spanning/cellSpanningFeature.utils.ts`.

The feature is stateless. Every span is derived from the rows a caller
actually renders, so sorting, filtering, pagination, expansion, and row
pinning only change adjacency and the index follows. Build the index once
with [`spanIndex`](#spanIndex) and read it per cell; there is no memoization
in this port, so rebuilding it per cell would be quadratic.

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Set exposing (Set)
import Table.Internal.Column as Column
import Table.Internal.ColumnPinning as ColumnPinning
import Table.Internal.Row as Row
import Table.Internal.RowPinning as RowPinning
import Table.Internal.Types
    exposing
        ( Cell
        , CellSpanIndex(..)
        , CellSpanIndexFields
        , Column
        , Config
        , Row
        , RowModel
        , RowSpanContext
        , SpanRows(..)
        , State
        )
import Table.Value exposing (Value(..))


{-| The stand-in for `Infinity` in a `spanColumns` callback: a span this wide
is always clamped to the end of the cell's pinned region.
-}
spanAllColumns : Int
spanAllColumns =
    9007199254740991


{-| Does this column take part in cell spanning? A column opting out wins
over the table option. Ports `column_getCanSpan`.
-}
canSpan : Config row -> Column row -> Bool
canSpan cfg col =
    (Column.fields col).enableCellSpanning && cfg.enableCellSpanning


{-| The visible leaf columns in the order their cells render: left-pinned
first, then center, then right-pinned. This is the order
`Table.visibleCells` emits, and the index space both cell spanning and cell
selection work in. Ports `getRenderedColumns` and cell selection's
`getDisplayOrderedColumns`.
-}
displayOrderedColumns : Config row -> State -> List (Column row)
displayOrderedColumns cfg state =
    ColumnPinning.leftVisibleLeafColumns cfg state
        ++ ColumnPinning.centerVisibleLeafColumns cfg state
        ++ ColumnPinning.rightVisibleLeafColumns cfg state


{-| The rows a renderer draws, in order, plus the positions at which a new
pinned section begins. Without row pinning this is the row model itself.
Ports `getRenderedRows`.
-}
renderedRows : Config row -> State -> RowModel row -> ( List (Row row), List Int )
renderedRows cfg state model =
    if List.isEmpty state.rowPinning.top && List.isEmpty state.rowPinning.bottom then
        ( model.rows, [] )

    else
        let
            source : { prePaginated : RowModel row, current : RowModel row }
            source =
                { prePaginated = model, current = model }

            top : List (Row row)
            top =
                RowPinning.topRows cfg state source

            center : List (Row row)
            center =
                RowPinning.centerRows state model

            bottom : List (Row row)
            bottom =
                RowPinning.bottomRows cfg state source
        in
        ( top ++ center ++ bottom
        , [ List.length top, List.length top + List.length center ]
        )


{-| The index's fields. Internal escape hatch for `Table.Internal.CellSelection`.
-}
fields : CellSpanIndex -> CellSpanIndexFields
fields (CellSpanIndex f) =
    f


{-| The row ids the index was built from, in render order. Ports
`CellSpanIndex.rows`.
-}
spanIndexRowIds : CellSpanIndex -> List String
spanIndexRowIds (CellSpanIndex f) =
    f.rowIds


{-| The vertical runs per column id, indexed by render-order row position.
Only columns that produced at least one run longer than one row appear. Ports
`CellSpanIndex.rowSpans`.
-}
spanIndexRowSpans : CellSpanIndex -> Dict String (List Int)
spanIndexRowSpans (CellSpanIndex f) =
    Dict.map (\_ spans -> Array.toList spans) f.rowSpans


{-| Build the span index of the rows a caller renders. Ports
`table_getCellSpanIndex`.
-}
spanIndex : Config row -> State -> RowModel row -> CellSpanIndex
spanIndex cfg state model =
    let
        ( rows, sectionStarts ) =
            renderedRows cfg state model

        columns : List (Column row)
        columns =
            displayOrderedColumns cfg state

        rowIds : List String
        rowIds =
            List.map Row.id rows

        base : CellSpanIndexFields
        base =
            { rowIds = rowIds
            , rowIndexes = indexesOf rowIds
            , columnIds = List.map Column.id columns
            , columnIndexes = indexesOf (List.map Column.id columns)
            , rowSpans = Dict.empty
            , colSpans = Dict.empty
            }

        rowCount : Int
        rowCount =
            List.length rows

        columnCount : Int
        columnCount =
            List.length columns
    in
    if rowCount == 0 || columnCount == 0 || not cfg.enableCellSpanning then
        CellSpanIndex base

    else
        let
            centerStart : Int
            centerStart =
                List.length (ColumnPinning.leftVisibleLeafColumns cfg state)

            centerEnd : Int
            centerEnd =
                columnCount - List.length (ColumnPinning.rightVisibleLeafColumns cfg state)

            colSpans : Dict Int (Array Int)
            colSpans =
                buildColSpans cfg rows columns columnCount centerStart centerEnd

            rowSpans : Dict String (Array Int)
            rowSpans =
                buildRowSpans cfg state rows columns colSpans (breaksOf rows sectionStarts)
        in
        CellSpanIndex { base | colSpans = colSpans, rowSpans = rowSpans }


indexesOf : List String -> Dict String Int
indexesOf ids =
    List.foldl (\id ( i, acc ) -> ( i + 1, Dict.insert id i acc )) ( 0, Dict.empty ) ids
        |> Tuple.second


{-| The row positions a vertical run may not merge across: the first row of
each pinned section, a row that sits at a different place in the row tree
than its predecessor, and every group row.
-}
breaksOf : List (Row row) -> List Int -> Set Int
breaksOf rows sectionStarts =
    let
        rowCount : Int
        rowCount =
            List.length rows

        fromSections : Set Int
        fromSections =
            List.filter (\start -> start < rowCount) sectionStarts
                |> Set.fromList

        step : Row row -> ( Int, Maybe (Row row), Set Int ) -> ( Int, Maybe (Row row), Set Int )
        step row ( r, previous, acc ) =
            let
                movedInTree : Bool
                movedInTree =
                    case previous of
                        Nothing ->
                            False

                        Just prev ->
                            Row.depth row /= Row.depth prev || Row.parentId row /= Row.parentId prev
            in
            ( r + 1
            , Just row
            , if movedInTree || Row.groupingColumnId row /= Nothing then
                Set.insert r acc

              else
                acc
            )
    in
    List.foldl step ( 0, Nothing, fromSections ) rows
        |> (\( _, _, acc ) -> acc)



-- PASS 1: COLUMN SPANS


buildColSpans : Config row -> List (Row row) -> List (Column row) -> Int -> Int -> Int -> Dict Int (Array Int)
buildColSpans cfg rows columns columnCount centerStart centerEnd =
    List.foldl (colSpansOfColumn cfg rows columnCount centerStart centerEnd) Dict.empty (withIndexes columns)


colSpansOfColumn :
    Config row
    -> List (Row row)
    -> Int
    -> Int
    -> Int
    -> ( Int, Column row )
    -> Dict Int (Array Int)
    -> Dict Int (Array Int)
colSpansOfColumn cfg rows columnCount centerStart centerEnd ( c, col ) acc =
    case ( (Column.fields col).spanColumns, canSpan cfg col ) of
        ( Just spanColumns, True ) ->
            let
                regionEnd : Int
                regionEnd =
                    if c < centerStart then
                        centerStart

                    else if c < centerEnd then
                        centerEnd

                    else
                        columnCount
            in
            List.foldl (colSpanOfRow spanColumns columnCount c regionEnd) acc (withIndexes rows)

        _ ->
            acc


colSpanOfRow :
    (Row row -> Int)
    -> Int
    -> Int
    -> Int
    -> ( Int, Row row )
    -> Dict Int (Array Int)
    -> Dict Int (Array Int)
colSpanOfRow spanColumns columnCount c regionEnd ( r, row ) acc =
    let
        existing : Maybe (Array Int)
        existing =
            Dict.get r acc

        covered : Bool
        covered =
            (existing |> Maybe.andThen (Array.get c)) == Just 0

        requested : Int
        requested =
            spanColumns row

        span : Int
        span =
            Basics.min requested (regionEnd - c)
    in
    if covered || requested <= 1 || span < 2 then
        acc

    else
        let
            target : Array Int
            target =
                Maybe.withDefault (Array.repeat columnCount 1) existing
        in
        Dict.insert r
            (List.foldl (\k a -> Array.set k 0 a) (Array.set c span target) (List.range (c + 1) (c + span - 1)))
            acc



-- PASS 2: ROW SPANS


buildRowSpans :
    Config row
    -> State
    -> List (Row row)
    -> List (Column row)
    -> Dict Int (Array Int)
    -> Set Int
    -> Dict String (Array Int)
buildRowSpans cfg state rows columns colSpans breaks =
    List.foldl (rowSpansOfColumn cfg state rows colSpans breaks) Dict.empty (withIndexes columns)


type alias RunState row =
    { spans : Array Int
    , anchorIndex : Int
    , anchorRow : Maybe (Row row)
    , anchorValue : Value
    , anchorColSpan : Int
    , anyRun : Bool
    , previousRow : Maybe (Row row)
    }


rowSpansOfColumn :
    Config row
    -> State
    -> List (Row row)
    -> Dict Int (Array Int)
    -> Set Int
    -> ( Int, Column row )
    -> Dict String (Array Int)
    -> Dict String (Array Int)
rowSpansOfColumn cfg state rows colSpans breaks ( c, col ) acc =
    let
        columnId : String
        columnId =
            Column.id col

        grouped : Bool
        grouped =
            List.member columnId state.grouping
    in
    case ( (Column.fields col).spanRows, canSpan cfg col && not grouped ) of
        ( Just spanRows, True ) ->
            let
                start : RunState row
                start =
                    { spans = Array.repeat (List.length rows) 1
                    , anchorIndex = -1
                    , anchorRow = Nothing
                    , anchorValue = Null
                    , anchorColSpan = 1
                    , anyRun = False
                    , previousRow = Nothing
                    }

                final : RunState row
                final =
                    List.foldl (rowSpanStep cfg spanRows columnId c colSpans breaks) start (withIndexes rows)
            in
            if final.anyRun then
                Dict.insert columnId final.spans acc

            else
                acc

        _ ->
            acc


rowSpanStep :
    Config row
    -> SpanRows row
    -> String
    -> Int
    -> Dict Int (Array Int)
    -> Set Int
    -> ( Int, Row row )
    -> RunState row
    -> RunState row
rowSpanStep cfg spanRows columnId c colSpans breaks ( r, row ) st =
    let
        cellSpan : Int
        cellSpan =
            Dict.get r colSpans
                |> Maybe.andThen (Array.get c)
                |> Maybe.withDefault 1
    in
    if cellSpan == 0 then
        { st | anchorIndex = -1, anchorRow = Nothing, previousRow = Just row }

    else
        let
            value : Value
            value =
                Row.getValue cfg row columnId

            joins : Bool
            joins =
                (st.anchorIndex >= 0)
                    && not (Set.member r breaks)
                    && (cellSpan == st.anchorColSpan)
                    && matches spanRows st row value
        in
        if joins then
            { st
                | spans =
                    st.spans
                        |> Array.set r 0
                        |> Array.set st.anchorIndex (1 + Maybe.withDefault 1 (Array.get st.anchorIndex st.spans))
                , anyRun = True
                , previousRow = Just row
            }

        else
            { st
                | anchorIndex = r
                , anchorRow = Just row
                , anchorValue = value
                , anchorColSpan = cellSpan
                , previousRow = Just row
            }


matches : SpanRows row -> RunState row -> Row row -> Value -> Bool
matches spanRows st row value =
    case spanRows of
        SpanRowsOnEqualValues ->
            value /= Null && value == st.anchorValue

        SpanRowsWhen predicate ->
            case ( st.anchorRow, st.previousRow ) of
                ( Just anchorRow, Just previousRow ) ->
                    predicate (context anchorRow previousRow row st.anchorValue value)

                _ ->
                    False


context : Row row -> Row row -> Row row -> Value -> Value -> RowSpanContext row
context anchorRow previousRow row anchorValue value =
    { anchorRow = anchorRow
    , anchorValue = anchorValue
    , previousRow = previousRow
    , row = row
    , value = value
    }


withIndexes : List a -> List ( Int, a )
withIndexes items =
    List.indexedMap Tuple.pair items



-- CELL READS


{-| How many rows this cell spans: `1` when it does not span, `0` when a
spanning cell above covers it. Ports `cell_getRowSpan`.
-}
cellRowSpan : CellSpanIndex -> Cell -> Int
cellRowSpan (CellSpanIndex f) cell =
    case ( Dict.get cell.columnId f.rowSpans, Dict.get cell.rowId f.rowIndexes ) of
        ( Just spans, Just r ) ->
            Maybe.withDefault 1 (Array.get r spans)

        _ ->
            1


{-| How many columns this cell spans: `1` when it does not span, `0` when
another cell's column span covers it. Ports `cell_getColSpan`.
-}
cellColSpan : CellSpanIndex -> Cell -> Int
cellColSpan (CellSpanIndex f) cell =
    case ( Dict.get cell.rowId f.rowIndexes, Dict.get cell.columnId f.columnIndexes ) of
        ( Just r, Just c ) ->
            Dict.get r f.colSpans
                |> Maybe.andThen (Array.get c)
                |> Maybe.withDefault 1

        _ ->
            1


{-| Does another cell's span cover this cell? Covered cells must not be
rendered. Ports `cell_getIsCovered`.
-}
cellIsCovered : CellSpanIndex -> Cell -> Bool
cellIsCovered index cell =
    cellRowSpan index cell == 0 || cellColSpan index cell == 0
