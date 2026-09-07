module Aggregation.Sales exposing (Sale, makeData)

{-| The Elm counterpart of `makeData.ts` in
`examples/react/aggregation`: sales rows, not people.

@docs Sale, makeData

-}

import Random exposing (Generator)


{-| One row.
-}
type alias Sale =
    { id : String
    , category : String
    , item : String
    , amount : Float
    , score : Float
    }


{-| `makeData length`, with a seed instead of faker's global one.
-}
makeData : Int -> Int -> List Sale
makeData seed length =
    Random.step (sales length) (Random.initialSeed seed)
        |> Tuple.first


sales : Int -> Generator (List Sale)
sales length =
    List.range 0 (length - 1)
        |> List.map (\index -> Random.map (\one -> { one | id = String.fromInt index }) sale)
        |> List.foldr (Random.map2 (::)) (Random.constant [])


sale : Generator Sale
sale =
    Random.map4
        (\category ( adjective, noun ) amount score ->
            { id = ""
            , category = category
            , item = adjective ++ " " ++ noun
            , amount = toFloat amount
            , score = toFloat score
            }
        )
        (Random.uniform "Hardware" [ "Software", "Services" ])
        (Random.map2 Tuple.pair
            (Random.uniform "Ergonomic" adjectives)
            (Random.uniform "Chair" nouns)
        )
        (Random.int 25 5000)
        (Random.int 60 100)


adjectives : List String
adjectives =
    [ "Handcrafted", "Refined", "Practical", "Sleek", "Rustic", "Awesome", "Generic", "Licensed", "Fantastic", "Small" ]


nouns : List String
nouns =
    [ "Table", "Keyboard", "Mouse", "Bench", "Lamp", "Bottle", "Shirt", "Gloves", "Ball", "Hat" ]
