module ColumnPinningSticky exposing (main)

{-| Sticky Column Pinning.

Ports `examples/react/column-pinning-sticky/src/main.tsx` from TanStack
Table: one table whose pinned cells are `position: sticky`, offset with
`getColumnStart` on the left region and `getColumnAfter` on the right one,
with the inset box shadow on the last left-pinned and the first right-pinned
column. Each header also prints `columnIndex` inside its own region, which is
the React example's `column.getIndex(...)` demo.

The React example also has drag resize handles (`columnResizingFeature`).
Drag resizing is outside this package, so they are left out here; see the
Column Sizing example for the sizing APIs.

-}

import Browser
import Html exposing (Html, button, div, input, label, pre, span, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (checked, class, classList, colspan, style, type_)
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
        [ Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First Name"
            |> Table.withSize 180
        , Table.column "lastName" (.lastName >> maybeString)
            |> Table.withHeader "Last Name"
            |> Table.withSize 180
        , Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
            |> Table.withSize 180
        , Table.column "visits" (.visits >> maybeNumber)
            |> Table.withHeader "Visits"
            |> Table.withSize 180
        , Table.column "status" (.status >> People.statusToString >> Value.String)
            |> Table.withHeader "Status"
            |> Table.withSize 180
        , Table.column "progress" (.progress >> toFloat >> Value.Number)
            |> Table.withHeader "Profile Progress"
            |> Table.withSize 180
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
    , data = People.makeData 42 [ 20 ]
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
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 20 ] }

        StressTest ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 1000 ] }

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
    in
    div [ class "demo-root" ]
        [ viewColumnToggles model.state
        , div [ class "spacer-md" ] []
        , div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ]
            , button [ onClick StressTest ] [ text "Stress Test (1k rows)" ]
            , button [ onClick ShuffleColumns ] [ text "Shuffle Columns" ]
            ]
        , div [ class "spacer-md" ] []
        , div [ class "sticky-table-container" ]
            [ table [ style "width" (px (Table.totalSize config model.state)) ]
                [ thead [] (List.map (viewHeaderRow model.state) (Table.headerGroups config model.state))
                , tbody [] (List.map (viewRow model.state) rowModel.rows)
                ]
            ]
        , pre [ class "state-dump" ] [ text (StateJson.dump model.state) ]
        ]


{-| The styles that make sticky column pinning work, straight from the React
example's `getCommonPinningStyles`.
-}
pinningStyles : Table.State -> Table.Column Person -> List (Html.Attribute Msg)
pinningStyles state column =
    let
        pinned : Table.ColumnPinPosition
        pinned =
            Table.columnIsPinned state column

        isLastLeft : Bool
        isLastLeft =
            pinned == Table.pinnedLeft && Table.columnIsLast config state Table.leftColumnsRegion column

        isFirstRight : Bool
        isFirstRight =
            pinned == Table.pinnedRight && Table.columnIsFirst config state Table.rightColumnsRegion column
    in
    [ classList
        [ ( "pinned-left", pinned == Table.pinnedLeft )
        , ( "pinned-right", pinned == Table.pinnedRight )
        ]
    , style "box-shadow"
        (if isLastLeft then
            "-4px 0 4px -4px gray inset"

         else if isFirstRight then
            "4px 0 4px -4px gray inset"

         else
            "none"
        )
    , style "left"
        (if pinned == Table.pinnedLeft then
            px (Table.getColumnStart config state Table.leftColumnsRegion column)

         else
            "auto"
        )
    , style "right"
        (if pinned == Table.pinnedRight then
            px (Table.getColumnAfter config state Table.rightColumnsRegion column)

         else
            "auto"
        )
    , style "opacity"
        (if pinned == Table.columnUnpinned then
            "1"

         else
            "0.95"
        )
    , style "position"
        (if pinned == Table.columnUnpinned then
            "relative"

         else
            "sticky"
        )
    , style "width" (px (Table.getColumnSize config state column))
    ]


px : Float -> String
px n =
    String.fromFloat n ++ "px"


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
    case Table.findColumn config (Table.headerColumnId header) of
        Nothing ->
            th [ colspan (Table.headerColSpan header) ] []

        Just column ->
            th (colspan (Table.headerColSpan header) :: pinningStyles state column)
                [ div []
                    [ text (headerLabel header ++ " ")
                    , span [ class "muted" ] [ text (String.fromInt (regionIndex state column)) ]
                    ]
                , if Table.columnCanPin config column then
                    viewPinActions state column

                  else
                    text ""
                ]


{-| `column.getIndex(column.getIsPinned() || 'center')` from the React example.
-}
regionIndex : Table.State -> Table.Column Person -> Int
regionIndex state column =
    let
        pinned : Table.ColumnPinPosition
        pinned =
            Table.columnIsPinned state column
    in
    if pinned == Table.pinnedLeft then
        Table.columnIndex config state Table.leftColumnsRegion column

    else if pinned == Table.pinnedRight then
        Table.columnIndex config state Table.rightColumnsRegion column

    else
        Table.columnIndex config state Table.centerColumnsRegion column


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


viewRow : Table.State -> Table.Row Person -> Html Msg
viewRow state row =
    tr [] (List.map (viewCell state) (Table.visibleCells config state row))


viewCell : Table.State -> Table.Cell -> Html Msg
viewCell state cell =
    case Table.findColumn config cell.columnId of
        Nothing ->
            td [] [ text (Value.toString cell.value) ]

        Just column ->
            td (pinningStyles state column) [ text (Value.toString cell.value) ]


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
