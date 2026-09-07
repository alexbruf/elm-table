module ColumnPinningSplit exposing (main)

{-| Column Pinning (Split).

Ports `examples/react/column-pinning-split/src/main.tsx` from TanStack
Table: the same table rendered as three separate `<table>` elements, one per
pinned region, using `leftHeaderGroups` / `centerHeaderGroups` /
`rightHeaderGroups` and `leftVisibleCells` / `centerVisibleCells` /
`rightVisibleCells`.

The React example's stress-test button builds 1,000,000 rows. `elm/random`
generates rows one at a time, so this page uses 10,000 instead.

-}

import Browser
import Html exposing (Html, button, div, input, label, p, pre, span, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (checked, class, colspan, type_)
import Html.Events exposing (onCheck, onClick)
import Random
import Shared.People as People exposing (Person)
import Shared.StateJson as StateJson
import Table
import Table.Value as Value



-- COLUMNS


config : Table.Config Person
config =
    Table.config
        [ Table.group "Name"
            [ Table.column "firstName" (.firstName >> Value.String)
                |> Table.withFooter "firstName"
            , Table.column "lastName" (.lastName >> maybeString)
                |> Table.withHeader "Last Name"
                |> Table.withFooter "lastName"
            ]
            |> Table.withHeader "Name"
            |> Table.withFooter "Name"
        , Table.group "Info"
            [ Table.column "age" (.age >> toFloat >> Value.Number)
                |> Table.withHeader "Age"
                |> Table.withFooter "age"
            , Table.group "More Info"
                [ Table.column "visits" (.visits >> maybeNumber)
                    |> Table.withHeader "Visits"
                    |> Table.withFooter "visits"
                , Table.column "status" (.status >> People.statusToString >> Value.String)
                    |> Table.withHeader "Status"
                    |> Table.withFooter "status"
                , Table.column "progress" (.progress >> toFloat >> Value.Number)
                    |> Table.withHeader "Profile Progress"
                    |> Table.withFooter "progress"
                ]
                |> Table.withHeader "More Info"
            ]
            |> Table.withHeader "Info"
            |> Table.withFooter "Info"
        ]
        |> Table.withGetRowId (\person _ _ -> person.id)


maybeString : Maybe String -> Value.Value
maybeString =
    Maybe.map Value.String >> Maybe.withDefault Value.Null


maybeNumber : Maybe Int -> Value.Value
maybeNumber =
    Maybe.map (toFloat >> Value.Number) >> Maybe.withDefault Value.Null



-- MODEL


type alias Model =
    { state : Table.State
    , data : List Person
    , seed : Int
    , shuffleSeed : Random.Seed
    }


init : Model
init =
    { state = Table.initialState
    , data = People.makeData 42 [ 1000 ]
    , seed = 42
    , shuffleSeed = Random.initialSeed 42
    }


type Msg
    = RegenerateData
    | StressTest
    | ShuffleColumns
    | ToggleColumn String Bool
    | ToggleAllColumns Bool
    | PinColumn String Table.ColumnPinPosition


update : Msg -> Model -> Model
update msg model =
    case msg of
        RegenerateData ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 1000 ] }

        StressTest ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 10000 ] }

        ShuffleColumns ->
            let
                ( order, nextSeed ) =
                    shuffle model.shuffleSeed (List.map Table.columnId (Table.leafColumns config))
            in
            { model
                | state = Table.setColumnOrder order model.state
                , shuffleSeed = nextSeed
            }

        ToggleColumn columnId visible ->
            case Table.findColumn config columnId of
                Just column ->
                    { model | state = Table.toggleColumnVisibility config column (Just visible) model.state }

                Nothing ->
                    model

        ToggleAllColumns visible ->
            { model | state = Table.toggleAllColumnsVisible config (Just visible) model.state }

        PinColumn columnId position ->
            case Table.findColumn config columnId of
                Just column ->
                    { model | state = Table.pinColumn position column model.state }

                Nothing ->
                    model


shuffle : Random.Seed -> List a -> ( List a, Random.Seed )
shuffle seed items =
    Random.step (Random.list (List.length items) (Random.int 0 1000000)) seed
        |> Tuple.mapFirst
            (\keys ->
                List.map2 Tuple.pair keys items
                    |> List.sortBy Tuple.first
                    |> List.map Tuple.second
            )



-- VIEW


view : Model -> Html Msg
view model =
    let
        rowModel : Table.RowModel Person
        rowModel =
            Table.coreRowModelFromList config model.state model.data

        rows : List (Table.Row Person)
        rows =
            List.take 20 rowModel.rows
    in
    div [ class "demo-root" ]
        [ viewColumnToggles model.state
        , div [ class "spacer-md" ] []
        , div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ]
            , button [ onClick StressTest ] [ text "Stress Test (10k rows)" ]
            , button [ onClick ShuffleColumns ] [ text "Shuffle Columns" ]
            ]
        , div [ class "spacer-md" ] []
        , p [ class "muted" ]
            [ text "This example takes advantage of the \"splitting\" APIs. (APIs that have \"left\", \"center\", and \"right\" modifiers)" ]
        , div [ class "split-tables" ]
            [ viewRegion model.state rows Table.leftHeaderGroups Table.leftVisibleCells
            , viewRegion model.state rows Table.centerHeaderGroups Table.centerVisibleCells
            , viewRegion model.state rows Table.rightHeaderGroups Table.rightVisibleCells
            ]
        , pre [ class "state-dump" ] [ text (StateJson.dump model.state) ]
        ]


viewRegion :
    Table.State
    -> List (Table.Row Person)
    -> (Table.Config Person -> Table.State -> List (Table.HeaderGroup Person))
    -> (Table.Config Person -> Table.State -> Table.Row Person -> List Table.Cell)
    -> Html Msg
viewRegion state rows groupsOf cellsOf =
    table []
        [ thead [] (List.map (viewHeaderRow state) (groupsOf config state))
        , tbody []
            (List.map
                (\row -> tr [] (List.map viewCell (cellsOf config state row)))
                rows
            )
        ]


viewColumnToggles : Table.State -> Html Msg
viewColumnToggles state =
    div [ class "checkbox-list" ]
        (label []
            [ input
                [ type_ "checkbox"
                , checked (Table.isAllColumnsVisible config state)
                , onCheck ToggleAllColumns
                ]
                []
            , text " Toggle All"
            ]
            :: List.map
                (\column ->
                    label []
                        [ input
                            [ type_ "checkbox"
                            , checked (Table.columnIsVisible state column)
                            , onCheck (ToggleColumn (Table.columnId column))
                            ]
                            []
                        , text (" " ++ Table.columnId column)
                        ]
                )
                (Table.leafColumns config)
        )


viewHeaderRow : Table.State -> Table.HeaderGroup Person -> Html Msg
viewHeaderRow state group =
    tr [] (List.map (viewHeaderCell state) group.headers)


viewHeaderCell : Table.State -> Table.Header Person -> Html Msg
viewHeaderCell state header =
    let
        column : Maybe (Table.Column Person)
        column =
            Table.findColumn config (Table.headerColumnId header)
    in
    th [ colspan (Table.headerColSpan header) ]
        (if Table.headerIsPlaceholder header then
            []

         else
            [ div [] [ text (headerLabel header) ]
            , case column of
                Just col ->
                    if Table.columnCanPin config col then
                        viewPinActions state col

                    else
                        text ""

                Nothing ->
                    text ""
            ]
        )


viewPinActions : Table.State -> Table.Column Person -> Html Msg
viewPinActions state column =
    let
        pinned : Table.ColumnPinPosition
        pinned =
            Table.columnIsPinned state column

        columnId : String
        columnId =
            Table.columnId column
    in
    div [ class "pin-actions" ]
        [ if pinned /= Table.pinnedLeft then
            button [ onClick (PinColumn columnId Table.pinnedLeft) ] [ text "<=" ]

          else
            text ""
        , if pinned /= Table.columnUnpinned then
            button [ onClick (PinColumn columnId Table.columnUnpinned) ] [ text "X" ]

          else
            text ""
        , if pinned /= Table.pinnedRight then
            button [ onClick (PinColumn columnId Table.pinnedRight) ] [ text "=>" ]

          else
            text ""
        ]


headerLabel : Table.Header Person -> String
headerLabel header =
    Table.findColumn config (Table.headerColumnId header)
        |> Maybe.andThen Table.columnHeader
        |> Maybe.withDefault (Table.headerColumnId header)


viewCell : Table.Cell -> Html Msg
viewCell cell =
    td [] [ span [] [ text (Value.toString cell.value) ] ]


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
