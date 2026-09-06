module ExpandingStateTest exposing (suite)

{-| Ports
`tests/unit/features/row-expanding/rowExpandingFeature.utils.test.ts`.

The vitest file drives a table instance and spies on `onExpandedChange`; here
every transition is `State -> State`, so a case asserts the state the
transition produces and a "no-op" case asserts that the state came back
unchanged.

-}

import Expect
import Fixtures exposing (Person)
import Set exposing (Set)
import Table
import Test exposing (Test, describe, test)


plain : Table.State
plain =
    Table.initialState


withIds : List String -> Table.State
withIds rowIds =
    { plain | expanded = Table.expandedIds (Set.fromList rowIds) }


allExpanded : Table.State
allExpanded =
    { plain | expanded = Table.expandAll }


config : Table.Config Person
config =
    Fixtures.config


{-| `makeTable(options, lengths)`: the row model over `generateTestData`.
-}
modelOf : Table.Config Person -> List Int -> Table.RowModel Person
modelOf cfg lengths =
    Table.coreRowModelFromList cfg plain (Fixtures.makeData lengths)


model : Table.RowModel Person
model =
    modelOf config [ 3, 2 ]


rowOf : Table.RowModel Person -> String -> Maybe (Table.Row Person)
rowOf =
    Table.findRow


expandedSet : Table.State -> Maybe (Set String)
expandedSet state =
    Table.expandedIdsOf state.expanded



-- SUITE


suite : Test
suite =
    describe "rowExpandingFeature.utils"
        [ defaultsSuite
        , toggleAllSuite
        , canExpandSuite
        , isAllRowsExpandedSuite
        , expandedDepthSuite
        , toggleRowSuite
        , rowStateSuite
        , handlerSuite
        ]


defaultsSuite : Test
defaultsSuite =
    describe "defaults, setExpanded and resetExpanded"
        [ test "should return an empty map and a new instance each time" <|
            \_ ->
                -- The "new instance" half is JavaScript object identity; Elm
                -- sets are values. `resetExpanded` is TanStack's
                -- `table_resetExpanded(table, true)`.
                expandedSet (Table.resetExpanded allExpanded)
                    |> Expect.equal (Just Set.empty)
        , test "should route the updater through onExpandedChange" <|
            \_ ->
                expandedSet (Table.setExpanded (Table.expandedIds (Set.singleton "0")) plain)
                    |> Expect.equal (Just (Set.singleton "0"))
        , test "should reset to an empty map when defaultState is true" <|
            \_ ->
                expandedSet (Table.resetExpanded (withIds [ "0" ]))
                    |> Expect.equal (Just Set.empty)
        , test "should reset to the initial expanded map by default" <|
            \_ ->
                -- There is no `initialState` here, so a caller that wants its
                -- own starting expansion back writes it with `setExpanded`;
                -- see `reports/phase-3.md`.
                expandedSet
                    (Table.setExpanded (Table.expandedIds (Set.singleton "0")) (withIds [ "1" ]))
                    |> Expect.equal (Just (Set.singleton "0"))
        , test "should preserve an expanded-all initial state" <|
            \_ ->
                (Table.setExpanded Table.expandAll (withIds [ "0" ])).expanded
                    |> Expect.equal Table.expandAll
        ]


toggleAllSuite : Test
toggleAllSuite =
    describe "table_toggleAllRowsExpanded"
        [ test "should expand all rows when not all rows are expanded" <|
            \_ ->
                (Table.toggleAllRowsExpanded config model Nothing plain).expanded
                    |> Expect.equal Table.expandAll
        , test "should collapse all rows when all rows are expanded" <|
            \_ ->
                expandedSet (Table.toggleAllRowsExpanded config model Nothing allExpanded)
                    |> Expect.equal (Just Set.empty)
        , test "should apply an explicit value without toggling" <|
            \_ ->
                expandedSet
                    (Table.toggleAllRowsExpanded config model (Just False) (withIds [ "0" ]))
                    |> Expect.equal (Just Set.empty)
        , test "should be a no-op when collapsing with nothing expanded" <|
            \_ ->
                Table.toggleAllRowsExpanded config model (Just False) plain
                    |> Expect.equal plain
        , test "should be a no-op when already in the expanded-all state" <|
            \_ ->
                Table.toggleAllRowsExpanded config model (Just True) allExpanded
                    |> Expect.equal allExpanded
        , test "should be a no-op when no rows can expand" <|
            \_ ->
                Table.toggleAllRowsExpanded config (modelOf config [ 3 ]) (Just True) plain
                    |> Expect.equal plain
        , test "should be a no-op when expanding is disabled" <|
            \_ ->
                let
                    cfg : Table.Config Person
                    cfg =
                        { config | enableExpanding = False }
                in
                Table.toggleAllRowsExpanded cfg (modelOf cfg [ 3, 2 ]) (Just True) plain
                    |> Expect.equal plain
        ]


canExpandSuite : Test
canExpandSuite =
    describe "table_getCanSomeRowsExpand"
        [ test "should return true when rows have subRows" <|
            \_ ->
                Table.getCanSomeRowsExpand config model |> Expect.equal True
        , test "should return false for flat data" <|
            \_ ->
                Table.getCanSomeRowsExpand config (modelOf config [ 3 ])
                    |> Expect.equal False
        , test "should return false with no expanded rows" <|
            \_ ->
                Table.getIsSomeRowsExpanded plain |> Expect.equal False
        , test "should return true when a row id is expanded" <|
            \_ ->
                Table.getIsSomeRowsExpanded (withIds [ "0" ]) |> Expect.equal True
        , test "should return true for the expanded-all state" <|
            \_ ->
                Table.getIsSomeRowsExpanded allExpanded |> Expect.equal True
        ]


isAllRowsExpandedSuite : Test
isAllRowsExpandedSuite =
    describe "table_getIsAllRowsExpanded"
        [ test "should return true for the expanded-all state" <|
            \_ ->
                Table.getIsAllRowsExpanded config allExpanded model |> Expect.equal True
        , test "should return false for an empty expanded state" <|
            \_ ->
                Table.getIsAllRowsExpanded config plain model |> Expect.equal False
        , test "should return true when every row id is expanded" <|
            \_ ->
                let
                    everyId : Table.State
                    everyId =
                        { plain
                            | expanded =
                                Table.expandedIds
                                    (Set.fromList (List.map Table.rowId model.flatRows))
                        }
                in
                Table.getIsAllRowsExpanded config everyId model |> Expect.equal True
        , test "should return true when only every expandable row id is expanded" <|
            \_ ->
                Table.getIsAllRowsExpanded config (withIds [ "0", "1", "2" ]) model
                    |> Expect.equal True
        , test "should return false when any expandable row is collapsed" <|
            \_ ->
                Table.getIsAllRowsExpanded config (withIds [ "0" ]) model
                    |> Expect.equal False
        , test "should return false for stale expanded ids when no rows can expand" <|
            \_ ->
                Table.getIsAllRowsExpanded config (withIds [ "0" ]) (modelOf config [ 3 ])
                    |> Expect.equal False
        ]


expandedDepthSuite : Test
expandedDepthSuite =
    describe "table_getExpandedDepth"
        [ test "should return 0 with nothing expanded" <|
            \_ ->
                Table.getExpandedDepth config plain model |> Expect.equal 0
        , test "should measure depth from expanded row ids" <|
            \_ ->
                Expect.equal
                    ( Table.getExpandedDepth config (withIds [ "0" ]) model
                    , Table.getExpandedDepth config (withIds [ "0.0" ]) model
                    )
                    ( 1, 2 )
        , test "should measure depth from the row model expandable rows for the expanded-all state" <|
            \_ ->
                Expect.equal
                    ( Table.getExpandedDepth config allExpanded model
                    , Table.getExpandedDepth config allExpanded (modelOf config [ 2, 2, 2 ])
                    )
                    ( 1, 2 )
        ]


toggleRowSuite : Test
toggleRowSuite =
    describe "row_toggleExpanded"
        [ test "should expand a collapsed row" <|
            \_ ->
                toggle config model "0" Nothing plain
                    |> Expect.equal (Just (Just (Set.singleton "0")))
        , test "should collapse an expanded row and keep other expanded rows" <|
            \_ ->
                toggle config model "0" Nothing (withIds [ "0", "1" ])
                    |> Expect.equal (Just (Just (Set.singleton "1")))
        , test "should be a no-op for a redundant expand" <|
            \_ ->
                unchanged config model "0" (Just True) (withIds [ "0" ])
                    |> Expect.equal (Just True)
        , test "should be a no-op for a redundant collapse" <|
            \_ ->
                unchanged config model "0" (Just False) plain |> Expect.equal (Just True)
        , test "should be a no-op for a redundant expand in the expanded-all state" <|
            \_ ->
                unchanged config model "0" (Just True) allExpanded |> Expect.equal (Just True)
        , test "should be a no-op when expanding a row that cannot expand" <|
            \_ ->
                Expect.equal
                    ( unchanged config model "0.0" Nothing plain
                    , unchanged config model "0.0" (Just True) plain
                    )
                    ( Just True, Just True )
        , test "should be a no-op when expanding is disabled" <|
            \_ ->
                let
                    cfg : Table.Config Person
                    cfg =
                        { config | enableExpanding = False }
                in
                unchanged cfg (modelOf cfg [ 3, 2 ]) "0" Nothing plain
                    |> Expect.equal (Just True)
        , test "should let options.getRowCanExpand allow expanding a row without subRows" <|
            \_ ->
                let
                    cfg : Table.Config Person
                    cfg =
                        config
                            |> Table.withRowCanExpand (\row -> Table.rowId row == "0.0")
                in
                toggle cfg (modelOf cfg [ 3, 2 ]) "0.0" Nothing plain
                    |> Expect.equal (Just (Just (Set.singleton "0.0")))
        , test "should still collapse an expanded row that can no longer expand" <|
            \_ ->
                let
                    cfg : Table.Config Person
                    cfg =
                        { config | enableExpanding = False }
                in
                toggle cfg (modelOf cfg [ 3, 2 ]) "0" Nothing (withIds [ "0" ])
                    |> Expect.equal (Just (Just Set.empty))
        , test "should materialize the expanded-all state with only expandable row ids when collapsing one row" <|
            \_ ->
                toggle config model "0" Nothing allExpanded
                    |> Expect.equal (Just (Just (Set.fromList [ "1", "2" ])))
        ]


{-| `row_toggleExpanded(row, expanded)` on a row of the model, as the ids it
leaves in `State.expanded`.
-}
toggle :
    Table.Config Person
    -> Table.RowModel Person
    -> String
    -> Maybe Bool
    -> Table.State
    -> Maybe (Maybe (Set String))
toggle cfg rowModel rowId wanted state =
    rowOf rowModel rowId
        |> Maybe.map
            (\row -> expandedSet (Table.toggleExpanded cfg rowModel row wanted state))


{-| Did the toggle leave the state alone? That is this port's counterpart of
`expect(onExpandedChange).not.toHaveBeenCalled()`.
-}
unchanged :
    Table.Config Person
    -> Table.RowModel Person
    -> String
    -> Maybe Bool
    -> Table.State
    -> Maybe Bool
unchanged cfg rowModel rowId wanted state =
    rowOf rowModel rowId
        |> Maybe.map
            (\row -> Table.toggleExpanded cfg rowModel row wanted state == state)


rowStateSuite : Test
rowStateSuite =
    describe "row_getIsExpanded / row_getCanExpand / row_getIsAllParentsExpanded"
        [ test "should read the expanded state for this row id" <|
            \_ ->
                Expect.equal
                    ( isExpanded config (withIds [ "0" ]) "0"
                    , isExpanded config (withIds [ "0" ]) "1"
                    )
                    ( Just True, Just False )
        , test "should return true for every row in the expanded-all state" <|
            \_ ->
                Expect.equal
                    ( isExpanded config allExpanded "0", isExpanded config allExpanded "1" )
                    ( Just True, Just True )
        , test "should let options.getIsRowExpanded override the state" <|
            \_ ->
                let
                    cfg : Table.Config Person
                    cfg =
                        config |> Table.withIsRowExpanded (\row -> Table.rowId row == "1")
                in
                Expect.equal
                    ( isExpanded cfg (withIds [ "0" ]) "0"
                    , isExpanded cfg (withIds [ "0" ]) "1"
                    )
                    ( Just False, Just True )
        , test "should return true for rows with subRows" <|
            \_ ->
                canExpand config "0" |> Expect.equal (Just True)
        , test "should return false for leaf rows" <|
            \_ ->
                canExpand config "0.0" |> Expect.equal (Just False)
        , test "should return false when expanding is disabled" <|
            \_ ->
                canExpand { config | enableExpanding = False } "0"
                    |> Expect.equal (Just False)
        , test "should let options.getRowCanExpand win" <|
            \_ ->
                let
                    cfg : Table.Config Person
                    cfg =
                        config
                            |> Table.withRowCanExpand (\row -> Table.rowId row == "0.0")
                in
                Expect.equal ( canExpand cfg "0", canExpand cfg "0.0" )
                    ( Just False, Just True )
        , test "should return true for top-level rows" <|
            \_ ->
                parentsExpanded plain "0" |> Expect.equal (Just True)
        , test "should return true when the parent chain is expanded" <|
            \_ ->
                parentsExpanded (withIds [ "0" ]) "0.0" |> Expect.equal (Just True)
        , test "should return false when a parent is collapsed" <|
            \_ ->
                parentsExpanded plain "0.0" |> Expect.equal (Just False)
        ]


isExpanded : Table.Config Person -> Table.State -> String -> Maybe Bool
isExpanded cfg state rowId =
    rowOf (modelOf cfg [ 3, 2 ]) rowId
        |> Maybe.map (Table.getIsExpanded cfg state)


canExpand : Table.Config Person -> String -> Maybe Bool
canExpand cfg rowId =
    rowOf (modelOf cfg [ 3, 2 ]) rowId
        |> Maybe.map (Table.getCanExpand cfg)


parentsExpanded : Table.State -> String -> Maybe Bool
parentsExpanded state rowId =
    rowOf model rowId
        |> Maybe.map (Table.getIsAllParentsExpanded config state model)


handlerSuite : Test
handlerSuite =
    describe "handlers"
        [ test "table_getToggleAllRowsExpandedHandler should toggle all rows expanded" <|
            \_ ->
                -- The handler is a plain call to `toggleAllRowsExpanded`.
                (Table.toggleAllRowsExpanded config model Nothing plain).expanded
                    |> Expect.equal Table.expandAll
        , test "row_getToggleExpandedHandler should toggle expandable rows" <|
            \_ ->
                handle config model "0" plain
                    |> Expect.equal (Just (Set.singleton "0"))
        , test "row_getToggleExpandedHandler should be a no-op for leaf rows" <|
            \_ ->
                handle config model "0.0" plain |> Expect.equal (Just Set.empty)
        ]


{-| `row_getToggleExpandedHandler`: the handler is a `getCanExpand` guard in
front of `toggleExpanded`.
-}
handle :
    Table.Config Person
    -> Table.RowModel Person
    -> String
    -> Table.State
    -> Maybe (Set String)
handle cfg rowModel rowId state =
    case rowOf rowModel rowId of
        Nothing ->
            Nothing

        Just row ->
            if Table.getCanExpand cfg row then
                expandedSet (Table.toggleExpanded cfg rowModel row Nothing state)

            else
                expandedSet state
