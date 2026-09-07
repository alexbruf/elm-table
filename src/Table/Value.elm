module Table.Value exposing
    ( Value(..)
    , toString, toNumber, isNull
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

@docs toString, toNumber, isNull

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


{-| Coerce a value to a number the way JavaScript's `Number(x)` does.

    toNumber (Number 29) == 29

    toNumber (String "29") == 29

    toNumber (String "") == 0

    toNumber (Bool True) == 1

    toNumber Null == 0

A value that does not coerce, such as `String "abc"`, gives `NaN`, which
compares `False` against everything just as it does in JavaScript. A `Date`
coerces to its millisecond timestamp and a one-element `List` coerces to its
element, both matching `Number(x)`.

-}
toNumber : Value -> Float
toNumber value =
    case value of
        Number n ->
            n

        String s ->
            stringToNumber s

        Bool True ->
            1

        Bool False ->
            0

        Date posix ->
            Basics.toFloat (Time.posixToMillis posix)

        List [] ->
            0

        List [ item ] ->
            toNumber item

        List _ ->
            notANumber

        Null ->
            0


notANumber : Float
notANumber =
    0 / 0


stringToNumber : String -> Float
stringToNumber raw =
    let
        trimmed : String
        trimmed =
            String.trim raw
    in
    if trimmed == "" then
        0

    else
        case String.toFloat trimmed of
            Just n ->
                n

            Nothing ->
                notANumber


{-| `True` only for `Null`.
-}
isNull : Value -> Bool
isNull value =
    case value of
        Null ->
            True

        _ ->
            False
