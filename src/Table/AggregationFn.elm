module Table.AggregationFn exposing
    ( AggregationFn
    , sum, min, max, extent, mean, median, unique, uniqueCount, count, first, last
    , custom, withMerge
    , aggregate, merge
    )

{-| Built-in aggregation functions, ported from
`row-aggregation/aggregationFns.ts`.

An `AggregationFn` folds the values of a column over a group's leaf rows.
Some also know how to `merge` the results of child groups, which lets nested
groups avoid re-reading every leaf.


# Type

@docs AggregationFn


# Built-ins

@docs sum, min, max, extent, mean, median, unique, uniqueCount, count, first, last


# Building your own

@docs custom, withMerge


# Applying

@docs aggregate, merge

-}

import Table.Value as Value exposing (Value(..))
import Time


{-| A fold over leaf values plus an optional merge of child results.
-}
type AggregationFn
    = AggregationFn
        { aggregate : List Value -> Value
        , merge : Maybe (List Value -> Value)
        }


{-| Sum of `Number` values; other values count as zero.
-}
sum : AggregationFn
sum =
    custom sumValues
        |> withMerge sumValues


{-| Smallest `Number` or `Date`; `Null` when there is none.
-}
min : AggregationFn
min =
    custom (pickExtreme isSmaller)
        |> withMerge (pickExtreme isSmaller)


{-| Largest `Number` or `Date`; `Null` when there is none.
-}
max : AggregationFn
max =
    custom (pickExtreme isLarger)
        |> withMerge (pickExtreme isLarger)


{-| `List [ min, max ]`, or `List [ Null, Null ]` when there is no value of a
comparable kind.
-}
extent : AggregationFn
extent =
    custom extentValues
        |> withMerge mergeExtents


{-| Arithmetic mean of numeric values; `Null` when there is none.
-}
mean : AggregationFn
mean =
    custom meanValues


{-| Median of `Number` values; `Null` when there is none.
-}
median : AggregationFn
median =
    custom medianValues


{-| Distinct values in first-seen order, as a `List`.
-}
unique : AggregationFn
unique =
    custom (\values -> List (uniqueValues values))


{-| Number of distinct values.
-}
uniqueCount : AggregationFn
uniqueCount =
    custom (\values -> Number (Basics.toFloat (List.length (uniqueValues values))))


{-| Number of rows.
-}
count : AggregationFn
count =
    custom (\values -> Number (Basics.toFloat (List.length values)))
        |> withMerge sumValues


{-| First row's value, `Null` for no rows.
-}
first : AggregationFn
first =
    custom (\values -> Maybe.withDefault Null (List.head values))
        |> withMerge (\values -> Maybe.withDefault Null (List.head values))


{-| Last row's value, `Null` for no rows.
-}
last : AggregationFn
last =
    custom lastValue
        |> withMerge lastValue


{-| Build an aggregation from a fold over leaf values.
-}
custom : (List Value -> Value) -> AggregationFn
custom fold =
    AggregationFn { aggregate = fold, merge = Nothing }


{-| Add a merge step for child-group results.
-}
withMerge : (List Value -> Value) -> AggregationFn -> AggregationFn
withMerge fold (AggregationFn def) =
    AggregationFn { def | merge = Just fold }


{-| Fold leaf values.
-}
aggregate : AggregationFn -> List Value -> Value
aggregate (AggregationFn def) =
    def.aggregate


{-| The merge step, if the aggregation has one.
-}
merge : AggregationFn -> Maybe (List Value -> Value)
merge (AggregationFn def) =
    def.merge



-- FOLDS


sumValues : List Value -> Value
sumValues values =
    Number (List.foldl (\value total -> total + numberOrZero value) 0 values)


numberOrZero : Value -> Float
numberOrZero value =
    case value of
        Number n ->
            n

        _ ->
            0


lastValue : List Value -> Value
lastValue values =
    Maybe.withDefault Null (List.head (List.reverse values))


uniqueValues : List Value -> List Value
uniqueValues values =
    List.foldl
        (\value seen ->
            if List.member value seen then
                seen

            else
                seen ++ [ value ]
        )
        []
        values


meanValues : List Value -> Value
meanValues values =
    let
        step : Value -> ( Float, Int ) -> ( Float, Int )
        step value ( total, counted ) =
            if Value.isNull value then
                ( total, counted )

            else
                let
                    n : Float
                    n =
                        Value.toNumber value
                in
                if isNaN n then
                    ( total, counted )

                else
                    ( total + n, counted + 1 )

        ( accumulated, howMany ) =
            List.foldl step ( 0, 0 ) values
    in
    if howMany == 0 then
        Null

    else
        Number (accumulated / Basics.toFloat howMany)


medianValues : List Value -> Value
medianValues values =
    let
        numbers : List Float
        numbers =
            List.sort (List.filterMap toNumberOnly values)

        howMany : Int
        howMany =
            List.length numbers
    in
    if howMany == 0 then
        Null

    else if modBy 2 howMany == 1 then
        Number (nth (howMany // 2) numbers)

    else
        Number ((nth (howMany // 2 - 1) numbers + nth (howMany // 2) numbers) / 2)


toNumberOnly : Value -> Maybe Float
toNumberOnly value =
    case value of
        Number n ->
            Just n

        _ ->
            Nothing


nth : Int -> List Float -> Float
nth index numbers =
    Maybe.withDefault 0 (List.head (List.drop index numbers))



-- RANGES


type Kind
    = NumberKind
    | DateKind


rangeKind : Value -> Maybe Kind
rangeKind value =
    case value of
        Number _ ->
            Just NumberKind

        Date _ ->
            Just DateKind

        _ ->
            Nothing


rangeNumber : Value -> Float
rangeNumber value =
    case value of
        Date posix ->
            Basics.toFloat (Time.posixToMillis posix)

        Number n ->
            n

        _ ->
            0


isSmaller : Float -> Float -> Bool
isSmaller candidate current =
    candidate - current < 0


isLarger : Float -> Float -> Bool
isLarger candidate current =
    candidate - current > 0


type alias ExtremeState =
    { kind : Maybe Kind
    , result : Value
    , number : Float
    }


pickExtreme : (Float -> Float -> Bool) -> List Value -> Value
pickExtreme better values =
    List.foldl (extremeStep better) { kind = Nothing, result = Null, number = 0 } values
        |> .result


extremeStep : (Float -> Float -> Bool) -> Value -> ExtremeState -> ExtremeState
extremeStep better value state =
    case rangeKind value of
        Nothing ->
            state

        Just kind ->
            if state.kind == Nothing then
                { kind = Just kind, result = value, number = rangeNumber value }

            else if state.kind /= Just kind then
                state

            else if better (rangeNumber value) state.number then
                { state | result = value, number = rangeNumber value }

            else
                state


type alias ExtentState =
    { kind : Maybe Kind
    , low : Value
    , high : Value
    , lowNumber : Float
    , highNumber : Float
    }


extentValues : List Value -> Value
extentValues values =
    let
        state : ExtentState
        state =
            List.foldl extentStep
                { kind = Nothing, low = Null, high = Null, lowNumber = 0, highNumber = 0 }
                values
    in
    List [ state.low, state.high ]


extentStep : Value -> ExtentState -> ExtentState
extentStep value state =
    case rangeKind value of
        Nothing ->
            state

        Just kind ->
            let
                number : Float
                number =
                    rangeNumber value
            in
            if state.kind == Nothing then
                { kind = Just kind, low = value, high = value, lowNumber = number, highNumber = number }

            else if state.kind /= Just kind then
                state

            else
                let
                    withLow : ExtentState
                    withLow =
                        if number - state.lowNumber < 0 then
                            { state | low = value, lowNumber = number }

                        else
                            state
                in
                if number - state.highNumber > 0 then
                    { withLow | high = value, highNumber = number }

                else
                    withLow


mergeExtents : List Value -> Value
mergeExtents values =
    let
        pairs : List ( Value, Value )
        pairs =
            List.filterMap validExtent values
    in
    case pairs of
        [] ->
            List [ Null, Null ]

        ( firstLow, firstHigh ) :: rest ->
            let
                kind : Maybe Kind
                kind =
                    rangeKind firstLow

                step : ( Value, Value ) -> ( Value, Value ) -> ( Value, Value )
                step ( low, high ) ( currentLow, currentHigh ) =
                    if rangeKind low /= kind then
                        ( currentLow, currentHigh )

                    else
                        ( if rangeNumber low - rangeNumber currentLow < 0 then
                            low

                          else
                            currentLow
                        , if rangeNumber high - rangeNumber currentHigh > 0 then
                            high

                          else
                            currentHigh
                        )

                ( resultLow, resultHigh ) =
                    List.foldl step ( firstLow, firstHigh ) rest
            in
            List [ resultLow, resultHigh ]


validExtent : Value -> Maybe ( Value, Value )
validExtent value =
    case value of
        List [ low, high ] ->
            case ( rangeKind low, Value.isNull high ) of
                ( Just _, False ) ->
                    Just ( low, high )

                _ ->
                    Nothing

        _ ->
            Nothing
