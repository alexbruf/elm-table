module Table.Internal.Faceting exposing (facetedMinMax, facetedUniqueValues)

{-| Faceting. Phase 3 fills the bodies in; until then both readers report
nothing.
-}

import Table.Internal.Types exposing (Config, RowModel, State)
import Table.Value exposing (Value)


{-| Every distinct value of one column with the number of rows that carry it.
-}
facetedUniqueValues : Config row -> State -> RowModel row -> String -> List ( Value, Int )
facetedUniqueValues =
    always (always (always (always [])))


{-| The smallest and largest numeric value of one column.
-}
facetedMinMax : Config row -> State -> RowModel row -> String -> Maybe ( Float, Float )
facetedMinMax =
    always (always (always (always Nothing)))
