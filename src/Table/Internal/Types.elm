module Table.Internal.Types exposing
    ( Cell
    , Column(..)
    , ColumnFields
    , ColumnFilter
    , ColumnPinPosition(..)
    , ColumnPinning
    , ColumnRegion(..)
    , Config
    , Expanded(..)
    , GroupedColumnMode(..)
    , Header(..)
    , HeaderFields
    , HeaderGroup
    , Pagination
    , PinRowOptions
    , PinnedColumns
    , PinnedRowsSource
    , Row(..)
    , RowFields
    , RowModel
    , RowPinPosition(..)
    , RowPinning
    , SelectOptions
    , SizeDefaults
    , SortColumn
    , SortUndefined(..)
    , State
    , SubRowSelection(..)
    )

{-| The shared types of the package. Every other module builds on these.

This module is internal: `Table` re-exports the types without their
constructors, which is what makes `Column`, `Row`, and `Header` opaque to
users of the package.

-}

import Dict exposing (Dict)
import Set exposing (Set)
import Table.AggregationFn exposing (AggregationFn)
import Table.FilterFn exposing (FilterFn)
import Table.SortFn exposing (SortFn)
import Table.Value exposing (Value)



-- COLUMNS


{-| A column definition. Opaque outside the package.
-}
type Column row
    = Column (ColumnFields row)


{-| Everything a column carries. `depth` and `parentId` are stamped by
`Table.group` when a column is nested, so they never need a table instance.
-}
type alias ColumnFields row =
    { id : String
    , accessorFn : Maybe (row -> Value)
    , columns : List (Column row)
    , depth : Int
    , parentId : Maybe String
    , header : Maybe String
    , footer : Maybe String
    , sortFn : Maybe SortFn
    , customSort : Maybe (Row row -> Row row -> Order)
    , sortDescFirst : Maybe Bool
    , invertSorting : Bool
    , sortUndefined : SortUndefined
    , enableSorting : Bool
    , enableMultiSort : Bool
    , filterFn : Maybe FilterFn
    , customFilter : Maybe (Row row -> Value -> Bool)
    , enableColumnFilter : Bool
    , enableGlobalFilter : Bool
    , aggregationFn : Maybe AggregationFn
    , getGroupingValue : Maybe (row -> Value)
    , getUniqueValues : Maybe (row -> List Value)
    , enableGrouping : Bool
    , enableHiding : Bool
    , enablePinning : Bool
    , size : Maybe Float
    , minSize : Maybe Float
    , maxSize : Maybe Float
    }


{-| Where `Null` cell values are placed by the sorted row model. Mirrors
TanStack's `sortUndefined: 'first' | 'last' | -1 | 1`.
-}
type SortUndefined
    = SortNullsFirst
    | SortNullsLast
    | SortNullsAsMinusOne
    | SortNullsAsPlusOne


{-| Mirrors TanStack's `groupedColumnMode: 'reorder' | 'remove' | false`.
-}
type GroupedColumnMode
    = GroupedColumnsReorder
    | GroupedColumnsRemove
    | GroupedColumnsIgnore



-- CONFIG


{-| The table configuration. It is a plain record so later versions can add
fields without breaking record-update call sites.
-}
type alias Config row =
    { columns : List (Column row)
    , getRowId : Maybe (row -> Int -> Maybe String -> String)
    , getSubRows : row -> List row
    , manualSorting : Bool
    , manualFiltering : Bool
    , manualGrouping : Bool
    , manualExpanding : Bool
    , manualPagination : Bool
    , enableSorting : Bool
    , enableMultiSort : Bool
    , maxMultiSortColCount : Int
    , enableSortingRemoval : Bool
    , enableMultiRemove : Bool
    , sortDescFirst : Bool
    , enableColumnFilters : Bool
    , enableGlobalFilter : Bool
    , filterFromLeafRows : Bool
    , maxLeafRowFilterDepth : Int
    , globalFilterFn : Maybe FilterFn
    , enableGrouping : Bool
    , groupedColumnMode : GroupedColumnMode
    , enableExpanding : Bool
    , paginateExpandedRows : Bool
    , enableRowSelection : Row row -> Bool
    , enableMultiRowSelection : Row row -> Bool
    , enableSubRowSelection : Row row -> Bool
    , enableRowPinning : Row row -> Bool
    , keepPinnedRows : Bool
    , enableColumnPinning : Bool
    , enableHiding : Bool
    , defaultColumn : SizeDefaults
    }


{-| The default sizing of a column, in pixels.
-}
type alias SizeDefaults =
    { size : Float
    , minSize : Float
    , maxSize : Float
    }



-- STATE


{-| Every state slice the pipeline reads. All of it is owned by the caller.
-}
type alias State =
    { sorting : List SortColumn
    , columnFilters : List ColumnFilter
    , globalFilter : Value
    , grouping : List String
    , expanded : Expanded
    , rowSelection : Set String
    , pagination : Pagination
    , columnOrder : List String
    , columnVisibility : Dict String Bool
    , columnPinning : ColumnPinning
    , columnSizing : Dict String Float
    , rowPinning : RowPinning
    }


{-| One entry of `State.sorting`.
-}
type alias SortColumn =
    { id : String
    , desc : Bool
    }


{-| One entry of `State.columnFilters`.
-}
type alias ColumnFilter =
    { id : String
    , value : Value
    }


{-| The page the paginated row model returns.
-}
type alias Pagination =
    { pageIndex : Int
    , pageSize : Int
    }


{-| Column ids pinned to either edge.
-}
type alias ColumnPinning =
    { left : List String
    , right : List String
    }


{-| Row ids pinned to the top or the bottom.
-}
type alias RowPinning =
    { top : List String
    , bottom : List String
    }


{-| Where a column is pinned. Mirrors TanStack's `'start' | 'end' | false`,
renamed to the `left` / `right` wording `State.columnPinning` uses.
-}
type ColumnPinPosition
    = PinnedLeft
    | PinnedRight
    | ColumnUnpinned


{-| Which slice of the visible leaf columns a query is about. `AllColumns`
is TanStack's absent `position` argument.
-}
type ColumnRegion
    = AllColumns
    | LeftColumns
    | CenterColumns
    | RightColumns


{-| The three column slices of a pinned table.
-}
type alias PinnedColumns row =
    { left : List (Column row)
    , center : List (Column row)
    , right : List (Column row)
    }


{-| Where a row is pinned. Mirrors TanStack's `'top' | 'bottom' | false`.
-}
type RowPinPosition
    = PinnedTop
    | PinnedBottom
    | RowUnpinned


{-| How much of a row's family `pinRow` pins along with it.
-}
type alias PinRowOptions =
    { includeLeafRows : Bool
    , includeParentRows : Bool
    }


{-| The two row models the pinned row lists read from: the model before
pagination and the model of the current page.
-}
type alias PinnedRowsSource row =
    { prePaginated : RowModel row
    , current : RowModel row
    }


{-| TanStack's `ToggleSelectedOptions`.
-}
type alias SelectOptions =
    { selectChildren : Bool
    , deselectParents : Bool
    }


{-| How much of a parent row's sub-tree is selected. Mirrors TanStack's
`isSubRowSelected` returning `false | 'some' | 'all'`.
-}
type SubRowSelection
    = NoSubRowsSelected
    | SomeSubRowsSelected
    | AllSubRowsSelected


{-| `ExpandAll` is TanStack's `expanded: true`.
-}
type Expanded
    = ExpandAll
    | ExpandedIds (Set String)



-- ROWS


{-| A row of the row model. Opaque outside the package.
-}
type Row row
    = Row (RowFields row)


{-| Everything a row carries. `groupingColumnId`, `groupingValue`,
`leafRows`, and `aggregatedValues` stay empty until the grouped row model
fills them in.
-}
type alias RowFields row =
    { id : String
    , index : Int
    , depth : Int
    , original : row
    , subRows : List (Row row)
    , parentId : Maybe String
    , originalSubRows : List row
    , groupingColumnId : Maybe String
    , groupingValue : Value
    , leafRows : List (Row row)
    , aggregatedValues : Dict String Value
    }


{-| The output of every pipeline stage.
-}
type alias RowModel row =
    { rows : List (Row row)
    , flatRows : List (Row row)
    , rowsById : Dict String (Row row)
    }


{-| One cell of one row, computed on demand.
-}
type alias Cell =
    { id : String
    , columnId : String
    , rowId : String
    , value : Value
    }



-- HEADERS


{-| A header cell. Opaque outside the package.
-}
type Header row
    = Header (HeaderFields row)


{-| Everything a header carries. Mirrors `constructHeader` in TanStack.
-}
type alias HeaderFields row =
    { id : String
    , columnId : String
    , colSpan : Int
    , rowSpan : Int
    , depth : Int
    , index : Int
    , isPlaceholder : Bool
    , placeholderId : Maybe String
    , subHeaders : List (Header row)
    }


{-| One rendered header row.
-}
type alias HeaderGroup row =
    { id : String
    , depth : Int
    , headers : List (Header row)
    }
