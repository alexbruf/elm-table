module RowSelectionRangeTest exposing (pendingIntegration, suite)

{-| Ports `tests/implementation/features/row-selection/rowSelectionRange.test.ts`.

The vitest cases drive shift-click through `row.getToggleSelectedHandler`.
This port drives the state half directly: `Table.selectRange` takes the
anchor row id, the target row, and the checkbox value, and falls back to an
ordinary toggle when the range is not usable, exactly like the handler.

`pendingIntegration` holds the cases whose display order comes from the
sorted, filtered, grouped, expanded, or paginated row model. Excluded cases
are listed in `reports/phase-5.md`.

-}

import Expect
import Set
import Table
import Table.Value as Value
import Test exposing (Test, describe, test)


type alias TestRow =
    { id : String
    , kind : String
    , value : Int
    , children : Children
    }


type Children
    = Children (List TestRow)


childrenOf : TestRow -> List TestRow
childrenOf row =
    case row.children of
        Children rows ->
            rows


leaf : String -> String -> Int -> TestRow
leaf id kind value =
    TestRow id kind value (Children [])


cfg : Table.Config TestRow
cfg =
    Table.config
        [ Table.column "id" (.id >> Value.String)
        , Table.column "kind" (.kind >> Value.String)
        , Table.column "value" (.value >> toFloat >> Value.Number)
        ]
        |> Table.withGetRowId (\row _ _ -> row.id)
        |> Table.withSubRows childrenOf


state : Table.State
state =
    Table.initialState


flatData : List TestRow
flatData =
    List.range 0 5
        |> List.map
            (\value ->
                leaf (String.fromInt value)
                    (if modBy 2 value == 1 then
                        "odd"

                     else
                        "even"
                    )
                    value
            )


nestedData : List TestRow
nestedData =
    [ leaf "a" "even" 0
    , TestRow "parent" "odd" 1 (Children [ leaf "child-1" "odd" 11, leaf "child-2" "even" 12 ])
    , leaf "z" "even" 2
    ]


modelOf : List TestRow -> Table.RowModel TestRow
modelOf data =
    Table.coreRowModelFromList cfg state data


flatModel : Table.RowModel TestRow
flatModel =
    modelOf flatData


selecting : List String -> Table.State
selecting ids =
    { state | rowSelection = Set.fromList ids }


selected : Table.State -> List String
selected current =
    Set.toList current.rowSelection


{-| One ordinary click: no anchor, so the row toggles on its own.
-}
click : Table.Config TestRow -> Table.RowModel TestRow -> String -> Bool -> Table.State -> Table.State
click config source rowId value current =
    case Table.findRow source rowId of
        Just row ->
            Table.toggleRowSelected config source row (Just value) current

        Nothing ->
            current


{-| One shift-click: a range from the anchor to this row.
-}
shiftClick : Table.Config TestRow -> Table.RowModel TestRow -> String -> String -> Bool -> Table.State -> Table.State
shiftClick config source anchorId rowId value current =
    case Table.findRow source rowId of
        Just row ->
            Table.selectRange config source anchorId row value current

        Nothing ->
            current


shiftClickWith : Table.SelectOptions -> Table.Config TestRow -> Table.RowModel TestRow -> String -> String -> Bool -> Table.State -> Table.State
shiftClickWith opts config source anchorId rowId value current =
    case Table.findRow source rowId of
        Just row ->
            Table.selectRangeWith config opts source anchorId row value current

        Nothing ->
            current


noChildren : Table.SelectOptions
noChildren =
    { selectChildren = False, deselectParents = False }


suite : Test
suite =
    describe "row selection ranges"
        [ describe "integration with the grouped, expanded and paginated stages" pendingIntegration
        , describe "row selection range event detection"
            [ -- adapted: there is no event, so the direct and the wrapped
              -- shift form collapse into the same `selectRange` call; the
              -- ordinary click is `toggleRowSelected`.
              test "detects direct and wrapped Shift events but ignores ordinary events" <|
                \_ ->
                    let
                        range : Table.State
                        range =
                            state
                                |> click cfg flatModel "0" True
                                |> shiftClick cfg flatModel "0" "2" True

                        ordinary : Table.State
                        ordinary =
                            state
                                |> click cfg flatModel "0" True
                                |> click cfg flatModel "2" True
                    in
                    Expect.equal ( selected range, selected ordinary )
                        ( [ "0", "1", "2" ], [ "0", "2" ] )

            -- adapted: range selection is opt-in at the call site here, so the
            -- caller is the range-event detector: an ordinary click toggles and
            -- the caller's own "range" interaction calls `selectRange`.
            , test "supports custom range event detection" <|
                \_ ->
                    let
                        afterOrdinary : Table.State
                        afterOrdinary =
                            state
                                |> click cfg flatModel "0" True
                                |> click cfg flatModel "2" True

                        afterCustomRange : Table.State
                        afterCustomRange =
                            shiftClick cfg flatModel "2" "4" True afterOrdinary
                    in
                    Expect.equal ( selected afterOrdinary, selected afterCustomRange )
                        ( [ "0", "2" ], [ "0", "2", "3", "4" ] )
            ]
        , describe "row selection anchor lifecycle"
            [ -- adapted: `_lastSelectedRowId` is instance data in TanStack; here
              -- the anchor is an argument the caller owns, so the case asserts
              -- that an ordinary toggle and a direct `setRowSelection` leave it
              -- untouched: a later range still spans from the same anchor.
              test "is not changed by direct row or table state APIs" <|
                \_ ->
                    let
                        afterDirectWrites : Table.State
                        afterDirectWrites =
                            state
                                |> click cfg flatModel "1" True
                                |> click cfg flatModel "0" True
                                |> Table.setRowSelection (Set.fromList [ "0", "1" ])
                    in
                    afterDirectWrites
                        |> shiftClick cfg flatModel "1" "3" True
                        |> selected
                        |> Expect.equal [ "0", "1", "2", "3" ]

            -- excluded: "clears through every selection reset and select-all
            --   path". The anchor is caller state in this port, so no reset
            --   path has an anchor to clear.
            ]
        , describe "row selection range performance"
            [ -- adapted: the `getRowsInDisplayOrder` spy becomes an
              -- observable difference. The model is ordered by `kind`, so
              -- display order (0, 2, 4, 1, 3, 5) is not row order: only a
              -- range that resolves display order can select exactly
              -- 0, 2 and 4.
              test "does not resolve display order for ordinary clicks but does for ranges" <|
                \_ ->
                    let
                        byKind : Table.State
                        byKind =
                            { state | sorting = [ { id = "kind", desc = False } ] }

                        display : Table.RowModel TestRow
                        display =
                            Table.coreRowModelFromList cfg byKind flatData
                                |> Table.sortedRowModel cfg byKind

                        ordinary : Table.State
                        ordinary =
                            byKind
                                |> click cfg display "0" True
                                |> click cfg display "4" True

                        range : Table.State
                        range =
                            byKind
                                |> click cfg display "0" True
                                |> shiftClick cfg display "0" "4" True
                    in
                    Expect.equal ( selected ordinary, selected range )
                        ( [ "0", "4" ], [ "0", "2", "4" ] )

            -- adapted: the spies become the one state the range returns; a
            -- range is a single transition here, never a toggle per row.
            , test "uses one selection change and never calls row.toggleSelected per interval row" <|
                \_ ->
                    state
                        |> click cfg flatModel "0" True
                        |> shiftClick cfg flatModel "0" "4" True
                        |> selected
                        |> Expect.equal [ "0", "1", "2", "3", "4" ]
            ]
        , test "establishes an anchor and selects forward and reverse inclusive ranges" <|
            \_ ->
                let
                    forward : Table.State
                    forward =
                        state
                            |> click cfg flatModel "1" True
                            |> shiftClick cfg flatModel "1" "4" True

                    reverse : Table.State
                    reverse =
                        state
                            |> click cfg flatModel "4" True
                            |> shiftClick cfg flatModel "4" "1" True
                in
                Expect.all
                    [ \_ -> Expect.equal [ "1", "2", "3", "4" ] (selected forward)
                    , \_ -> Expect.equal [ "1", "2", "3", "4" ] (selected reverse)
                    ]
                    ()
        , test "uses the checkbox value for inclusive deselection and same-row ranges" <|
            \_ ->
                let
                    afterRange : Table.State
                    afterRange =
                        selecting [ "0", "1", "2", "3", "4", "5" ]
                            |> click cfg flatModel "1" False
                            |> shiftClick cfg flatModel "1" "4" False

                    afterSameRow : Table.State
                    afterSameRow =
                        afterRange
                            |> click cfg flatModel "5" True
                            |> shiftClick cfg flatModel "5" "5" False
                in
                Expect.all
                    [ \_ -> Expect.equal [ "0", "5" ] (selected afterRange)
                    , \_ -> Expect.equal [ "0" ] (selected afterSameRow)
                    ]
                    ()
        , test "preserves selections outside the interval and advances the anchor" <|
            \_ ->
                selecting [ "5" ]
                    |> click cfg flatModel "0" True
                    |> shiftClick cfg flatModel "0" "2" True
                    |> shiftClick cfg flatModel "2" "4" False
                    |> selected
                    |> Expect.equal [ "0", "1", "5" ]
        , test "can disable range selection" <|
            \_ ->
                state
                    |> click cfg flatModel "0" True
                    |> click cfg flatModel "3" True
                    |> selected
                    |> Expect.equal [ "0", "3" ]
        , test "falls back to ordinary selection when the current row cannot multi-select" <|
            \_ ->
                let
                    single : Table.Config TestRow
                    single =
                        { cfg | enableMultiRowSelection = always False }
                in
                state
                    |> click single flatModel "0" True
                    |> shiftClick single flatModel "0" "3" True
                    |> selected
                    |> Expect.equal [ "3" ]
        , test "respects per-row multi-select predicates at endpoints and inside ranges" <|
            \_ ->
                let
                    endpointConfig : Table.Config TestRow
                    endpointConfig =
                        { cfg | enableMultiRowSelection = \row -> Table.rowId row /= "3" }

                    insideConfig : Table.Config TestRow
                    insideConfig =
                        { cfg | enableMultiRowSelection = \row -> Table.rowId row /= "2" }

                    endpoint : Table.State
                    endpoint =
                        state
                            |> click endpointConfig flatModel "0" True
                            |> shiftClick endpointConfig flatModel "0" "3" True

                    inside : Table.State
                    inside =
                        state
                            |> click insideConfig flatModel "0" True
                            |> shiftClick insideConfig flatModel "0" "4" True
                in
                Expect.all
                    [ \_ -> Expect.equal [ "3" ] (selected endpoint)
                    , \_ -> Expect.equal [ "0", "1", "3", "4" ] (selected inside)
                    ]
                    ()
        , test "skips non-selectable rows inside a range" <|
            \_ ->
                let
                    guarded : Table.Config TestRow
                    guarded =
                        { cfg | enableRowSelection = \row -> Table.rowId row /= "2" }
                in
                state
                    |> click guarded flatModel "0" True
                    |> shiftClick guarded flatModel "0" "4" True
                    |> selected
                    |> Expect.equal [ "0", "1", "3", "4" ]
        , test "falls back to an ordinary toggle for invalid and removed anchor ids" <|
            \_ ->
                let
                    invalid : Table.State
                    invalid =
                        shiftClick cfg flatModel "missing" "3" True state

                    withoutRowOne : Table.RowModel TestRow
                    withoutRowOne =
                        modelOf (List.filter (\row -> row.id /= "0") flatData)

                    removed : Table.State
                    removed =
                        state
                            |> click cfg flatModel "0" True
                            |> shiftClick cfg withoutRowOne "0" "2" True
                in
                Expect.all
                    [ \_ -> Expect.equal [ "3" ] (selected invalid)
                    , \_ -> Expect.equal [ "0", "2" ] (selected removed)
                    ]
                    ()
        , test "selects collapsed descendants by default and can limit selection to displayed rows" <|
            \_ ->
                let
                    nested : Table.RowModel TestRow
                    nested =
                        modelOf nestedData

                    recursive : Table.State
                    recursive =
                        state
                            |> click cfg nested "a" True
                            |> shiftClick cfg nested "a" "z" True

                    displayedOnly : Table.State
                    displayedOnly =
                        state
                            |> click cfg nested "a" True
                            |> shiftClickWith noChildren cfg nested "a" "z" True
                in
                Expect.all
                    [ \_ ->
                        Expect.equal [ "a", "child-1", "child-2", "parent", "z" ] (selected recursive)
                    , \_ -> Expect.equal [ "a", "parent", "z" ] (selected displayedOnly)
                    ]
                    ()
        , test "respects boolean and per-row sub-selection options" <|
            \_ ->
                let
                    nested : Table.RowModel TestRow
                    nested =
                        modelOf nestedData

                    disabledConfig : Table.Config TestRow
                    disabledConfig =
                        { cfg | enableSubRowSelection = always False }

                    predicateConfig : Table.Config TestRow
                    predicateConfig =
                        { cfg | enableSubRowSelection = \row -> Table.rowId row /= "parent" }

                    disabled : Table.State
                    disabled =
                        state
                            |> click disabledConfig nested "a" True
                            |> shiftClick disabledConfig nested "a" "z" True

                    predicate : Table.State
                    predicate =
                        state
                            |> click predicateConfig nested "a" True
                            |> shiftClick predicateConfig nested "a" "z" True
                in
                Expect.all
                    [ \_ -> Expect.equal [ "a", "parent", "z" ] (selected disabled)
                    , \_ -> Expect.equal [ "a", "parent", "z" ] (selected predicate)
                    ]
                    ()
        , test "preserves anchors across data replacement only when the id remains loaded" <|
            \_ ->
                let
                    reloaded : Table.RowModel TestRow
                    reloaded =
                        modelOf (List.map (\row -> { row | value = row.value + 10 }) flatData)

                    withoutOne : Table.RowModel TestRow
                    withoutOne =
                        modelOf (List.filter (\row -> row.id /= "1") flatData)

                    preserved : Table.State
                    preserved =
                        state
                            |> click cfg flatModel "1" True
                            |> shiftClick cfg reloaded "1" "3" True

                    removed : Table.State
                    removed =
                        state
                            |> click cfg flatModel "1" True
                            |> shiftClick cfg withoutOne "1" "3" True
                in
                Expect.all
                    [ \_ -> Expect.equal [ "1", "2", "3" ] (selected preserved)
                    , \_ -> Expect.equal [ "1", "3" ] (selected removed)
                    ]
                    ()
        ]


{-| Cases whose display order comes from a pipeline stage that is still an
identity stub in this worktree.
-}
pendingIntegration : List Test
pendingIntegration =
    let
        expandedNested : Table.State -> Table.RowModel TestRow
        expandedNested current =
            Table.coreRowModelFromList cfg current nestedData
                |> Table.expandedRowModel cfg current

        expandedParent : Table.State
        expandedParent =
            { state | expanded = Table.expandedIds (Set.singleton "parent") }
    in
    [ describe "range child selection semantics"
        [ test "changes expanded descendants explicitly when child recursion is disabled" <|
            \_ ->
                let
                    display : Table.RowModel TestRow
                    display =
                        expandedNested expandedParent
                in
                expandedParent
                    |> click cfg display "a" True
                    |> shiftClickWith noChildren cfg display "a" "z" True
                    |> selected
                    |> Expect.equal [ "a", "child-1", "child-2", "parent", "z" ]
        , test "prunes ancestors of deselected range rows with deselectParents" <|
            \_ ->
                let
                    display : Table.RowModel TestRow
                    display =
                        expandedNested expandedParent

                    afterSelect : Table.State
                    afterSelect =
                        click cfg display "parent" True expandedParent

                    afterRange : Table.State
                    afterRange =
                        afterSelect
                            |> click cfg display "child-1" False
                            |> shiftClickWith { selectChildren = True, deselectParents = True }
                                cfg
                                display
                                "child-1"
                                "child-2"
                                False
                in
                Expect.all
                    [ \_ -> Expect.equal [ "child-1", "child-2", "parent" ] (selected afterSelect)
                    , \_ -> Expect.equal [] (selected afterRange)
                    ]
                    ()
        ]
    , describe "range selection follows the display pipeline"
        [ test "uses the latest sorting order between interactions" <|
            \_ ->
                let
                    sortedState : Table.State
                    sortedState =
                        { state | sorting = [ { id = "value", desc = True } ] }

                    display : Table.RowModel TestRow
                    display =
                        Table.coreRowModelFromList cfg sortedState flatData
                            |> Table.sortedRowModel cfg sortedState
                in
                sortedState
                    |> click cfg display "0" True
                    |> shiftClick cfg display "0" "3" True
                    |> selected
                    |> Expect.equal [ "0", "1", "2", "3" ]
        , test "uses the latest filtered order while a visible anchor remains valid" <|
            \_ ->
                let
                    filteredState : Table.State
                    filteredState =
                        { state | columnFilters = [ { id = "kind", value = Value.String "even" } ] }

                    display : Table.RowModel TestRow
                    display =
                        Table.coreRowModelFromList cfg filteredState flatData
                            |> Table.filteredRowModel cfg filteredState
                in
                filteredState
                    |> click cfg display "0" True
                    |> shiftClick cfg display "0" "4" True
                    |> selected
                    |> Expect.equal [ "0", "2", "4" ]
        , test "includes grouped rows in display order" <|
            \_ ->
                let
                    groupedState : Table.State
                    groupedState =
                        { state | grouping = [ "kind" ] }

                    display : Table.RowModel TestRow
                    display =
                        Table.coreRowModelFromList cfg groupedState flatData
                            |> Table.groupedRowModel cfg groupedState
                in
                groupedState
                    |> (\current ->
                            case Table.findRow display "kind:even" of
                                Just row ->
                                    Table.selectRangeWith cfg noChildren display "kind:even" row True current

                                Nothing ->
                                    current
                       )
                    |> shiftClickWith noChildren cfg display "kind:even" "kind:odd" True
                    |> selected
                    |> Expect.equal [ "kind:even", "kind:odd" ]
        , test "selects across client-side pages" <|
            \_ ->
                let
                    paged : Int -> Table.State
                    paged index =
                        { state | pagination = { pageIndex = index, pageSize = 2 } }

                    -- Range selection takes the pre-pagination row model, as
                    -- TanStack's getRowsInDisplayOrder does, so the page in
                    -- state does not limit the range.
                    display : Table.State -> Table.RowModel TestRow
                    display current =
                        Table.coreRowModelFromList cfg current flatData
                            |> Table.expandedRowModel cfg current
                in
                state
                    |> click cfg (display (paged 0)) "0" True
                    |> shiftClick cfg (display (paged 2)) "0" "4" True
                    |> selected
                    |> Expect.equal [ "0", "1", "2", "3", "4" ]
        , test "includes expanded rows when paginateExpandedRows is true or false" <|
            \_ ->
                let
                    data : List TestRow
                    data =
                        [ TestRow "parent" "odd" 0 (Children [ leaf "child-1" "odd" 1, leaf "child-2" "even" 2 ])
                        , leaf "z" "even" 3
                        ]

                    current : Table.State
                    current =
                        { state
                            | expanded = Table.expandedIds (Set.singleton "parent")
                            , pagination = { pageIndex = 0, pageSize = 1 }
                        }

                    configFor : Bool -> Table.Config TestRow
                    configFor paginateExpandedRows =
                        { cfg | paginateExpandedRows = paginateExpandedRows }

                    -- The pre-pagination model: when paginateExpandedRows is
                    -- False the expanded stage leaves the tree folded and
                    -- rowsInDisplayOrder unfolds it, exactly as in TanStack.
                    display : Bool -> Table.RowModel TestRow
                    display paginateExpandedRows =
                        Table.coreRowModelFromList (configFor paginateExpandedRows) current data
                            |> Table.expandedRowModel (configFor paginateExpandedRows) current

                    run : Bool -> List String
                    run paginateExpandedRows =
                        current
                            |> click (configFor paginateExpandedRows) (display paginateExpandedRows) "child-1" True
                            |> shiftClickWith noChildren (configFor paginateExpandedRows) (display paginateExpandedRows) "child-1" "z" True
                            |> selected
                in
                Expect.all
                    [ \_ -> Expect.equal [ "child-1", "child-2", "z" ] (run True)
                    , \_ -> Expect.equal [ "child-1", "child-2", "z" ] (run False)
                    ]
                    ()
        ]
    ]
