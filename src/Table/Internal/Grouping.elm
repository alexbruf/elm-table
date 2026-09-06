module Table.Internal.Grouping exposing (groupedRowModel)

{-| Grouping and aggregation. Phase 4 fills the body in; until then the stage
passes its input through, which is also what `manualGrouping` does.
-}

import Table.Internal.Types exposing (Config, RowModel, State)


{-| Replace the rows with one group row per distinct value of every grouped
column.
-}
groupedRowModel : Config row -> State -> RowModel row -> RowModel row
groupedRowModel =
    always (always identity)
