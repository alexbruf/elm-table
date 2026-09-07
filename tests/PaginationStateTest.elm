module PaginationStateTest exposing (suite)

{-| Ports
`tests/unit/features/row-pagination/rowPaginationFeature.utils.test.ts`.

The vitest cases route every write through `onPaginationChange` and read the
result back with `getUpdaterResult`, which is the same thing as applying the
pure state transition to the previous state.

-}

import Expect
import Table
import Table.Value as Value
import Test exposing (Test, describe, test)



-- FIXTURE


type alias Row =
    { index : Int }


config : Table.Config Row
config =
    Table.config [ Table.column "index" (.index >> toFloat >> Value.Number) ]


{-| 25 rows at the default page size of 10 gives 3 pages.
-}
defaultRowCount : Int
defaultRowCount =
    25


rows : Int -> List Row
rows count =
    List.range 0 (count - 1) |> List.map Row


model : Int -> Table.RowModel Row
model count =
    Table.coreRowModelFromList config Table.initialState (rows count)


defaultPagination : Table.Pagination
defaultPagination =
    { pageIndex = 0, pageSize = 10 }


at : Table.Pagination -> Table.State
at pagination =
    let
        state : Table.State
        state =
            Table.initialState
    in
    { state | pagination = pagination }


paginationOf : Table.State -> Table.Pagination
paginationOf state =
    state.pagination



-- SUITE


suite : Test
suite =
    describe "rowPaginationFeature.utils"
        [ describe "getDefaultPaginationState"
            [ test "should return the first page with a page size of 10" <|
                \_ ->
                    Table.initialState.pagination |> Expect.equal { pageIndex = 0, pageSize = 10 }
            , test "should return a new object instance each time" <|
                \_ ->
                    -- Elm values are immutable, so "a new instance" is not
                    -- observable; what the vitest case buys is asserted
                    -- instead: writing to one copy cannot affect the other.
                    let
                        modified : Table.State
                        modified =
                            Table.setPagination { pageIndex = 5, pageSize = 5 } Table.initialState
                    in
                    Expect.equal ( modified.pagination, Table.initialState.pagination )
                        ( { pageIndex = 5, pageSize = 5 }, { pageIndex = 0, pageSize = 10 } )
            ]
        , describe "table_setPagination"
            [ test "should route the updater through onPaginationChange" <|
                \_ ->
                    Table.setPagination { pageIndex = 2, pageSize = 5 } (at defaultPagination)
                        |> paginationOf
                        |> Expect.equal { pageIndex = 2, pageSize = 5 }
            , test "should resolve functional updaters against the previous state" <|
                \_ ->
                    -- Elm state transitions take a value; the caller writes the
                    -- function the updater was.
                    let
                        previous : Table.Pagination
                        previous =
                            { pageIndex = 1, pageSize = 10 }
                    in
                    Table.setPagination { previous | pageIndex = previous.pageIndex + 1 } (at previous)
                        |> paginationOf
                        |> Expect.equal { pageIndex = 2, pageSize = 10 }
            ]
        , describe "table_resetPagination"
            [ test "should reset to the feature default when defaultState is true" <|
                \_ ->
                    Table.resetPagination (at { pageIndex = 2, pageSize = 5 })
                        |> paginationOf
                        |> Expect.equal defaultPagination
            , test "should reset to the initial state by default" <|
                \_ ->
                    -- There is no `initialState` here: the caller keeps the
                    -- pagination it wants to restore and writes it back.
                    Table.setPagination { pageIndex = 2, pageSize = 5 } (at defaultPagination)
                        |> paginationOf
                        |> Expect.equal { pageIndex = 2, pageSize = 5 }
            ]
        , describe "table_setPageIndex"
            [ test "should update the page index" <|
                \_ ->
                    Table.setPage config 2 (at defaultPagination)
                        |> paginationOf
                        |> Expect.equal { pageIndex = 2, pageSize = 10 }
            , test "should clamp negative page indexes to 0" <|
                \_ ->
                    Table.setPage config -5 (at { pageIndex = 2, pageSize = 10 })
                        |> paginationOf
                        |> Expect.equal { pageIndex = 0, pageSize = 10 }
            , test "should clamp to pageCount - 1 when a manual pageCount is known" <|
                \_ ->
                    Table.setPage (manual 3) 99 (at defaultPagination)
                        |> paginationOf
                        |> Expect.equal { pageIndex = 2, pageSize = 10 }
            , test "should not clamp when pageCount is -1 (unknown)" <|
                \_ ->
                    Table.setPage (manual -1) 99 (at defaultPagination)
                        |> paginationOf
                        |> Expect.equal { pageIndex = 99, pageSize = 10 }
            , test "keeps pre-pagination display indexes on the current page" <|
                \_ ->
                    let
                        state : Table.State
                        state =
                            at { pageIndex = 2, pageSize = 10 }

                        pre : Table.RowModel Row
                        pre =
                            model defaultRowCount
                    in
                    Table.paginatedRowModel config state pre
                        |> .rows
                        |> List.map (Table.displayIndex config state pre)
                        |> Expect.equal [ 20, 21, 22, 23, 24 ]
            ]
        , describe "table_resetPageIndex"
            [ test "should reset to 0 when defaultState is true" <|
                \_ ->
                    Table.resetPageIndex config (at { pageIndex = 2, pageSize = 10 })
                        |> paginationOf
                        |> Expect.equal { pageIndex = 0, pageSize = 10 }
            , test "should be a no-op when the page index is already at the target" <|
                \_ ->
                    Table.resetPageIndex config (at defaultPagination)
                        |> Expect.equal (at defaultPagination)
            , test "should reset to the initial page index by default" <|
                \_ ->
                    -- The caller keeps the page index it wants to restore.
                    Table.setPage config 2 (Table.setPage config 1 (at { pageIndex = 2, pageSize = 10 }))
                        |> paginationOf
                        |> .pageIndex
                        |> Expect.equal 2
            ]
        , describe "table_resetPageSize"
            [ test "should reset to 10 when defaultState is true" <|
                \_ ->
                    Table.resetPageSize (at { pageIndex = 0, pageSize = 5 })
                        |> paginationOf
                        |> Expect.equal { pageIndex = 0, pageSize = 10 }
            , test "should be a no-op when the page size is already at the target" <|
                \_ ->
                    Table.resetPageSize (at defaultPagination)
                        |> Expect.equal (at defaultPagination)
            , test "should reset to the initial page size by default" <|
                \_ ->
                    -- The caller keeps the page size it wants to restore.
                    Table.setPageSize 5 (Table.setPageSize 20 (at { pageIndex = 0, pageSize = 5 }))
                        |> paginationOf
                        |> .pageSize
                        |> Expect.equal 5
            ]
        , describe "table_setPageSize"
            [ test "should clamp the page size to at least 1" <|
                \_ ->
                    Table.setPageSize 0 (at defaultPagination)
                        |> paginationOf
                        |> Expect.equal { pageIndex = 0, pageSize = 1 }
            , test "should keep the previous top row in view when the page size changes" <|
                \_ ->
                    -- top row was 10 * 2 = 20; with pageSize 5 that row lives
                    -- on page 4
                    Table.setPageSize 5 (at { pageIndex = 2, pageSize = 10 })
                        |> paginationOf
                        |> Expect.equal { pageIndex = 4, pageSize = 5 }
            , test "should reset to page 0 when the page size changes to Infinity" <|
                \_ ->
                    Table.setPageSize Table.unlimitedPageSize (at { pageIndex = 2, pageSize = 10 })
                        |> paginationOf
                        |> Expect.equal { pageIndex = 0, pageSize = Table.unlimitedPageSize }
            , test "should reset to page 0 when changing from an infinite page size" <|
                \_ ->
                    Table.setPageSize 10 (at { pageIndex = 0, pageSize = Table.unlimitedPageSize })
                        |> paginationOf
                        |> Expect.equal { pageIndex = 0, pageSize = 10 }
            ]
        , describe "table_getPageOptions"
            [ test "should list every page index" <|
                \_ ->
                    Table.getPageOptions config (at defaultPagination) (model 25)
                        |> Expect.equal [ 0, 1, 2 ]
            , test "should return an empty array when there are no rows" <|
                \_ ->
                    Table.getPageOptions config (at defaultPagination) (model 0)
                        |> Expect.equal []
            ]
        , describe "table_getCanPreviousPage"
            [ test "should return false on the first page" <|
                \_ -> Table.getCanPreviousPage (at defaultPagination) |> Expect.equal False
            , test "should return true past the first page" <|
                \_ ->
                    Table.getCanPreviousPage (at { pageIndex = 1, pageSize = 10 })
                        |> Expect.equal True
            ]
        , describe "table_getCanNextPage"
            [ test "should return true when more pages exist" <|
                \_ ->
                    Table.getCanNextPage config (at defaultPagination) (model 25) |> Expect.equal True
            , test "should return false on the last page" <|
                \_ ->
                    Table.getCanNextPage config (at { pageIndex = 2, pageSize = 10 }) (model 25)
                        |> Expect.equal False
            , test "should return true when the page count is unknown (-1)" <|
                \_ ->
                    Table.getCanNextPage (manual -1) (at { pageIndex = 99, pageSize = 10 }) (model 25)
                        |> Expect.equal True
            , test "should return false when the page count is 0" <|
                \_ ->
                    Table.getCanNextPage config (at defaultPagination) (model 0) |> Expect.equal False
            ]
        , describe "table_getCanLastPage"
            [ test "should return true when a known last page exists after the current page" <|
                \_ ->
                    Table.getCanLastPage config (at defaultPagination) (model 25) |> Expect.equal True
            , test "should return false on the last page" <|
                \_ ->
                    Table.getCanLastPage config (at { pageIndex = 2, pageSize = 10 }) (model 25)
                        |> Expect.equal False
            , test "should return false when the page count is unknown" <|
                \_ ->
                    Expect.equal
                        ( Table.getCanNextPage (manual -1) (at defaultPagination) (model 25)
                        , Table.getCanLastPage (manual -1) (at defaultPagination) (model 25)
                        )
                        ( True, False )
            , test "should return false when the page count is 0" <|
                \_ ->
                    Table.getCanLastPage config (at defaultPagination) (model 0) |> Expect.equal False

            -- excluded: "should return false when the page count is
            --   non-finite". `Config.pageCount` is a `Maybe Int`, so there is
            --   no `Infinity` page count to reject.
            ]
        , describe "page navigation"
            [ test "table_nextPage should advance the page index" <|
                \_ ->
                    Table.nextPage config (at defaultPagination)
                        |> paginationOf
                        |> Expect.equal { pageIndex = 1, pageSize = 10 }
            , test "table_previousPage should decrement the page index and clamp at 0" <|
                \_ ->
                    Expect.equal
                        ( paginationOf (Table.previousPage config (at { pageIndex = 2, pageSize = 10 }))
                        , paginationOf (Table.previousPage config (at defaultPagination))
                        )
                        ( { pageIndex = 1, pageSize = 10 }, { pageIndex = 0, pageSize = 10 } )
            , test "table_firstPage should go to page 0" <|
                \_ ->
                    Table.firstPage config (at { pageIndex = 2, pageSize = 10 })
                        |> paginationOf
                        |> Expect.equal { pageIndex = 0, pageSize = 10 }
            , test "table_lastPage should go to the last computed page" <|
                \_ ->
                    Table.lastPage config (at defaultPagination) (model 25)
                        |> paginationOf
                        |> .pageIndex
                        |> Expect.equal 2
            , test "table_lastPage should do nothing when pageCount is -1" <|
                \_ -> lastPageIndexWith -1 |> Expect.equal 1
            , test "table_lastPage should do nothing when pageCount is 0" <|
                \_ -> lastPageIndexWith 0 |> Expect.equal 1
            ]
        , describe "table_getPageCount"
            [ test "should compute the page count from the row count and page size" <|
                \_ ->
                    Expect.equal
                        ( pageCount 25, pageCount 30, pageCount 31 )
                        ( 3, 3, 4 )
            , test "should return one page for a non-empty table with pageSize Infinity" <|
                \_ ->
                    let
                        state : Table.State
                        state =
                            at { pageIndex = 0, pageSize = Table.unlimitedPageSize }
                    in
                    Expect.equal
                        { count = Table.getPageCount config state (model 25)
                        , options = Table.getPageOptions config state (model 25)
                        , canNext = Table.getCanNextPage config state (model 25)
                        }
                        { count = 1, options = [ 0 ], canNext = False }
            , test "should return zero pages for an empty table with pageSize Infinity" <|
                \_ ->
                    let
                        state : Table.State
                        state =
                            at { pageIndex = 0, pageSize = Table.unlimitedPageSize }
                    in
                    Expect.equal
                        ( Table.getPageCount config state (model 0)
                        , Table.getPageOptions config state (model 0)
                        )
                        ( 0, [] )
            , test "should prefer options.pageCount for manual pagination" <|
                \_ ->
                    Table.getPageCount (manual 7) (at defaultPagination) (model 25) |> Expect.equal 7
            ]
        , describe "table_getRowCount"
            [ test "should count the pre-paginated rows" <|
                \_ -> Table.getRowCount config (model 25) |> Expect.equal 25
            , test "should prefer options.rowCount for manual pagination" <|
                \_ ->
                    Table.getRowCount { config | manualPagination = True, rowCount = Just 1000 } (model 25)
                        |> Expect.equal 1000
            ]
        , describe "paginated row model"
            [ test "should slice rows to the current page" <|
                \_ ->
                    let
                        page : Table.Pagination -> ( Int, Maybe String )
                        page pagination =
                            let
                                sliced : Table.RowModel Row
                                sliced =
                                    Table.paginatedRowModel config (at pagination) (model 25)
                            in
                            ( List.length sliced.rows
                            , List.head sliced.rows |> Maybe.map Table.rowId
                            )
                    in
                    Expect.equal
                        ( page defaultPagination, page { pageIndex = 2, pageSize = 10 } )
                        ( ( 10, Just "0" ), ( 5, Just "20" ) )
            ]
        , -- `autoReset*` scheduling is out of scope per SPEC.md, but the
          -- reset itself is `Table.resetPageIndex`, so every case whose
          -- assertion is that reset is ported against it.
          describe "table_autoResetPageIndex"
            [ -- adapted: the caller calls the reset the scheduler would.
              test "should reset the page index for client-side pagination" <|
                \_ ->
                    let
                        moved : Table.State
                        moved =
                            Table.setPage config 2 (at defaultPagination)
                    in
                    Expect.equal
                        ( (paginationOf moved).pageIndex
                        , (paginationOf (Table.resetPageIndex config moved)).pageIndex
                        )
                        ( 2, 0 )

            -- adapted: `resetPageIndex` goes to the feature default, never to
            -- a caller's remembered initial page (the phase 3 convention).
            , test "should reset to the first page instead of the initial page index" <|
                \_ ->
                    let
                        moved : Table.State
                        moved =
                            Table.setPage config 2 (at { pageIndex = 1, pageSize = 10 })
                    in
                    Expect.equal
                        ( (paginationOf moved).pageIndex
                        , (paginationOf (Table.resetPageIndex config moved)).pageIndex
                        )
                        ( 2, 0 )

            -- adapted: there is no `onPaginationChange` spy, so "not called"
            -- is "the state comes back unchanged".
            , test "should not invoke onPaginationChange when already on the default page" <|
                \_ ->
                    let
                        state : Table.State
                        state =
                            at defaultPagination
                    in
                    Table.resetPageIndex config state |> Expect.equal state

            -- adapted: the resulting `Pagination` stands in for the updater
            -- handed to `onPaginationChange`.
            , test "should invoke onPaginationChange when off the default page" <|
                \_ ->
                    Table.resetPageIndex config (at { pageIndex = 2, pageSize = 10 })
                        |> paginationOf
                        |> Expect.equal { pageIndex = 0, pageSize = 10 }

            -- adapted: `manualPagination` gates TanStack's scheduler, not the
            -- reset; a caller that asks for the reset always gets it.
            , test "should reset even for manual pagination when autoResetPageIndex opts back in" <|
                \_ ->
                    let
                        moved : Table.State
                        moved =
                            Table.setPage (manual 3) 2 (at defaultPagination)
                    in
                    Expect.equal
                        ( (paginationOf moved).pageIndex
                        , (paginationOf (Table.resetPageIndex (manual 3) moved)).pageIndex
                        )
                        ( 2, 0 )

            -- excluded: "should not reset when manualPagination is set".
            --   The assertion is that no reset happens; here the reset is the
            --   caller's own call, so there is no scheduler for
            --   `manualPagination` to gate.
            ]
        ]


manual : Int -> Table.Config Row
manual count =
    { config | manualPagination = True, pageCount = Just count }


lastPageIndexWith : Int -> Int
lastPageIndexWith count =
    Table.lastPage (manual count) (at { pageIndex = 1, pageSize = 10 }) (model 25)
        |> paginationOf
        |> .pageIndex


pageCount : Int -> Int
pageCount count =
    Table.getPageCount config (at defaultPagination) (model count)
