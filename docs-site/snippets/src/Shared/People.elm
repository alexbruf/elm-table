module Shared.People exposing (Person, people)

{-| The fixture every snippet module shares, so the snippets themselves stay
about one idea each. Not shown in the docs.
-}


type alias Person =
    { id : String
    , firstName : String
    , lastName : String
    , department : String
    , age : Int
    , salary : Float
    , active : Bool
    , tags : List String
    }


people : List Person
people =
    [ Person "1" "Ada" "Lovelace" "Engineering" 36 98000 True [ "founder" ]
    , Person "2" "Grace" "Hopper" "Engineering" 45 112000 True [ "navy", "compilers" ]
    , Person "3" "Katherine" "Johnson" "Engineering" 41 105000 False [ "nasa" ]
    , Person "4" "Susan" "Kare" "Design" 34 89000 True [ "icons" ]
    , Person "5" "Jony" "Ive" "Design" 47 130000 True []
    , Person "6" "Mary" "Barra" "Sales" 44 91000 False [ "auto" ]
    ]
