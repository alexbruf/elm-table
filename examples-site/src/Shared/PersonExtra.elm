module Shared.PersonExtra exposing (phone, city, country, department, salary)

{-| The extra fields `examples/react/cell-selection/src/makeData.ts` adds to
its `Person` — twice the usual field count, so there are enough columns to
hide, reorder, and pin while a cell selection is active.

`Shared.People.Person` stays one type for every example, so these are
derived deterministically from the person that `Shared.People.makeData`
already generated: same seed, same values, no second generator.

@docs phone, city, country, department, salary

-}

import Shared.People exposing (Person)


{-| A US-shaped phone number.
-}
phone : Person -> String
phone person =
    let
        n : Int
        n =
            hash ("phone" ++ person.id ++ person.email)
    in
    "("
        ++ pad 3 (200 + modBy 800 n)
        ++ ") "
        ++ pad 3 (200 + modBy 800 (n // 7))
        ++ "-"
        ++ pad 4 (modBy 10000 (n // 13))


{-| A city name.
-}
city : Person -> String
city person =
    pick cities (hash ("city" ++ person.id ++ person.email))


{-| A country name.
-}
country : Person -> String
country person =
    pick countries (hash ("country" ++ person.id ++ person.email))


{-| A commerce department name.
-}
department : Person -> String
department person =
    pick departments (hash ("department" ++ person.id ++ person.email))


{-| A salary between 40,000 and 200,000.
-}
salary : Person -> Int
salary person =
    40000 + modBy 160001 (hash ("salary" ++ person.id ++ person.email))


cities : List String
cities =
    [ "Amsterdam", "Austin", "Berlin", "Boston", "Chicago", "Denver", "Dublin", "Lisbon", "London", "Madrid", "Melbourne", "Montreal", "Oslo", "Paris", "Portland", "Prague", "Seattle", "Seoul", "Tokyo", "Toronto" ]


countries : List String
countries =
    [ "Australia", "Canada", "Czechia", "France", "Germany", "Ireland", "Japan", "Netherlands", "Norway", "Portugal", "South Korea", "Spain", "United Kingdom", "United States" ]


departments : List String
departments =
    [ "Automotive", "Books", "Clothing", "Electronics", "Garden", "Grocery", "Health", "Home", "Industrial", "Jewelry", "Kids", "Movies", "Music", "Outdoors", "Shoes", "Sports", "Tools", "Toys" ]


pick : List String -> Int -> String
pick options n =
    List.drop (modBy (List.length options) n) options
        |> List.head
        |> Maybe.withDefault ""


pad : Int -> Int -> String
pad width n =
    String.padLeft width '0' (String.fromInt n)


hash : String -> Int
hash text =
    String.foldl (\char acc -> modBy 2147483647 (acc * 31 + Char.toCode char)) 7 text
