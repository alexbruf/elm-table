module AutoResetTest exposing (suite)

{-| Ports `tests/implementation/core/autoReset.test.ts`.

TanStack's auto-resets are `onAfterUpdate` hooks on the row-model stage memos,
dispatched through `table._reactivity.schedule`. There is no scheduler and no
table instance here, so `Table.autoReset` applies in one pure step every reset
those hooks would schedule for one change; the vitest's
`setPageIndex` / `setColumnFilters` / `getRowModel` / `flushMicrotasks` dance
becomes a `previous` state, a `next` state and a `dataChanged` flag.

Two cases are excluded and marked with `-- excluded` comment blocks where they
would otherwise sit: both assert scheduling rather than a resulting state.

-}

import Expect
import Set
import Table
import Table.Value as Value
import Test exposing (Test, describe, test)



-- FIXTURE


type alias Person =
    { name : String
    , age : Float
    , group : String
    }


{-| The three columns of the vitest fixture. The data itself never reaches
`Table.autoReset`, which reads the config flags and the two states only.
-}
config : Table.Config Person
config =
    Table.config
        [ Table.column "name" (.name >> Value.String)
        , Table.column "age" (.age >> Value.Number)
        , Table.column "group" (.group >> Value.String)
        ]


{-| A second config with an equal but separately built column list, standing
in for `setOptions({ columns: [...old.columns] })`.
-}
recolumned : Table.Config Person
recolumned =
    Table.config
        [ Table.column "name" (.name >> Value.String)
        , Table.column "age" (.age >> Value.Number)
        , Table.column "group" (.group >> Value.String)
        ]


{-| `initialState: { pagination: { pageIndex: 0, pageSize: 2 } }`.
-}
start : Table.State
start =
    onPage 0 Table.initialState


onPage : Int -> Table.State -> Table.State
onPage index state =
    { state | pagination = { pageIndex = index, pageSize = 2 } }


pageIndexOf : Table.State -> Int
pageIndexOf state =
    state.pagination.pageIndex


ageSorting : List Table.SortColumn
ageSorting =
    [ { id = "age", desc = True } ]


nameSorting : List Table.SortColumn
nameSorting =
    [ { id = "name", desc = False } ]


evenGroup : List Table.ColumnFilter
evenGroup =
    [ { id = "group", value = Value.String "even" } ]


withSorting : List Table.SortColumn -> Table.State -> Table.State
withSorting sorting state =
    { state | sorting = sorting }


withFilters : List Table.ColumnFilter -> Table.State -> Table.State
withFilters filters state =
    { state | columnFilters = filters }


withGrouping : List String -> Table.State -> Table.State
withGrouping grouping state =
    { state | grouping = grouping }


expandRow : String -> Table.State -> Table.State
expandRow rowId state =
    Table.setExpanded (Table.expandedIds (Set.singleton rowId)) state


expandedIdsOf : Table.State -> List String
expandedIdsOf state =
    Table.expandedIdsOf state.expanded
        |> Maybe.map Set.toList
        |> Maybe.withDefault [ "<expand all>" ]


{-| One state change, with the data left alone.
-}
change : Table.Config Person -> Table.State -> Table.State -> Table.State
change cfg previous next =
    Table.autoReset cfg { previous = previous, next = next, dataChanged = False }


{-| A data change, with the state left alone.
-}
replaceData : Table.Config Person -> Table.State -> Table.State
replaceData cfg state =
    Table.autoReset cfg { previous = state, next = state, dataChanged = True }



-- SUITE


suite : Test
suite =
    describe "autoReset"
        [ pageIndexSuite
        , sortingSuite
        , expandedSuite
        , firstRunSuite
        ]



-- PAGE INDEX


{-| `setPageIndex(2)`, then the change under test.
-}
fromPageTwo : Table.Config Person -> (Table.State -> Table.State) -> Int
fromPageTwo cfg apply =
    let
        previous : Table.State
        previous =
            onPage 2 start
    in
    pageIndexOf (change cfg previous (apply previous))


{-| The vitest `triggerReset`: page 2, then a column filter change.
-}
triggerPageReset : Table.Config Person -> Int
triggerPageReset cfg =
    fromPageTwo cfg (withFilters evenGroup)


pageIndexSuite : Test
pageIndexSuite =
    describe "autoResetPageIndex end-to-end wiring"
        [ -- adapted: `setOptions({ data })` is the `dataChanged` flag.
          test "should reset pageIndex when data changes via setOptions" <|
            \_ ->
                Expect.equal
                    ( pageIndexOf (onPage 2 start)
                    , pageIndexOf (replaceData config (onPage 2 start))
                    )
                    ( 2, 0 )
        , test "should reset pageIndex when column filters change" <|
            \_ ->
                fromPageTwo config (withFilters evenGroup)
                    |> Expect.equal 0
        , test "should reset pageIndex when sorting changes" <|
            \_ ->
                fromPageTwo config (withSorting ageSorting)
                    |> Expect.equal 0
        , test "should reset pageIndex when grouping changes" <|
            \_ ->
                fromPageTwo config (withGrouping [ "group" ])
                    |> Expect.equal 0

        -- adapted: there is no `table.initialState`, so "not to
        -- initialState.pageIndex" is asserted as the reset going to the
        -- feature default from a page the caller seeded itself.
        , test "should reset pageIndex to 0, not to initialState.pageIndex" <|
            \_ ->
                let
                    seeded : Table.State
                    seeded =
                        onPage 1 start

                    previous : Table.State
                    previous =
                        onPage 2 seeded
                in
                pageIndexOf (change config previous (withFilters evenGroup previous))
                    |> Expect.equal 0

        -- excluded: "should not reset pageIndex until a row model is actually
        --   pulled" — the whole case is about lazy memos scheduling the reset
        --   only when a row model is read. `Table.autoReset` is the reset
        --   itself, called by the caller; there is nothing to defer.
        , test "should not reset pageIndex for state changes that do not recompute row model stages" <|
            \_ ->
                fromPageTwo config
                    (\state -> { state | rowSelection = Set.singleton "0" })
                    |> Expect.equal 2

        -- adapted: the column definitions are not an input of
        -- `Table.autoReset` at all, so "only the columns changed" is a second
        -- config with an equal column list and no state or data change.
        , test "should not reset pageIndex when only the column definitions reference changes" <|
            \_ ->
                fromPageTwo recolumned identity
                    |> Expect.equal 2
        , describe "option precedence"
            [ test "should skip the reset when autoResetAll is false" <|
                \_ ->
                    triggerPageReset (Table.withAutoResetAll False config)
                        |> Expect.equal 2
            , test "should force the reset when autoResetAll is true even with manualPagination" <|
                \_ ->
                    triggerPageReset
                        (Table.withAutoResetAll True { config | manualPagination = True })
                        |> Expect.equal 0
            , test "should skip the reset when autoResetPageIndex is false" <|
                \_ ->
                    triggerPageReset (Table.withAutoResetPageIndex False config)
                        |> Expect.equal 2
            , test "should opt back in with autoResetPageIndex true despite manualPagination" <|
                \_ ->
                    triggerPageReset
                        (Table.withAutoResetPageIndex True { config | manualPagination = True })
                        |> Expect.equal 0
            , test "should skip the reset by default when manualPagination is true" <|
                \_ ->
                    triggerPageReset { config | manualPagination = True }
                        |> Expect.equal 2
            ]
        ]



-- SORTING


sortingSuite : Test
sortingSuite =
    describe "autoResetSorting end-to-end wiring"
        [ test "should preserve sorting by default when data changes" <|
            \_ ->
                -- `Nothing` is TanStack's `autoResetSorting: false` default.
                Expect.equal
                    ( config.autoResetSorting
                    , (replaceData config (withSorting ageSorting start)).sorting
                    )
                    ( Nothing, ageSorting )
        , test "should reset sorting when data changes and autoResetSorting is true" <|
            \_ ->
                (replaceData (Table.withAutoResetSorting True config) (withSorting ageSorting start)).sorting
                    |> Expect.equal []

        -- adapted: the reset goes to the feature default, never to a
        -- remembered initial slice; there is no `table.initialState`.
        , test "should reset sorting to initialState.sorting" <|
            \_ ->
                (replaceData (Table.withAutoResetSorting True config) (withSorting nameSorting start)).sorting
                    |> Expect.equal []
        , test "should not reset sorting when the sorting state itself changes" <|
            \_ ->
                let
                    cfg : Table.Config Person
                    cfg =
                        Table.withAutoResetSorting True config
                in
                (change cfg start (withSorting ageSorting start)).sorting
                    |> Expect.equal ageSorting
        , test "should not reset sorting when filters or grouping change" <|
            \_ ->
                let
                    cfg : Table.Config Person
                    cfg =
                        Table.withAutoResetSorting True config

                    sorted : Table.State
                    sorted =
                        withSorting ageSorting start

                    filtered : Table.State
                    filtered =
                        change cfg sorted (withFilters evenGroup sorted)

                    grouped : Table.State
                    grouped =
                        change cfg filtered (withGrouping [ "group" ] filtered)
                in
                Expect.equal ( filtered.sorting, grouped.sorting ) ( ageSorting, ageSorting )
        , test "should allow autoResetAll to enable the reset" <|
            \_ ->
                (replaceData (Table.withAutoResetAll True config) (withSorting ageSorting start)).sorting
                    |> Expect.equal []
        , test "should allow autoResetAll to disable an explicit sorting reset" <|
            \_ ->
                let
                    cfg : Table.Config Person
                    cfg =
                        config
                            |> Table.withAutoResetSorting True
                            |> Table.withAutoResetAll False
                in
                (replaceData cfg (withSorting ageSorting start)).sorting
                    |> Expect.equal ageSorting
        , test "should honor an explicit reset with manual sorting" <|
            \_ ->
                let
                    cfg : Table.Config Person
                    cfg =
                        Table.withAutoResetSorting True { config | manualSorting = True }
                in
                (replaceData cfg (withSorting ageSorting start)).sorting
                    |> Expect.equal []
        ]



-- EXPANDED


{-| Row `1` expanded, then the change under test.
-}
fromExpandedOne : Table.Config Person -> (Table.State -> Table.State) -> List String
fromExpandedOne cfg apply =
    let
        previous : Table.State
        previous =
            expandRow "1" start
    in
    expandedIdsOf (change cfg previous (apply previous))


{-| The vitest `triggerReset` of this block: row `1` expanded, then a grouping
change.
-}
triggerExpandedReset : Table.Config Person -> List String
triggerExpandedReset cfg =
    fromExpandedOne cfg (withGrouping [ "group" ])


expandedSuite : Test
expandedSuite =
    describe "autoResetExpanded end-to-end wiring"
        [ test "should reset expanded when data changes without the grouping feature" <|
            \_ ->
                let
                    expanded : Table.State
                    expanded =
                        expandRow "1" start
                in
                Expect.equal
                    ( expandedIdsOf expanded
                    , expandedIdsOf (replaceData config expanded)
                    )
                    ( [ "1" ], [] )
        , test "should reset expanded to an empty map when grouping changes" <|
            \_ ->
                triggerExpandedReset config
                    |> Expect.equal []

        -- adapted: unlike TanStack, the reset goes to the feature default and
        -- never to a seeded `initialState.expanded`; there is none here.
        , test "should reset expanded to a seeded initialState.expanded when grouping changes" <|
            \_ ->
                let
                    previous : Table.State
                    previous =
                        Table.setExpanded (Table.expandedIds (Set.fromList [ "0", "1" ])) start
                in
                expandedIdsOf (change config previous (withGrouping [ "group" ] previous))
                    |> Expect.equal []
        , test "should not reset expanded when only sorting changes" <|
            \_ ->
                fromExpandedOne config (withSorting ageSorting)
                    |> Expect.equal [ "1" ]
        , test "should reset expanded when column filters change (grouped stage is downstream of filtering)" <|
            \_ ->
                fromExpandedOne config (withFilters evenGroup)
                    |> Expect.equal []
        , describe "option precedence"
            [ test "should skip the reset when autoResetAll is false" <|
                \_ ->
                    triggerExpandedReset (Table.withAutoResetAll False config)
                        |> Expect.equal [ "1" ]
            , test "should force the reset when autoResetAll is true even with manualExpanding" <|
                \_ ->
                    triggerExpandedReset
                        (Table.withAutoResetAll True { config | manualExpanding = True })
                        |> Expect.equal []
            , test "should skip the reset when autoResetExpanded is false" <|
                \_ ->
                    triggerExpandedReset (Table.withAutoResetExpanded False config)
                        |> Expect.equal [ "1" ]
            , test "should opt back in with autoResetExpanded true despite manualExpanding" <|
                \_ ->
                    triggerExpandedReset
                        (Table.withAutoResetExpanded True { config | manualExpanding = True })
                        |> Expect.equal []
            , test "should skip the reset by default when manualExpanding is true" <|
                \_ ->
                    triggerExpandedReset { config | manualExpanding = True }
                        |> Expect.equal [ "1" ]
            ]
        ]



-- FIRST RUN


firstRunSuite : Test
firstRunSuite =
    describe "first-run guard"
        [ -- adapted: `skipFirstRun` guards the first row-model computation,
          -- which is not a change. Here the first computation is a call in
          -- which nothing changed at all, and nothing resets.
          test "should not reset initialState.pageIndex on the first row model read" <|
            \_ ->
                let
                    seeded : Table.State
                    seeded =
                        onPage 1 start
                in
                pageIndexOf (change config seeded seeded)
                    |> Expect.equal 1

        -- excluded: "should not push controlled-state resets to the consumer
        --   on mount" — the assertion is that `onExpandedChange` and
        --   `onPaginationChange` were never called. There are no change
        --   handlers here: `Table.autoReset` returns a state.
        , test "should still auto-reset on the first change after mount" <|
            \_ ->
                let
                    seeded : Table.State
                    seeded =
                        onPage 1 start

                    previous : Table.State
                    previous =
                        onPage 2 seeded
                in
                pageIndexOf (change config previous (withFilters evenGroup previous))
                    |> Expect.equal 0
        ]
