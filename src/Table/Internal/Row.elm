module Table.Internal.Row exposing
    ( aggregatedValues
    , depth
    , findRow
    , flattenRows
    , getAllCells
    , getLeafRows
    , getParentRow
    , getParentRows
    , getUniqueValues
    , getValue
    , groupingColumnId
    , groupingValue
    , id
    , index
    , leafRows
    , maxSubRowDepth
    , original
    , originalSubRows
    , parentId
    , subRows
    )

{-| Row accessors and the row helpers of `core/rows/coreRowsFeature.utils.ts`.
-}

import Dict exposing (Dict)
import Table.Internal.Column as Column
import Table.Internal.Types exposing (Cell, Column, Config, Row(..), RowModel, State)
import Table.Value exposing (Value(..))


{-| The row id.
-}
id : Row row -> String
id (Row f) =
    f.id


{-| The row's index among its siblings.
-}
index : Row row -> Int
index (Row f) =
    f.index


{-| How deep the row sits in the row tree. Root rows are `0`.
-}
depth : Row row -> Int
depth (Row f) =
    f.depth


{-| The original datum this row was built from.
-}
original : Row row -> row
original (Row f) =
    f.original


{-| The row's children.
-}
subRows : Row row -> List (Row row)
subRows (Row f) =
    f.subRows


{-| The id of the row's parent, when it has one.
-}
parentId : Row row -> Maybe String
parentId (Row f) =
    f.parentId


{-| The raw children `Config.getSubRows` returned for this row.
-}
originalSubRows : Row row -> List row
originalSubRows (Row f) =
    f.originalSubRows


{-| The column a group row groups by, when the row is a group row.
-}
groupingColumnId : Row row -> Maybe String
groupingColumnId (Row f) =
    f.groupingColumnId


{-| The value a group row groups by.
-}
groupingValue : Row row -> Value
groupingValue (Row f) =
    f.groupingValue


{-| The leaf rows a group row was built from. Empty for ordinary rows.
-}
leafRows : Row row -> List (Row row)
leafRows (Row f) =
    f.leafRows


{-| The aggregated values of a group row, keyed by column id.
-}
aggregatedValues : Row row -> Dict String Value
aggregatedValues (Row f) =
    f.aggregatedValues


{-| Read one cell value. Aggregated values win, then the column accessor.
Unknown columns and columns without an accessor give `Null`.
-}
getValue : Config row -> Row row -> String -> Value
getValue cfg (Row f) columnId =
    case Dict.get columnId f.aggregatedValues of
        Just value ->
            value

        Nothing ->
            case Maybe.andThen Column.accessorFn (Column.findColumn cfg columnId) of
                Just accessor ->
                    accessor f.original

                Nothing ->
                    Null


{-| The values faceting and grouping use for one cell. A column with
`withGetUniqueValues` decides them; otherwise the cell value is wrapped in a
one-item list.
-}
getUniqueValues : Config row -> Row row -> String -> List Value
getUniqueValues cfg (Row f) columnId =
    case Column.findColumn cfg columnId of
        Nothing ->
            []

        Just col ->
            case Column.accessorFn col of
                Nothing ->
                    []

                Just _ ->
                    case (Column.fields col).getUniqueValues of
                        Just fn ->
                            fn f.original

                        Nothing ->
                            [ getValue cfg (Row f) columnId ]


{-| Every descendant of a row, depth first. The row itself is not included.
-}
getLeafRows : Row row -> List (Row row)
getLeafRows (Row f) =
    flattenRows f.subRows


{-| Flatten a row tree depth first, parents before their children.
-}
flattenRows : List (Row row) -> List (Row row)
flattenRows rows =
    flattenHelp rows [] |> List.reverse


flattenHelp : List (Row row) -> List (Row row) -> List (Row row)
flattenHelp queue acc =
    case queue of
        [] ->
            acc

        (Row f) :: rest ->
            flattenHelp (f.subRows ++ rest) (Row f :: acc)


{-| Look a row up by id.
-}
findRow : RowModel row -> String -> Maybe (Row row)
findRow model rowId =
    Dict.get rowId model.rowsById


{-| The direct parent of a row, looked up in a row model.
-}
getParentRow : RowModel row -> Row row -> Maybe (Row row)
getParentRow model (Row f) =
    Maybe.andThen (findRow model) f.parentId


{-| The ancestors of a row, from the root down to its direct parent.
-}
getParentRows : RowModel row -> Row row -> List (Row row)
getParentRows model row =
    parentsHelp model row []


parentsHelp : RowModel row -> Row row -> List (Row row) -> List (Row row)
parentsHelp model row acc =
    case getParentRow model row of
        Nothing ->
            acc

        Just parent ->
            parentsHelp model parent (parent :: acc)


{-| One cell per leaf column, in leaf column order. Hidden columns are
included, exactly like TanStack's `row.getAllCells()`.
-}
getAllCells : Config row -> State -> Row row -> List Cell
getAllCells cfg state row =
    Column.orderedLeafColumns cfg state
        |> List.map (toCell cfg row)


toCell : Config row -> Row row -> Column row -> Cell
toCell cfg row col =
    let
        columnId : String
        columnId =
            Column.id col
    in
    { id = id row ++ "_" ++ columnId
    , columnId = columnId
    , rowId = id row
    , value = getValue cfg row columnId
    }


{-| The deepest row depth in a row model.
-}
maxSubRowDepth : RowModel row -> Int
maxSubRowDepth model =
    List.foldl (\r acc -> Basics.max acc (depth r)) 0 model.flatRows
