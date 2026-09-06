module Table.Internal.CellSelectionGeometry exposing
    ( add
    , applyOperations
    , contains
    , expand
    , findAt
    , intersect
    , mergeAdjacent
    , subtract
    )

{-| The rectangle algebra cell selection runs on.

Ports `features/cell-selection/cellSelectionGeometry.ts`. Every rectangle is
inclusive on all four sides and lives in display-order index space: rows are
positions in `Table.rowsInDisplayOrder`, columns are positions in the visible
leaf columns in render order.

-}

import Table.Internal.Types exposing (CellSelectionBounds, CellSelectionOperation(..))


compareBounds : CellSelectionBounds -> CellSelectionBounds -> Order
compareBounds a b =
    case Basics.compare a.minRowIndex b.minRowIndex of
        EQ ->
            case Basics.compare a.minColumnIndex b.minColumnIndex of
                EQ ->
                    case Basics.compare a.maxRowIndex b.maxRowIndex of
                        EQ ->
                            Basics.compare a.maxColumnIndex b.maxColumnIndex

                        other ->
                            other

                other ->
                    other

        other ->
            other


{-| Does this rectangle contain the given cell coordinate?
-}
contains : Int -> Int -> CellSelectionBounds -> Bool
contains rowIndex columnIndex bound =
    rowIndex
        >= bound.minRowIndex
        && rowIndex
        <= bound.maxRowIndex
        && columnIndex
        >= bound.minColumnIndex
        && columnIndex
        <= bound.maxColumnIndex


{-| The first rectangle of the list that contains the coordinate. Ports
`findMergeBoundsAt`.
-}
findAt : List CellSelectionBounds -> Int -> Int -> Maybe CellSelectionBounds
findAt bounds rowIndex columnIndex =
    List.filter (contains rowIndex columnIndex) bounds
        |> List.head


{-| The overlap of two rectangles, or `Nothing` when they are disjoint. Ports
`intersectCellSelectionBounds`.
-}
intersect : CellSelectionBounds -> CellSelectionBounds -> Maybe CellSelectionBounds
intersect a b =
    let
        intersection : CellSelectionBounds
        intersection =
            { minRowIndex = Basics.max a.minRowIndex b.minRowIndex
            , maxRowIndex = Basics.min a.maxRowIndex b.maxRowIndex
            , minColumnIndex = Basics.max a.minColumnIndex b.minColumnIndex
            , maxColumnIndex = Basics.min a.maxColumnIndex b.maxColumnIndex
            }
    in
    if
        intersection.minRowIndex
            <= intersection.maxRowIndex
            && intersection.minColumnIndex
            <= intersection.maxColumnIndex
    then
        Just intersection

    else
        Nothing


{-| The parts of `source` that `excluded` does not cover, as up to four
disjoint rectangles. Ports `subtractCellSelectionBounds`.
-}
subtract : CellSelectionBounds -> CellSelectionBounds -> List CellSelectionBounds
subtract source excluded =
    case intersect source excluded of
        Nothing ->
            [ source ]

        Just cut ->
            List.concat
                [ if source.minRowIndex < cut.minRowIndex then
                    [ { source | maxRowIndex = cut.minRowIndex - 1 } ]

                  else
                    []
                , if cut.maxRowIndex < source.maxRowIndex then
                    [ { source | minRowIndex = cut.maxRowIndex + 1 } ]

                  else
                    []
                , if source.minColumnIndex < cut.minColumnIndex then
                    [ { minRowIndex = cut.minRowIndex
                      , maxRowIndex = cut.maxRowIndex
                      , minColumnIndex = source.minColumnIndex
                      , maxColumnIndex = cut.minColumnIndex - 1
                      }
                    ]

                  else
                    []
                , if cut.maxColumnIndex < source.maxColumnIndex then
                    [ { minRowIndex = cut.minRowIndex
                      , maxRowIndex = cut.maxRowIndex
                      , minColumnIndex = cut.maxColumnIndex + 1
                      , maxColumnIndex = source.maxColumnIndex
                      }
                    ]

                  else
                    []
                ]


mergePair : CellSelectionBounds -> CellSelectionBounds -> Maybe CellSelectionBounds
mergePair a b =
    if
        a.minRowIndex
            == b.minRowIndex
            && a.maxRowIndex
            == b.maxRowIndex
            && (a.maxColumnIndex + 1 == b.minColumnIndex || b.maxColumnIndex + 1 == a.minColumnIndex)
    then
        Just
            { minRowIndex = a.minRowIndex
            , maxRowIndex = a.maxRowIndex
            , minColumnIndex = Basics.min a.minColumnIndex b.minColumnIndex
            , maxColumnIndex = Basics.max a.maxColumnIndex b.maxColumnIndex
            }

    else if
        a.minColumnIndex
            == b.minColumnIndex
            && a.maxColumnIndex
            == b.maxColumnIndex
            && (a.maxRowIndex + 1 == b.minRowIndex || b.maxRowIndex + 1 == a.minRowIndex)
    then
        Just
            { minRowIndex = Basics.min a.minRowIndex b.minRowIndex
            , maxRowIndex = Basics.max a.maxRowIndex b.maxRowIndex
            , minColumnIndex = a.minColumnIndex
            , maxColumnIndex = a.maxColumnIndex
            }

    else
        Nothing


{-| Fuse rectangles that share a full side into one, to a fixed point, then
sort. Ports `mergeAdjacentCellSelectionBounds`.
-}
mergeAdjacent : List CellSelectionBounds -> List CellSelectionBounds
mergeAdjacent input =
    mergeLoop input
        |> List.sortWith compareBounds


mergeLoop : List CellSelectionBounds -> List CellSelectionBounds
mergeLoop items =
    case mergeStep [] items of
        Just next ->
            mergeLoop next

        Nothing ->
            items


mergeStep : List CellSelectionBounds -> List CellSelectionBounds -> Maybe (List CellSelectionBounds)
mergeStep before rest =
    case rest of
        [] ->
            Nothing

        a :: after ->
            case mergeFirst a [] after of
                Just ( merged, remaining ) ->
                    Just (List.reverse before ++ (merged :: remaining))

                Nothing ->
                    mergeStep (a :: before) after


mergeFirst :
    CellSelectionBounds
    -> List CellSelectionBounds
    -> List CellSelectionBounds
    -> Maybe ( CellSelectionBounds, List CellSelectionBounds )
mergeFirst a seen candidates =
    case candidates of
        [] ->
            Nothing

        b :: rest ->
            case mergePair a b of
                Just merged ->
                    Just ( merged, List.reverse seen ++ rest )

                Nothing ->
                    mergeFirst a (b :: seen) rest


{-| Add a rectangle to a disjoint set, keeping the set disjoint. Ports
`addCellSelectionBounds`.
-}
add : List CellSelectionBounds -> CellSelectionBounds -> List CellSelectionBounds
add selected included =
    let
        fragments : List CellSelectionBounds
        fragments =
            List.foldl
                (\existing acc -> List.concatMap (\fragment -> subtract fragment existing) acc)
                [ included ]
                selected
    in
    if List.isEmpty fragments then
        selected

    else
        mergeAdjacent (selected ++ fragments)


{-| Grow a rectangle until it fully contains every merged-cell rectangle it
touches. Ports `expandCellSelectionBounds`.
-}
expand : CellSelectionBounds -> List CellSelectionBounds -> CellSelectionBounds
expand bounds merges =
    let
        pass : CellSelectionBounds -> CellSelectionBounds
        pass current =
            List.foldl
                (\merge acc ->
                    case intersect acc merge of
                        Nothing ->
                            acc

                        Just _ ->
                            { minRowIndex = Basics.min acc.minRowIndex merge.minRowIndex
                            , maxRowIndex = Basics.max acc.maxRowIndex merge.maxRowIndex
                            , minColumnIndex = Basics.min acc.minColumnIndex merge.minColumnIndex
                            , maxColumnIndex = Basics.max acc.maxColumnIndex merge.maxColumnIndex
                            }
                )
                current
                merges

        next : CellSelectionBounds
        next =
            pass bounds
    in
    if next == bounds then
        bounds

    else
        expand next merges


{-| Run ordered include and exclude operations, giving the final positive
selection as disjoint rectangles. Ports
`applyCellSelectionBoundsOperations`.
-}
applyOperations : List ( CellSelectionOperation, CellSelectionBounds ) -> List CellSelectionBounds
applyOperations operations =
    List.foldl applyOperation [] operations
        |> List.sortWith compareBounds


applyOperation : ( CellSelectionOperation, CellSelectionBounds ) -> List CellSelectionBounds -> List CellSelectionBounds
applyOperation ( operation, bounds ) selected =
    case operation of
        ExcludeCells ->
            mergeAdjacent (List.concatMap (\bound -> subtract bound bounds) selected)

        IncludeCells ->
            add selected bounds
