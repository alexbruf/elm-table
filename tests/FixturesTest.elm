module FixturesTest exposing (suite)

{-| Phase 0 placeholder: checks the fixture generator shape.
-}

import Expect
import Fixtures
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Fixtures"
        [ test "staticData has three people" <|
            \_ ->
                Fixtures.staticData
                    |> List.map .firstName
                    |> Expect.equal [ "John", "Jane", "Alice" ]
        , test "makeData [3, 2] builds 3 parents with 2 sub-rows each" <|
            \_ ->
                Fixtures.makeData [ 3, 2 ]
                    |> List.map (Fixtures.subRowsOf >> List.length)
                    |> Expect.equal [ 2, 2, 2 ]
        , test "makeData ids are unique across the tree" <|
            \_ ->
                let
                    ids =
                        Fixtures.makeData [ 4, 3, 2 ]
                            |> flatten
                            |> List.map .id
                in
                Expect.equal (List.length ids) (List.length (unique ids))
        , test "statusToString matches the TypeScript literals" <|
            \_ ->
                Fixtures.staticData
                    |> List.map (.status >> Fixtures.statusToString)
                    |> Expect.equal [ "relationship", "complicated", "single" ]
        , test "makeData is deterministic" <|
            \_ ->
                Expect.equal (Fixtures.makeData [ 5 ]) (Fixtures.makeData [ 5 ])
        ]


flatten : List Fixtures.Person -> List Fixtures.Person
flatten people =
    List.concatMap (\p -> p :: flatten (Fixtures.subRowsOf p)) people


unique : List String -> List String
unique =
    List.foldl
        (\x acc ->
            if List.member x acc then
                acc

            else
                x :: acc
        )
        []
