module Table.FilterFn exposing (equals)

{-| Built-in filter functions. Phase 1 fills this module in.

@docs equals

-}

import Table.Value exposing (Value)


{-| Placeholder structural equality. Replaced in phase 1 by the real
`equals` filter.
-}
equals : Value -> Value -> Bool
equals dataValue filterValue =
    dataValue == filterValue
