module Sorting exposing (main)

{-| Ports `examples/react/sorting/src/main.tsx`.

Click a header to step its sort cycle, shift-click to add it to the sort
instead of replacing it. The columns show off the per-column knobs:
`sortUndefined`, `sortDescFirst`, an explicit `sortFn`, `invertSorting`, and
a custom row comparison for the `status` enum.

-}

import Browser
import Html exposing (Html, button, div, span, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, colspan, title)
import Html.Events exposing (onClick)
import Shared.Controls as Controls
import Shared.People as People exposing (Person, Status(..))
import Table
import Table.SortFn as SortFn
import Table.Value as Value exposing (Value)



-- CONFIG


config : Table.Config Person
config =
    Table.config
        [ Table.display "rowNumber"
            |> Table.withHeader "#"
        , Table.column "firstName" (.firstName >> Value.String)

        -- this column will sort in ascending order by default since it is a
        -- string column
        , Table.column "lastName" (.lastName >> maybeString)
            |> Table.withHeader "Last Name"
            -- force null values to the end
            |> Table.withSortUndefined Table.sortNullsLast
            -- first sort order will be ascending (nullable values can mess up
            -- auto detection of sort order)
            |> Table.withSortDescFirst False
        , Table.column "email" (.email >> Value.String)
            |> Table.withHeader "Email"
            |> Table.withSortFn SortFn.alphanumeric

        -- this column will sort in descending order by default since it is a
        -- number column
        , Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
        , Table.column "visits" (.visits >> maybeNumber)
            |> Table.withHeader "Visits"
            |> Table.withSortUndefined Table.sortNullsLast
        , Table.column "status" (.status >> People.statusToString >> Value.String)
            |> Table.withHeader "Status"
            -- use our custom sorting function for this enum column
            |> Table.withCustomSort sortStatus
        , Table.column "progress" (.progress >> toFloat >> Value.Number)
            |> Table.withHeader "Profile Progress"
        , Table.column "rank" (.rank >> toFloat >> Value.Number)
            |> Table.withHeader "Rank"
            -- invert the sorting order (golf score-like where smaller is better)
            |> Table.withInvertSorting True
        , Table.column "createdAt" (.createdAt >> Value.Date)
            |> Table.withHeader "Created At"
        ]
        |> Table.withGetRowId (\person _ _ -> person.id)


{-| `sortStatusFn` in the React example: single, complicated, relationship.
-}
sortStatus : Table.Row Person -> Table.Row Person -> Order
sortStatus rowA rowB =
    compare
        (statusOrder (Table.rowOriginal rowA).status)
        (statusOrder (Table.rowOriginal rowB).status)


statusOrder : Status -> Int
statusOrder status =
    case status of
        Single ->
            0

        Complicated ->
            1

        Relationship ->
            2


maybeString : Maybe String -> Value
maybeString =
    Maybe.map Value.String >> Maybe.withDefault Value.Null


maybeNumber : Maybe Int -> Value
maybeNumber =
    Maybe.map (toFloat >> Value.Number) >> Maybe.withDefault Value.Null



-- MODEL


rowCount : Int
rowCount =
    1000


type alias Model =
    { state : Table.State
    , seed : Int
    , data : List Person
    }


init : Model
init =
    { state = Table.initialState
    , seed = 42
    , data = People.makeData 42 [ rowCount ]
    }


type alias Stages =
    { filtered : Table.RowModel Person
    , sorted : Table.RowModel Person
    }


stages : Model -> Stages
stages model =
    let
        filtered : Table.RowModel Person
        filtered =
            Table.coreRowModelFromList config model.state model.data
                |> Table.filteredRowModel config model.state
    in
    { filtered = filtered
    , sorted = Table.sortedRowModel config model.state filtered
    }



-- UPDATE


type Msg
    = RegenerateData
    | SortClicked String Bool


update : Msg -> Model -> Model
update msg model =
    case msg of
        RegenerateData ->
            let
                seed : Int
                seed =
                    model.seed + 1
            in
            { model | seed = seed, data = People.makeData seed [ rowCount ] }

        SortClicked columnId multi ->
            { model
                | state =
                    Table.toggleSort config
                        (stages model).filtered
                        columnId
                        { desc = Nothing, multi = multi }
                        model.state
            }



-- VIEW


view : Model -> Html Msg
view model =
    let
        current : Stages
        current =
            stages model

        visibleRows : List (Table.Row Person)
        visibleRows =
            List.take 10 current.sorted.rows
    in
    div [ class "demo-root" ]
        [ div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ] ]
        , div [ class "spacer-sm" ] []
        , table []
            [ thead []
                (List.map (viewHeaderRow model current) (Table.headerGroups config model.state))
            , tbody [] (List.indexedMap (viewRow model.state) visibleRows)
            ]
        , div [] [ text (Controls.formatInt (List.length current.sorted.rows) ++ " Rows") ]
        , Controls.stateDump model.state
        ]


viewHeaderRow : Model -> Stages -> Table.HeaderGroup Person -> Html Msg
viewHeaderRow model current group =
    tr [] (List.map (viewHeaderCell model current) group.headers)


viewHeaderCell : Model -> Stages -> Table.Header Person -> Html Msg
viewHeaderCell model current header =
    let
        columnId : String
        columnId =
            Table.headerColumnId header

        canSort : Bool
        canSort =
            Table.getCanSort config columnId

        label : String
        label =
            headerLabel columnId ++ Controls.sortArrow (Table.getIsSorted model.state columnId)
    in
    th [ colspan (Table.headerColSpan header) ]
        [ if canSort then
            span
                [ class "sortable"
                , title (nextSortTitle model current columnId)
                , Controls.onClickShift (SortClicked columnId)
                ]
                [ text label ]

          else
            text label
        ]


nextSortTitle : Model -> Stages -> String -> String
nextSortTitle model current columnId =
    case Table.getNextSortingOrder config current.filtered model.state columnId False of
        Nothing ->
            "Clear sort"

        Just dir ->
            if dir == Table.sortAsc then
                "Sort ascending"

            else
                "Sort descending"


headerLabel : String -> String
headerLabel columnId =
    Table.findColumn config columnId
        |> Maybe.andThen Table.columnHeader
        |> Maybe.withDefault columnId


viewRow : Table.State -> Int -> Table.Row Person -> Html Msg
viewRow state displayIndex row =
    tr [] (List.map (viewCell displayIndex) (Table.getAllCells config state row))


viewCell : Int -> Table.Cell -> Html Msg
viewCell displayIndex cell =
    td []
        [ if cell.columnId == "rowNumber" then
            text (String.fromInt (displayIndex + 1))

          else
            text (Controls.valueToString cell.value)
        ]


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
