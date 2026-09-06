module Table.Internal.Filtering exposing (filteredRowModel)

{-| Column and global filtering. Phase 3 fills the body in; until then the
stage passes its input through, which is also what `manualFiltering` does.
-}

import Table.Internal.Types exposing (Config, RowModel, State)


{-| Drop the rows that fail the column filters and the global filter.
-}
filteredRowModel : Config row -> State -> RowModel row -> RowModel row
filteredRowModel =
    always (always identity)
