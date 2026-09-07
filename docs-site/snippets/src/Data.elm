module Data exposing (..)

import Array
import Shared.People exposing (Person, people)
import Table
import Table.Value as Value


type alias Employee =
    { name : { first : String, last : String }
    , info : { age : Int, visits : Int }
    }


type Category
    = Category
        { id : String
        , name : String
        , total : Float
        , children : List Category
        }


nestedColumns : List (Table.Column Employee)
nestedColumns =
    [ Table.column "firstName" (.name >> .first >> Value.String)
        |> Table.withHeader "First name"
    , Table.column "lastName" (.name >> .last >> Value.String)
        |> Table.withHeader "Last name"
    , Table.column "age" (.info >> .age >> toFloat >> Value.Number)
        |> Table.withHeader "Age"
    ]


categoryConfig : Table.Config Category
categoryConfig =
    Table.config
        [ Table.column "name" (\(Category c) -> Value.String c.name)
            |> Table.withHeader "Name"
        , Table.column "total" (\(Category c) -> Value.Number c.total)
            |> Table.withHeader "Total"
        ]
        |> Table.withSubRows (\(Category c) -> c.children)
        |> Table.withGetRowId (\(Category c) _ _ -> c.id)


stableIds : Table.Config Person
stableIds =
    Table.config [ Table.column "firstName" (.firstName >> Value.String) ]
        |> Table.withGetRowId (\person _ _ -> person.id)


fromList : Table.State -> Table.RowModel Person
fromList state =
    Table.rowsFromList stableIds state people


fromArray : Table.State -> Table.RowModel Person
fromArray state =
    Table.rows stableIds state (Array.fromList people)
