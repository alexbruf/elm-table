module CoreRowModelsFeatureTest exposing (suite)

{-| Ports
`tests/unit/core/row-models/coreRowModelsFeature.utils.test.ts`.

Phase 3 filled in the filtering, sorting and pagination stages and phase 4
the grouping and expanding ones, so the matrix cases below assert both
halves of every "one manual option at a time" case. The `setOptions` runtime
toggles are ported as two configs, one per side of the toggle. Excluded cases
are listed in `reports/phase-2.md` and `reports/rehoming.md`.

-}

import Expect
import Fixtures exposing (Person)
import Table
import Table.Value as Value
import Test exposing (Test, describe, test)


type alias Item =
    { name : String
    , status : String
    , subRows : SubItems
    }


type SubItems
    = SubItems (List Item)


item : String -> String -> Item
item name status =
    Item name status (SubItems [])


matrixData : List Item
matrixData =
    [ item "echo" "group-a"
    , item "alpha" "group-b"
    , item "delta" "group-a"
    , Item "bravo" "group-b" (SubItems [ item "bravo-child" "group-b" ])
    , item "charlie" "excluded"
    ]


matrixConfig : Table.Config Item
matrixConfig =
    Table.config
        [ Table.column "name" (.name >> Value.String)
        , Table.column "status" (.status >> Value.String)
        ]
        |> Table.withSubRows (\row -> subItemsOf row.subRows)


subItemsOf : SubItems -> List Item
subItemsOf (SubItems items) =
    items


matrixState : Table.State
matrixState =
    let
        state =
            Table.initialState
    in
    { state
        | columnFilters = [ { id = "status", value = Value.String "group" } ]
        , grouping = [ "status" ]
        , sorting = [ { id = "name", desc = False } ]
        , expanded = Table.expandAll
        , pagination = { pageIndex = 0, pageSize = 2 }
    }


type alias Stages =
    { core : Table.RowModel Item
    , preFiltered : Table.RowModel Item
    , filtered : Table.RowModel Item
    , preGrouped : Table.RowModel Item
    , grouped : Table.RowModel Item
    , preSorted : Table.RowModel Item
    , sorted : Table.RowModel Item
    , preExpanded : Table.RowModel Item
    , expanded : Table.RowModel Item
    , prePaginated : Table.RowModel Item
    , paginated : Table.RowModel Item
    , final : Table.RowModel Item
    }


stages : Table.Config Item -> Table.State -> List Item -> Stages
stages cfg state data =
    let
        core =
            Table.coreRowModelFromList cfg state data

        filtered =
            Table.filteredRowModel cfg state core

        grouped =
            Table.groupedRowModel cfg state filtered

        sorted =
            Table.sortedRowModel cfg state grouped

        expanded =
            Table.expandedRowModel cfg state sorted

        paginated =
            Table.paginatedRowModel cfg state expanded
    in
    { core = core
    , preFiltered = core
    , filtered = filtered
    , preGrouped = filtered
    , grouped = grouped
    , preSorted = grouped
    , sorted = sorted
    , preExpanded = sorted
    , expanded = expanded
    , prePaginated = expanded
    , paginated = paginated
    , final = Table.rowsFromList cfg state data
    }


matrix : (Table.Config Item -> Table.Config Item) -> Stages
matrix tweak =
    stages (tweak matrixConfig) matrixState matrixData


suite : Test
suite =
    describe "coreRowModelsFeature.utils"
        [ describe "row model fallback chains"
            [ test "should fall through every stage to the core row model when no factories are registered" <|
                \_ ->
                    let
                        cfg =
                            Table.config Fixtures.columns

                        model : Table.RowModel Person
                        model =
                            Table.coreRowModelFromList cfg Table.initialState (Fixtures.makeData [ 3 ])

                        every =
                            [ Table.filteredRowModel cfg Table.initialState model
                            , Table.groupedRowModel cfg Table.initialState model
                            , Table.sortedRowModel cfg Table.initialState model
                            , Table.expandedRowModel cfg Table.initialState model
                            , Table.paginatedRowModel cfg Table.initialState model
                            , Table.rowsFromList cfg Table.initialState (Fixtures.makeData [ 3 ])
                            ]
                    in
                    every
                        |> List.map (\stage -> stage == model)
                        |> Expect.equal (List.repeat 6 True)

            -- adapted: nothing is cached in a pure port, so the assertion is
            -- that repeated builds from the same config and data are equal.
            , test "should cache the core row model factory across calls" <|
                \_ ->
                    let
                        cfg : Table.Config Person
                        cfg =
                            Table.config Fixtures.columns

                        build : () -> Table.RowModel Person
                        build () =
                            Table.coreRowModelFromList cfg Table.initialState (Fixtures.makeData [ 3 ])
                    in
                    Expect.equal (build ()) (build ())
            ]
        , describe "manual processing options"
            [ test "manualFiltering should bypass a registered filtered row model" <|
                \_ ->
                    let
                        s =
                            matrix (\cfg -> { cfg | manualFiltering = True })
                    in
                    Expect.equal ( s.filtered == s.preFiltered, List.length s.filtered.rows )
                        ( True, 5 )
            , test "manualSorting should bypass a registered sorted row model" <|
                \_ ->
                    let
                        s =
                            matrix (\cfg -> { cfg | manualFiltering = True, manualSorting = True })
                    in
                    Expect.equal (s.sorted == s.preSorted) True
            , test "registered factories should apply when manual options are off" <|
                \_ ->
                    let
                        cfg : Table.Config Item
                        cfg =
                            matrixConfig

                        state : Table.State
                        state =
                            { matrixState
                                | columnFilters = [ { id = "name", value = Value.String "zzz-no-match" } ]
                            }

                        core : Table.RowModel Item
                        core =
                            Table.coreRowModelFromList cfg state matrixData

                        filtered : Table.RowModel Item
                        filtered =
                            Table.filteredRowModel cfg state core
                    in
                    Expect.equal ( List.length filtered.rows, filtered == core ) ( 0, False )
            ]
        , describe "one manual option at a time"
            [ test "manualFiltering should bypass filtering while grouping still groups the unfiltered rows" <|
                \_ ->
                    let
                        s =
                            matrix (\cfg -> { cfg | manualFiltering = True })
                    in
                    Expect.equal
                        { bypassed = s.filtered == s.preFiltered
                        , rows = List.length s.filtered.rows
                        , groupedIds = List.map Table.rowId s.grouped.rows
                        }
                        { bypassed = True
                        , rows = 5
                        , groupedIds =
                            [ "status:group-a", "status:group-b", "status:excluded" ]
                        }
            , test "manualGrouping should bypass grouping while sorting still sorts the filtered leaf rows" <|
                \_ ->
                    let
                        s =
                            matrix (\cfg -> { cfg | manualGrouping = True })
                    in
                    Expect.equal
                        { bypassed = s.grouped == s.preGrouped
                        , identity_ = s.grouped == s.filtered
                        , sortedNames = List.map (Table.rowOriginal >> .name) s.sorted.rows
                        }
                        { bypassed = True
                        , identity_ = True
                        , sortedNames = [ "alpha", "bravo", "delta", "echo" ]
                        }
            , test "manualSorting should bypass sorting while expanding still flattens the grouped rows" <|
                \_ ->
                    let
                        s =
                            matrix (\cfg -> { cfg | manualSorting = True })
                    in
                    Expect.equal
                        { bypassed = s.sorted == s.preSorted
                        , identity_ = s.sorted == s.grouped
                        , expandedIds = List.map Table.rowId s.expanded.rows
                        }
                        { bypassed = True
                        , identity_ = True
                        , expandedIds =
                            [ "status:group-a", "0", "2", "status:group-b", "1", "3", "3.0" ]
                        }
            , test "manualExpanding should bypass expanding while pagination still slices the unexpanded rows" <|
                \_ ->
                    let
                        s =
                            matrix (\cfg -> { cfg | manualExpanding = True })
                    in
                    Expect.equal
                        { bypassed = s.expanded == s.preExpanded
                        , identity_ = s.expanded == s.sorted
                        , pageSize = List.length s.paginated.rows
                        , allGroups =
                            List.all (Table.rowId >> String.startsWith "status:")
                                s.paginated.rows
                        }
                        { bypassed = True, identity_ = True, pageSize = 2, allGroups = True }
            , test "manualPagination should bypass pagination so the final row model keeps every expanded row" <|
                \_ ->
                    -- pageSize is 2 but all 7 expanded rows (2 group rows, 4
                    -- leaves and 1 child) survive because pagination is
                    -- bypassed.
                    let
                        s =
                            matrix (\cfg -> { cfg | manualPagination = True })
                    in
                    Expect.equal
                        { bypassed = s.paginated == s.prePaginated
                        , identity_ = s.final == s.expanded
                        , keepsEveryRow = List.length s.final.rows
                        }
                        { bypassed = True, identity_ = True, keepsEveryRow = 7 }
            ]
        , -- adapted: there is no factory to instantiate, so only the
          -- observable half is asserted: the stage is bypassed while the
          -- manual option is on and applies as soon as it is off.
          describe "instantiate-then-bypass ordering"
            [ test "should instantiate a registered factory even when its manual option bypasses the result" <|
                \_ ->
                    let
                        state : Table.State
                        state =
                            { matrixState
                                | columnFilters = [ { id = "name", value = Value.String "zzz-no-match" } ]
                            }

                        core : Table.RowModel Item
                        core =
                            Table.coreRowModelFromList matrixConfig state matrixData

                        bypassed : Table.RowModel Item
                        bypassed =
                            Table.filteredRowModel { matrixConfig | manualFiltering = True } state core

                        applied : Table.RowModel Item
                        applied =
                            Table.filteredRowModel matrixConfig state core
                    in
                    Expect.equal
                        { bypassedIsCore = bypassed == core
                        , appliedIsCore = applied == core
                        , appliedRows = List.length applied.rows
                        }
                        { bypassedIsCore = True, appliedIsCore = False, appliedRows = 0 }
            ]
        , -- adapted: `setOptions` has no counterpart, so each toggle is two
          -- configs, one per side of the switch (the phase 3 convention).
          describe "runtime toggling via setOptions"
            [ test "manualFiltering toggle should switch between identity and applied filtering" <|
                \_ ->
                    let
                        on =
                            matrix (\cfg -> { cfg | manualFiltering = True })

                        off =
                            matrix identity
                    in
                    Expect.equal
                        { manualBypassed = on.filtered == on.preFiltered
                        , manualRows = List.length on.filtered.rows
                        , appliedBypassed = off.filtered == off.preFiltered
                        , appliedIds = List.map Table.rowId off.filtered.rows
                        }
                        { manualBypassed = True
                        , manualRows = 5
                        , appliedBypassed = False
                        , appliedIds = [ "0", "1", "2", "3" ]
                        }
            , test "manualGrouping toggle should switch between identity and applied grouping" <|
                \_ ->
                    let
                        on =
                            matrix (\cfg -> { cfg | manualGrouping = True })

                        off =
                            matrix identity
                    in
                    Expect.equal
                        { manualBypassed = on.grouped == on.preGrouped
                        , appliedBypassed = off.grouped == off.preGrouped
                        , appliedIds = List.map Table.rowId off.grouped.rows
                        }
                        { manualBypassed = True
                        , appliedBypassed = False
                        , appliedIds = [ "status:group-a", "status:group-b" ]
                        }
            , test "manualSorting toggle should switch between identity and applied sorting" <|
                \_ ->
                    let
                        on =
                            matrix (\cfg -> { cfg | manualGrouping = True, manualSorting = True })

                        off =
                            matrix (\cfg -> { cfg | manualGrouping = True })
                    in
                    Expect.equal
                        { manualBypassed = on.sorted == on.preSorted
                        , appliedBypassed = off.sorted == off.preSorted
                        , appliedNames = List.map (Table.rowOriginal >> .name) off.sorted.rows
                        }
                        { manualBypassed = True
                        , appliedBypassed = False
                        , appliedNames = [ "alpha", "bravo", "delta", "echo" ]
                        }
            , test "manualExpanding toggle should switch between identity and applied expanding" <|
                \_ ->
                    let
                        on =
                            matrix (\cfg -> { cfg | manualExpanding = True })

                        off =
                            matrix identity
                    in
                    Expect.equal
                        { manualBypassed = on.expanded == on.preExpanded
                        , manualRows = List.length on.expanded.rows
                        , appliedBypassed = off.expanded == off.preExpanded
                        , appliedRows = List.length off.expanded.rows
                        }
                        { manualBypassed = True
                        , manualRows = 2
                        , appliedBypassed = False
                        , appliedRows = 7
                        }
            , test "manualPagination toggle should switch between identity and applied pagination" <|
                \_ ->
                    let
                        on =
                            matrix (\cfg -> { cfg | manualPagination = True })

                        off =
                            matrix identity
                    in
                    Expect.equal
                        { manualBypassed = on.paginated == on.prePaginated
                        , manualRows = List.length on.paginated.rows
                        , appliedBypassed = off.paginated == off.prePaginated
                        , appliedRows = List.length off.paginated.rows
                        }
                        { manualBypassed = True
                        , manualRows = 7
                        , appliedBypassed = False
                        , appliedRows = 2
                        }
            ]
        , describe "all manual options at once"
            [ test "should make the final row model identity-equal to the core row model" <|
                \_ ->
                    let
                        s =
                            matrix
                                (\cfg ->
                                    { cfg
                                        | manualFiltering = True
                                        , manualGrouping = True
                                        , manualSorting = True
                                        , manualExpanding = True
                                        , manualPagination = True
                                    }
                                )
                    in
                    Expect.equal
                        { final = s.final == s.core
                        , filtered = s.filtered == s.core
                        , grouped = s.grouped == s.core
                        , sorted = s.sorted == s.core
                        , expanded = s.expanded == s.core
                        , paginated = s.paginated == s.core
                        , rows = List.length s.final.rows
                        }
                        { final = True
                        , filtered = True
                        , grouped = True
                        , sorted = True
                        , expanded = True
                        , paginated = True
                        , rows = 5
                        }
            ]
        ]
