module Data exposing
    ( Intent(..)
    , Keyword
    , Variant
    , allIntents
    , generate
    , intentFromLabel
    , intentLabel
    , rowCount
    , subRows
    )

{-| The demo dataset: a keyword report generated in Elm from one integer seed.

Nothing here is fetched. `generate` is a pure function of the seed and of the
reference time, so the same seed always gives the same 5,000 rows.

-}

import Array exposing (Array)
import Random
import Time


{-| How many top-level rows a dataset holds.
-}
rowCount : Int
rowCount =
    5000


{-| What a searcher seems to want.
-}
type Intent
    = Informational
    | Commercial
    | Transactional
    | Navigational


{-| A query variant that shares its parent's cluster.
-}
type alias Variant =
    { keyword : String
    , searchVolume : Int
    , position : Int
    }


{-| One row of the report.
-}
type alias Keyword =
    { keyword : String
    , cluster : String
    , intent : Intent
    , searchVolume : Int
    , difficulty : Int
    , position : Int
    , previousPosition : Int
    , change : Int
    , url : String
    , lastCrawled : Time.Posix
    , variants : List Variant
    }


{-| Every intent, in reading order.
-}
allIntents : List Intent
allIntents =
    [ Informational, Commercial, Transactional, Navigational ]


{-| The label shown in the table and used as the enum filter value.
-}
intentLabel : Intent -> String
intentLabel intent =
    case intent of
        Informational ->
            "Informational"

        Commercial ->
            "Commercial"

        Transactional ->
            "Transactional"

        Navigational ->
            "Navigational"


{-| The reverse of `intentLabel`.
-}
intentFromLabel : String -> Maybe Intent
intentFromLabel label =
    case label of
        "Informational" ->
            Just Informational

        "Commercial" ->
            Just Commercial

        "Transactional" ->
            Just Transactional

        "Navigational" ->
            Just Navigational

        _ ->
            Nothing


{-| A variant read as a row of its own, for `Table.withSubRows`.
-}
subRows : Keyword -> List Keyword
subRows parent =
    List.map (variantRow parent) parent.variants


variantRow : Keyword -> Variant -> Keyword
variantRow parent variant =
    { keyword = variant.keyword
    , cluster = parent.cluster
    , intent = parent.intent
    , searchVolume = variant.searchVolume
    , difficulty = parent.difficulty
    , position = variant.position
    , previousPosition = variant.position
    , change = 0
    , url = parent.url
    , lastCrawled = parent.lastCrawled
    , variants = []
    }



-- GENERATION


{-| 5,000 rows from one seed. `now` anchors the crawl dates, which land in
the 90 days before it.
-}
generate : Int -> Time.Posix -> Array Keyword
generate seed now =
    Random.step (Random.list rowCount (rawGen |> Random.map (toKeyword now))) (Random.initialSeed seed)
        |> Tuple.first
        |> Array.fromList


type alias Raw =
    { clusterIx : Int
    , modifierIx : Int
    , tailIx : Int
    , intent : Intent
    , volumeIx : Int
    , difficulty : Int
    , position : Int
    , delta : Int
    , daysAgo : Int
    , secondOfDay : Int
    , variantCount : Int
    , variantPicks : List ( Int, Int, Int )
    }


andMap : Random.Generator a -> Random.Generator (a -> b) -> Random.Generator b
andMap =
    Random.map2 (|>)


rawGen : Random.Generator Raw
rawGen =
    Random.constant Raw
        |> andMap (Random.int 0 (List.length clusters - 1))
        |> andMap (Random.int 0 (List.length modifiers - 1))
        |> andMap (Random.int 0 (List.length tails - 1))
        |> andMap intentGen
        |> andMap (Random.int 0 999)
        |> andMap (Random.int 0 100)
        |> andMap (Random.int 1 100)
        |> andMap (Random.int -12 12)
        |> andMap (Random.int 0 89)
        |> andMap (Random.int 0 86399)
        |> andMap (Random.weighted ( 45, 0 ) [ ( 25, 1 ), ( 18, 2 ), ( 12, 3 ) ])
        |> andMap
            (Random.list 3
                (Random.map3 (\a b c -> ( a, b, c ))
                    (Random.int 0 (List.length variantTails - 1))
                    (Random.int 0 999)
                    (Random.int 1 100)
                )
            )


intentGen : Random.Generator Intent
intentGen =
    Random.weighted ( 44, Informational )
        [ ( 28, Commercial ), ( 18, Transactional ), ( 10, Navigational ) ]


toKeyword : Time.Posix -> Raw -> Keyword
toKeyword now raw =
    let
        cluster : String
        cluster =
            pick clusters raw.clusterIx

        modifier : String
        modifier =
            pick modifiers raw.modifierIx

        tail : String
        tail =
            pick tails raw.tailIx

        phrase : String
        phrase =
            joinWords [ modifier, cluster, tail ]

        previous : Int
        previous =
            clamp 1 100 (raw.position + raw.delta)
    in
    { keyword = phrase
    , cluster = cluster
    , intent = raw.intent
    , searchVolume = volumeOf raw.volumeIx
    , difficulty = raw.difficulty
    , position = raw.position
    , previousPosition = previous
    , change = previous - raw.position
    , url = "https://example.com/" ++ slug cluster ++ "/" ++ slug (joinWords [ modifier, tail ])
    , lastCrawled = crawledAt now raw.daysAgo raw.secondOfDay
    , variants =
        List.take raw.variantCount raw.variantPicks
            |> List.map (\( ti, vi, pos ) -> Variant (joinWords [ cluster, pick variantTails ti ]) (volumeOf vi // 4 + 10) pos)
    }


{-| A long tail: most keywords are small, a few are large.
-}
volumeOf : Int -> Int
volumeOf index =
    20 + (index * index) // 42


crawledAt : Time.Posix -> Int -> Int -> Time.Posix
crawledAt now daysAgo secondOfDay =
    Time.millisToPosix
        (Time.posixToMillis now - (daysAgo * 86400000) - (secondOfDay * 1000))


pick : List String -> Int -> String
pick list index =
    List.drop index list |> List.head |> Maybe.withDefault ""


joinWords : List String -> String
joinWords parts =
    parts
        |> List.filter (\part -> part /= "")
        |> String.join " "


slug : String -> String
slug text =
    if text == "" then
        "index"

    else
        String.replace " " "-" text



-- VOCABULARY


clusters : List String
clusters =
    [ "project management software"
    , "time tracking app"
    , "invoice generator"
    , "expense reports"
    , "payroll software"
    , "crm for small business"
    , "email marketing"
    , "landing page builder"
    , "seo audit tool"
    , "keyword research"
    , "backlink checker"
    , "rank tracker"
    , "site speed test"
    , "web analytics"
    , "heatmap software"
    , "split testing tool"
    , "form builder"
    , "survey tool"
    , "help desk software"
    , "live chat widget"
    , "knowledge base"
    , "ticketing system"
    , "video conferencing"
    , "screen recorder"
    , "password manager"
    , "vpn service"
    , "cloud storage"
    , "file transfer"
    , "backup software"
    , "antivirus software"
    , "photo editor"
    , "video editor"
    , "logo maker"
    , "font pairing"
    , "stock photos"
    , "icon library"
    , "web hosting"
    , "domain registrar"
    , "ssl certificate"
    , "website builder"
    ]


modifiers : List String
modifiers =
    [ ""
    , ""
    , "free"
    , "cheap"
    , "online"
    , "simple"
    , "open source"
    , "self hosted"
    , "team"
    , "mobile"
    ]


tails : List String
tails =
    [ ""
    , ""
    , "pricing"
    , "review"
    , "alternatives"
    , "for freelancers"
    , "for agencies"
    , "comparison"
    , "tutorial"
    , "examples"
    , "cost per month"
    , "free trial"
    , "for mac"
    , "for windows"
    , "checklist"
    ]


variantTails : List String
variantTails =
    [ "near me"
    , "reddit"
    , "uk"
    , "app"
    , "guide"
    , "download"
    , "login"
    , "demo"
    ]
