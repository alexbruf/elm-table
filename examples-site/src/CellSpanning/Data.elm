module CellSpanning.Data exposing
    ( Shift, SummaryRow, SummaryKind(..)
    , makeData, makeSummaryData
    , regions, statuses
    )

{-| The Elm counterpart of `examples/react/cell-spanning/src/makeData.ts`.

Rows come out region-major, then team, then shift, so equal values are
already adjacent: value-based row spanning only merges adjacent rows, and a
per-row random generator would produce a table with no merges at all until
the user sorted it.

@docs Shift, SummaryRow, SummaryKind
@docs makeData, makeSummaryData
@docs regions, statuses

-}

import Random exposing (Generator)
import Shared.People as People


type alias Shift =
    { id : String
    , region : String
    , team : String
    , shift : String
    , employee : String
    , hours : Int
    , status : String
    }


type SummaryKind
    = ShiftRow
    | Subtotal


type alias SummaryRow =
    { id : String
    , kind : SummaryKind
    , label : String
    , region : String
    , hours : Int
    }


regions : List String
regions =
    [ "North", "South", "East", "West" ]


teams : List String
teams =
    [ "Alpha", "Bravo", "Charlie" ]


shifts : List String
shifts =
    [ "Morning", "Evening", "Night" ]


statuses : List String
statuses =
    [ "Approved", "Pending", "Rejected" ]


{-| Every region × team × shift combination, in that order.
-}
makeData : Int -> List Shift
makeData seed =
    Random.step (sequence (List.concat (List.indexedMap rowsForRegion regions)))
        (Random.initialSeed seed)
        |> Tuple.first


rowsForRegion : Int -> String -> List (Generator Shift)
rowsForRegion regionIndex region =
    List.concat
        (List.indexedMap
            (\teamIndex team ->
                List.indexedMap
                    (\shiftIndex shift ->
                        shiftGenerator
                            (String.fromInt regionIndex ++ "-" ++ String.fromInt teamIndex ++ "-" ++ String.fromInt shiftIndex)
                            region
                            team
                            shift
                    )
                    shifts
            )
            teams
        )


shiftGenerator : String -> String -> String -> String -> Generator Shift
shiftGenerator id region team shift =
    Random.map3
        (\employee hours status ->
            { id = id
            , region = region
            , team = team
            , shift = shift
            , employee = employee
            , hours = hours
            , status = status
            }
        )
        fullName
        (Random.int 4 12)
        (Random.uniform "Approved" [ "Pending", "Rejected" ])


fullName : Generator String
fullName =
    Random.map2 (\first last -> first ++ " " ++ last)
        (Random.uniform "Tanner" People.firstNames)
        (Random.uniform "Linsley" People.lastNames)


sequence : List (Generator a) -> Generator (List a)
sequence gens =
    List.foldr (Random.map2 (::)) (Random.constant []) gens


{-| The small fixed dataset for the column-spanning panel: per-region hour
subtotals rendered as full-width label rows between the data rows.
-}
makeSummaryData : Int -> List SummaryRow
makeSummaryData seed =
    let
        hoursFor : Generator (List Int)
        hoursFor =
            Random.list (2 * List.length teams) (Random.int 8 40)

        drawn : List Int
        drawn =
            Random.step hoursFor (Random.initialSeed seed) |> Tuple.first
    in
    List.take 2 regions
        |> List.indexedMap
            (\regionIndex region ->
                let
                    hours : List Int
                    hours =
                        List.take (List.length teams)
                            (List.drop (regionIndex * List.length teams) drawn)
                in
                List.map2
                    (\team teamHours ->
                        { id = region ++ "-" ++ team
                        , kind = ShiftRow
                        , label = region ++ " / " ++ team
                        , region = region
                        , hours = teamHours
                        }
                    )
                    teams
                    hours
                    ++ [ { id = region ++ "-subtotal"
                         , kind = Subtotal
                         , label = region ++ " total"
                         , region = ""
                         , hours = List.sum hours
                         }
                       ]
            )
        |> List.concat
