module CellSelectionFeatureTest exposing (suite)

{-| Ports `tests/implementation/features/cell-selection/cellSelectionFeature.test.ts`.

The `autoResetCellSelection` block and the handler cases whose assertions are
only about event plumbing or the drag session are excluded; the state half of
every handler is ported through `selectCell`, `extendCellSelectionTo`, and
`toggleCellSelection`. See `reports/phase-6.md`.

-}

import Dict
import Expect
import Table
import Table.Value as Value
import Test exposing (Test, describe, test)


type alias TestRow =
    { id : String
    , a : Float
    , b : Float
    , c : Float
    }


makeData : Int -> List TestRow
makeData count =
    List.range 0 (count - 1)
        |> List.map
            (\i ->
                { id = "r" ++ String.fromInt i
                , a = toFloat (i * 10)
                , b = toFloat (i * 10 + 1)
                , c = toFloat (i * 10 + 2)
                }
            )


columns : List (Table.Column TestRow)
columns =
    [ Table.column "a" (.a >> Value.Number)
    , Table.column "b" (.b >> Value.Number)
    , Table.column "c" (.c >> Value.Number)
    ]


{-| The vitest fixture's `columns` with `b` opted out.
-}
optedOutColumns : List (Table.Column TestRow)
optedOutColumns =
    [ Table.column "a" (.a >> Value.Number)
    , Table.column "b" (.b >> Value.Number) |> Table.withEnableCellSelection False
    , Table.column "c" (.c >> Value.Number)
    ]


configOf : List (Table.Column TestRow) -> Table.Config TestRow
configOf cols =
    Table.config cols
        |> Table.withGetRowId (\r _ _ -> r.id)


cfg : Table.Config TestRow
cfg =
    configOf columns


base : Table.State
base =
    Table.initialState


rowsOf : Table.Config TestRow -> Table.State -> List TestRow -> Table.SelectionRows TestRow
rowsOf config state data =
    let
        prePaginated : Table.RowModel TestRow
        prePaginated =
            Table.coreRowModelFromList config state data
                |> Table.filteredRowModel config state
                |> Table.groupedRowModel config state
                |> Table.sortedRowModel config state
                |> Table.expandedRowModel config state
    in
    { prePaginated = prePaginated
    , current = Table.paginatedRowModel config state prePaginated
    }


rows : Table.SelectionRows TestRow
rows =
    rowsOf cfg base (makeData 4)


getCell : Table.Config TestRow -> Table.State -> Table.SelectionRows TestRow -> String -> String -> Table.Cell
getCell config state selectionRows rowId columnId =
    case Dict.get rowId selectionRows.prePaginated.rowsById of
        Nothing ->
            { id = "", columnId = "", rowId = "", value = Value.Null }

        Just row ->
            Table.getAllCells config state row
                |> List.filter (\cell -> cell.columnId == columnId)
                |> List.head
                |> Maybe.withDefault { id = "", columnId = "", rowId = "", value = Value.Null }


cellOf : String -> String -> Table.Cell
cellOf rowId columnId =
    getCell cfg base rows rowId columnId


rangeOf : String -> String -> String -> String -> Table.CellSelectionRange
rangeOf =
    Table.cellRange


suite : Test
suite =
    describe "cellSelectionFeature"
        [ stateSuite
        , canSelectSuite
        , isSelectedSuite
        , focusSuite
        , edgesSuite
        , navigationSuite
        , derivedDataSuite
        , selectAllSuite
        , handlerSuite
        ]


stateSuite : Test
stateSuite =
    describe "state"
        [ test "defaults to an empty selection" <|
            \_ ->
                base.cellSelection |> Expect.equal []
        , test "respects initialState" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        { base | cellSelection = [ rangeOf "r0" "a" "r1" "b" ] }
                in
                Table.selectedCellCount cfg state rows |> Expect.equal 4

        -- Adapted: `Updater` has no counterpart, so the second half of the
        -- case sets the empty list directly.
        , test "setCellSelection accepts a value and an updater" <|
            \_ ->
                let
                    withOne : Table.State
                    withOne =
                        Table.setCellSelection [ rangeOf "r0" "a" "r0" "a" ] base
                in
                Expect.equal
                    ( List.length withOne.cellSelection
                    , List.length (Table.setCellSelection [] withOne).cellSelection
                    )
                    ( 1, 0 )

        -- Adapted: there is no `table.initialState`, so restoring a remembered
        -- initial slice is `setCellSelection`; `clearCellSelection` is
        -- TanStack's `resetCellSelection(table, true)`.
        , test "resetCellSelection restores initial state, or clears with true" <|
            \_ ->
                let
                    initial : List Table.CellSelectionRange
                    initial =
                        [ rangeOf "r0" "a" "r0" "a" ]

                    selected : Table.State
                    selected =
                        Table.selectCellRange (rangeOf "r1" "b" "r2" "c") { base | cellSelection = initial }
                in
                Expect.equal
                    { count = Table.selectedCellCount cfg selected rows
                    , restored = (Table.setCellSelection initial selected).cellSelection
                    , cleared = (Table.clearCellSelection selected).cellSelection
                    }
                    { count = 4, restored = initial, cleared = [] }

        -- Adapted: writes return a new `State` instead of calling
        -- `onCellSelectionChange`.
        , test "routes writes through onCellSelectionChange when provided" <|
            \_ ->
                (Table.selectCellRange (rangeOf "r0" "a" "r1" "b") base).cellSelection
                    |> Expect.equal [ rangeOf "r0" "a" "r1" "b" ]
        ]


canSelectSuite : Test
canSelectSuite =
    describe "cell.getCanSelect"
        [ test "defaults to true" <|
            \_ ->
                Table.cellCanSelect cfg (cellOf "r0" "a") |> Expect.equal True
        , test "honors the table-level boolean" <|
            \_ ->
                Table.cellCanSelect (Table.withCellSelection False cfg) (cellOf "r0" "a")
                    |> Expect.equal False
        , test "honors a per-cell predicate" <|
            \_ ->
                let
                    config : Table.Config TestRow
                    config =
                        Table.withCellSelectionWhen (\cell -> cell.rowId /= "r1") cfg
                in
                Expect.equal
                    ( Table.cellCanSelect config (cellOf "r0" "a")
                    , Table.cellCanSelect config (cellOf "r1" "a")
                    )
                    ( True, False )
        , test "lets a column def opt out" <|
            \_ ->
                let
                    config : Table.Config TestRow
                    config =
                        configOf optedOutColumns
                in
                Expect.equal
                    ( Table.cellCanSelect config (cellOf "r0" "a")
                    , Table.cellCanSelect config (cellOf "r0" "b")
                    )
                    ( True, False )
        ]


isSelectedSuite : Test
isSelectedSuite =
    let
        selected : Table.State
        selected =
            Table.selectCellRange (rangeOf "r1" "a" "r2" "b") base

        isSelected : Table.State -> String -> String -> Bool
        isSelected state rowId columnId =
            Table.cellIsSelected cfg state rows (cellOf rowId columnId)
    in
    describe "cell.getIsSelected"
        [ test "covers the inclusive rectangle" <|
            \_ ->
                Expect.equal
                    [ isSelected selected "r1" "a"
                    , isSelected selected "r1" "b"
                    , isSelected selected "r2" "a"
                    , isSelected selected "r2" "b"
                    ]
                    [ True, True, True, True ]
        , test "excludes cells outside the rectangle" <|
            \_ ->
                Expect.equal
                    [ isSelected selected "r0" "a"
                    , isSelected selected "r3" "a"
                    , isSelected selected "r1" "c"
                    ]
                    [ False, False, False ]
        , test "normalizes a range dragged up and to the left" <|
            \_ ->
                let
                    reversed : Table.State
                    reversed =
                        Table.selectCellRange (rangeOf "r2" "b" "r1" "a") base
                in
                Expect.equal
                    ( isSelected reversed "r1" "a", isSelected reversed "r2" "b" )
                    ( True, True )
        , test "excludes cells in an opted-out column inside the rectangle" <|
            \_ ->
                let
                    config : Table.Config TestRow
                    config =
                        configOf optedOutColumns

                    optedRows : Table.SelectionRows TestRow
                    optedRows =
                        rowsOf config base (makeData 4)

                    state : Table.State
                    state =
                        Table.selectCellRange (rangeOf "r0" "a" "r1" "c") base

                    at : String -> Bool
                    at columnId =
                        Table.cellIsSelected config state optedRows (getCell config base optedRows "r0" columnId)
                in
                Expect.equal [ at "a", at "b", at "c" ] [ True, False, True ]
        ]


focusSuite : Test
focusSuite =
    describe "focus"
        [ test "derives the focused cell from the active range anchor" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.selectCellRange (rangeOf "r1" "b" "r3" "c") base
                in
                Expect.equal
                    { focused = Table.focusedCell cfg state rows |> Maybe.map .id
                    , anchorIsFocused = Table.cellIsFocused state (cellOf "r1" "b")
                    , movingCornerIsFocused = Table.cellIsFocused state (cellOf "r3" "c")
                    }
                    { focused = Just "r1_b", anchorIsFocused = True, movingCornerIsFocused = False }
        , test "is undefined with nothing selected" <|
            \_ ->
                Table.focusedCell cfg base rows |> Expect.equal Nothing
        , test "drives roving tabindex" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.setFocusedCell "r2" "c" base
                in
                Expect.equal
                    ( Table.cellTabIndex state (cellOf "r2" "c")
                    , Table.cellTabIndex state (cellOf "r0" "a")
                    )
                    ( 0, -1 )
        , test "setFocusedCell collapses the selection to one cell" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.selectCellRange (rangeOf "r0" "a" "r3" "c") base
                            |> Table.setFocusedCell "r1" "b"
                in
                Expect.equal
                    ( Table.selectedCellCount cfg state rows, Table.selectedCellIds cfg state rows )
                    ( 1, [ "r1_b" ] )
        ]


edgesSuite : Test
edgesSuite =
    describe "cell.getSelectionEdges"
        [ test "reports all four sides for a single-cell selection" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.setFocusedCell "r1" "b" base
                in
                Table.cellSelectionEdges cfg state rows (cellOf "r1" "b")
                    |> Expect.equal { top = True, right = True, bottom = True, left = True }
        , test "reports only outer sides inside a larger rectangle" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.selectCellRange (rangeOf "r0" "a" "r2" "c") base
                in
                Expect.equal
                    [ Table.cellSelectionEdges cfg state rows (cellOf "r0" "a")
                    , Table.cellSelectionEdges cfg state rows (cellOf "r1" "b")
                    , Table.cellSelectionEdges cfg state rows (cellOf "r2" "c")
                    ]
                    [ { top = True, right = False, bottom = False, left = True }
                    , { top = False, right = False, bottom = False, left = False }
                    , { top = False, right = True, bottom = True, left = False }
                    ]
        , test "reports no edges for an unselected cell" <|
            \_ ->
                Table.cellSelectionEdges cfg base rows (cellOf "r0" "a")
                    |> Expect.equal { top = False, right = False, bottom = False, left = False }
        ]


navigationSuite : Test
navigationSuite =
    let
        optedConfig : Table.Config TestRow
        optedConfig =
            configOf optedOutColumns

        optedRows : Table.SelectionRows TestRow
        optedRows =
            rowsOf optedConfig base (makeData 4)

        paged : Table.State
        paged =
            { base | pagination = { pageIndex = 1, pageSize = 2 } }

        pagedRows : Table.SelectionRows TestRow
        pagedRows =
            rowsOf cfg paged (makeData 6)
    in
    describe "navigation"
        [ test "moveCellSelection seeds the first cell when nothing is selected" <|
            \_ ->
                Table.moveCellSelection cfg rows Table.cellDown base
                    |> (\state -> Table.selectedCellIds cfg state rows)
                    |> Expect.equal [ "r0_a" ]
        , test "moveCellSelection collapses to a single moved cell" <|
            \_ ->
                Table.selectCellRange (rangeOf "r0" "a" "r2" "c") base
                    |> Table.moveCellSelection cfg rows Table.cellDown
                    |> (\state -> Table.selectedCellIds cfg state rows)
                    |> Expect.equal [ "r1_a" ]
        , test "moveCellSelection stops at the grid edges" <|
            \_ ->
                let
                    start : Table.State
                    start =
                        Table.setFocusedCell "r0" "a" base

                    up : Table.State
                    up =
                        Table.moveCellSelection cfg rows Table.cellUp start
                in
                Expect.equal
                    ( Table.selectedCellIds cfg up rows
                    , Table.selectedCellIds cfg (Table.moveCellSelection cfg rows Table.cellLeft up) rows
                    )
                    ( [ "r0_a" ], [ "r0_a" ] )
        , test "moveCellSelection skips over opted-out columns" <|
            \_ ->
                Table.setFocusedCell "r0" "a" base
                    |> Table.moveCellSelection optedConfig optedRows Table.cellRight
                    |> (\state -> Table.selectedCellIds optedConfig state optedRows)
                    |> Expect.equal [ "r0_c" ]
        , test "recovers navigation from an opted-out anchor column" <|
            \_ ->
                let
                    from : Table.CellDirection -> List String
                    from direction =
                        Table.setFocusedCell "r0" "b" base
                            |> Table.moveCellSelection optedConfig optedRows direction
                            |> (\state -> Table.selectedCellIds optedConfig state optedRows)
                in
                Expect.equal
                    ( from Table.cellRight, from Table.cellLeft, from Table.cellDown )
                    ( [ "r0_c" ], [ "r0_a" ], [ "r1_a" ] )
        , test "extendCellSelection moves the focus and keeps the anchor" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.setFocusedCell "r1" "a" base
                            |> Table.extendCellSelection cfg rows Table.cellDown
                            |> Table.extendCellSelection cfg rows Table.cellRight
                in
                Expect.equal
                    ( state.cellSelection, Table.selectedCellCount cfg state rows )
                    ( [ rangeOf "r1" "a" "r2" "b" ], 4 )
        , test "extendCellSelection stops at the grid edges" <|
            \_ ->
                Table.setFocusedCell "r0" "a" base
                    |> Table.extendCellSelection cfg rows Table.cellUp
                    |> (\state -> Table.selectedCellCount cfg state rows)
                    |> Expect.equal 1
        , test "keeps movement within the current pagination page" <|
            \_ ->
                let
                    first : Table.State
                    first =
                        Table.moveCellSelection cfg pagedRows Table.cellDown paged

                    second : Table.State
                    second =
                        Table.moveCellSelection cfg pagedRows Table.cellDown first

                    third : Table.State
                    third =
                        Table.moveCellSelection cfg pagedRows Table.cellDown second

                    ids : Table.State -> List String
                    ids state =
                        Table.selectedCellIds cfg state pagedRows
                in
                Expect.equal ( ids first, ids second, ids third )
                    ( [ "r2_a" ], [ "r3_a" ], [ "r3_a" ] )
        , test "keeps range extension within the current pagination page" <|
            \_ ->
                Table.setFocusedCell "r2" "a" paged
                    |> Table.extendCellSelection cfg pagedRows Table.cellDown
                    |> Table.extendCellSelection cfg pagedRows Table.cellDown
                    |> .cellSelection
                    |> Expect.equal [ rangeOf "r2" "a" "r3" "a" ]
        ]


derivedDataSuite : Test
derivedDataSuite =
    describe "derived data"
        [ test "getSelectedCellIds lists ids in row-major order" <|
            \_ ->
                Table.selectCellRange (rangeOf "r0" "a" "r1" "b") base
                    |> (\state -> Table.selectedCellIds cfg state rows)
                    |> Expect.equal [ "r0_a", "r0_b", "r1_a", "r1_b" ]
        , test "getSelectedCellCount uses rectangle arithmetic" <|
            \_ ->
                Table.selectCellRange (rangeOf "r0" "a" "r3" "c") base
                    |> (\state -> Table.selectedCellCount cfg state rows)
                    |> Expect.equal 12
        , test "getSelectedCellCount falls back to enumeration for a predicate" <|
            \_ ->
                let
                    config : Table.Config TestRow
                    config =
                        Table.withCellSelectionWhen (\cell -> cell.rowId /= "r1") cfg
                in
                Table.selectCellRange (rangeOf "r0" "a" "r1" "c") base
                    |> (\state -> Table.selectedCellCount config state rows)
                    |> Expect.equal 3
        , test "returns no selected cells when selection is disabled" <|
            \_ ->
                let
                    config : Table.Config TestRow
                    config =
                        Table.withCellSelection False cfg

                    state : Table.State
                    state =
                        { base | cellSelection = [ rangeOf "r0" "a" "r1" "b" ] }
                in
                Expect.equal
                    ( Table.selectedCellIds config state rows
                    , Table.selectedCellCount config state rows
                    , Table.selectedCellRangesData config state rows
                    )
                    ( [], 0, [] )

        -- Adapted: `setOptions` has no counterpart, so the two predicates are
        -- two configs.
        , test "recomputes derivations when the selection predicate changes" <|
            \_ ->
                let
                    yes : Table.Config TestRow
                    yes =
                        Table.withCellSelectionWhen (always True) cfg

                    no : Table.Config TestRow
                    no =
                        Table.withCellSelectionWhen (always False) cfg

                    state : Table.State
                    state =
                        Table.selectCellRange (rangeOf "r0" "a" "r1" "b") base
                in
                Expect.equal
                    { yesCount = Table.selectedCellCount yes state rows
                    , yesIds = List.length (Table.selectedCellIds yes state rows)
                    , noCount = Table.selectedCellCount no state rows
                    , noIds = Table.selectedCellIds no state rows
                    , noData = Table.selectedCellRangesData no state rows
                    }
                    { yesCount = 4, yesIds = 4, noCount = 0, noIds = [], noData = [] }
        , test "getSelectedCellRangesData returns a row-major grid per range" <|
            \_ ->
                Table.selectCellRange (rangeOf "r0" "a" "r1" "b") base
                    |> (\state -> Table.selectedCellRangesData cfg state rows)
                    |> Expect.equal
                        [ [ [ Value.Number 0, Value.Number 1 ]
                          , [ Value.Number 10, Value.Number 11 ]
                          ]
                        ]
        , test "getSelectedCellRangesData keeps ranges separate" <|
            \_ ->
                Table.selectCellRange (rangeOf "r0" "a" "r0" "b") base
                    |> Table.selectCellRangeWith Table.includeSelection (rangeOf "r2" "b" "r2" "c")
                    |> (\state -> Table.selectedCellRangesData cfg state rows)
                    |> Expect.equal
                        [ [ [ Value.Number 0, Value.Number 1 ] ]
                        , [ [ Value.Number 21, Value.Number 22 ] ]
                        ]
        , test "getCellSelectionRowIds and ColumnIds report intersections" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.selectCellRange (rangeOf "r1" "b" "r2" "c") base
                in
                Expect.equal
                    ( Table.cellSelectionRowIds cfg state rows
                    , Table.cellSelectionColumnIds cfg state rows
                    )
                    ( [ "r1", "r2" ], [ "b", "c" ] )
        , test "returns empty derivations with nothing selected" <|
            \_ ->
                Expect.equal
                    { ids = Table.selectedCellIds cfg base rows
                    , count = Table.selectedCellCount cfg base rows
                    , data = Table.selectedCellRangesData cfg base rows
                    , rowIds = Table.cellSelectionRowIds cfg base rows
                    , columnIds = Table.cellSelectionColumnIds cfg base rows
                    }
                    { ids = [], count = 0, data = [], rowIds = [], columnIds = [] }
        ]


selectAllSuite : Test
selectAllSuite =
    describe "selectAllCells"
        [ test "selects the whole grid as one range" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.selectAllCells cfg rows base
                in
                Expect.equal
                    ( Table.selectedCellCount cfg state rows, state.cellSelection )
                    ( 12, [ rangeOf "r0" "a" "r3" "c" ] )
        , test "spans only selectable columns" <|
            \_ ->
                let
                    config : Table.Config TestRow
                    config =
                        configOf
                            [ Table.column "a" (.a >> Value.Number)
                            , Table.column "b" (.b >> Value.Number)
                            , Table.column "c" (.c >> Value.Number) |> Table.withEnableCellSelection False
                            ]

                    configRows : Table.SelectionRows TestRow
                    configRows =
                        rowsOf config base (makeData 4)
                in
                (Table.selectAllCells config configRows base).cellSelection
                    |> Expect.equal [ rangeOf "r0" "a" "r3" "b" ]
        , test "does nothing when selection is disabled" <|
            \_ ->
                (Table.selectAllCells (Table.withCellSelection False cfg) rows base).cellSelection
                    |> Expect.equal []
        ]


handlerSuite : Test
handlerSuite =
    describe "handlers"
        [ -- Adapted: the drag flag is instance data with no counterpart, so
          -- only the state half is asserted.
          test "mousedown selects a single cell and opens a drag" <|
            \_ ->
                (Table.selectCell cfg (cellOf "r1" "b") base).cellSelection
                    |> Expect.equal [ rangeOf "r1" "b" "r1" "b" ]
        , test "mouseenter extends the active range while dragging" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.selectCell cfg (cellOf "r0" "a") base
                            |> Table.extendCellSelectionTo cfg (cellOf "r2" "c")
                in
                Expect.equal
                    ( state.cellSelection, Table.selectedCellCount cfg state rows )
                    ( [ rangeOf "r0" "a" "r2" "c" ], 9 )

        -- Adapted: structural equality instead of reference identity.
        , test "mouseenter on the already-focused cell writes nothing" <|
            \_ ->
                let
                    before : Table.State
                    before =
                        Table.selectCell cfg (cellOf "r0" "a") base
                in
                (Table.extendCellSelectionTo cfg (cellOf "r0" "a") before).cellSelection
                    |> Expect.equal before.cellSelection
        , test "shift-mousedown extends from the existing anchor" <|
            \_ ->
                Table.selectCell cfg (cellOf "r0" "a") base
                    |> Table.extendCellSelectionTo cfg (cellOf "r2" "b")
                    |> .cellSelection
                    |> Expect.equal [ rangeOf "r0" "a" "r2" "b" ]
        , test "ctrl-mousedown adds a second disjoint rectangle" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.selectCell cfg (cellOf "r0" "a") base
                            |> Table.toggleCellSelection cfg rows (cellOf "r3" "c")
                in
                Expect.equal
                    ( state.cellSelection, Table.selectedCellCount cfg state rows )
                    ( [ rangeOf "r0" "a" "r0" "a", rangeOf "r3" "c" "r3" "c" ], 2 )
        , test "ctrl-mousedown on a selected cell subtracts it" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.selectCellRange (rangeOf "r0" "a" "r2" "c") base
                            |> Table.toggleCellSelection cfg rows (cellOf "r1" "b")
                in
                Expect.equal
                    { ranges = state.cellSelection
                    , count = Table.selectedCellCount cfg state rows
                    , isSelected = Table.cellIsSelected cfg state rows (cellOf "r1" "b")
                    , isFocused = Table.cellIsFocused state (cellOf "r1" "b")
                    }
                    { ranges =
                        [ rangeOf "r0" "a" "r2" "c"
                        , { anchorRowId = "r1"
                          , anchorColumnId = "b"
                          , focusRowId = "r1"
                          , focusColumnId = "b"
                          , operation = Table.excludeCells
                          }
                        ]
                    , count = 8
                    , isSelected = False
                    , isFocused = True
                    }
        , test "ctrl-drag subtracts cells and shrinking the drag restores them" <|
            \_ ->
                let
                    dragged : Table.State
                    dragged =
                        Table.selectCellRange (rangeOf "r0" "a" "r2" "c") base
                            |> Table.toggleCellSelection cfg rows (cellOf "r1" "a")
                            |> Table.extendCellSelectionTo cfg (cellOf "r1" "c")

                    shrunk : Table.State
                    shrunk =
                        Table.extendCellSelectionTo cfg (cellOf "r1" "b") dragged
                in
                Expect.equal
                    { dragged = Table.selectedCellCount cfg dragged rows
                    , shrunk = Table.selectedCellCount cfg shrunk rows
                    , active = List.head (List.reverse shrunk.cellSelection)
                    }
                    { dragged = 6
                    , shrunk = 7
                    , active =
                        Just
                            { anchorRowId = "r1"
                            , anchorColumnId = "a"
                            , focusRowId = "r1"
                            , focusColumnId = "b"
                            , operation = Table.excludeCells
                            }
                    }
        , test "shift and keyboard extension preserve an active exclusion" <|
            \_ ->
                let
                    excluded : Table.State
                    excluded =
                        Table.selectCellRange (rangeOf "r0" "a" "r2" "c") base
                            |> Table.toggleCellSelection cfg rows (cellOf "r1" "a")
                            |> Table.extendCellSelectionTo cfg (cellOf "r1" "b")

                    extended : Table.State
                    extended =
                        Table.extendCellSelection cfg rows Table.cellRight excluded
                in
                Expect.equal
                    { count = Table.selectedCellCount cfg excluded rows
                    , active = List.head (List.reverse excluded.cellSelection)
                    , extendedCount = Table.selectedCellCount cfg extended rows
                    , extendedActive = List.head (List.reverse extended.cellSelection)
                    }
                    { count = 7
                    , active =
                        Just
                            { anchorRowId = "r1"
                            , anchorColumnId = "a"
                            , focusRowId = "r1"
                            , focusColumnId = "b"
                            , operation = Table.excludeCells
                            }
                    , extendedCount = 6
                    , extendedActive =
                        Just
                            { anchorRowId = "r1"
                            , anchorColumnId = "a"
                            , focusRowId = "r1"
                            , focusColumnId = "c"
                            , operation = Table.excludeCells
                            }
                    }
        , test "ctrl-drag beginning on an unselected cell only includes the rectangle" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        Table.selectCellRange (rangeOf "r0" "a" "r0" "a") base
                            |> Table.toggleCellSelection cfg rows (cellOf "r1" "b")
                            |> Table.extendCellSelectionTo cfg (cellOf "r2" "c")
                in
                Expect.equal
                    ( Table.selectedCellIds cfg state rows
                    , List.head (List.reverse state.cellSelection) |> Maybe.map .operation
                    )
                    ( [ "r0_a", "r1_b", "r1_c", "r2_b", "r2_c" ], Just Table.includeCells )
        , test "ignores subtractive modifiers when multi-range selection is disabled" <|
            \_ ->
                let
                    config : Table.Config TestRow
                    config =
                        Table.withMultiCellRangeSelection False cfg

                    state : Table.State
                    state =
                        Table.selectCellRange (rangeOf "r0" "a" "r2" "c") base
                            |> Table.toggleCellSelection config rows (cellOf "r1" "b")
                in
                Expect.equal
                    ( state.cellSelection, Table.selectedCellCount config state rows )
                    ( [ rangeOf "r1" "b" "r1" "b" ], 1 )
        , test "does nothing for a cell that cannot be selected" <|
            \_ ->
                (Table.selectCell (Table.withCellSelection False cfg) (cellOf "r0" "a") base).cellSelection
                    |> Expect.equal []
        , test "ignores shift when range selection is disabled" <|
            \_ ->
                let
                    config : Table.Config TestRow
                    config =
                        Table.withCellRangeSelection False cfg
                in
                Table.selectCell config (cellOf "r0" "a") base
                    |> Table.extendCellSelectionTo config (cellOf "r2" "b")
                    |> .cellSelection
                    |> Expect.equal [ rangeOf "r2" "b" "r2" "b" ]
        , test "ignores ctrl when multi-range is disabled" <|
            \_ ->
                let
                    config : Table.Config TestRow
                    config =
                        Table.withMultiCellRangeSelection False cfg
                in
                Table.selectCell config (cellOf "r0" "a") base
                    |> Table.toggleCellSelection config rows (cellOf "r3" "c")
                    |> .cellSelection
                    |> List.length
                    |> Expect.equal 1
        ]
