module Shared.People exposing
    ( Person, Status(..), SubRows(..)
    , makeData, subRowsOf, statusToString
    , firstNames, lastNames
    )

{-| The Elm counterpart of `makeData.ts` in the TanStack examples: a
deterministic `Person` generator driven by `elm/random`.

    makeData 42 [ 1000 ]          -- 1000 flat rows
    makeData 42 [ 100, 5, 3 ]     -- 100 rows, 5 sub-rows each, 3 sub-sub-rows each

Like the TypeScript, `lastName` and `visits` are missing about one time in
ten so examples can show `Null` handling.

@docs Person, Status, SubRows
@docs makeData, subRowsOf, statusToString
@docs firstNames, lastNames

-}

import Random exposing (Generator)
import Time


type alias Person =
    { id : String
    , firstName : String
    , lastName : Maybe String
    , email : String
    , age : Int
    , visits : Maybe Int
    , progress : Int
    , status : Status
    , rank : Int
    , createdAt : Time.Posix
    , subRows : SubRows
    }


type Status
    = Relationship
    | Complicated
    | Single


{-| Elm forbids recursive type aliases, so the children are wrapped.
-}
type SubRows
    = SubRows (List Person)


subRowsOf : Person -> List Person
subRowsOf p =
    case p.subRows of
        SubRows rows ->
            rows


statusToString : Status -> String
statusToString status =
    case status of
        Relationship ->
            "relationship"

        Complicated ->
            "complicated"

        Single ->
            "single"


{-| `makeData seed lengths`: one count per depth, ids are index paths
(`"3"`, `"3.1"`, ...).
-}
makeData : Int -> List Int -> List Person
makeData seed lengths =
    Random.step (level lengths "") (Random.initialSeed seed)
        |> Tuple.first


level : List Int -> String -> Generator (List Person)
level lengths prefix =
    case lengths of
        [] ->
            Random.constant []

        len :: rest ->
            List.range 0 (len - 1)
                |> List.map
                    (\i ->
                        let
                            id =
                                prefix ++ String.fromInt i
                        in
                        Random.map2 (\p subs -> { p | id = id, subRows = SubRows subs })
                            personGenerator
                            (level rest (id ++ "."))
                    )
                |> sequence


sequence : List (Generator a) -> Generator (List a)
sequence gens =
    List.foldr (Random.map2 (::)) (Random.constant []) gens


personGenerator : Generator Person
personGenerator =
    Random.map5
        (\first last age visits progress ->
            { id = ""
            , firstName = first
            , lastName = last
            , email = ""
            , age = age
            , visits = visits
            , progress = progress
            , status = Single
            , rank = 0
            , createdAt = Time.millisToPosix 0
            , subRows = SubRows []
            }
        )
        (pick "Tanner" firstNames)
        (maybeOneInTen (pick "Linsley" lastNames))
        (Random.int 0 40)
        (maybeOneInTen (Random.int 0 1000))
        (Random.int 0 100)
        |> Random.andThen
            (\p ->
                Random.map4
                    (\status rank createdAt emailNumber ->
                        { p
                            | status = status
                            , rank = rank
                            , createdAt = Time.millisToPosix createdAt
                            , email =
                                String.toLower
                                    (p.firstName
                                        ++ "."
                                        ++ Maybe.withDefault "unknown" p.lastName
                                        ++ String.fromInt emailNumber
                                        ++ "@example.com"
                                    )
                        }
                    )
                    (pick Single [ Relationship, Complicated ])
                    (Random.int 0 100)
                    (Random.int 1262304000000 1767225600000)
                    (Random.int 0 9999)
            )


maybeOneInTen : Generator a -> Generator (Maybe a)
maybeOneInTen gen =
    Random.int 0 9
        |> Random.andThen
            (\n ->
                if n == 0 then
                    Random.constant Nothing

                else
                    Random.map Just gen
            )


pick : a -> List a -> Generator a
pick first rest =
    Random.uniform first rest


firstNames : List String
firstNames =
    [ "Tandy", "Joe", "Kevin", "Alice", "Bob", "Carol", "Dave", "Eve", "Frank", "Grace", "Heidi", "Ivan", "Judy", "Mallory", "Niaj", "Olivia", "Peggy", "Rupert", "Sybil", "Trent", "Victor", "Walter", "Wendy", "Yuki", "Zoe" ]


lastNames : List String
lastNames =
    [ "Miller", "Dirte", "Vandy", "Smith", "Johnson", "Brown", "Williams", "Jones", "Davis", "Garcia", "Rodriguez", "Wilson", "Martinez", "Anderson", "Taylor", "Thomas", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson", "White", "Harris", "Clark" ]
