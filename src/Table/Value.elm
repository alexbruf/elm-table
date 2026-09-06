module Table.Value exposing
    ( Value(..)
    , toString, isNull
    )

{-| The one union type for cell values.

Column accessors return a `Value`. Built-in sort, filter, and aggregation
functions operate on `Value`. Custom sort and filter functions receive the
original `row` instead, so users are never forced through `Value` for their
own logic.

`Null` stands in for both JavaScript `null` and `undefined`. `List` is the
Elm counterpart of a JavaScript array cell value and exists so the array
filter functions (`arrIncludes`, `arrIncludesAll`, `arrIncludesSome`) and
the `extent` / `unique` aggregations can be expressed faithfully.


# Type

@docs Value


# Helpers

@docs toString, isNull

-}

import Time


{-| A cell value.
-}
type Value
    = String String
    | Number Float
    | Bool Bool
    | Date Time.Posix
    | List (List Value)
    | Null


{-| Coerce a value to a string the way JavaScript's `String(x)` does, except
that `Null` becomes the empty string (TanStack writes `String(x ?? '')` at
every call site that matters).

    toString (Number 1) == "1"

    toString (Number 1.5) == "1.5"

    toString (Bool True) == "true"

    toString Null == ""

-}
toString : Value -> String
toString value =
    case value of
        String s ->
            s

        Number n ->
            String.fromFloat n

        Bool True ->
            "true"

        Bool False ->
            "false"

        Date posix ->
            String.fromInt (Time.posixToMillis posix)

        List items ->
            String.join "," (List.map toString items)

        Null ->
            ""


{-| `True` only for `Null`.
-}
isNull : Value -> Bool
isNull value =
    case value of
        Null ->
            True

        _ ->
            False
