module CellSelectionGeometryTest exposing (suite)

{-| Ports `tests/implementation/features/cell-selection/cellSelectionGeometry.test.ts`.

Every case of that file is ported; see `reports/phase-6.md`.

-}

import Expect
import Table
import Test exposing (Test, describe, test)


bounds : Int -> Int -> Int -> Int -> Table.CellSelectionBounds
bounds minRowIndex maxRowIndex minColumnIndex maxColumnIndex =
    { minRowIndex = minRowIndex
    , maxRowIndex = maxRowIndex
    , minColumnIndex = minColumnIndex
    , maxColumnIndex = maxColumnIndex
    }


suite : Test
suite =
    describe "cellSelectionGeometry"
        [ describe "cell selection geometry"
            [ test "intersects inclusive rectangles" <|
                \_ ->
                    Expect.equal
                        ( Table.intersectCellSelectionBounds (bounds 0 2 0 2) (bounds 1 3 2 4)
                        , Table.intersectCellSelectionBounds (bounds 0 0 0 0) (bounds 1 1 1 1)
                        )
                        ( Just (bounds 1 2 2 2), Nothing )
            , test "cuts an interior rectangle into four disjoint pieces" <|
                \_ ->
                    Table.subtractCellSelectionBounds (bounds 0 4 0 4) (bounds 1 3 1 3)
                        |> Expect.equal
                            [ bounds 0 0 0 4
                            , bounds 4 4 0 4
                            , bounds 1 3 0 0
                            , bounds 1 3 4 4
                            ]
            , test "leaves a rectangle unchanged when the exclusion does not overlap" <|
                \_ ->
                    Table.subtractCellSelectionBounds (bounds 0 1 0 1) (bounds 3 4 3 4)
                        |> Expect.equal [ bounds 0 1 0 1 ]
            , test "adds only the uncovered fragments of overlapping rectangles" <|
                \_ ->
                    Table.addCellSelectionBounds [ bounds 0 1 0 1 ] (bounds 1 2 1 2)
                        |> Expect.equal [ bounds 0 1 0 1, bounds 1 1 2 2, bounds 2 2 1 2 ]
            , test "merges adjacent rectangles with identical spans" <|
                \_ ->
                    Table.mergeAdjacentCellSelectionBounds
                        [ bounds 2 2 0 2, bounds 0 0 0 2, bounds 1 1 0 2 ]
                        |> Expect.equal [ bounds 0 2 0 2 ]
            , test "applies include and exclude operations in order" <|
                \_ ->
                    Table.applyCellSelectionBoundsOperations
                        [ ( Table.includeCells, bounds 0 2 0 2 )
                        , ( Table.excludeCells, bounds 1 1 1 1 )
                        , ( Table.includeCells, bounds 1 1 1 1 )
                        ]
                        |> Expect.equal [ bounds 0 2 0 2 ]
            , test "ignores an exclusion before any matching inclusion" <|
                \_ ->
                    Table.applyCellSelectionBoundsOperations
                        [ ( Table.excludeCells, bounds 0 2 0 2 )
                        , ( Table.includeCells, bounds 1 1 1 1 )
                        ]
                        |> Expect.equal [ bounds 1 1 1 1 ]
            ]
        , describe "expandCellSelectionBounds"
            [ test "returns the rectangle unchanged with no merges or contained merges" <|
                \_ ->
                    Expect.equal
                        ( Table.expandCellSelectionBounds (bounds 0 2 0 2) []
                        , Table.expandCellSelectionBounds (bounds 0 4 0 4) [ bounds 1 2 1 1 ]
                          -- A disjoint merge never grows the rectangle.
                        , Table.expandCellSelectionBounds (bounds 0 1 0 1) [ bounds 5 7 0 0 ]
                        )
                        ( bounds 0 2 0 2, bounds 0 4 0 4, bounds 0 1 0 1 )
            , test "grows the rectangle to enclose a clipped merge" <|
                \_ ->
                    -- The rectangle clips the top row of a three-row merge.
                    Table.expandCellSelectionBounds (bounds 0 1 0 2) [ bounds 1 3 0 0 ]
                        |> Expect.equal (bounds 0 3 0 2)
            , test "cascades to a fixed point across chained merges" <|
                \_ ->
                    Table.expandCellSelectionBounds (bounds 1 1 0 2)
                        [ bounds 1 3 0 0, bounds 3 5 2 2, bounds 5 7 1 1 ]
                        |> Expect.equal (bounds 1 7 0 2)
            , test "keeps merges all-or-nothing through the operations algebra" <|
                \_ ->
                    let
                        merges : List Table.CellSelectionBounds
                        merges =
                            [ bounds 2 4 0 0 ]

                        selected : List Table.CellSelectionBounds
                        selected =
                            Table.applyCellSelectionBoundsOperations
                                [ ( Table.includeCells, Table.expandCellSelectionBounds (bounds 0 5 0 2) merges )
                                , ( Table.excludeCells, Table.expandCellSelectionBounds (bounds 3 3 0 0) merges )
                                ]

                        inside : Int -> Bool
                        inside rowIndex =
                            List.any
                                (\bound ->
                                    rowIndex
                                        >= bound.minRowIndex
                                        && rowIndex
                                        <= bound.maxRowIndex
                                        && bound.minColumnIndex
                                        <= 0
                                        && bound.maxColumnIndex
                                        >= 0
                                )
                                selected
                    in
                    List.range 2 4
                        |> List.map (\rowIndex -> ( rowIndex, inside rowIndex ))
                        |> Expect.equal [ ( 2, False ), ( 3, False ), ( 4, False ) ]
            ]
        ]
