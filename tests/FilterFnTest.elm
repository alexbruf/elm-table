module FilterFnTest exposing (suite)

{-| Port of `packages/table-core/tests/unit/fns/filterFns.test.ts`.

Every `describe` / `it` name from the vitest file is reproduced verbatim.
The vitest file builds `mockRows` from `getStaticTestData()` and reads a
column off the row; here the cell values of that first fixture row are used
directly, because a row model only arrives in phase 2.

Cases that need a table row model, JavaScript object identity, or the filter
fn registry are listed as `-- excluded` comment blocks and in
`reports/phase-1.md`.

-}

import Expect
import Fixtures
import Table.FilterFn as FilterFn exposing (FilterFn)
import Table.Value as Value exposing (Value)
import Test exposing (Test, describe, test)
import Time


suite : Test
suite =
    describe "filterFns"
        [ filterFunctions
        , numberRangeFilters
        , constructFilterFnSuite
        , startsEndsWithSuite
        , emptySuite
        , inDateRangeSuite
        ]


filterFunctions : Test
filterFunctions =
    describe "Filter Functions"
        [ basicFilters
        , stringFilters
        , numberFilters
        , rangeFilters
        , arrayFilters
        ]



-- HELPERS


person0 : Fixtures.Person
person0 =
    Fixtures.staticData
        |> List.head
        |> Maybe.withDefault
            (Fixtures.Person "0" "" "" 0 0 0 Fixtures.Single (Fixtures.SubRows []))


{-| `mockRows[0].getValue('firstName')`.
-}
firstNameValue : Value
firstNameValue =
    Value.String person0.firstName


{-| `mockRows[0].getValue('id')`.
-}
idValue : Value
idValue =
    Value.String person0.id


{-| `mockRows[0].getValue('age')`.
-}
ageValue : Value
ageValue =
    Value.Number (toFloat person0.age)


apply : FilterFn -> Value -> Value -> Bool
apply =
    FilterFn.filter


resolve : FilterFn -> Value -> Value
resolve =
    FilterFn.resolveFilterValue


removes : FilterFn -> Value -> Bool
removes =
    FilterFn.autoRemove


str : String -> Value
str =
    Value.String


num : Float -> Value
num =
    Value.Number


list : List Value -> Value
list =
    Value.List


nan : Float
nan =
    0 / 0


positiveInfinity : Float
positiveInfinity =
    1 / 0


negativeInfinity : Float
negativeInfinity =
    -1 / 0



-- BASIC FILTERS


basicFilters : Test
basicFilters =
    describe "Basic Filters"
        [ describe "filterFn_equals"
            [ test "should match exact values" <|
                \_ -> Expect.equal True (apply FilterFn.equals firstNameValue (str "John"))
            , test "should not match values with type coercion (e.g., \"1\" == 1)" <|
                \_ -> Expect.equal False (apply FilterFn.equals idValue (num 1))
            , test "should handle null/undefined values" <|
                \_ -> Expect.equal False (apply FilterFn.equals firstNameValue Value.Null)
            , test "should correctly identify non-matches" <|
                \_ -> Expect.equal False (apply FilterFn.equals firstNameValue (str "Jane"))
            ]
        , describe "filterFn_weakEquals"
            [ test "should match exact values" <|
                \_ -> Expect.equal True (apply FilterFn.weakEquals firstNameValue (str "John"))
            , test "should match values with type coercion (e.g., \"1\" == 1)" <|
                \_ -> Expect.equal True (apply FilterFn.weakEquals idValue (num 1))
            , test "should handle null/undefined values" <|
                \_ -> Expect.equal False (apply FilterFn.weakEquals firstNameValue Value.Null)
            , test "should correctly identify non-matches" <|
                \_ -> Expect.equal False (apply FilterFn.weakEquals firstNameValue (str "Jane"))
            ]
        ]



-- STRING FILTERS


stringFilters : Test
stringFilters =
    describe "String Filters"
        [ describe "filterFn_includesStringSensitive"
            [ test "should match case-sensitive substrings" <|
                \_ -> Expect.equal True (apply FilterFn.includesStringSensitive firstNameValue (str "John"))
            , test "should not match different case substrings" <|
                \_ -> Expect.equal False (apply FilterFn.includesStringSensitive firstNameValue (str "john"))
            , test "should handle partial matches" <|
                \_ -> Expect.equal True (apply FilterFn.includesStringSensitive firstNameValue (str "ohn"))
            , test "should stringify resolved filter values for row-model filtering" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal (str "123") (resolve FilterFn.includesStringSensitive (num 123))
                        , \_ -> Expect.equal (str "John") (resolve FilterFn.includesStringSensitive (str "John"))
                        ]
                        ()
            ]
        , describe "filterFn_includesString"
            [ test "should match case-insensitive substrings" <|
                \_ ->
                    Expect.equal True
                        (apply FilterFn.includesString firstNameValue (resolve FilterFn.includesString (str "John")))
            , test "should match different case substrings" <|
                \_ ->
                    Expect.equal True
                        (apply FilterFn.includesString firstNameValue (resolve FilterFn.includesString (str "jOhN")))
            , test "should handle partial matches" <|
                \_ ->
                    Expect.equal True
                        (apply FilterFn.includesString firstNameValue (resolve FilterFn.includesString (str "OHN")))
            , test "should normalize resolved filter values for row-model filtering" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal (str "joh") (resolve FilterFn.includesString (str "JoH"))
                        , \_ -> Expect.equal (str "123") (resolve FilterFn.includesString (num 123))
                        ]
                        ()
            ]
        , describe "filterFn_equalsString"
            [ test "should match exact strings" <|
                \_ ->
                    Expect.equal True
                        (apply FilterFn.equalsString firstNameValue (resolve FilterFn.equalsString (str "John")))
            , test "should match case-insensitive exact strings" <|
                \_ ->
                    Expect.equal True
                        (apply FilterFn.equalsString firstNameValue (resolve FilterFn.equalsString (str "jOhN")))
            , test "should not match partial strings" <|
                \_ ->
                    Expect.equal False
                        (apply FilterFn.equalsString firstNameValue (resolve FilterFn.equalsString (str "ohn")))
            , test "should normalize resolved filter values for row-model filtering" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal (str "john") (resolve FilterFn.equalsString (str "JoHn"))
                        , \_ -> Expect.equal (str "123") (resolve FilterFn.equalsString (num 123))
                        ]
                        ()
            ]
        , describe "filterFn_equalsStringSensitive"
            [ test "should match case-sensitive exact strings" <|
                \_ -> Expect.equal True (apply FilterFn.equalsStringSensitive firstNameValue (str "John"))
            , test "should not match case-insensitive exact strings" <|
                \_ -> Expect.equal False (apply FilterFn.equalsStringSensitive firstNameValue (str "john"))
            , test "should not match partial strings" <|
                \_ -> Expect.equal False (apply FilterFn.equalsStringSensitive firstNameValue (str "ohn"))
            , test "should stringify resolved filter values for row-model filtering" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal (str "123") (resolve FilterFn.equalsStringSensitive (num 123))
                        , \_ -> Expect.equal (str "John") (resolve FilterFn.equalsStringSensitive (str "John"))
                        ]
                        ()
            ]
        ]



-- NUMBER FILTERS


comparisonFns : List FilterFn
comparisonFns =
    [ FilterFn.greaterThan
    , FilterFn.greaterThanOrEqualTo
    , FilterFn.lessThan
    , FilterFn.lessThanOrEqualTo
    ]


numberFilters : Test
numberFilters =
    describe "Number Filters"
        [ describe "numeric comparison filter metadata"
            [ test "does not transform filter values during row-model filtering" <|
                \_ ->
                    -- Elm resolvers are total, so "no resolveFilterValue" is
                    -- expressed as "resolveFilterValue is the identity".
                    comparisonFns
                        |> List.concatMap (\fn -> List.map (resolve fn) [ num 30, str "30", Value.Null ])
                        |> Expect.equal
                            (List.concatMap (\_ -> [ num 30, str "30", Value.Null ]) comparisonFns)
            , test "auto-removes only empty comparison filter values" <|
                \_ ->
                    comparisonFns
                        |> List.concatMap
                            (\fn -> List.map (removes fn) [ num 30, str "30", num 0, Value.Null, str "" ])
                        |> Expect.equal
                            (List.concatMap (\_ -> [ False, False, False, True, True ]) comparisonFns)
            ]
        , describe "filterFn_greaterThan"
            [ test "should match greater than values" <|
                \_ -> Expect.equal True (apply FilterFn.greaterThan ageValue (num 29))
            , test "should not match equal values" <|
                \_ -> Expect.equal False (apply FilterFn.greaterThan ageValue (num 30))
            , test "should not match less than values" <|
                \_ -> Expect.equal False (apply FilterFn.greaterThan ageValue (num 31))
            , test "should match strings greater than numbers" <|
                \_ -> Expect.equal True (apply FilterFn.greaterThan ageValue (str "29"))
            , test "should not match strings less than numbers" <|
                \_ -> Expect.equal False (apply FilterFn.greaterThan ageValue (str "31"))
            , test "should match strings greater than other strings" <|
                \_ -> Expect.equal True (apply FilterFn.greaterThan firstNameValue (str "a"))
            , test "should not match strings less than other strings" <|
                \_ -> Expect.equal False (apply FilterFn.greaterThan firstNameValue (str "z"))
            , test "should not match strings equal to other strings" <|
                \_ -> Expect.equal False (apply FilterFn.greaterThan firstNameValue (str "John"))
            ]
        , describe "filterFn_greaterThanOrEqualTo"
            [ test "should match greater than values" <|
                \_ -> Expect.equal True (apply FilterFn.greaterThanOrEqualTo ageValue (num 29))
            , test "should match equal values" <|
                \_ -> Expect.equal True (apply FilterFn.greaterThanOrEqualTo ageValue (num 30))
            , test "should not match less than values" <|
                \_ -> Expect.equal False (apply FilterFn.greaterThanOrEqualTo ageValue (num 31))
            , test "should match strings greater than to numbers" <|
                \_ -> Expect.equal True (apply FilterFn.greaterThanOrEqualTo ageValue (str "29"))
            , test "should not match strings less than numbers" <|
                \_ -> Expect.equal False (apply FilterFn.greaterThanOrEqualTo ageValue (str "31"))
            , test "should match strings greater than other strings" <|
                \_ -> Expect.equal True (apply FilterFn.greaterThanOrEqualTo firstNameValue (str "a"))
            , test "should not match strings less than other strings" <|
                \_ -> Expect.equal False (apply FilterFn.greaterThanOrEqualTo firstNameValue (str "z"))
            , test "should match strings equal to other strings" <|
                \_ -> Expect.equal True (apply FilterFn.greaterThanOrEqualTo firstNameValue (str "John"))
            ]
        , describe "filterFn_lessThan"
            [ test "should match less than values" <|
                \_ -> Expect.equal True (apply FilterFn.lessThan ageValue (num 31))
            , test "should not match equal values" <|
                \_ -> Expect.equal False (apply FilterFn.lessThan ageValue (num 30))
            , test "should not match greater than values" <|
                \_ -> Expect.equal False (apply FilterFn.lessThan ageValue (num 29))
            , test "should match strings less than numbers" <|
                \_ -> Expect.equal True (apply FilterFn.lessThan ageValue (str "31"))
            , test "should match strings less than other strings" <|
                \_ -> Expect.equal True (apply FilterFn.lessThan firstNameValue (str "z"))
            , test "should not match strings equal to other strings" <|
                \_ -> Expect.equal False (apply FilterFn.lessThan firstNameValue (str "John"))
            , test "should not match strings greater than other strings" <|
                \_ -> Expect.equal False (apply FilterFn.lessThan firstNameValue (str "a"))
            ]
        , describe "filterFn_lessThanOrEqualTo"
            [ test "should match less than values" <|
                \_ -> Expect.equal True (apply FilterFn.lessThanOrEqualTo ageValue (num 31))
            , test "should match equal values" <|
                \_ -> Expect.equal True (apply FilterFn.lessThanOrEqualTo ageValue (num 30))
            , test "should not match greater than values" <|
                \_ -> Expect.equal False (apply FilterFn.lessThanOrEqualTo ageValue (num 29))
            , test "should match strings less than to numbers" <|
                \_ -> Expect.equal True (apply FilterFn.lessThanOrEqualTo ageValue (str "31"))
            , test "should not match strings greater than numbers" <|
                \_ -> Expect.equal False (apply FilterFn.lessThanOrEqualTo ageValue (str "29"))
            , test "should match strings less than to other strings" <|
                \_ -> Expect.equal True (apply FilterFn.lessThanOrEqualTo firstNameValue (str "z"))
            , test "should not match strings greater than other strings" <|
                \_ -> Expect.equal False (apply FilterFn.lessThanOrEqualTo firstNameValue (str "a"))
            , test "should match strings equal to other strings" <|
                \_ -> Expect.equal True (apply FilterFn.lessThanOrEqualTo firstNameValue (str "John"))
            ]
        ]



-- RANGE FILTERS


rangeFilters : Test
rangeFilters =
    describe "Range Filters"
        [ describe "filterFns.between"
            [ test "matches values strictly between both endpoints" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal True (apply FilterFn.between ageValue (list [ num 29, num 31 ]))
                        , \_ -> Expect.equal False (apply FilterFn.between ageValue (list [ num 30, num 31 ]))
                        , \_ -> Expect.equal False (apply FilterFn.between ageValue (list [ num 29, num 30 ]))
                        ]
                        ()
            , test "treats blank endpoints as open-ended" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal True (apply FilterFn.between ageValue (list [ Value.Null, num 31 ]))
                        , \_ -> Expect.equal True (apply FilterFn.between ageValue (list [ str "", num 31 ]))
                        , \_ -> Expect.equal True (apply FilterFn.between ageValue (list [ num 29, Value.Null ]))
                        , \_ -> Expect.equal True (apply FilterFn.between ageValue (list [ num 29, str "" ]))
                        ]
                        ()
            , test "enforces a negative max when the min endpoint is blank" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal False (apply FilterFn.between ageValue (list [ Value.Null, num -1 ]))
                        , \_ -> Expect.equal False (apply FilterFn.between ageValue (list [ str "", num -1 ]))
                        ]
                        ()
            , test "preserves reversed-range behavior after the lower bound passes" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal True (apply FilterFn.between ageValue (list [ num 29, num 20 ]))
                        , \_ -> Expect.equal False (apply FilterFn.between ageValue (list [ num 31, num 20 ]))
                        ]
                        ()
            ]
        , describe "filterFns.betweenInclusive"
            [ test "matches values inclusively between both endpoints" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal True (apply FilterFn.betweenInclusive ageValue (list [ num 29, num 31 ]))
                        , \_ -> Expect.equal True (apply FilterFn.betweenInclusive ageValue (list [ num 30, num 31 ]))
                        , \_ -> Expect.equal True (apply FilterFn.betweenInclusive ageValue (list [ num 29, num 30 ]))
                        , \_ -> Expect.equal False (apply FilterFn.betweenInclusive ageValue (list [ num 31, num 40 ]))
                        ]
                        ()
            , test "treats blank endpoints as open-ended" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal True (apply FilterFn.betweenInclusive ageValue (list [ Value.Null, num 30 ]))
                        , \_ -> Expect.equal True (apply FilterFn.betweenInclusive ageValue (list [ str "", num 30 ]))
                        , \_ -> Expect.equal True (apply FilterFn.betweenInclusive ageValue (list [ num 30, Value.Null ]))
                        , \_ -> Expect.equal True (apply FilterFn.betweenInclusive ageValue (list [ num 30, str "" ]))
                        ]
                        ()
            , test "enforces a negative max when the min endpoint is blank" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal False (apply FilterFn.betweenInclusive ageValue (list [ Value.Null, num -1 ]))
                        , \_ -> Expect.equal False (apply FilterFn.betweenInclusive ageValue (list [ str "", num -1 ]))
                        ]
                        ()
            , test "preserves reversed-range behavior after the lower bound passes" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal True (apply FilterFn.betweenInclusive ageValue (list [ num 30, num 20 ]))
                        , \_ -> Expect.equal False (apply FilterFn.betweenInclusive ageValue (list [ num 31, num 20 ]))
                        ]
                        ()
            ]
        , rangeAutoRemoveSuite "filterFns.between.autoRemove" FilterFn.between
        , rangeAutoRemoveSuite "filterFns.betweenInclusive.autoRemove" FilterFn.betweenInclusive
        , describe "filterFns.inNumberRange.autoRemove"
            (rangeAutoRemoveTests FilterFn.inNumberRange
                ++ [ test "should NOT auto-remove a non-empty scalar number passed instead of a range tuple" <|
                        \_ ->
                            Expect.all
                                [ \_ -> Expect.equal False (removes FilterFn.inNumberRange (num 99))
                                , \_ -> Expect.equal False (removes FilterFn.inNumberRange (num 0))
                                ]
                                ()
                   , test "should auto-remove an empty-string scalar (matches existing testFalsy behavior)" <|
                        \_ -> Expect.equal True (removes FilterFn.inNumberRange (str ""))
                   ]
            )
        , describe "filterFn_inNumberRange"
            [ test "should match numbers inside the range and on the inclusive boundaries" <|
                \_ ->
                    let
                        range =
                            resolve FilterFn.inNumberRange (list [ num 0, num 20 ])
                    in
                    Expect.all
                        [ \_ -> Expect.equal True (apply FilterFn.inNumberRange (num 15) range)
                        , \_ -> Expect.equal True (apply FilterFn.inNumberRange (num 0) range)
                        , \_ -> Expect.equal True (apply FilterFn.inNumberRange (num 20) range)
                        ]
                        ()
            , test "should not match numbers outside the range" <|
                \_ ->
                    let
                        range =
                            resolve FilterFn.inNumberRange (list [ num 0, num 20 ])
                    in
                    Expect.all
                        [ \_ -> Expect.equal False (apply FilterFn.inNumberRange (num 25) range)
                        , \_ -> Expect.equal False (apply FilterFn.inNumberRange (num -5) range)
                        ]
                        ()
            , test "should not match nullish or blank values in a zero-spanning range" <|
                \_ ->
                    let
                        range =
                            resolve FilterFn.inNumberRange (list [ num 0, num 20 ])
                    in
                    Expect.all
                        -- `null` and `undefined` are both `Null` in Elm, so the
                        -- vitest file's three expectations collapse into two.
                        [ \_ -> Expect.equal False (apply FilterFn.inNumberRange Value.Null range)
                        , \_ -> Expect.equal False (apply FilterFn.inNumberRange (str "") range)
                        ]
                        ()
            , test "should not match booleans, numeric strings, or NaN" <|
                \_ ->
                    let
                        range =
                            resolve FilterFn.inNumberRange (list [ num 0, num 20 ])
                    in
                    Expect.all
                        [ \_ -> Expect.equal False (apply FilterFn.inNumberRange (Value.Bool True) range)
                        , \_ -> Expect.equal False (apply FilterFn.inNumberRange (Value.Bool False) range)
                        , \_ -> Expect.equal False (apply FilterFn.inNumberRange (str "15") range)
                        , \_ -> Expect.equal False (apply FilterFn.inNumberRange (num nan) range)
                        ]
                        ()
            , test "should keep matching real numbers in open-ended ranges while excluding empty values" <|
                \_ ->
                    Expect.all
                        [ \_ ->
                            Expect.equal True
                                (apply FilterFn.inNumberRange
                                    (num -5)
                                    (resolve FilterFn.inNumberRange (list [ str "", num 20 ]))
                                )
                        , \_ ->
                            Expect.equal False
                                (apply FilterFn.inNumberRange
                                    Value.Null
                                    (resolve FilterFn.inNumberRange (list [ str "", num 20 ]))
                                )
                        , \_ ->
                            Expect.equal True
                                (apply FilterFn.inNumberRange
                                    (num 500)
                                    (resolve FilterFn.inNumberRange (list [ num 0, str "" ]))
                                )
                        ]
                        ()
            ]
        ]


rangeAutoRemoveSuite : String -> FilterFn -> Test
rangeAutoRemoveSuite name fn =
    describe name
        (rangeAutoRemoveTests fn
            ++ [ test "should NOT auto-remove a scalar value passed instead of a range tuple" <|
                    \_ -> Expect.equal False (removes fn (num 99))
               ]
        )


rangeAutoRemoveTests : FilterFn -> List Test
rangeAutoRemoveTests fn =
    [ test "should auto-remove when both endpoints are undefined" <|
        \_ -> Expect.equal True (removes fn (list [ Value.Null, Value.Null ]))
    , test "should auto-remove when both endpoints are null" <|
        \_ -> Expect.equal True (removes fn (list [ Value.Null, Value.Null ]))
    , test "should auto-remove when both endpoints are empty strings" <|
        \_ -> Expect.equal True (removes fn (list [ str "", str "" ]))
    , test "should NOT auto-remove when both endpoints are valid numbers" <|
        \_ -> Expect.equal False (removes fn (list [ num 5, num 10 ]))
    , test "should NOT auto-remove when lower bound is 0 (falsy number)" <|
        \_ -> Expect.equal False (removes fn (list [ num 0, num 10 ]))
    , test "should NOT auto-remove when only one endpoint is provided" <|
        \_ ->
            Expect.all
                [ \_ -> Expect.equal False (removes fn (list [ Value.Null, num 10 ]))
                , \_ -> Expect.equal False (removes fn (list [ num 5, Value.Null ]))
                ]
                ()
    ]



-- ARRAY FILTERS


arrayFilters : Test
arrayFilters =
    describe "Array Filters"
        [ describe "filterFns.arrHas"
            [ test "matches scalar values against any filter value" <|
                \_ ->
                    -- The `getValueCalls()` spy assertion has no Elm counterpart.
                    Expect.equal True (apply FilterFn.arrHas (str "b") (list [ str "a", str "b" ]))
            , test "does not match when no filter value equals the scalar value" <|
                \_ -> Expect.equal False (apply FilterFn.arrHas (str "c") (list [ str "a", str "b" ]))
            ]
        , describe "filterFns.arrIncludes"
            [ test "matches array values that include any filter value" <|
                \_ ->
                    Expect.equal True
                        (apply FilterFn.arrIncludes (list [ str "a", str "b" ]) (list [ str "z", str "b" ]))
            , test "matches string values that include any filter value" <|
                \_ ->
                    Expect.equal True
                        (apply FilterFn.arrIncludes (str "hello") (list [ str "zz", str "ell" ]))
            , test "does not match when no filter value is included" <|
                \_ ->
                    Expect.equal False
                        (apply FilterFn.arrIncludes (list [ str "a", str "b" ]) (list [ str "x", str "y" ]))
            , test "does not throw or match for nullish row values" <|
                \_ ->
                    -- `null` and `undefined` are both `Null` in Elm.
                    Expect.equal False (apply FilterFn.arrIncludes Value.Null (list [ str "a" ]))
            ]
        , describe "filterFns.arrIncludesAll"
            [ test "matches array values that include every filter value" <|
                \_ ->
                    Expect.equal True
                        (apply FilterFn.arrIncludesAll
                            (list [ str "a", str "b", str "c" ])
                            (list [ str "a", str "c" ])
                        )
            , test "does not match when any filter value is missing" <|
                \_ ->
                    Expect.equal False
                        (apply FilterFn.arrIncludesAll (list [ str "a", str "b" ]) (list [ str "a", str "c" ]))
            , test "does not match non-array row values" <|
                \_ ->
                    Expect.equal False (apply FilterFn.arrIncludesAll (str "abc") (list [ str "a" ]))
            ]
        , describe "filterFns.arrIncludesSome"
            [ test "matches array values that include at least one filter value" <|
                \_ ->
                    Expect.equal True
                        (apply FilterFn.arrIncludesSome (list [ str "a", str "b" ]) (list [ str "z", str "b" ]))
            , test "does not match when no filter value is included" <|
                \_ ->
                    Expect.equal False
                        (apply FilterFn.arrIncludesSome (list [ str "a", str "b" ]) (list [ str "x", str "y" ]))
            , test "does not match non-array row values" <|
                \_ ->
                    Expect.equal False (apply FilterFn.arrIncludesSome (str "abc") (list [ str "a" ]))
            ]
        , describe "filterFns.arrHas.autoRemove"
            [ test "should auto-remove when the filter value is undefined" <|
                \_ -> Expect.equal True (removes FilterFn.arrHas Value.Null)
            , test "should auto-remove when the filter value is null" <|
                \_ -> Expect.equal True (removes FilterFn.arrHas Value.Null)
            , test "should auto-remove when the filter value is an empty string" <|
                \_ -> Expect.equal True (removes FilterFn.arrHas (str ""))
            , test "should auto-remove when the filter value is an empty array" <|
                \_ -> Expect.equal True (removes FilterFn.arrHas (list []))
            , test "should NOT auto-remove when the filter value is a non-empty array" <|
                \_ -> Expect.equal False (removes FilterFn.arrHas (list [ str "a" ]))
            ]
        ]



-- NUMBER RANGE FILTERS


numberRangeFilters : Test
numberRangeFilters =
    describe "Number Range Filters"
        [ describe "filterFn_inNumberRange"
            [ test "should match values inclusively within the range" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal True (apply FilterFn.inNumberRange ageValue (list [ num 29, num 31 ]))
                        , \_ -> Expect.equal True (apply FilterFn.inNumberRange ageValue (list [ num 30, num 30 ]))
                        , \_ -> Expect.equal False (apply FilterFn.inNumberRange ageValue (list [ num 31, num 40 ]))
                        , \_ -> Expect.equal False (apply FilterFn.inNumberRange ageValue (list [ num 10, num 29 ]))
                        ]
                        ()
            , test "should coerce string endpoints in resolveFilterValue" <|
                \_ ->
                    Expect.equal (list [ num 29, num 31 ])
                        (resolve FilterFn.inNumberRange (list [ str "29", str "31" ]))
            , test "should treat null and non-numeric endpoints as open-ended" <|
                \_ ->
                    Expect.all
                        [ \_ ->
                            Expect.equal (list [ num negativeInfinity, num 31 ])
                                (resolve FilterFn.inNumberRange (list [ Value.Null, num 31 ]))
                        , \_ ->
                            Expect.equal (list [ num 29, num positiveInfinity ])
                                (resolve FilterFn.inNumberRange (list [ num 29, str "abc" ]))
                        ]
                        ()
            , test "should swap reversed ranges" <|
                \_ ->
                    Expect.equal (list [ num 29, num 31 ])
                        (resolve FilterFn.inNumberRange (list [ num 31, num 29 ]))
            , test "should auto-remove only fully empty ranges" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal True (removes FilterFn.inNumberRange Value.Null)
                        , \_ -> Expect.equal True (removes FilterFn.inNumberRange (list [ Value.Null, Value.Null ]))
                        , \_ -> Expect.equal True (removes FilterFn.inNumberRange (list [ str "", str "" ]))
                        , \_ -> Expect.equal False (removes FilterFn.inNumberRange (list [ num 5, Value.Null ]))
                        , \_ -> Expect.equal False (removes FilterFn.inNumberRange (list [ Value.Null, num 10 ]))
                        , \_ -> Expect.equal False (removes FilterFn.inNumberRange (list [ num 0, num 10 ]))
                        ]
                        ()
            ]
        ]



-- CONSTRUCT FILTER FN


{-| `String(val ?? '').toLowerCase().normalize('NFD').replace(/\p{Diacritic}/gu, '')`
for the letters the ported tests use. Elm core has no Unicode normalisation.
-}
normalize : Value -> Value
normalize value =
    Value.toString value
        |> String.toLower
        |> String.map
            (\c ->
                case c of
                    'é' ->
                        'e'

                    'ë' ->
                        'e'

                    _ ->
                        c
            )
        |> Value.String


includesStringIgnoreDiacritics : FilterFn
includesStringIgnoreDiacritics =
    FilterFn.includesString
        |> FilterFn.withResolveFilterValue normalize
        |> FilterFn.withResolveDataValue normalize


constructFilterFnSuite : Test
constructFilterFnSuite =
    describe "constructFilterFn"
        [ test "matches data with diacritics against plain filter text" <|
            \_ ->
                let
                    row =
                        str "Éric Bernard"
                in
                Expect.all
                    [ \_ ->
                        Expect.equal True
                            (apply includesStringIgnoreDiacritics
                                row
                                (resolve includesStringIgnoreDiacritics (str "eric"))
                            )
                    , \_ ->
                        Expect.equal False
                            (apply FilterFn.includesString
                                row
                                (resolve FilterFn.includesString (str "eric"))
                            )
                    ]
                    ()
        , test "matches filter text with diacritics against plain data" <|
            \_ ->
                Expect.equal True
                    (apply includesStringIgnoreDiacritics
                        (str "Zoe Smith")
                        (resolve includesStringIgnoreDiacritics (str "Zoë"))
                    )
        , test "inherits the base autoRemove behavior through the spread" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal True (removes includesStringIgnoreDiacritics (str ""))
                    , \_ -> Expect.equal False (removes includesStringIgnoreDiacritics (str "x"))
                    ]
                    ()
        , test "honors resolveDataValue assigned after creation" <|
            \_ ->
                let
                    upperCaseEquals =
                        FilterFn.equalsStringSensitive
                            |> FilterFn.withResolveDataValue
                                (\value -> Value.String (String.toUpper (Value.toString value)))
                in
                Expect.equal True (apply upperCaseEquals (str "john") (str "JOHN"))

        -- moved: "applies both resolvers when filtering through the table row
        -- model" needs the filtered row model, so it lives in
        -- tests/FilteringRowModelTest.elm since phase 3.
        ]



-- STARTS WITH / ENDS WITH


startsEndsWithSuite : Test
startsEndsWithSuite =
    describe "filterFn_startsWith / filterFn_endsWith"
        [ test "matches prefixes case-insensitively" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        Expect.equal True
                            (apply FilterFn.startsWith firstNameValue (resolve FilterFn.startsWith (str "JO")))
                    , \_ ->
                        Expect.equal False
                            (apply FilterFn.startsWith firstNameValue (resolve FilterFn.startsWith (str "ohn")))
                    ]
                    ()
        , test "matches suffixes case-insensitively" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        Expect.equal True
                            (apply FilterFn.endsWith firstNameValue (resolve FilterFn.endsWith (str "HN")))
                    , \_ ->
                        Expect.equal False
                            (apply FilterFn.endsWith firstNameValue (resolve FilterFn.endsWith (str "Jo")))
                    ]
                    ()
        , test "auto-removes empty filter values" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal True (removes FilterFn.startsWith (str ""))
                    , \_ -> Expect.equal True (removes FilterFn.endsWith Value.Null)
                    , \_ -> Expect.equal False (removes FilterFn.startsWith (str "j"))
                    ]
                    ()
        ]



-- EMPTY / NOT EMPTY


emptySuite : Test
emptySuite =
    describe "filterFn_empty / filterFn_notEmpty"
        [ test "treats nullish and whitespace-only values as empty" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal True (apply FilterFn.empty Value.Null (Value.Bool True))
                    , \_ -> Expect.equal True (apply FilterFn.empty (str "") (Value.Bool True))
                    , \_ -> Expect.equal True (apply FilterFn.empty (str "   ") (Value.Bool True))
                    , \_ -> Expect.equal True (apply FilterFn.empty (list []) (Value.Bool True))
                    ]
                    ()
        , test "treats real values as not empty, including falsy ones" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal False (apply FilterFn.empty (str "x") (Value.Bool True))
                    , \_ -> Expect.equal False (apply FilterFn.empty (num 0) (Value.Bool True))
                    , \_ -> Expect.equal False (apply FilterFn.empty (Value.Bool False) (Value.Bool True))
                    ]
                    ()
        , test "mirrors empty with notEmpty" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal False (apply FilterFn.notEmpty Value.Null (Value.Bool True))
                    , \_ -> Expect.equal True (apply FilterFn.notEmpty (str "x") (Value.Bool True))
                    ]
                    ()
        , test "auto-removes only when the flag is turned off or blank" <|
            \_ ->
                [ FilterFn.empty, FilterFn.notEmpty ]
                    |> List.concatMap
                        (\fn -> List.map (removes fn) [ Value.Bool False, Value.Null, str "", Value.Bool True ])
                    |> Expect.equal [ True, True, True, False, True, True, True, False ]
        ]



-- IN DATE RANGE


{-| `new Date('2026-01-01').getTime()`.
-}
jan01Millis : Int
jan01Millis =
    1767225600000


dayMillis : Int
dayMillis =
    86400000


{-| `new Date('2026-01-<n>')` as a `Value`.
-}
jan : Int -> Value
jan dayOfMonth =
    Value.Date (Time.millisToPosix (janMillis dayOfMonth))


janMillis : Int -> Int
janMillis dayOfMonth =
    jan01Millis + (dayOfMonth - 1) * dayMillis


janNumber : Int -> Value
janNumber dayOfMonth =
    num (toFloat (janMillis dayOfMonth))


inDateRangeSuite : Test
inDateRangeSuite =
    describe "filterFn_inDateRange"
        [ test "coerces Date, string, and timestamp endpoints to timestamps" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        Expect.equal (list [ janNumber 1, janNumber 31 ])
                            (resolve FilterFn.inDateRange (list [ jan 1, jan 31 ]))
                    , \_ ->
                        Expect.equal (list [ janNumber 1, janNumber 31 ])
                            (resolve FilterFn.inDateRange (list [ str "2026-01-01", janNumber 31 ]))
                    ]
                    ()
        , test "treats blank or invalid endpoints as open-ended and swaps reversed ranges" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        Expect.equal (list [ num negativeInfinity, num positiveInfinity ])
                            (resolve FilterFn.inDateRange (list [ Value.Null, Value.Null ]))
                    , \_ ->
                        Expect.equal (list [ janNumber 1, num positiveInfinity ])
                            (resolve FilterFn.inDateRange (list [ jan 1, str "" ]))
                    , \_ ->
                        Expect.equal (list [ num negativeInfinity, janNumber 1 ])
                            (resolve FilterFn.inDateRange (list [ str "not a date", jan 1 ]))
                    , \_ ->
                        Expect.equal (list [ janNumber 1, janNumber 31 ])
                            (resolve FilterFn.inDateRange (list [ jan 31, jan 1 ]))
                    ]
                    ()
        , test "matches Date, string, and timestamp row values inside the range" <|
            \_ ->
                let
                    range =
                        resolve FilterFn.inDateRange (list [ jan 5, jan 15 ])
                in
                Expect.all
                    [ \_ -> Expect.equal True (apply FilterFn.inDateRange (jan 10) range)
                    , \_ -> Expect.equal True (apply FilterFn.inDateRange (str "2026-01-10") range)
                    , \_ -> Expect.equal True (apply FilterFn.inDateRange (janNumber 10) range)
                    , \_ -> Expect.equal False (apply FilterFn.inDateRange (jan 20) range)
                    ]
                    ()
        , test "never matches rows without a valid date" <|
            \_ ->
                let
                    range =
                        resolve FilterFn.inDateRange (list [ Value.Null, Value.Null ])
                in
                Expect.all
                    [ \_ -> Expect.equal False (apply FilterFn.inDateRange Value.Null range)
                    , \_ -> Expect.equal False (apply FilterFn.inDateRange (str "nope") range)
                    ]
                    ()
        , test "auto-removes only fully blank ranges" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal True (removes FilterFn.inDateRange Value.Null)
                    , \_ -> Expect.equal True (removes FilterFn.inDateRange (list [ Value.Null, Value.Null ]))
                    , \_ ->
                        Expect.equal False
                            (removes FilterFn.inDateRange (list [ Value.Date (Time.millisToPosix 0), Value.Null ]))
                    ]
                    ()
        ]



-- excluded: describe "filter fn registry"
--   * "registers the case-sensitive string equality filter fn"
--   * "registers the new built-in filter fns"
--   Both assert JavaScript object identity between a registry entry and the
--   exported fn; Elm has no filter fn registry and no reference equality.
--
-- moved: describe "auto filter fn for date columns"
--   * "resolves inDateRange for Date-valued columns"
--   * "filters date rows through the table row model"
--   Both need `Table.getAutoFilterFn` and the filtered row model, so they live
--   in tests/FilteringRowModelTest.elm since phase 3.
