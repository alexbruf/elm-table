module Table.Internal.CoreRowModel exposing (coreRowModel, fromList)

{-| Ports `core/row-models/createCoreRowModel.ts`.
-}

import Array exposing (Array)
import Dict
import Table.Internal.Config as Config
import Table.Internal.Row as Row
import Table.Internal.Types exposing (Config, Row(..), RowModel, State)
import Table.Value exposing (Value(..))


{-| Build the untouched row model from the data.
-}
coreRowModel : Config row -> State -> Array row -> RowModel row
coreRowModel cfg state data =
    fromList cfg state (Array.toList data)


{-| The `List` form of [`coreRowModel`](#coreRowModel).
-}
fromList : Config row -> State -> List row -> RowModel row
fromList cfg _ data =
    let
        tree : List (Row row)
        tree =
            accessRows cfg 0 Nothing data

        flat : List (Row row)
        flat =
            Row.flattenRows tree
    in
    { rows = tree
    , flatRows = flat
    , rowsById = List.foldl (\r acc -> Dict.insert (Row.id r) r acc) Dict.empty flat
    }


accessRows : Config row -> Int -> Maybe String -> List row -> List (Row row)
accessRows cfg depth parentId originals =
    List.indexedMap (buildRow cfg depth parentId) originals


buildRow : Config row -> Int -> Maybe String -> Int -> row -> Row row
buildRow cfg depth parentId index originalRow =
    let
        rowId : String
        rowId =
            Config.rowIdFor cfg originalRow index parentId

        originalSubRows : List row
        originalSubRows =
            cfg.getSubRows originalRow
    in
    Row
        { id = rowId
        , index = index
        , depth = depth
        , original = originalRow
        , subRows = accessRows cfg (depth + 1) (Just rowId) originalSubRows
        , parentId = parentId
        , originalSubRows = originalSubRows
        , groupingColumnId = Nothing
        , groupingValue = Null
        , leafRows = []
        , aggregatedValues = Dict.empty
        }
