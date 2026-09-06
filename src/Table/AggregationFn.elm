module Table.AggregationFn exposing (count)

{-| Built-in aggregation functions. Phase 1 fills this module in.

@docs count

-}

import Table.Value exposing (Value(..))


{-| Placeholder row count. Replaced in phase 1 by the real `count`
aggregation.
-}
count : List Value -> Value
count values =
    Number (toFloat (List.length values))
