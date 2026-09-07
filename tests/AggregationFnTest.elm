module AggregationFnTest exposing (suite)

{-| Port of `packages/table-core/tests/unit/fns/aggregationFns.test.ts`.

Every `describe` / `it` name from the vitest file is reproduced verbatim.
The vitest `context(values)` helper wraps the values in fake rows; an Elm
aggregation takes the column's values directly, so the value list is passed
as is.

-}

import Expect
import Table.AggregationFn as AggregationFn exposing (AggregationFn)
import Table.Value as Value exposing (Value)
import Test exposing (Test, describe, test)
import Time


suite : Test
suite =
    describe "aggregation function definitions"
        [ test "preserves sum coercion and NaN behavior" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        Expect.equal (num 4)
                            (run AggregationFn.sum [ num 1, str "2", num 3, Value.Null ])
                    , \_ ->
                        Expect.equal True (isNaNValue (run AggregationFn.sum [ num 1, num nan ]))
                    , \_ -> Expect.equal (num 0) (run AggregationFn.sum [])
                    , \_ ->
                        Expect.equal (Just (num 10))
                            (runMerge AggregationFn.sum [ num 4, Value.Null, num 6 ])
                    ]
                    ()
        , test "calculates numeric and Date ranges while preserving types" <|
            \_ ->
                let
                    early =
                        date 1704067200000

                    late =
                        date 1709251200000
                in
                Expect.all
                    [ \_ -> Expect.equal (num -1) (run AggregationFn.min [ num 3, num -1, num 2 ])
                    , \_ -> Expect.equal (num 3) (run AggregationFn.max [ num 3, num -1, num 2 ])
                    , \_ ->
                        Expect.equal (list [ num -1, num 3 ])
                            (run AggregationFn.extent [ num 3, num -1, num 2 ])
                    , \_ ->
                        Expect.equal (list [ early, late ])
                            (run AggregationFn.extent [ late, Value.Null, early ])
                    , \_ ->
                        Expect.equal (list [ Value.Null, Value.Null ])
                            (run AggregationFn.extent [])
                    ]
                    ()
        , test "uses the first valid range type and ignores incompatible values" <|
            \_ ->
                let
                    day =
                        date 1704067200000
                in
                Expect.all
                    [ \_ ->
                        Expect.equal (list [ num 2, num 4 ])
                            (run AggregationFn.extent [ num 2, day, num 4 ])
                    , \_ ->
                        Expect.equal (list [ day, day ])
                            (run AggregationFn.extent [ day, num 2 ])
                    ]
                    ()
        , test "preserves mean coercion and median numeric-only behavior" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        Expect.equal (num 2)
                            (run AggregationFn.mean
                                [ Value.Null, Value.Null, str "", str "2", num 4, str "x" ]
                            )
                    , \_ ->
                        -- Non-numeric values are skipped, not treated as a reason
                        -- to bail out, so the median comes from (1, 2, 3).
                        Expect.equal (num 2)
                            (run AggregationFn.median [ num 3, str "2", num 1, num 2 ])
                    , \_ -> Expect.equal (num 2) (run AggregationFn.median [ num 3, num 1, num 2 ])
                    , \_ -> Expect.equal Value.Null (run AggregationFn.mean [])
                    , \_ -> Expect.equal Value.Null (run AggregationFn.median [])
                    , \_ -> Expect.equal Nothing (isMerging AggregationFn.mean)
                    , \_ -> Expect.equal Nothing (isMerging AggregationFn.median)
                    ]
                    ()
        , test "skips null/non-numeric values in median, like sum/min/max/mean" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        Expect.equal (num 2)
                            (run AggregationFn.median [ num 1, Value.Null, num 2, num 3 ])
                    , \_ ->
                        Expect.equal (num 5)
                            (run AggregationFn.median [ Value.Null, Value.Null, num 4, str "5", num 6 ])
                    , \_ ->
                        Expect.equal (num 2.5)
                            (run AggregationFn.median [ num 1, Value.Null, num 2, num 3, num 4 ])
                    , \_ ->
                        Expect.equal Value.Null
                            (run AggregationFn.median [ Value.Null, Value.Null, str "x", str "y" ])
                    ]
                    ()
        , test "uses Set semantics for unique values" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        -- `null` and `undefined` are one value in Elm, so the
                        -- vitest expectation of three entries becomes two.
                        Expect.equal (list [ str "a", Value.Null ])
                            (run AggregationFn.unique [ str "a", Value.Null, Value.Null, str "a" ])
                    , \_ ->
                        Expect.equal (num 2)
                            (run AggregationFn.uniqueCount [ str "a", Value.Null, Value.Null, str "a" ])
                    , \_ -> Expect.equal (list []) (run AggregationFn.unique [])
                    , \_ -> Expect.equal (num 0) (run AggregationFn.uniqueCount [])
                    ]
                    ()
        , test "counts rows and preserves positional nullish values" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        Expect.equal (num 3)
                            (run AggregationFn.count [ Value.Null, num 2, Value.Null ])
                    , \_ -> Expect.equal (num 0) (run AggregationFn.count [])
                    , \_ ->
                        Expect.equal Value.Null
                            (run AggregationFn.first [ Value.Null, str "a", str "b" ])
                    , \_ ->
                        Expect.equal Value.Null
                            (run AggregationFn.last [ str "a", str "b", Value.Null ])
                    ]
                    ()
        , -- adapted: an Elm aggregation sees values, not rows, so the custom
          -- fn joins the two values (`1,2`) where the vitest joins the two
          -- fake row ids (`0,1`); there is no type inference to check.
          test "preserves custom definition result inference" <|
            \_ ->
                let
                    joined : AggregationFn
                    joined =
                        AggregationFn.custom
                            (\values ->
                                Value.String
                                    (String.join "," (List.map Value.toString values))
                            )
                in
                run joined [ num 1, num 2 ] |> Expect.equal (str "1,2")
        ]



-- HELPERS


run : AggregationFn -> List Value -> Value
run =
    AggregationFn.aggregate


runMerge : AggregationFn -> List Value -> Maybe Value
runMerge fn values =
    Maybe.map (\merge -> merge values) (AggregationFn.merge fn)


isMerging : AggregationFn -> Maybe ()
isMerging fn =
    Maybe.map (\_ -> ()) (AggregationFn.merge fn)


num : Float -> Value
num =
    Value.Number


str : String -> Value
str =
    Value.String


list : List Value -> Value
list =
    Value.List


date : Int -> Value
date millis =
    Value.Date (Time.millisToPosix millis)


nan : Float
nan =
    0 / 0


isNaNValue : Value -> Bool
isNaNValue value =
    case value of
        Value.Number n ->
            isNaN n

        _ ->
            False
