module Table.FilterFn exposing
    ( FilterFn
    , equals, weakEquals
    , includesString, includesStringSensitive, equalsString, equalsStringSensitive, startsWith, endsWith
    , empty, notEmpty
    , greaterThan, greaterThanOrEqualTo, lessThan, lessThanOrEqualTo
    , between, betweenInclusive, inNumberRange, inDateRange
    , arrHas, arrIncludes, arrIncludesAll, arrIncludesSome
    , custom, withResolveFilterValue, withResolveDataValue, withAutoRemove
    , filter, resolveFilterValue, resolveDataValue, autoRemove
    , toDateTimestamp
    )

{-| Built-in filter functions, ported from `column-filtering/filterFns.ts`.

A `FilterFn` is a comparison between a cell value and a filter value plus
three helpers that TanStack attaches to every filter fn:

  - `resolveFilterValue` normalises the filter value once per filter before
    any row is tested (the table does this, not [`filter`](#filter)).
  - `resolveDataValue` normalises the cell value before comparison
    ([`filter`](#filter) does this).
  - `autoRemove` says when a filter value is blank enough that the filter
    should be dropped from state.


# Type

@docs FilterFn


# Basic

@docs equals, weakEquals


# Strings

@docs includesString, includesStringSensitive, equalsString, equalsStringSensitive, startsWith, endsWith


# Blank

@docs empty, notEmpty


# Numbers

@docs greaterThan, greaterThanOrEqualTo, lessThan, lessThanOrEqualTo


# Ranges

@docs between, betweenInclusive, inNumberRange, inDateRange


# Arrays

@docs arrHas, arrIncludes, arrIncludesAll, arrIncludesSome


# Building your own

@docs custom, withResolveFilterValue, withResolveDataValue, withAutoRemove


# Applying

@docs filter, resolveFilterValue, resolveDataValue, autoRemove


# Dates

@docs toDateTimestamp

-}

import Table.Value as Value exposing (Value)
import Time


{-| A filter comparison with its resolvers.
-}
type FilterFn
    = FilterFn
        { filter : Value -> Value -> Bool
        , resolveFilterValue : Value -> Value
        , resolveDataValue : Value -> Value
        , autoRemove : Value -> Bool
        }


{-| Strict equality.
-}
equals : FilterFn
equals =
    custom (==)


{-| Loose equality (`"1" == 1`).
-}
weakEquals : FilterFn
weakEquals =
    custom looseEquals


{-| Case-insensitive substring match.
-}
includesString : FilterFn
includesString =
    custom includesFilterValue
        |> withResolveFilterValue toLowerString
        |> withResolveDataValue toLowerStringOrNull


{-| Case-sensitive substring match.
-}
includesStringSensitive : FilterFn
includesStringSensitive =
    custom includesFilterValue
        |> withResolveFilterValue toPlainString
        |> withResolveDataValue toPlainStringOrNull


{-| Case-insensitive string equality.
-}
equalsString : FilterFn
equalsString =
    custom (==)
        |> withResolveFilterValue toLowerString
        |> withResolveDataValue toLowerStringOrNull


{-| Case-sensitive string equality.
-}
equalsStringSensitive : FilterFn
equalsStringSensitive =
    custom (==)
        |> withResolveFilterValue toPlainString
        |> withResolveDataValue toPlainStringOrNull


{-| Case-insensitive prefix match.
-}
startsWith : FilterFn
startsWith =
    custom (matchesAffix String.startsWith)
        |> withResolveFilterValue toLowerString
        |> withResolveDataValue toLowerStringOrNull


{-| Case-insensitive suffix match.
-}
endsWith : FilterFn
endsWith =
    custom (matchesAffix String.endsWith)
        |> withResolveFilterValue toLowerString
        |> withResolveDataValue toLowerStringOrNull


{-| Keeps blank cells. The filter value is only an on/off flag.
-}
empty : FilterFn
empty =
    custom (\dataValue _ -> isValueEmpty dataValue)
        |> withAutoRemove flagAutoRemove


{-| Keeps non-blank cells. The filter value is only an on/off flag.
-}
notEmpty : FilterFn
notEmpty =
    custom (\dataValue _ -> not (isValueEmpty dataValue))
        |> withAutoRemove flagAutoRemove


{-| Numeric when both sides parse as numbers, string comparison otherwise.
-}
greaterThan : FilterFn
greaterThan =
    custom compareGreaterThan


{-| See [`greaterThan`](#greaterThan).
-}
greaterThanOrEqualTo : FilterFn
greaterThanOrEqualTo =
    custom compareGreaterThanOrEqualTo


{-| See [`greaterThan`](#greaterThan).
-}
lessThan : FilterFn
lessThan =
    custom (\dataValue filterValue -> not (compareGreaterThanOrEqualTo dataValue filterValue))


{-| See [`greaterThan`](#greaterThan).
-}
lessThanOrEqualTo : FilterFn
lessThanOrEqualTo =
    custom (\dataValue filterValue -> not (compareGreaterThan dataValue filterValue))


{-| Exclusive range; the filter value is `List [ min, max ]`.
-}
between : FilterFn
between =
    custom (\dataValue filterValue -> compareBetween dataValue filterValue False)
        |> withAutoRemove rangeAutoRemove


{-| Inclusive range; the filter value is `List [ min, max ]`.
-}
betweenInclusive : FilterFn
betweenInclusive =
    custom (\dataValue filterValue -> compareBetween dataValue filterValue True)
        |> withAutoRemove rangeAutoRemove


{-| Inclusive numeric range; only `Number` cells can match.
-}
inNumberRange : FilterFn
inNumberRange =
    custom inNumberRangeFilter
        |> withResolveFilterValue resolveNumberRange
        |> withAutoRemove rangeAutoRemove


{-| Inclusive date range on `Date` cells (or timestamps, or `YYYY-MM-DD`
strings).
-}
inDateRange : FilterFn
inDateRange =
    custom inDateRangeFilter
        |> withResolveFilterValue resolveDateRange
        |> withResolveDataValue (\value -> Value.Number (toDateTimestamp value))
        |> withAutoRemove rangeAutoRemove


{-| Scalar cell equals at least one of the filter values.
-}
arrHas : FilterFn
arrHas =
    custom (\dataValue filterValue -> List.member dataValue (itemsOf filterValue))
        |> withAutoRemove arrayAutoRemove


{-| `List` or `String` cell includes at least one filter value.
-}
arrIncludes : FilterFn
arrIncludes =
    custom arrIncludesFilter
        |> withAutoRemove arrayAutoRemove


{-| `List` cell includes every filter value.
-}
arrIncludesAll : FilterFn
arrIncludesAll =
    custom (listFilter List.all)
        |> withAutoRemove arrayAutoRemove


{-| `List` cell includes at least one filter value.
-}
arrIncludesSome : FilterFn
arrIncludesSome =
    custom (listFilter List.any)
        |> withAutoRemove arrayAutoRemove


{-| Build a filter fn from a comparison. Resolvers default to `identity`
and `autoRemove` defaults to removing `Null` and the empty string.
-}
custom : (Value -> Value -> Bool) -> FilterFn
custom fn =
    FilterFn
        { filter = fn
        , resolveFilterValue = identity
        , resolveDataValue = identity
        , autoRemove = isFalsy
        }


{-| Replace the filter-value normaliser.
-}
withResolveFilterValue : (Value -> Value) -> FilterFn -> FilterFn
withResolveFilterValue resolver (FilterFn def) =
    FilterFn { def | resolveFilterValue = resolver }


{-| Replace the cell-value normaliser.
-}
withResolveDataValue : (Value -> Value) -> FilterFn -> FilterFn
withResolveDataValue resolver (FilterFn def) =
    FilterFn { def | resolveDataValue = resolver }


{-| Replace the auto-remove predicate.
-}
withAutoRemove : (Value -> Bool) -> FilterFn -> FilterFn
withAutoRemove predicate (FilterFn def) =
    FilterFn { def | autoRemove = predicate }


{-| Test a raw cell value against an already resolved filter value. The
cell value is passed through `resolveDataValue` first; the filter value is
not (resolve it once with [`resolveFilterValue`](#resolveFilterValue)).
-}
filter : FilterFn -> Value -> Value -> Bool
filter (FilterFn def) dataValue filterValue =
    def.filter (def.resolveDataValue dataValue) filterValue


{-| Normalise a filter value.
-}
resolveFilterValue : FilterFn -> Value -> Value
resolveFilterValue (FilterFn def) =
    def.resolveFilterValue


{-| Normalise a cell value.
-}
resolveDataValue : FilterFn -> Value -> Value
resolveDataValue (FilterFn def) =
    def.resolveDataValue


{-| Should this filter value cause the filter to be dropped?
-}
autoRemove : FilterFn -> Value -> Bool
autoRemove (FilterFn def) =
    def.autoRemove


{-| `toDateTimestamp` from `filterFns.ts`: a `Date` gives its milliseconds,
a `Number` passes through, and everything else that is not a parseable date
string gives `NaN`, which never falls inside a range.

Elm has no `new Date(string)`, so the string form is limited to ISO 8601
`YYYY-MM-DD`, optionally followed by `THH:MM`, `THH:MM:SS` and a `Z`.

-}
toDateTimestamp : Value -> Float
toDateTimestamp value =
    case value of
        Value.Date posix ->
            Basics.toFloat (Time.posixToMillis posix)

        Value.Number n ->
            n

        Value.String s ->
            if String.trim s == "" then
                notANumber

            else
                parseIsoDate s

        _ ->
            notANumber



-- VALUE COERCION


notANumber : Float
notANumber =
    0 / 0


toPlainString : Value -> Value
toPlainString value =
    Value.String (Value.toString value)


toLowerString : Value -> Value
toLowerString value =
    Value.String (String.toLower (Value.toString value))


toPlainStringOrNull : Value -> Value
toPlainStringOrNull value =
    if Value.isNull value then
        Value.Null

    else
        toPlainString value


toLowerStringOrNull : Value -> Value
toLowerStringOrNull value =
    if Value.isNull value then
        Value.Null

    else
        toLowerString value


isFalsy : Value -> Bool
isFalsy value =
    case value of
        Value.Null ->
            True

        Value.String "" ->
            True

        _ ->
            False


flagAutoRemove : Value -> Bool
flagAutoRemove value =
    isFalsy value || value == Value.Bool False


isValueEmpty : Value -> Bool
isValueEmpty value =
    Value.isNull value || String.trim (Value.toString value) == ""



-- STRING FILTERS


includesFilterValue : Value -> Value -> Bool
includesFilterValue dataValue filterValue =
    case dataValue of
        Value.String s ->
            String.contains (Value.toString filterValue) s

        _ ->
            False


matchesAffix : (String -> String -> Bool) -> Value -> Value -> Bool
matchesAffix affix dataValue filterValue =
    case dataValue of
        Value.String s ->
            affix (Value.toString filterValue) s

        _ ->
            False



-- EQUALITY


{-| JavaScript's `==` over `Value`: `Null` (both `null` and `undefined`) only
equals `Null`, same-kind values compare structurally, and a mixed pair falls
back to numeric coercion.
-}
looseEquals : Value -> Value -> Bool
looseEquals a b =
    case ( a, b ) of
        ( Value.Null, Value.Null ) ->
            True

        ( Value.Null, _ ) ->
            False

        ( _, Value.Null ) ->
            False

        ( Value.String sa, Value.String sb ) ->
            sa == sb

        ( Value.Bool ba, Value.Bool bb ) ->
            ba == bb

        ( Value.List _, Value.List _ ) ->
            a == b

        ( Value.Date _, Value.Date _ ) ->
            a == b

        _ ->
            let
                na : Float
                na =
                    Value.toNumber a
            in
            not (isNaN na) && na == Value.toNumber b



-- COMPARISON FILTERS


compareGreaterThan : Value -> Value -> Bool
compareGreaterThan dataValue filterValue =
    let
        numericDataValue : Float
        numericDataValue =
            if Value.isNull dataValue then
                0

            else
                Value.toNumber dataValue

        numericFilterValue : Float
        numericFilterValue =
            Value.toNumber filterValue
    in
    if not (isNaN numericFilterValue) && not (isNaN numericDataValue) then
        numericDataValue > numericFilterValue

    else
        normalizeForCompare dataValue > normalizeForCompare filterValue


compareGreaterThanOrEqualTo : Value -> Value -> Bool
compareGreaterThanOrEqualTo dataValue filterValue =
    dataValue == filterValue || compareGreaterThan dataValue filterValue


normalizeForCompare : Value -> String
normalizeForCompare value =
    String.trim (String.toLower (Value.toString value))



-- RANGE FILTERS


rangeItem : Int -> Value -> Value
rangeItem index value =
    case value of
        Value.List items ->
            List.drop index items
                |> List.head
                |> Maybe.withDefault Value.Null

        _ ->
            Value.Null


compareBetween : Value -> Value -> Bool -> Bool
compareBetween dataValue filterValue inclusive =
    let
        minValue : Value
        minValue =
            rangeItem 0 filterValue

        hasMin : Bool
        hasMin =
            not (isFalsy minValue)

        passesMin : Bool
        passesMin =
            if inclusive then
                compareGreaterThanOrEqualTo dataValue minValue

            else
                compareGreaterThan dataValue minValue
    in
    if hasMin && not passesMin then
        False

    else
        let
            maxValue : Value
            maxValue =
                rangeItem 1 filterValue
        in
        if isFalsy maxValue then
            True

        else if hasMin && isReversedNumericRange minValue maxValue then
            True

        else if inclusive then
            not (compareGreaterThan dataValue maxValue)

        else
            not (compareGreaterThanOrEqualTo dataValue maxValue)


isReversedNumericRange : Value -> Value -> Bool
isReversedNumericRange minValue maxValue =
    let
        numericMin : Float
        numericMin =
            Value.toNumber minValue

        numericMax : Float
        numericMax =
            Value.toNumber maxValue
    in
    not (isNaN numericMin) && not (isNaN numericMax) && numericMin > numericMax


rangeAutoRemove : Value -> Bool
rangeAutoRemove value =
    case value of
        Value.List _ ->
            isFalsy (rangeItem 0 value) && isFalsy (rangeItem 1 value)

        _ ->
            isFalsy value


inNumberRangeFilter : Value -> Value -> Bool
inNumberRangeFilter dataValue filterValue =
    case ( dataValue, filterValue ) of
        ( Value.Number n, Value.List _ ) ->
            not (isNaN n)
                && (n >= Value.toNumber (rangeItem 0 filterValue))
                && (n <= Value.toNumber (rangeItem 1 filterValue))

        _ ->
            False


resolveNumberRange : Value -> Value
resolveNumberRange value =
    orderedRange
        (parseRangeEndpoint (rangeItem 0 value) (-1 / 0))
        (parseRangeEndpoint (rangeItem 1 value) (1 / 0))


parseRangeEndpoint : Value -> Float -> Float
parseRangeEndpoint value fallback =
    let
        parsed : Float
        parsed =
            case value of
                Value.Number n ->
                    n

                Value.String s ->
                    Maybe.withDefault notANumber (String.toFloat (String.trim s))

                _ ->
                    notANumber
    in
    if isNaN parsed then
        fallback

    else
        parsed


inDateRangeFilter : Value -> Value -> Bool
inDateRangeFilter dataValue filterValue =
    let
        timestamp : Float
        timestamp =
            Value.toNumber dataValue
    in
    (timestamp >= Value.toNumber (rangeItem 0 filterValue))
        && (timestamp <= Value.toNumber (rangeItem 1 filterValue))


resolveDateRange : Value -> Value
resolveDateRange value =
    orderedRange
        (orInfinity (toDateTimestamp (rangeItem 0 value)) (-1 / 0))
        (orInfinity (toDateTimestamp (rangeItem 1 value)) (1 / 0))


orInfinity : Float -> Float -> Float
orInfinity n fallback =
    if isNaN n then
        fallback

    else
        n


orderedRange : Float -> Float -> Value
orderedRange low high =
    if low > high then
        Value.List [ Value.Number high, Value.Number low ]

    else
        Value.List [ Value.Number low, Value.Number high ]



-- ARRAY FILTERS


itemsOf : Value -> List Value
itemsOf value =
    case value of
        Value.List items ->
            items

        _ ->
            []


arrIncludesFilter : Value -> Value -> Bool
arrIncludesFilter dataValue filterValue =
    case dataValue of
        Value.String s ->
            List.any (\item -> String.contains (Value.toString item) s) (itemsOf filterValue)

        Value.List items ->
            List.any (\item -> List.member item items) (itemsOf filterValue)

        _ ->
            False


listFilter : ((Value -> Bool) -> List Value -> Bool) -> Value -> Value -> Bool
listFilter quantifier dataValue filterValue =
    case dataValue of
        Value.List items ->
            quantifier (\item -> List.member item items) (itemsOf filterValue)

        _ ->
            False


arrayAutoRemove : Value -> Bool
arrayAutoRemove value =
    isFalsy value || lengthOf value == 0


lengthOf : Value -> Int
lengthOf value =
    case value of
        Value.List items ->
            List.length items

        Value.String s ->
            String.length s

        _ ->
            0



-- ISO 8601 DATES


parseIsoDate : String -> Float
parseIsoDate raw =
    case String.split "T" (String.trim raw) of
        [ datePart ] ->
            dateMillis datePart 0

        [ datePart, timePart ] ->
            case parseTimeOfDay timePart of
                Just offset ->
                    dateMillis datePart offset

                Nothing ->
                    notANumber

        _ ->
            notANumber


dateMillis : String -> Float -> Float
dateMillis datePart offset =
    case List.map String.toInt (String.split "-" datePart) of
        [ Just year, Just month, Just day ] ->
            if month >= 1 && month <= 12 && day >= 1 && day <= 31 then
                Basics.toFloat (daysFromCivil year month day) * 86400000 + offset

            else
                notANumber

        _ ->
            notANumber


parseTimeOfDay : String -> Maybe Float
parseTimeOfDay raw =
    let
        trimmed : String
        trimmed =
            if String.endsWith "Z" raw then
                String.dropRight 1 raw

            else
                raw
    in
    case List.map String.toFloat (String.split ":" trimmed) of
        [ Just hours, Just minutes ] ->
            Just ((hours * 3600 + minutes * 60) * 1000)

        [ Just hours, Just minutes, Just seconds ] ->
            Just ((hours * 3600 + minutes * 60 + seconds) * 1000)

        _ ->
            Nothing


{-| Days since 1970-01-01, by Howard Hinnant's `days_from_civil`.
-}
daysFromCivil : Int -> Int -> Int -> Int
daysFromCivil year month day =
    let
        shiftedYear : Int
        shiftedYear =
            if month <= 2 then
                year - 1

            else
                year

        era : Int
        era =
            if shiftedYear >= 0 then
                shiftedYear // 400

            else
                (shiftedYear - 399) // 400

        yearOfEra : Int
        yearOfEra =
            shiftedYear - era * 400

        shiftedMonth : Int
        shiftedMonth =
            if month > 2 then
                month - 3

            else
                month + 9

        dayOfYear : Int
        dayOfYear =
            (153 * shiftedMonth + 2) // 5 + day - 1

        dayOfEra : Int
        dayOfEra =
            yearOfEra * 365 + yearOfEra // 4 - yearOfEra // 100 + dayOfYear
    in
    era * 146097 + dayOfEra - 719468
