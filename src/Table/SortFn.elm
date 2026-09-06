module Table.SortFn exposing
    ( SortFn
    , alphanumeric, alphanumericCaseSensitive, text, textCaseSensitive, datetime, basic
    , custom, withResolveDataValue
    , compare, resolveDataValue
    , splitAlphaNumeric
    )

{-| Built-in sort functions, ported from `row-sorting/sortFns.ts`.

A `SortFn` compares two cell values in ascending order. Descending order is
applied by the sorted row model. Each sort fn carries an optional
`resolveDataValue` normaliser that runs on both values before comparison,
which is how the built-ins lowercase text or turn dates into timestamps.


# Type

@docs SortFn


# Built-ins

@docs alphanumeric, alphanumericCaseSensitive, text, textCaseSensitive, datetime, basic


# Building your own

@docs custom, withResolveDataValue


# Applying

@docs compare, resolveDataValue


# Chunking

@docs splitAlphaNumeric

-}

import Table.Value as Value exposing (Value)
import Time


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
    custom compareAlphanumericValues
        |> withResolveDataValue (\value -> Value.String (String.toLower (toSortString value)))


{-| Natural sort, case-sensitive.
-}
alphanumericCaseSensitive : SortFn
alphanumericCaseSensitive =
    custom compareAlphanumericValues
        |> withResolveDataValue (\value -> Value.String (toSortString value))


{-| Plain lexicographic sort, case-insensitive.
-}
text : SortFn
text =
    custom compareBasic
        |> withResolveDataValue (\value -> Value.String (String.toLower (toSortString value)))


{-| Plain lexicographic sort, case-sensitive.
-}
textCaseSensitive : SortFn
textCaseSensitive =
    custom compareBasic
        |> withResolveDataValue (\value -> Value.String (toSortString value))


{-| Chronological sort on `Date` values (and numeric timestamps).

`Date` values become millisecond timestamps first; anything else is compared
with JavaScript's relational rules, so two strings compare as strings and
everything else compares numerically.

-}
datetime : SortFn
datetime =
    custom compareRelational
        |> withResolveDataValue toDateSortValue


{-| Direct comparison with no normalisation.
-}
basic : SortFn
basic =
    custom compareBasic


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


{-| The Elm counterpart of splitting a string with TanStack's
`reSplitAlphaNumeric` regex (`/([0-9]+)/gm`): runs of digits become their own
segments, and the empty segments JavaScript leaves at the boundaries are kept.

    splitAlphaNumeric "apple" == [ "apple" ]

    splitAlphaNumeric "item10" == [ "item", "10", "" ]

    splitAlphaNumeric "10abc" == [ "", "10", "abc" ]

    splitAlphaNumeric "" == [ "" ]

-}
splitAlphaNumeric : String -> List String
splitAlphaNumeric str =
    splitChars (String.toList str)


splitChars : List Char -> List String
splitChars chars =
    let
        ( letters, rest ) =
            span (\c -> not (Char.isDigit c)) chars
    in
    case rest of
        [] ->
            [ String.fromList letters ]

        _ ->
            let
                ( digits, remainder ) =
                    span Char.isDigit rest
            in
            String.fromList letters :: String.fromList digits :: splitChars remainder



-- VALUE COERCION


toSortString : Value -> String
toSortString value =
    case value of
        Value.Number n ->
            if isNaN n || isInfinite n then
                ""

            else
                String.fromFloat n

        Value.String s ->
            s

        _ ->
            ""


toDateSortValue : Value -> Value
toDateSortValue value =
    case value of
        Value.Date posix ->
            Value.Number (Basics.toFloat (Time.posixToMillis posix))

        _ ->
            value



-- COMPARATORS


compareBasic : Value -> Value -> Order
compareBasic a b =
    if a == b then
        EQ

    else if jsGreaterThan a b then
        GT

    else
        LT


compareRelational : Value -> Value -> Order
compareRelational a b =
    if jsGreaterThan a b then
        GT

    else if jsGreaterThan b a then
        LT

    else
        EQ


jsGreaterThan : Value -> Value -> Bool
jsGreaterThan a b =
    case ( a, b ) of
        ( Value.String sa, Value.String sb ) ->
            sa > sb

        _ ->
            let
                na : Float
                na =
                    Value.toNumber a

                nb : Float
                nb =
                    Value.toNumber b
            in
            not (isNaN na) && not (isNaN nb) && na > nb


compareAlphanumericValues : Value -> Value -> Order
compareAlphanumericValues a b =
    compareAlphanumeric (Value.toString a) (Value.toString b)


compareAlphanumeric : String -> String -> Order
compareAlphanumeric a b =
    compareChunks (chunksOf a) (chunksOf b)


type Chunk
    = Digits String
    | Letters String


chunksOf : String -> List Chunk
chunksOf str =
    chunksOfChars (String.toList str)


chunksOfChars : List Char -> List Chunk
chunksOfChars chars =
    case chars of
        [] ->
            []

        first :: _ ->
            let
                isNumeric : Bool
                isNumeric =
                    Char.isDigit first

                ( chunk, rest ) =
                    span (\c -> Char.isDigit c == isNumeric) chars

                chunkString : String
                chunkString =
                    String.fromList chunk
            in
            (if isNumeric then
                Digits chunkString

             else
                Letters chunkString
            )
                :: chunksOfChars rest


compareChunks : List Chunk -> List Chunk -> Order
compareChunks a b =
    case ( a, b ) of
        ( [], [] ) ->
            EQ

        ( [], _ ) ->
            LT

        ( _, [] ) ->
            GT

        ( x :: xs, y :: ys ) ->
            case compareChunk x y of
                EQ ->
                    compareChunks xs ys

                other ->
                    other


compareChunk : Chunk -> Chunk -> Order
compareChunk a b =
    case ( a, b ) of
        ( Letters sa, Letters sb ) ->
            Basics.compare sa sb

        ( Letters _, Digits _ ) ->
            LT

        ( Digits _, Letters _ ) ->
            GT

        ( Digits da, Digits db ) ->
            compareDigits da db


compareDigits : String -> String -> Order
compareDigits a b =
    let
        sa : String
        sa =
            stripLeadingZeros a

        sb : String
        sb =
            stripLeadingZeros b
    in
    case Basics.compare (String.length sa) (String.length sb) of
        EQ ->
            Basics.compare sa sb

        other ->
            other


stripLeadingZeros : String -> String
stripLeadingZeros str =
    if String.startsWith "0" str then
        stripLeadingZeros (String.dropLeft 1 str)

    else
        str


span : (a -> Bool) -> List a -> ( List a, List a )
span predicate list =
    case list of
        [] ->
            ( [], [] )

        first :: rest ->
            if predicate first then
                let
                    ( taken, remainder ) =
                        span predicate rest
                in
                ( first :: taken, remainder )

            else
                ( [], list )
