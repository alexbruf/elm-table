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

Phase 1 replaces the placeholder bodies below.


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

-}

import Table.Value exposing (Value)


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
    placeholder


{-| Loose equality (`"1" == 1`).
-}
weakEquals : FilterFn
weakEquals =
    placeholder


{-| Case-insensitive substring match.
-}
includesString : FilterFn
includesString =
    placeholder


{-| Case-sensitive substring match.
-}
includesStringSensitive : FilterFn
includesStringSensitive =
    placeholder


{-| Case-insensitive string equality.
-}
equalsString : FilterFn
equalsString =
    placeholder


{-| Case-sensitive string equality.
-}
equalsStringSensitive : FilterFn
equalsStringSensitive =
    placeholder


{-| Case-insensitive prefix match.
-}
startsWith : FilterFn
startsWith =
    placeholder


{-| Case-insensitive suffix match.
-}
endsWith : FilterFn
endsWith =
    placeholder


{-| Keeps blank cells.
-}
empty : FilterFn
empty =
    placeholder


{-| Keeps non-blank cells.
-}
notEmpty : FilterFn
notEmpty =
    placeholder


{-| Numeric when both sides parse as numbers, string comparison otherwise.
-}
greaterThan : FilterFn
greaterThan =
    placeholder


{-| See [`greaterThan`](#greaterThan).
-}
greaterThanOrEqualTo : FilterFn
greaterThanOrEqualTo =
    placeholder


{-| See [`greaterThan`](#greaterThan).
-}
lessThan : FilterFn
lessThan =
    placeholder


{-| See [`greaterThan`](#greaterThan).
-}
lessThanOrEqualTo : FilterFn
lessThanOrEqualTo =
    placeholder


{-| Exclusive range; the filter value is `List [ min, max ]`.
-}
between : FilterFn
between =
    placeholder


{-| Inclusive range; the filter value is `List [ min, max ]`.
-}
betweenInclusive : FilterFn
betweenInclusive =
    placeholder


{-| Inclusive numeric range; only `Number` cells can match.
-}
inNumberRange : FilterFn
inNumberRange =
    placeholder


{-| Inclusive date range on `Date` cells (or timestamps).
-}
inDateRange : FilterFn
inDateRange =
    placeholder


{-| Scalar cell equals at least one of the filter values.
-}
arrHas : FilterFn
arrHas =
    placeholder


{-| `List` or `String` cell includes at least one filter value.
-}
arrIncludes : FilterFn
arrIncludes =
    placeholder


{-| `List` cell includes every filter value.
-}
arrIncludesAll : FilterFn
arrIncludesAll =
    placeholder


{-| `List` cell includes at least one filter value.
-}
arrIncludesSome : FilterFn
arrIncludesSome =
    placeholder


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


placeholder : FilterFn
placeholder =
    custom (==)


isFalsy : Value -> Bool
isFalsy value =
    case value of
        Table.Value.Null ->
            True

        Table.Value.String "" ->
            True

        _ ->
            False
