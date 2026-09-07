module FiltersFacetedBucketed.Accounts exposing
    ( Account
    , makeData, referenceDate
    , formatBytes
    )

{-| The Elm counterpart of `makeData.ts` in
`examples/react/filters-faceted-bucketed`.

That example does not use the `Person` shape the rest of the examples share:
it needs a continuous date and a continuous size so the bucket filters have
something to bucket.

`dataReferenceDate` is `new Date()` there. The site compiles without flags,
so the reference is a fixed instant here and the data is generated relative
to it, which keeps the "Today" and "This week" buckets meaningful.

@docs Account
@docs makeData, referenceDate
@docs formatBytes

-}

import Random exposing (Generator)
import Shared.People as People
import Time


{-| One row.
-}
type alias Account =
    { id : String
    , name : String
    , lastLogin : Time.Posix
    , storageBytes : Float
    , files : Int
    }


{-| `dataReferenceDate`: 2025-06-15T12:00:00Z.
-}
referenceDate : Time.Posix
referenceDate =
    Time.millisToPosix 1749988800000


{-| `makeData seed len`.
-}
makeData : Int -> Int -> List Account
makeData seed len =
    Random.step (accounts len) (Random.initialSeed seed)
        |> Tuple.first


accounts : Int -> Generator (List Account)
accounts len =
    List.range 0 (len - 1)
        |> List.map
            (\index ->
                Random.map (\one -> { one | id = String.fromInt index }) account
            )
        |> List.foldr (Random.map2 (::)) (Random.constant [])


account : Generator Account
account =
    Random.map4
        (\first last ageAndStorage files ->
            let
                ( ageInDays, storageInGb ) =
                    ageAndStorage
            in
            { id = ""
            , name = first ++ " " ++ last
            , lastLogin =
                Time.millisToPosix
                    (Time.posixToMillis referenceDate
                        - round (ageInDays * 24 * 60 * 60 * 1000)
                    )
            , storageBytes = storageInGb * gigabyte
            , files = files
            }
        )
        (Random.uniform "Tanner" People.firstNames)
        (Random.uniform "Linsley" People.lastNames)
        (Random.map2 Tuple.pair
            -- `faker.number.float({ min: 0, max: 1 }) ** 2 * 400`
            (Random.map (\x -> x * x * 400) (Random.float 0 1))
            -- `0.05 * 10 ** faker.number.float({ min: 0, max: 4 })`
            (Random.map (\e -> 0.05 * 10 ^ e) (Random.float 0 4))
        )
        (Random.int 0 50000)


gigabyte : Float
gigabyte =
    1024 * 1024 * 1024


{-| `formatBytes` from the React example.
-}
formatBytes : Float -> String
formatBytes value =
    if value < gigabyte then
        String.fromInt (round (value / (1024 * 1024))) ++ " MB"

    else
        oneDecimal (value / gigabyte) ++ " GB"


oneDecimal : Float -> String
oneDecimal value =
    let
        tenths : Int
        tenths =
            round (value * 10)
    in
    String.fromInt (tenths // 10) ++ "." ++ String.fromInt (modBy 10 tenths)
