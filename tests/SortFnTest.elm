module SortFnTest exposing (suite)

{-| Port of `packages/table-core/tests/unit/fns/sortFns.test.ts`.

Every `describe` / `it` name from the vitest file is reproduced verbatim.
The vitest helper `cmp` normalises the comparator result to `-1 / 0 / 1`;
Elm comparators already return `LT / EQ / GT`, so the expectations use those.

-}

import Expect
import Table.SortFn as SortFn exposing (SortFn)
import Table.Value as Value exposing (Value)
import Test exposing (Test, describe, test)
import Time


suite : Test
suite =
    describe "sortFns"
        [ alphanumericSuite
        , alphanumericCaseSensitiveSuite
        , textSuite
        , textCaseSensitiveSuite
        , basicSuite
        , boundaryChunksSuite
        , datetimeSuite
        , splitSuite
        , constructSortFnSuite
        ]



-- HELPERS


cmp : SortFn -> Value -> Value -> Order
cmp =
    SortFn.compare


str : String -> Value
str =
    Value.String


num : Float -> Value
num =
    Value.Number


nan : Float
nan =
    sqrt -1


infinity : Float
infinity =
    1 / 0



-- SUITES


alphanumericSuite : Test
alphanumericSuite =
    describe "sortFn_alphanumeric (compareAlphanumeric)"
        [ test "returns 0 for equal strings" <|
            \_ ->
                Expect.equal EQ (cmp SortFn.alphanumeric (str "abc") (str "abc"))
        , test "returns 0 for two empty strings" <|
            \_ ->
                Expect.equal EQ (cmp SortFn.alphanumeric (str "") (str ""))
        , test "sorts pure strings lexicographically" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal LT (cmp SortFn.alphanumeric (str "apple") (str "banana"))
                    , \_ -> Expect.equal GT (cmp SortFn.alphanumeric (str "banana") (str "apple"))
                    ]
                    ()
        , test "sorts pure numbers numerically (natural sort)" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal LT (cmp SortFn.alphanumeric (str "item2") (str "item10"))
                    , \_ -> Expect.equal GT (cmp SortFn.alphanumeric (str "item10") (str "item2"))
                    ]
                    ()
        , test "sorts mixed alphanumeric strings naturally" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal LT (cmp SortFn.alphanumeric (str "a1b2") (str "a1b10"))
                    , \_ -> Expect.equal LT (cmp SortFn.alphanumeric (str "a2b") (str "a10b"))
                    ]
                    ()
        , test "treats string chunk less than number chunk in mixed-type comparison" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal LT (cmp SortFn.alphanumeric (str "abc") (str "123"))
                    , \_ -> Expect.equal GT (cmp SortFn.alphanumeric (str "123") (str "abc"))
                    ]
                    ()
        , test "returns difference in chunk count when one is a prefix of the other" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal LT (cmp SortFn.alphanumeric (str "abc") (str "abc1"))
                    , \_ -> Expect.equal GT (cmp SortFn.alphanumeric (str "abc1") (str "abc"))
                    ]
                    ()
        , test "returns 0 when both strings normalize to no chunks" <|
            \_ ->
                Expect.equal EQ (cmp SortFn.alphanumeric (str "") (str ""))
        , test "lowercases input (case-insensitive)" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal EQ (cmp SortFn.alphanumeric (str "ABC") (str "abc"))
                    , \_ -> Expect.equal LT (cmp SortFn.alphanumeric (str "Apple") (str "banana"))
                    ]
                    ()
        , test "coerces numbers to strings via toString" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal LT (cmp SortFn.alphanumeric (num 2) (num 10))
                    , \_ -> Expect.equal GT (cmp SortFn.alphanumeric (num 10) (num 2))
                    ]
                    ()
        , test "treats NaN/Infinity numbers as empty" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal EQ (cmp SortFn.alphanumeric (num nan) (str ""))
                    , \_ -> Expect.equal EQ (cmp SortFn.alphanumeric (num infinity) (str ""))
                    ]
                    ()
        , test "handles long mixed strings (stress: many chunks)" <|
            \_ ->
                let
                    a =
                        str "abc1def2ghi3jkl4mno5"

                    b =
                        str "abc1def2ghi3jkl4mno10"
                in
                Expect.all
                    [ \_ -> Expect.equal LT (cmp SortFn.alphanumeric a b)
                    , \_ -> Expect.equal GT (cmp SortFn.alphanumeric b a)
                    ]
                    ()
        , test "sort() integration: produces natural order" <|
            \_ ->
                [ "item10", "item2", "item1", "item20", "item3" ]
                    |> List.map str
                    |> List.sortWith (cmp SortFn.alphanumeric)
                    |> List.map Value.toString
                    |> Expect.equal [ "item1", "item2", "item3", "item10", "item20" ]
        ]


alphanumericCaseSensitiveSuite : Test
alphanumericCaseSensitiveSuite =
    describe "sortFn_alphanumericCaseSensitive"
        [ test "preserves case (uppercase < lowercase by ASCII)" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal LT (cmp SortFn.alphanumericCaseSensitive (str "ABC") (str "abc"))
                    , \_ -> Expect.equal GT (cmp SortFn.alphanumericCaseSensitive (str "abc") (str "ABC"))
                    ]
                    ()
        , test "sorts naturally with case sensitivity" <|
            \_ ->
                Expect.equal LT (cmp SortFn.alphanumericCaseSensitive (str "Item2") (str "Item10"))
        ]


textSuite : Test
textSuite =
    describe "sortFn_text"
        [ test "returns 0 for equal strings" <|
            \_ ->
                Expect.equal EQ (cmp SortFn.text (str "abc") (str "abc"))
        , test "sorts lexicographically (no natural sort)" <|
            \_ ->
                Expect.equal LT (cmp SortFn.text (str "item10") (str "item2"))
        , test "lowercases input" <|
            \_ ->
                Expect.equal EQ (cmp SortFn.text (str "ABC") (str "abc"))
        ]


textCaseSensitiveSuite : Test
textCaseSensitiveSuite =
    describe "sortFn_textCaseSensitive"
        [ test "preserves case" <|
            \_ ->
                Expect.equal LT (cmp SortFn.textCaseSensitive (str "ABC") (str "abc"))
        ]


basicSuite : Test
basicSuite =
    describe "sortFn_basic"
        [ test "returns 0 for equal values" <|
            \_ ->
                Expect.equal EQ (cmp SortFn.basic (num 5) (num 5))
        , test "compares numbers" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal LT (cmp SortFn.basic (num 1) (num 2))
                    , \_ -> Expect.equal GT (cmp SortFn.basic (num 2) (num 1))
                    ]
                    ()
        , test "compares strings" <|
            \_ ->
                Expect.equal LT (cmp SortFn.basic (str "a") (str "b"))
        ]


boundaryChunksSuite : Test
boundaryChunksSuite =
    describe "compareAlphanumeric boundary chunks (filter-removal regression)"
        [ test "handles leading digit groups" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal GT (cmp SortFn.alphanumeric (str "1abc") (str "abc1"))
                    , \_ -> Expect.equal LT (cmp SortFn.alphanumeric (str "abc1") (str "1abc"))
                    , \_ -> Expect.equal LT (cmp SortFn.alphanumeric (str "2abc") (str "10abc"))
                    ]
                    ()
        , test "handles pure digit strings (leading and trailing empties)" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal EQ (cmp SortFn.alphanumeric (str "12") (str "12"))
                    , \_ -> Expect.equal LT (cmp SortFn.alphanumeric (str "2") (str "10"))
                    , \_ -> Expect.equal GT (cmp SortFn.alphanumeric (str "10") (str "2"))
                    ]
                    ()
        , test "treats leading zeros as numerically equal" <|
            \_ ->
                Expect.equal EQ (cmp SortFn.alphanumeric (str "item007") (str "item7"))
        , test "counts only non-empty chunks in the prefix tail" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal LT (cmp SortFn.alphanumeric (str "1") (str "1abc"))
                    , \_ -> Expect.equal GT (cmp SortFn.alphanumeric (str "1abc") (str "1"))
                    , \_ -> Expect.equal LT (cmp SortFn.alphanumeric (str "abc") (str "abc123"))
                    ]
                    ()
        , test "handles empty vs non-empty strings" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal LT (cmp SortFn.alphanumeric (str "") (str "a"))
                    , \_ -> Expect.equal GT (cmp SortFn.alphanumeric (str "a") (str ""))
                    ]
                    ()
        , test "matches the previous filter-based implementation across all vocab pairs" <|
            \_ ->
                vocab
                    |> List.concatMap (\a -> List.map (Tuple.pair a) vocab)
                    |> List.filter
                        (\( a, b ) ->
                            cmp SortFn.alphanumericCaseSensitive (str a) (str b)
                                /= referenceCompare a b
                        )
                    |> Expect.equal []
        ]


{-| The vocabulary from the vitest file, compared pair by pair against a port
of the pre-refactor `split(/([0-9]+)/gm).filter(Boolean)` implementation.
-}
vocab : List String
vocab =
    [ ""
    , "a"
    , "ab"
    , "1"
    , "0"
    , "12"
    , "007"
    , "7"
    , "1a"
    , "a1"
    , "1a1"
    , "a1a"
    , "1a2b"
    , "a1b2"
    , "12ab34"
    , "ab12cd"
    , "item2"
    , "item10"
    , "2item"
    , "10item"
    , "a007b"
    , "a7b"
    , "nan"
    , "infinity"
    , "999999999999999999999999999999"
    ]


referenceCompare : String -> String -> Order
referenceCompare a b =
    referenceLoop (referenceChunks a) (referenceChunks b)


referenceChunks : String -> List String
referenceChunks value =
    List.filter (\chunk -> chunk /= "") (SortFn.splitAlphaNumeric value)


referenceLoop : List String -> List String -> Order
referenceLoop left right =
    case ( left, right ) of
        ( a :: restA, b :: restB ) ->
            case ( String.toFloat a, String.toFloat b ) of
                ( Nothing, Nothing ) ->
                    if a > b then
                        GT

                    else if b > a then
                        LT

                    else
                        referenceLoop restA restB

                ( Nothing, Just _ ) ->
                    LT

                ( Just _, Nothing ) ->
                    GT

                ( Just an, Just bn ) ->
                    if an > bn then
                        GT

                    else if bn > an then
                        LT

                    else
                        referenceLoop restA restB

        _ ->
            Basics.compare (List.length left) (List.length right)


datetimeSuite : Test
datetimeSuite =
    describe "sortFn_datetime"
        [ test "returns 0 for equal dates" <|
            \_ ->
                let
                    d =
                        date 1770000000000
                in
                Expect.equal EQ (cmp SortFn.datetime d d)
        , test "compares dates by chronology" <|
            \_ ->
                let
                    earlier =
                        date 1770000000000

                    later =
                        date 1770086400000
                in
                Expect.all
                    [ \_ -> Expect.equal LT (cmp SortFn.datetime earlier later)
                    , \_ -> Expect.equal GT (cmp SortFn.datetime later earlier)
                    ]
                    ()
        , test "compares numeric timestamps" <|
            \_ ->
                Expect.equal LT (cmp SortFn.datetime (num 1000) (num 2000))
        , test "compares dates and numeric timestamps by time" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal GT (cmp SortFn.datetime (date 2000) (num 1000))
                    , \_ -> Expect.equal LT (cmp SortFn.datetime (num 1000) (date 2000))
                    ]
                    ()
        , test "preserves string fallback comparisons" <|
            \_ ->
                Expect.equal LT (cmp SortFn.datetime (str "2026-01-01") (str "2026-02-01"))
        , test "keeps invalid dates equal-like under relational comparison" <|
            \_ ->
                -- `Time.Posix` cannot hold `new Date(NaN)`, so the invalid date
                -- is ported as the NaN timestamp it resolves to.
                Expect.equal EQ (cmp SortFn.datetime (num nan) (num 1000))
        ]


date : Int -> Value
date millis =
    Value.Date (Time.millisToPosix millis)


splitSuite : Test
splitSuite =
    describe "reSplitAlphaNumeric"
        [ test "should keep plain text as a single segment" <|
            \_ ->
                Expect.equal [ "apple" ] (SortFn.splitAlphaNumeric "apple")
        , test "should capture numeric runs as their own segments" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal [ "item", "10", "" ] (SortFn.splitAlphaNumeric "item10")
                    , \_ -> Expect.equal [ "a", "1", "b", "22", "c" ] (SortFn.splitAlphaNumeric "a1b22c")
                    ]
                    ()
        , test "should handle leading digits and empty strings" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal [ "", "10", "abc" ] (SortFn.splitAlphaNumeric "10abc")
                    , \_ -> Expect.equal [ "" ] (SortFn.splitAlphaNumeric "")
                    ]
                    ()
        ]


constructSortFnSuite : Test
constructSortFnSuite =
    describe "constructSortFn"
        [ test "sorts names with diacritics next to their plain counterparts" <|
            \_ ->
                [ "Zak O'Sullivan"
                , "Éric Bernard"
                , "Enrico Toccacelo"
                , "Eric Brandon"
                , "Fred Wacker"
                ]
                    |> List.map str
                    |> List.sortWith (cmp alphanumericIgnoreDiacritics)
                    |> List.map Value.toString
                    |> Expect.equal
                        [ "Enrico Toccacelo"
                        , "Éric Bernard"
                        , "Eric Brandon"
                        , "Fred Wacker"
                        , "Zak O'Sullivan"
                        ]
        , test "keeps the base behavior for values without diacritics" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal LT (cmp alphanumericIgnoreDiacritics (str "item2") (str "item10"))
                    , \_ -> Expect.equal EQ (cmp alphanumericIgnoreDiacritics (str "ABC") (str "abc"))
                    ]
                    ()
        , test "sorts diacritics last with the unmodified base sort fn" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal GT (cmp SortFn.alphanumeric (str "Éric Bernard") (str "Zak"))
                    , \_ -> Expect.equal LT (cmp alphanumericIgnoreDiacritics (str "Éric Bernard") (str "Zak"))
                    ]
                    ()
        , test "honors resolveDataValue assigned after creation" <|
            \_ ->
                let
                    bySecondWord =
                        SortFn.text
                            |> SortFn.withResolveDataValue
                                (\value ->
                                    String.split " " (Value.toString value)
                                        |> List.drop 1
                                        |> List.head
                                        |> Maybe.withDefault ""
                                        |> Value.String
                                )
                in
                Expect.equal LT (cmp bySecondWord (str "Zak Adams") (str "Al Zimmer"))
        ]


{-| The PR-6241 use case: an ignore-diacritics variant of a built-in sort fn,
built by wrapping the base fn's `resolveDataValue`.
-}
alphanumericIgnoreDiacritics : SortFn
alphanumericIgnoreDiacritics =
    SortFn.alphanumeric
        |> SortFn.withResolveDataValue
            (\value ->
                SortFn.resolveDataValue SortFn.alphanumeric value
                    |> Value.toString
                    |> stripDiacritics
                    |> Value.String
            )


{-| `value.normalize('NFD').replace(/\p{Diacritic}/gu, '')` for the letters the
ported tests use. Elm has no Unicode normalisation in core.
-}
stripDiacritics : String -> String
stripDiacritics =
    String.map
        (\c ->
            case c of
                'é' ->
                    'e'

                'É' ->
                    'E'

                'ë' ->
                    'e'

                'Ë' ->
                    'E'

                _ ->
                    c
        )
