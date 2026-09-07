module Table.Internal.Config exposing
    ( config
    , defaultColumnResizing
    , initialState
    , rowIdFor
    , withAutoResetAll
    , withAutoResetCellSelection
    , withAutoResetExpanded
    , withAutoResetPageIndex
    , withAutoResetSorting
    , withCellRangeSelection
    , withCellSelection
    , withCellSelectionWhen
    , withCellSpanning
    , withDefaultColumn
    , withGetRowId
    , withGlobalFilterFn
    , withIsRowExpanded
    , withManualAggregation
    , withMultiCellRangeSelection
    , withRowCanExpand
    , withRowSelection
    , withSubRows
    )

{-| Defaults and builders for `Config` and `State`.
-}

import Dict
import Set
import Table.FilterFn exposing (FilterFn)
import Table.Internal.Types exposing (Cell, Column, ColumnResizeDirection(..), ColumnResizeMode(..), ColumnResizingState, Config, Expanded(..), GroupedColumnMode(..), Row, SizeDefaults, State)
import Table.Value exposing (Value(..))


{-| A configuration with TanStack's defaults for every flag.
-}
config : List (Column row) -> Config row
config columns =
    { columns = columns
    , getRowId = Nothing
    , getSubRows = \_ -> []
    , manualSorting = False
    , manualFiltering = False
    , manualGrouping = False
    , manualExpanding = False
    , manualPagination = False
    , enableSorting = True
    , enableMultiSort = True
    , maxMultiSortColCount = maxSafeInt
    , enableSortingRemoval = True
    , enableMultiRemove = True
    , sortDescFirst = Nothing
    , enableFilters = True
    , enableColumnFilters = True
    , enableGlobalFilter = True
    , getColumnCanGlobalFilter = Nothing
    , filterFromLeafRows = False
    , maxLeafRowFilterDepth = 100
    , globalFilterFn = Nothing
    , enableGrouping = True
    , groupedColumnMode = GroupedColumnsReorder
    , enableExpanding = True
    , getRowCanExpand = Nothing
    , getIsRowExpanded = Nothing
    , paginateExpandedRows = True
    , pageCount = Nothing
    , rowCount = Nothing
    , enableRowSelection = always True
    , enableMultiRowSelection = always True
    , enableSubRowSelection = always True
    , enableRowPinning = always True
    , keepPinnedRows = True
    , enableColumnPinning = True
    , enableHiding = True
    , defaultColumn = defaultSizes
    , enableCellSpanning = True
    , enableCellSelection = True
    , cellSelectionFilter = Nothing
    , enableCellRangeSelection = True
    , enableMultiCellRangeSelection = True
    , manualAggregation = False
    , autoResetAll = Nothing
    , autoResetPageIndex = Nothing
    , autoResetExpanded = Nothing
    , autoResetSorting = Nothing
    , autoResetCellSelection = Nothing
    , enableColumnResizing = True
    , columnResizeMode = ResizeOnEnd
    , columnResizeDirection = Ltr
    }


maxSafeInt : Int
maxSafeInt =
    9007199254740991


defaultSizes : SizeDefaults
defaultSizes =
    { size = 150
    , minSize = 20
    , maxSize = toFloat maxSafeInt
    }


{-| The state every slice starts from.
-}
initialState : State
initialState =
    { sorting = []
    , columnFilters = []
    , globalFilter = Null
    , grouping = []
    , expanded = ExpandedIds Set.empty
    , rowSelection = Set.empty
    , pagination = { pageIndex = 0, pageSize = 10 }
    , columnOrder = []
    , columnVisibility = Dict.empty
    , columnPinning = { left = [], right = [] }
    , columnSizing = Dict.empty
    , rowPinning = { top = [], bottom = [] }
    , cellSelection = []
    , columnResizing = defaultColumnResizing
    }


{-| The transient resize state of a table with no drag in progress. Ports
`getDefaultColumnResizingState`.
-}
defaultColumnResizing : ColumnResizingState
defaultColumnResizing =
    { columnSizingStart = []
    , deltaOffset = Nothing
    , deltaPercentage = Nothing
    , isResizingColumn = Nothing
    , startOffset = Nothing
    , startSize = Nothing
    }


{-| Set a custom row id function: `originalRow -> index -> parentRowId -> id`.
-}
withGetRowId : (row -> Int -> Maybe String -> String) -> Config row -> Config row
withGetRowId fn cfg =
    { cfg | getRowId = Just fn }


{-| Tell the core row model how to reach a row's children.
-}
withSubRows : (row -> List row) -> Config row -> Config row
withSubRows fn cfg =
    { cfg | getSubRows = fn }


{-| Override the default column sizing.
-}
withDefaultColumn : SizeDefaults -> Config row -> Config row
withDefaultColumn sizes cfg =
    { cfg | defaultColumn = sizes }


{-| Set the filter function used by the global filter.
-}
withGlobalFilterFn : FilterFn -> Config row -> Config row
withGlobalFilterFn fn cfg =
    { cfg | globalFilterFn = Just fn }


{-| Decide per row whether it can be expanded, overriding `enableExpanding`
and the "has sub-rows" rule.
-}
withRowCanExpand : (Row row -> Bool) -> Config row -> Config row
withRowCanExpand fn cfg =
    { cfg | getRowCanExpand = Just fn }


{-| Decide per row whether it is expanded, overriding `State.expanded`.
-}
withIsRowExpanded : (Row row -> Bool) -> Config row -> Config row
withIsRowExpanded fn cfg =
    { cfg | getIsRowExpanded = Just fn }


{-| Allow or forbid cell spanning for the whole table. `False` makes every
cell report a span of `1`. Ports the `enableCellSpanning` table option.
-}
withCellSpanning : Bool -> Config row -> Config row
withCellSpanning enabled cfg =
    { cfg | enableCellSpanning = enabled }


{-| Allow or forbid cell selection for the whole table. Ports
`enableCellSelection` in its boolean form.
-}
withCellSelection : Bool -> Config row -> Config row
withCellSelection enabled cfg =
    { cfg | enableCellSelection = enabled }


{-| Decide per cell whether it can be selected. Ports `enableCellSelection`
in its predicate form; the predicate is consulted on top of the table and
column flags.
-}
withCellSelectionWhen : (Cell -> Bool) -> Config row -> Config row
withCellSelectionWhen fn cfg =
    { cfg | cellSelectionFilter = Just fn }


{-| Allow or forbid extending a cell selection into a range. Ports
`enableCellRangeSelection`.
-}
withCellRangeSelection : Bool -> Config row -> Config row
withCellRangeSelection enabled cfg =
    { cfg | enableCellRangeSelection = enabled }


{-| Allow or forbid adding and subtracting further rectangles. Ports
`enableMultiCellRangeSelection`.
-}
withMultiCellRangeSelection : Bool -> Config row -> Config row
withMultiCellRangeSelection enabled cfg =
    { cfg | enableMultiCellRangeSelection = enabled }


{-| Decide per row whether it can be selected.
-}
withRowSelection : (Row row -> Bool) -> Config row -> Config row
withRowSelection fn cfg =
    { cfg | enableRowSelection = fn }


{-| Hand every column's aggregation value to the caller: `Table.aggregationValue`
and `Table.aggregationValueOf` return `Null` for a column with no
`withGetAggregationValue`. Ports the `manualAggregation` table option.
-}
withManualAggregation : Bool -> Config row -> Config row
withManualAggregation flag cfg =
    { cfg | manualAggregation = flag }


{-| Force every auto-reset on or off, overriding each individual flag. Ports
`autoResetAll`.
-}
withAutoResetAll : Bool -> Config row -> Config row
withAutoResetAll flag cfg =
    { cfg | autoResetAll = Just flag }


{-| Override whether `Table.autoReset` returns to page 0. The default is on
unless `manualPagination` is set. Ports `autoResetPageIndex`.
-}
withAutoResetPageIndex : Bool -> Config row -> Config row
withAutoResetPageIndex flag cfg =
    { cfg | autoResetPageIndex = Just flag }


{-| Override whether `Table.autoReset` collapses the expanded rows. The
default is on unless `manualExpanding` is set. Ports `autoResetExpanded`.
-}
withAutoResetExpanded : Bool -> Config row -> Config row
withAutoResetExpanded flag cfg =
    { cfg | autoResetExpanded = Just flag }


{-| Override whether `Table.autoReset` clears the sorting on a data change.
The default is off. Ports `autoResetSorting`.
-}
withAutoResetSorting : Bool -> Config row -> Config row
withAutoResetSorting flag cfg =
    { cfg | autoResetSorting = Just flag }


{-| Override whether `Table.autoReset` clears the cell selection on a data
change. The default is on. Ports `autoResetCellSelection`.
-}
withAutoResetCellSelection : Bool -> Config row -> Config row
withAutoResetCellSelection flag cfg =
    { cfg | autoResetCellSelection = Just flag }


{-| Resolve a row id the way `table_getRowId` does: `Config.getRowId` wins,
otherwise root rows use their index and children append theirs to the parent
id, such as `0.2`.
-}
rowIdFor : Config row -> row -> Int -> Maybe String -> String
rowIdFor cfg original index parentId =
    case cfg.getRowId of
        Just fn ->
            fn original index parentId

        Nothing ->
            case parentId of
                Just pid ->
                    pid ++ "." ++ String.fromInt index

                Nothing ->
                    String.fromInt index
