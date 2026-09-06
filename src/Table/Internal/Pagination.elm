module Table.Internal.Pagination exposing
    ( firstPage
    , getCanLastPage
    , getCanNextPage
    , getCanPreviousPage
    , getPageCount
    , getPageOptions
    , getRowCount
    , lastPage
    , nextPage
    , paginatedRowModel
    , previousPage
    , resetPageIndex
    , resetPageSize
    , resetPagination
    , rowsInDisplayOrder
    , setPage
    , setPageSize
    , setPagination
    , unlimitedPageSize
    )

{-| Pagination: ports `row-pagination/createPaginatedRowModel.ts` and
`row-pagination/rowPaginationFeature.utils.ts`.

The page slice runs on the row model handed in, which is the expanded row
model in the standard pipeline. `Config.pageCount` and `Config.rowCount` are
the manual (server-side) overrides.

-}

import Set exposing (Set)
import Table.Internal.Expanding as Expanding
import Table.Internal.Types exposing (Config, Pagination, Row(..), RowModel, State)


{-| Elm has no `Infinity` for `Int`. This is `Number.MAX_SAFE_INTEGER`, the
page size to use where TanStack would use `Infinity`: one page holds every
row.
-}
unlimitedPageSize : Int
unlimitedPageSize =
    9007199254740991


defaultPageIndex : Int
defaultPageIndex =
    0


defaultPageSize : Int
defaultPageSize =
    10



-- THE ROW MODEL


{-| Keep only the rows of the current page.

With `Config.paginateExpandedRows = False` the slice runs on the collapsed
rows and the expanded children of the page rows are inserted afterwards, so
they never consume a page slot.

-}
paginatedRowModel : Config row -> State -> RowModel row -> RowModel row
paginatedRowModel cfg state model =
    if List.isEmpty model.rows then
        model

    else
        let
            pageStart : Int
            pageStart =
                state.pagination.pageSize * state.pagination.pageIndex

            pageRows : List (Row row)
            pageRows =
                model.rows
                    |> List.drop pageStart
                    |> List.take state.pagination.pageSize

            displayed : List (Row row)
            displayed =
                if cfg.paginateExpandedRows then
                    pageRows

                else
                    Expanding.expandList cfg state pageRows
        in
        { rows = displayed
        , flatRows = flattenUnique displayed
        , rowsById = model.rowsById
        }


{-| The page rows plus every sub-row below them, each row listed once. The
page rows may already contain expanded children inline, hence the seen set.
-}
flattenUnique : List (Row row) -> List (Row row)
flattenUnique rows =
    flattenHelp rows Set.empty []
        |> Tuple.first
        |> List.reverse


flattenHelp : List (Row row) -> Set String -> List (Row row) -> ( List (Row row), Set String )
flattenHelp queue seen acc =
    case queue of
        [] ->
            ( acc, seen )

        (Row f) :: rest ->
            if Set.member f.id seen then
                flattenHelp rest seen acc

            else
                let
                    ( nextAcc, nextSeen ) =
                        flattenHelp f.subRows (Set.insert f.id seen) (Row f :: acc)
                in
                flattenHelp rest nextSeen nextAcc


{-| `table_getRowsInDisplayOrder`: the rows a caller renders, in order.
`Config.paginateExpandedRows = False` inserts the expanded descendants that
the pre-pagination row model does not carry.
-}
rowsInDisplayOrder : Config row -> State -> RowModel row -> List (Row row)
rowsInDisplayOrder cfg state model =
    if cfg.paginateExpandedRows then
        model.rows

    else
        Expanding.expandList cfg state model.rows



-- PAGINATION STATE


{-| `table_setPagination`.
-}
setPagination : Pagination -> State -> State
setPagination pagination state =
    { state | pagination = pagination }


{-| `table_setPageIndex`, clamped to `[0, pageCount - 1]` when
`Config.pageCount` is known. TanStack calls it `setPageIndex`; `SPEC.md`
calls it `setPage`.
-}
setPage : Config row -> Int -> State -> State
setPage cfg pageIndex state =
    let
        maxPageIndex : Int
        maxPageIndex =
            case cfg.pageCount of
                Just count ->
                    if count == -1 then
                        unlimitedPageSize

                    else
                        count - 1

                Nothing ->
                    unlimitedPageSize

        pagination : Pagination
        pagination =
            state.pagination
    in
    setPagination { pagination | pageIndex = max 0 (min pageIndex maxPageIndex) } state


{-| `table_setPageSize`: at least `1`, and `pageIndex` moves so the row that
was at the top of the page stays in view.
-}
setPageSize : Int -> State -> State
setPageSize size state =
    let
        pageSize : Int
        pageSize =
            max 1 size

        topRowIndex : Int
        topRowIndex =
            state.pagination.pageSize * state.pagination.pageIndex
    in
    setPagination { pageIndex = topRowIndex // pageSize, pageSize = pageSize } state


{-| `table_resetPagination table true`.
-}
resetPagination : State -> State
resetPagination state =
    setPagination { pageIndex = defaultPageIndex, pageSize = defaultPageSize } state


{-| `table_resetPageIndex table true`.
-}
resetPageIndex : Config row -> State -> State
resetPageIndex cfg state =
    setPage cfg defaultPageIndex state


{-| `table_resetPageSize table true`.
-}
resetPageSize : State -> State
resetPageSize state =
    setPageSize defaultPageSize state


{-| `table_getRowCount`: `Config.rowCount` wins, otherwise the rows of the
pre-pagination row model.
-}
getRowCount : Config row -> RowModel row -> Int
getRowCount cfg model =
    case cfg.rowCount of
        Just count ->
            count

        Nothing ->
            List.length model.rows


{-| `table_getPageCount`: `Config.pageCount` wins, otherwise the row count
divided by the page size, rounded up.
-}
getPageCount : Config row -> State -> RowModel row -> Int
getPageCount cfg state model =
    case cfg.pageCount of
        Just count ->
            count

        Nothing ->
            let
                rowCount : Int
                rowCount =
                    getRowCount cfg model
            in
            ceilingDiv rowCount state.pagination.pageSize


ceilingDiv : Int -> Int -> Int
ceilingDiv numerator denominator =
    if denominator <= 0 then
        0

    else
        (numerator + denominator - 1) // denominator


{-| `table_getPageOptions`: `[0, 1, ... pageCount - 1]`.
-}
getPageOptions : Config row -> State -> RowModel row -> List Int
getPageOptions cfg state model =
    let
        pageCount : Int
        pageCount =
            getPageCount cfg state model
    in
    if pageCount > 0 then
        List.range 0 (pageCount - 1)

    else
        []


{-| `table_getCanPreviousPage`.
-}
getCanPreviousPage : State -> Bool
getCanPreviousPage state =
    state.pagination.pageIndex > 0


{-| `table_getCanNextPage`. An unknown page count (`Just -1`) always allows a
next page.
-}
getCanNextPage : Config row -> State -> RowModel row -> Bool
getCanNextPage cfg state model =
    let
        pageCount : Int
        pageCount =
            getPageCount cfg state model
    in
    if pageCount == -1 then
        True

    else if pageCount == 0 then
        False

    else
        state.pagination.pageIndex < pageCount - 1


{-| `table_getCanLastPage`: only a known, non-empty page count has a last
page to jump to.
-}
getCanLastPage : Config row -> State -> RowModel row -> Bool
getCanLastPage cfg state model =
    let
        pageCount : Int
        pageCount =
            getPageCount cfg state model
    in
    pageCount > 0 && state.pagination.pageIndex < pageCount - 1


{-| `table_previousPage`.
-}
previousPage : Config row -> State -> State
previousPage cfg state =
    setPage cfg (state.pagination.pageIndex - 1) state


{-| `table_nextPage`.
-}
nextPage : Config row -> State -> State
nextPage cfg state =
    setPage cfg (state.pagination.pageIndex + 1) state


{-| `table_firstPage`.
-}
firstPage : Config row -> State -> State
firstPage cfg state =
    setPage cfg 0 state


{-| `table_lastPage`: a no-op when the page count is unknown or empty.
-}
lastPage : Config row -> State -> RowModel row -> State
lastPage cfg state model =
    let
        pageCount : Int
        pageCount =
            getPageCount cfg state model
    in
    if pageCount <= 0 then
        state

    else
        setPage cfg (pageCount - 1) state
