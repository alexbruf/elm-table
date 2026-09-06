module Table.Internal.Pagination exposing (paginatedRowModel)

{-| Pagination. Phase 3 fills the body in; until then the stage passes its
input through, which is also what `manualPagination` does.
-}

import Table.Internal.Types exposing (Config, RowModel, State)


{-| Keep only the rows of the current page.
-}
paginatedRowModel : Config row -> State -> RowModel row -> RowModel row
paginatedRowModel =
    always (always identity)
