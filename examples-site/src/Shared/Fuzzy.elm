module Shared.Fuzzy exposing
    ( Ranking, Rank(..)
    , rankItem, compareRankings
    )

{-| A small stand-in for `@tanstack/match-sorter-utils`, which the fuzzy
filters example uses for `rankItem` and `compareItems`.

Ranking is case-insensitive and coarse: an exact match beats a prefix, a
prefix beats a substring, and a substring beats a plain subsequence. That is
enough to drive a filter (`passed`) and a sort (`rank`), which is all the
example asks of it.

@docs Ranking, Rank
@docs rankItem, compareRankings

-}


{-| How well one value matched, best first when compared with
[`compareRankings`](#compareRankings).
-}
type Rank
    = NoMatch
    | Subsequence
    | Contains
    | StartsWith
    | Exact


{-| `RankingInfo`: the rank plus whether the item should be kept.
-}
type alias Ranking =
    { rank : Rank
    , passed : Bool
    }


{-| `rankItem(value, search)`.

An empty search passes everything, exactly as match-sorter does, and ranks
it as `NoMatch` so it does not disturb an existing order.

-}
rankItem : String -> String -> Ranking
rankItem value search =
    let
        needle : String
        needle =
            String.toLower (String.trim search)

        haystack : String
        haystack =
            String.toLower value
    in
    if needle == "" then
        { rank = NoMatch, passed = True }

    else if haystack == needle then
        { rank = Exact, passed = True }

    else if String.startsWith needle haystack then
        { rank = StartsWith, passed = True }

    else if String.contains needle haystack then
        { rank = Contains, passed = True }

    else if isSubsequence (String.toList needle) (String.toList haystack) then
        { rank = Subsequence, passed = True }

    else
        { rank = NoMatch, passed = False }


isSubsequence : List Char -> List Char -> Bool
isSubsequence needle haystack =
    case ( needle, haystack ) of
        ( [], _ ) ->
            True

        ( _, [] ) ->
            False

        ( n :: needleRest, h :: haystackRest ) ->
            if n == h then
                isSubsequence needleRest haystackRest

            else
                isSubsequence needle haystackRest


{-| `compareItems(a, b)`: the better match sorts first.
-}
compareRankings : Ranking -> Ranking -> Order
compareRankings a b =
    Basics.compare (score b.rank) (score a.rank)


score : Rank -> Int
score rank =
    case rank of
        NoMatch ->
            0

        Subsequence ->
            1

        Contains ->
            2

        StartsWith ->
            3

        Exact ->
            4
