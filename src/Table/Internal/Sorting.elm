module Table.Internal.Sorting exposing (sortedRowModel)

{-| Sorting. Phase 3 fills the body in; until then the stage passes its input
through, which is also what `manualSorting` does.
-}

import Table.Internal.Types exposing (Config, RowModel, State)


{-| Sort every level of the row tree by `State.sorting`.
-}
sortedRowModel : Config row -> State -> RowModel row -> RowModel row
sortedRowModel =
    always (always identity)
