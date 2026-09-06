module Table.Internal.Config exposing
    ( config
    , initialState
    , rowIdFor
    , withDefaultColumn
    , withGetRowId
    , withGlobalFilterFn
    , withIsRowExpanded
    , withRowCanExpand
    , withRowSelection
    , withSubRows
    )

{-| Defaults and builders for `Config` and `State`.
-}

import Dict
import Set
import Table.FilterFn exposing (FilterFn)
import Table.Internal.Types exposing (Column, Config, Expanded(..), GroupedColumnMode(..), Row, SizeDefaults, State)
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
    , enableRowSelection = \_ -> True
    , enableMultiRowSelection = True
    , enableSubRowSelection = True
    , enableRowPinning = True
    , keepPinnedRows = True
    , enableColumnPinning = True
    , enableHiding = True
    , defaultColumn = defaultSizes
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


{-| Decide per row whether it can be selected.
-}
withRowSelection : (row -> Bool) -> Config row -> Config row
withRowSelection fn cfg =
    { cfg | enableRowSelection = fn }


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
