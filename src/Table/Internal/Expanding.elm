module Table.Internal.Expanding exposing (expandedRowModel)

{-| Expansion. Phase 4 fills the body in; until then the stage passes its
input through, which is also what `manualExpanding` does.
-}

import Table.Internal.Types exposing (Config, RowModel, State)


{-| Flatten the expanded branches of the row tree into the row list.
-}
expandedRowModel : Config row -> State -> RowModel row -> RowModel row
expandedRowModel =
    always (always identity)
