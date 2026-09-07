module Table.Internal.AutoReset exposing (autoReset)

{-| The `autoReset*` options, ported as one pure function.

TanStack schedules its resets from the `onAfterUpdate` hook of a row-model
stage memo, so which change resets which slice follows from the pipeline
wiring:

  - `createCoreRowModel` (data changed) runs `table_autoResetExpanded`,
    `table_autoResetPageIndex`, `table_autoResetSorting` and
    `table_autoResetCellSelection`.
  - `createFilteredRowModel` (data, column filters or the global filter
    changed) runs `table_autoResetPageIndex`.
  - `createGroupedRowModel` (the grouping or the pre-grouped, that is
    filtered, row model changed) runs `table_autoResetExpanded` and
    `table_autoResetPageIndex`. This is why a filter change resets the
    expanded rows even with no grouping active.
  - `createSortedRowModel` (data or the sorting changed) runs
    `table_autoResetPageIndex`.

Each `table_autoReset*` then reads `autoResetAll ?? autoResetX ?? <default>`,
where the default is `not manualPagination`, `not manualExpanding`, `False`
for sorting and `True` for cell selection.

There is no scheduler here and no table instance, so the caller applies the
whole thing in one call once it has produced the next state.

-}

import Table.Internal.CellSelection as CellSelection
import Table.Internal.Expanding as Expanding
import Table.Internal.Pagination as Pagination
import Table.Internal.Sorting as Sorting
import Table.Internal.Types exposing (Config, State)


{-| Apply every reset TanStack would schedule for one change.
-}
autoReset : Config row -> { previous : State, next : State, dataChanged : Bool } -> State
autoReset cfg change =
    let
        filtersChanged : Bool
        filtersChanged =
            (change.previous.columnFilters /= change.next.columnFilters)
                || (change.previous.globalFilter /= change.next.globalFilter)

        sortingChanged : Bool
        sortingChanged =
            change.previous.sorting /= change.next.sorting

        groupingChanged : Bool
        groupingChanged =
            change.previous.grouping /= change.next.grouping

        allows : Maybe Bool -> Bool -> Bool
        allows own byDefault =
            case cfg.autoResetAll of
                Just forced ->
                    forced

                Nothing ->
                    Maybe.withDefault byDefault own

        applyWhen : Bool -> (State -> State) -> State -> State
        applyWhen enabled reset state =
            if enabled then
                reset state

            else
                state
    in
    change.next
        |> applyWhen
            ((change.dataChanged || filtersChanged || sortingChanged || groupingChanged)
                && allows cfg.autoResetPageIndex (not cfg.manualPagination)
            )
            (Pagination.resetPageIndex cfg)
        |> applyWhen
            ((change.dataChanged || filtersChanged || groupingChanged)
                && allows cfg.autoResetExpanded (not cfg.manualExpanding)
            )
            Expanding.resetExpanded
        |> applyWhen
            (change.dataChanged && allows cfg.autoResetSorting False)
            Sorting.resetSorting
        |> applyWhen
            (change.dataChanged && allows cfg.autoResetCellSelection True)
            CellSelection.clearCellSelection
