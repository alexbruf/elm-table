port module Bench exposing (main)

{-| Timing harness for `Table.coreRowModel`.

`run.js` sends a command through the `request` port, this program does the
work inside the subscription handler and answers through `response`, and the
JavaScript side times the round trip with `performance.now()`.

-}

import Array exposing (Array)
import Dict
import Platform
import Table
import Table.Value as Value


port request : (String -> msg) -> Sub msg


port response : String -> Cmd msg


type alias Person =
    { id : String
    , firstName : String
    , lastName : String
    , age : Int
    , visits : Int
    , progress : Int
    , status : String
    , subRows : SubRows
    }


type SubRows
    = SubRows (List Person)


subRowsOf : Person -> List Person
subRowsOf row =
    case row.subRows of
        SubRows rows ->
            rows


type alias Model =
    { flat : Array Person
    , nested : Array Person
    }


columns : List (Table.Column Person)
columns =
    [ Table.column "id" (.id >> Value.String)
    , Table.column "firstName" (.firstName >> Value.String)
    , Table.column "lastName" (.lastName >> Value.String)
    , Table.column "age" (.age >> toFloat >> Value.Number)
    , Table.column "visits" (.visits >> toFloat >> Value.Number)
    , Table.column "progress" (.progress >> toFloat >> Value.Number)
    , Table.column "status" (.status >> Value.String)
    ]


flatConfig : Table.Config Person
flatConfig =
    Table.config columns


nestedConfig : Table.Config Person
nestedConfig =
    Table.config columns |> Table.withSubRows subRowsOf


person : Int -> String -> Person
person seed id =
    { id = id
    , firstName = "First" ++ String.fromInt (modBy 1000 seed)
    , lastName = "Last" ++ String.fromInt (modBy 997 seed)
    , age = modBy 80 seed
    , visits = modBy 1000 seed
    , progress = modBy 100 seed
    , status = statuses (modBy 3 seed)
    , subRows = SubRows []
    }


statuses : Int -> String
statuses n =
    case n of
        0 ->
            "relationship"

        1 ->
            "complicated"

        _ ->
            "single"


{-| 10000 rows, no children.
-}
flatRows : Array Person
flatRows =
    List.range 0 9999
        |> List.map (\i -> person i (String.fromInt i))
        |> Array.fromList


{-| 2500 parents with 3 children each: 10000 rows in total.
-}
nestedRows : Array Person
nestedRows =
    List.range 0 2499
        |> List.map
            (\i ->
                let
                    parent : Person
                    parent =
                        person i (String.fromInt i)

                    children : List Person
                    children =
                        List.range 0 2
                            |> List.map
                                (\j ->
                                    person (i * 3 + j)
                                        (String.fromInt i ++ "." ++ String.fromInt j)
                                )
                in
                { parent | subRows = SubRows children }
            )
        |> Array.fromList


main : Program () Model String
main =
    Platform.worker
        { init = init
        , update = update
        , subscriptions = \_ -> request identity
        }


init : () -> ( Model, Cmd String )
init _ =
    ( { flat = flatRows, nested = nestedRows }, Cmd.none )


update : String -> Model -> ( Model, Cmd String )
update command model =
    case command of
        "flat" ->
            ( model, response (measure flatConfig model.flat) )

        "nested" ->
            ( model, response (measure nestedConfig model.nested) )

        _ ->
            ( model
            , response
                ("prepared "
                    ++ String.fromInt (Array.length model.flat)
                    ++ " "
                    ++ String.fromInt (Array.length model.nested)
                )
            )


{-| Force the whole row model so nothing is left unevaluated.
-}
measure : Table.Config Person -> Array Person -> String
measure cfg data =
    let
        model : Table.RowModel Person
        model =
            Table.coreRowModel cfg Table.initialState data
    in
    String.fromInt (List.length model.rows)
        ++ " "
        ++ String.fromInt (List.length model.flatRows)
        ++ " "
        ++ String.fromInt (Dict.size model.rowsById)
