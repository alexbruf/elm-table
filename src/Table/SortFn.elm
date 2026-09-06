module Table.SortFn exposing
    ( SortFn
    , alphanumeric, alphanumericCaseSensitive, text, textCaseSensitive, datetime, basic
    , custom, withResolveDataValue
    , compare, resolveDataValue
    )

{-| Built-in sort functions, ported from `row-sorting/sortFns.ts`.

A `SortFn` compares two cell values in ascending order. Descending order is
applied by the sorted row model. Each sort fn carries an optional
`resolveDataValue` normaliser that runs on both values before comparison,
which is how the built-ins lowercase text or turn dates into timestamps.

Phase 1 replaces the placeholder bodies below.


# Type

@docs SortFn


# Built-ins

@docs alphanumeric, alphanumericCaseSensitive, text, textCaseSensitive, datetime, basic


# Building your own

@docs custom, withResolveDataValue


# Applying

@docs compare, resolveDataValue

-}

import Table.Value as Value exposing (Value)


{-| An ascending comparison on cell values plus its value normaliser.
-}
type SortFn
    = SortFn
        { resolveDataValue : Value -> Value
        , sort : Value -> Value -> Order
        }


{-| Natural sort, case-insensitive: `item2` before `item10`.
-}
alphanumeric : SortFn
alphanumeric =
    placeholder


{-| Natural sort, case-sensitive.
-}
alphanumericCaseSensitive : SortFn
alphanumericCaseSensitive =
    placeholder


{-| Plain lexicographic sort, case-insensitive.
-}
text : SortFn
text =
    placeholder


{-| Plain lexicographic sort, case-sensitive.
-}
textCaseSensitive : SortFn
textCaseSensitive =
    placeholder


{-| Chronological sort on `Date` values (and numeric timestamps).
-}
datetime : SortFn
datetime =
    placeholder


{-| Direct comparison with no normalisation.
-}
basic : SortFn
basic =
    placeholder


{-| Build a sort fn from a comparison. Use [`withResolveDataValue`](#withResolveDataValue)
to add a normaliser.
-}
custom : (Value -> Value -> Order) -> SortFn
custom sort =
    SortFn { resolveDataValue = identity, sort = sort }


{-| Replace the normaliser that runs on both values before comparison.
-}
withResolveDataValue : (Value -> Value) -> SortFn -> SortFn
withResolveDataValue resolver (SortFn def) =
    SortFn { def | resolveDataValue = resolver }


{-| Compare two raw cell values: both are passed through the normaliser, then
the comparison runs.
-}
compare : SortFn -> Value -> Value -> Order
compare (SortFn def) a b =
    def.sort (def.resolveDataValue a) (def.resolveDataValue b)


{-| Run only the normaliser.
-}
resolveDataValue : SortFn -> Value -> Value
resolveDataValue (SortFn def) =
    def.resolveDataValue


placeholder : SortFn
placeholder =
    custom (\a b -> Basics.compare (Value.toString a) (Value.toString b))
