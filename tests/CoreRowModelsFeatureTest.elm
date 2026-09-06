module CoreRowModelsFeatureTest exposing (suite)

{-| Ports
`tests/unit/core/row-models/coreRowModelsFeature.utils.test.ts`.

Phase 3 filled in the filtering, sorting and pagination stages and phase 4
the grouping and expanding ones, so the matrix cases below assert both
halves of every "one manual option at a time" case. Excluded cases are
listed in `reports/phase-2.md`.

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
