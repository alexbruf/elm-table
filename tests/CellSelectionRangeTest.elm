module CellSelectionRangeTest exposing (suite)

{-| Ports `tests/implementation/features/cell-selection/cellSelectionRange.test.ts`.

Only the memoization case is excluded; see `reports/phase-6.md`.

-}

import Dict
import Expect
import Table
import Table.FilterFn as FilterFn
import Table.Value as Value
import Test exposing (Test, describe, test)


type alias TestRow =
    { id : String
    , a : Float
    , b : Float
    , c : Float
    }


{-| `a` descends while row order ascends, so sorting on `a` reverses the rows.
-}
makeData : List TestRow
makeData =
    List.range 0 5
        |> List.map
            (\i ->
                { id = "r" ++ String.fromInt i
                , a = toFloat ((6 - i) * 10)
                , b = toFloat (i * 10 + 1)
                , c = toFloat (i * 10 + 2)
                }
            )


cfg : Table.Config TestRow
cfg =
    Table.config
        [ Table.column "a" (.a >> Value.Number) |> Table.withFilterFn FilterFn.inNumberRange
        , Table.column "b" (.b >> Value.Number)
        , Table.column "c" (.c >> Value.Number)
        ]
        |> Table.withGetRowId (\r _ _ -> r.id)


base : Table.State
base =
    Table.initialState


rowsOf : Table.State -> Table.SelectionRows TestRow
rowsOf state =
    let
        prePaginated : Table.RowModel TestRow
        prePaginated =
            Table.coreRowModelFromList cfg state makeData
                |> Table.filteredRowModel cfg state
                |> Table.groupedRowModel cfg state
                |> Table.sortedRowModel cfg state
                |> Table.expandedRowModel cfg state
    in
    { prePaginated = prePaginated
    , current = Table.paginatedRowModel cfg state prePaginated
    }


rows : Table.SelectionRows TestRow
rows =
    rowsOf base


rangeOf : String -> String -> String -> String -> Table.CellSelectionRange
rangeOf =
    Table.cellRange


bounds : Int -> Int -> Int -> Int -> Table.CellSelectionBounds
bounds minRowIndex maxRowIndex minColumnIndex maxColumnIndex =
    { minRowIndex = minRowIndex
    , maxRowIndex = maxRowIndex
    , minColumnIndex = minColumnIndex
    , maxColumnIndex = maxColumnIndex
    }


suite : Test
suite =
    describe "cell selection ranges"
        [ boundsSuite
        , sortingSuite
        , filteringSuite
        , paginationSuite
        , columnSuite
        , fallbackSuite
        ]


boundsSuite : Test
boundsSuite =
    describe "bounds resolution"
        [ test "normalizes corners into inclusive index rectangles" <|
            \_ ->
                Table.selectCellRange (rangeOf "r3" "c" "r1" "a") base
                    |> (\state -> Table.cellSelectionBounds cfg state rows)
                    |> Expect.equal [ bounds 1 3 0 2 ]
        , test "resolves multiple disjoint rectangles" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.selectCellRange (rangeOf "r0" "a" "r0" "a") base
                            |> Table.selectCellRangeWith Table.includeSelection (rangeOf "r4" "c" "r5" "c")
                in
                Expect.equal
                    { regions = List.length (Table.cellSelectionBounds cfg state rows)
                    , count = Table.selectedCellCount cfg state rows
                    , ids = Table.selectedCellIds cfg state rows
                    }
                    { regions = 2, count = 3, ids = [ "r0_a", "r4_c", "r5_c" ] }
        , test "deduplicates overlapping rectangles in the row/column rollups" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.selectCellRange (rangeOf "r0" "a" "r2" "b") base
                            |> Table.selectCellRangeWith Table.includeSelection (rangeOf "r1" "b" "r3" "c")
                in
                Expect.equal
                    ( Table.cellSelectionRowIds cfg state rows
                    , Table.cellSelectionColumnIds cfg state rows
                    )
                    ( [ "r0", "r1", "r2", "r3" ], [ "a", "b", "c" ] )
        , test "deduplicates overlapping rectangles in cell ids and count" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.selectCellRange (rangeOf "r0" "a" "r1" "b") base
                            |> Table.selectCellRangeWith Table.includeSelection (rangeOf "r1" "b" "r2" "c")
                in
                Expect.equal
                    ( Table.selectedCellIds cfg state rows
                    , Table.selectedCellCount cfg state rows
                    )
                    ( [ "r0_a", "r0_b", "r1_a", "r1_b", "r1_c", "r2_b", "r2_c" ], 7 )
        , test "subtracts a range from the positive selection geometry" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.selectCellRange (rangeOf "r0" "a" "r2" "c") base
                            |> Table.selectCellRangeWith Table.excludeSelection (rangeOf "r1" "b" "r1" "b")
                in
                Expect.equal
                    { count = Table.selectedCellCount cfg state rows
                    , hasCentre = List.member "r1_b" (Table.selectedCellIds cfg state rows)
                    , bounds = Table.cellSelectionBounds cfg state rows
                    }
                    { count = 8
                    , hasCentre = False
                    , bounds = [ bounds 0 0 0 2, bounds 1 1 0 0, bounds 1 1 2 2, bounds 2 2 0 2 ]
                    }
        , test "can include cells again after excluding them" <|
            \_ ->
                let
                    centre : Table.CellSelectionRange
                    centre =
                        rangeOf "r1" "b" "r1" "b"

                    state : Table.State
                    state =
                        Table.selectCellRange (rangeOf "r0" "a" "r2" "c") base
                            |> Table.selectCellRangeWith Table.excludeSelection centre
                            |> Table.selectCellRangeWith Table.includeSelection centre
                in
                Expect.equal
                    ( Table.selectedCellCount cfg state rows
                    , Table.cellSelectionBounds cfg state rows
                    )
                    ( 9, [ bounds 0 2 0 2 ] )

        -- Adapted: there is no deprecated `additive` option here, so the case
        -- asserts that `replaceSelection` replaces an existing selection.
        , test "lets mode override the deprecated additive option" <|
            \_ ->
                Table.selectCellRange (rangeOf "r0" "a" "r1" "b") base
                    |> Table.selectCellRangeWith Table.replaceSelection (rangeOf "r0" "a" "r0" "a")
                    |> (\state -> Table.selectedCellIds cfg state rows)
                    |> Expect.equal [ "r0_a" ]
        , test "recomputes when the selection changes" <|
            \_ ->
                let
                    first : List Table.CellSelectionBounds
                    first =
                        Table.selectCellRange (rangeOf "r0" "a" "r2" "b") base
                            |> (\state -> Table.cellSelectionBounds cfg state rows)

                    second : List Table.CellSelectionBounds
                    second =
                        Table.selectCellRange (rangeOf "r0" "a" "r3" "b") base
                            |> (\state -> Table.cellSelectionBounds cfg state rows)
                in
                Expect.equal
                    ( second == first, List.map .maxRowIndex second )
                    ( False, [ 3 ] )
        ]


sortingSuite : Test
sortingSuite =
    describe "sorting"
        [ test "keeps corners pinned to their cells and recomputes contents" <|
            \_ ->
                let
                    unsorted : Table.State
                    unsorted =
                        Table.selectCellRange (rangeOf "r0" "a" "r2" "a") base

                    sorted : Table.State
                    sorted =
                        Table.setSorting [ { id = "a", desc = False } ] unsorted
                in
                Expect.equal
                    { natural = Table.cellSelectionRowIds cfg unsorted rows
                    , sorted = Table.cellSelectionRowIds cfg sorted (rowsOf sorted)
                    , stored = sorted.cellSelection
                    }
                    { natural = [ "r0", "r1", "r2" ]
                    , sorted = [ "r2", "r1", "r0" ]
                    , stored = [ rangeOf "r0" "a" "r2" "a" ]
                    }
        , test "spans the reversed interval after sorting" <|
            \_ ->
                let
                    sorted : Table.State
                    sorted =
                        Table.setSorting [ { id = "a", desc = False } ] base
                            |> Table.selectCellRange (rangeOf "r5" "a" "r3" "a")

                    unsorted : Table.State
                    unsorted =
                        Table.setSorting [] sorted
                in
                Expect.equal
                    ( Table.cellSelectionRowIds cfg sorted (rowsOf sorted)
                    , Table.cellSelectionRowIds cfg unsorted (rowsOf unsorted)
                    )
                    ( [ "r5", "r4", "r3" ], [ "r3", "r4", "r5" ] )
        ]


filteringSuite : Test
filteringSuite =
    let
        upTo50 : List Table.ColumnFilter
        upTo50 =
            [ { id = "a", value = Value.List [ Value.Number 0, Value.Number 50 ] } ]
    in
    describe "filtering"
        [ test "goes inert when a corner is filtered out, then returns" <|
            \_ ->
                let
                    selected : Table.State
                    selected =
                        Table.selectCellRange (rangeOf "r0" "a" "r1" "b") base

                    filtered : Table.State
                    filtered =
                        { selected | columnFilters = upTo50 }

                    cleared : Table.State
                    cleared =
                        { filtered | columnFilters = [] }
                in
                Expect.equal
                    { before = Table.selectedCellCount cfg selected rows
                    , bounds = Table.cellSelectionBounds cfg filtered (rowsOf filtered)
                    , count = Table.selectedCellCount cfg filtered (rowsOf filtered)
                    , stored = filtered.cellSelection
                    , after = Table.selectedCellCount cfg cleared (rowsOf cleared)
                    }
                    { before = 4
                    , bounds = []
                    , count = 0
                    , stored = [ rangeOf "r0" "a" "r1" "b" ]
                    , after = 4
                    }
        , test "keeps a range whose corners both survive the filter" <|
            \_ ->
                let
                    filtered : Table.State
                    filtered =
                        Table.selectCellRange (rangeOf "r1" "a" "r2" "a") base
                            |> (\state -> { state | columnFilters = upTo50 })
                in
                Table.cellSelectionRowIds cfg filtered (rowsOf filtered)
                    |> Expect.equal [ "r1", "r2" ]
        ]


paginationSuite : Test
paginationSuite =
    let
        paged : Int -> Table.State
        paged pageIndex =
            { base | pagination = { pageIndex = pageIndex, pageSize = 2 } }
    in
    describe "pagination"
        [ test "resolves against pre-pagination indexes so ranges span pages" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.selectCellRange (rangeOf "r0" "a" "r4" "a") (paged 0)
                in
                Expect.equal
                    ( Table.cellSelectionRowIds cfg state (rowsOf state)
                    , Table.selectedCellCount cfg state (rowsOf state)
                    )
                    ( [ "r0", "r1", "r2", "r3", "r4" ], 5 )
        , test "keeps the same selection while paging" <|
            \_ ->
                let
                    first : Table.State
                    first =
                        Table.selectCellRange (rangeOf "r0" "a" "r4" "a") (paged 0)

                    later : Table.State
                    later =
                        { first | pagination = { pageIndex = 2, pageSize = 2 } }
                in
                Table.selectedCellIds cfg later (rowsOf later)
                    |> Expect.equal (Table.selectedCellIds cfg first (rowsOf first))
        ]


columnSuite : Test
columnSuite =
    describe "column visibility and order"
        [ test "drops a range whose corner column is hidden, then restores it" <|
            \_ ->
                let
                    selected : Table.State
                    selected =
                        Table.selectCellRange (rangeOf "r0" "a" "r1" "c") base

                    hidden : Table.State
                    hidden =
                        Table.setColumnVisibility (Dict.fromList [ ( "c", False ) ]) selected

                    shown : Table.State
                    shown =
                        Table.setColumnVisibility Dict.empty hidden
                in
                Expect.equal
                    { before = Table.selectedCellCount cfg selected rows
                    , hidden = Table.cellSelectionBounds cfg hidden (rowsOf hidden)
                    , after = Table.selectedCellCount cfg shown (rowsOf shown)
                    }
                    { before = 6, hidden = [], after = 6 }
        , test "narrows the rectangle when an interior column is hidden" <|
            \_ ->
                let
                    hidden : Table.State
                    hidden =
                        Table.selectCellRange (rangeOf "r0" "a" "r1" "c") base
                            |> Table.setColumnVisibility (Dict.fromList [ ( "b", False ) ])
                in
                Expect.equal
                    ( Table.cellSelectionColumnIds cfg hidden (rowsOf hidden)
                    , Table.selectedCellCount cfg hidden (rowsOf hidden)
                    )
                    ( [ "a", "c" ], 4 )
        , test "indexes columns in render order, not definition order, when pinned" <|
            \_ ->
                let
                    pinned : Table.State
                    pinned =
                        Table.setColumnPinning { left = [ "c" ], right = [] } base

                    state : Table.State
                    state =
                        Table.selectCellRange (rangeOf "r0" "c" "r0" "a") pinned
                in
                Expect.equal
                    { indexes = Table.cellSelectionColumnIndexes cfg pinned
                    , columnIds = Table.cellSelectionColumnIds cfg state (rowsOf state)
                    , cellIds = Table.selectedCellIds cfg state (rowsOf state)
                    }
                    { indexes = Dict.fromList [ ( "c", 0 ), ( "a", 1 ), ( "b", 2 ) ]
                    , columnIds = [ "c", "a" ]
                    , cellIds = [ "r0_c", "r0_a" ]
                    }
        , test "keeps a selection contiguous on screen when a column is pinned" <|
            \_ ->
                let
                    selected : Table.State
                    selected =
                        Table.selectCellRange (rangeOf "r0" "b" "r0" "c") base

                    pinned : Table.State
                    pinned =
                        Table.setColumnPinning { left = [], right = [ "a" ] } selected
                in
                Expect.equal
                    { before = Table.cellSelectionColumnIds cfg selected rows
                    , after = Table.cellSelectionColumnIds cfg pinned (rowsOf pinned)
                    , ids = Table.selectedCellIds cfg pinned (rowsOf pinned)
                    }
                    { before = [ "b", "c" ], after = [ "b", "c" ], ids = [ "r0_b", "r0_c" ] }
        , test "resolves end-pinned columns after center ones" <|
            \_ ->
                let
                    pinned : Table.State
                    pinned =
                        Table.setColumnPinning { left = [ "b" ], right = [ "a" ] } base

                    selected : Table.State
                    selected =
                        Table.selectAllCells cfg (rowsOf pinned) pinned
                in
                Expect.equal
                    ( Table.cellSelectionColumnIndexes cfg pinned
                    , Table.cellSelectionColumnIds cfg selected (rowsOf selected)
                    )
                    ( Dict.fromList [ ( "b", 0 ), ( "c", 1 ), ( "a", 2 ) ], [ "b", "c", "a" ] )
        , test "values follow render order under pinning" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.setColumnPinning { left = [ "c" ], right = [] } base
                            |> Table.selectCellRange (rangeOf "r0" "c" "r0" "a")
                in
                Table.selectedCellRangesData cfg state (rowsOf state)
                    |> Expect.equal [ [ [ Value.Number 2, Value.Number 60 ] ] ]
        , test "follows the column order rather than definition order" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.setColumnOrder [ "c", "b", "a" ] base
                            |> Table.selectCellRange (rangeOf "r0" "c" "r0" "b")
                in
                Expect.equal
                    ( Table.cellSelectionColumnIds cfg state (rowsOf state)
                    , Table.selectedCellIds cfg state (rowsOf state)
                    )
                    ( [ "c", "b" ], [ "r0_c", "r0_b" ] )
        ]


fallbackSuite : Test
fallbackSuite =
    -- Adapted: there is no feature registry, so "without
    -- columnVisibilityFeature registered" is the ordinary path.
    describe "without columnVisibilityFeature registered"
        [ test "still resolves column indexes through the static fallback" <|
            \_ ->
                Table.selectCellRange (rangeOf "r0" "a" "r1" "b") base
                    |> (\state -> Table.selectedCellIds cfg state rows)
                    |> Expect.equal [ "r0_a", "r0_b", "r1_a", "r1_b" ]
        ]
