module Table.SortFn exposing (basic)

{-| Built-in sort functions. Phase 1 fills this module in.

@docs basic

-}

import Table.Value as Value exposing (Value)


{-| Placeholder comparison on the string form of two values. Replaced in
phase 1 by the real `basic` sort.
-}
basic : Value -> Value -> Order
basic a b =
    compare (Value.toString a) (Value.toString b)
