module Fixtures exposing
    ( Person, Status(..), SubRows(..)
    , staticData, makeData
    , statusToString, subRowsOf
    )

{-| Typed counterpart of `tests/fixtures/data/types.ts` and
`tests/fixtures/data/generateTestData.ts` in the TanStack repo.

`makeData [ 3, 2 ]` builds 3 parent rows with 2 sub-rows each, like
`generateTestData(3, 2)`. Generation is deterministic (a small linear
congruential generator seeded per call) so tests are reproducible.

@docs Person, Status, SubRows
@docs staticData, makeData
@docs statusToString, subRowsOf

-}


{-| Mirrors the `Person` type. `subRows` is empty instead of `undefined`.
Elm forbids recursive type aliases, so the children are wrapped in `SubRows`.
-}
type alias Person =
    { id : String
    , firstName : String
    , lastName : String
    , age : Int
    , visits : Int
    , progress : Int
    , status : Status
    , subRows : SubRows
    }


{-| Wrapper that makes the recursive `Person` record legal.
-}
type SubRows
    = SubRows (List Person)


{-| Unwrap a person's sub-rows.
-}
subRowsOf : Person -> List Person
subRowsOf person =
    case person.subRows of
        SubRows rows ->
            rows


{-| `'relationship' | 'complicated' | 'single'`
-}
type Status
    = Relationship
    | Complicated
    | Single


{-| The string form used by the TypeScript fixtures.
-}
statusToString : Status -> String
statusToString status =
    case status of
        Relationship ->
            "relationship"

        Complicated ->
            "complicated"

        Single ->
            "single"


{-| Mirrors `getStaticTestData()`.
-}
staticData : List Person
staticData =
    [ Person "1" "John" "Doe" 30 100 50 Relationship (SubRows [])
    , Person "2" "Jane" "Smith" 25 200 75 Complicated (SubRows [])
    , Person "3" "Alice" "Johnson" 35 150 60 Single (SubRows [])
    ]


{-| Mirrors `generateTestData(...lengths)`. Each number is the count of rows
at that depth. Ids are unique across the whole tree.
-}
makeData : List Int -> List Person
makeData lengths =
    makeLevel lengths 12345 ""
        |> Tuple.first


makeLevel : List Int -> Int -> String -> ( List Person, Int )
makeLevel lengths seed idPrefix =
    case lengths of
        [] ->
            ( [], seed )

        len :: rest ->
            List.range 0 (len - 1)
                |> List.foldl
                    (\i ( acc, s ) ->
                        let
                            id =
                                idPrefix ++ String.fromInt i

                            ( person, s1 ) =
                                makePerson id s

                            ( subRows, s2 ) =
                                makeLevel rest s1 (id ++ ".")
                        in
                        ( { person | subRows = SubRows subRows } :: acc, s2 )
                    )
                    ( [], seed )
                |> Tuple.mapFirst List.reverse


makePerson : String -> Int -> ( Person, Int )
makePerson id seed =
    let
        ( first, s1 ) =
            pick "John" firstNames seed

        ( last, s2 ) =
            pick "Doe" lastNames s1

        ( age, s3 ) =
            nextInt 40 s2

        ( visits, s4 ) =
            nextInt 1000 s3

        ( progress, s5 ) =
            nextInt 100 s4

        ( status, s6 ) =
            pick Relationship [ Complicated, Single ] s5
    in
    ( Person id first last age visits progress status (SubRows []), s6 )


nextInt : Int -> Int -> ( Int, Int )
nextInt bound seed =
    let
        next =
            modBy 2147483647 (seed * 48271)
    in
    ( modBy bound (next // 7), next )


pick : a -> List a -> Int -> ( a, Int )
pick first rest seed =
    let
        ( i, next ) =
            nextInt (1 + List.length rest) seed
    in
    case List.drop i (first :: rest) of
        x :: _ ->
            ( x, next )

        [] ->
            ( first, next )


firstNames : List String
firstNames =
    [ "Jane", "Alice", "Bob", "Carol", "Dave", "Eve", "Frank", "Grace", "Heidi", "Ivan", "Judy", "Mallory", "Niaj", "Olivia", "Peggy" ]


lastNames : List String
lastNames =
    [ "Smith", "Johnson", "Brown", "Williams", "Jones", "Miller", "Davis", "Garcia", "Rodriguez", "Wilson", "Martinez", "Anderson", "Taylor", "Thomas", "Moore" ]
