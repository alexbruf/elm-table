module ColumnSizing exposing (main)

{-| Column Sizing.

Ports `examples/react/column-sizing/src/main.tsx` from TanStack Table. As
the React file says, this is not the resizing example: it is the simplified
one that just sets static column sizes, so every width here comes from
`Table.setColumnSize` through a number input per column, exactly like the
React version. Drag resizing is outside this package.

The same table is rendered three times, as in the React example: a real
`<table>` sized with `centerTotalSize`, a flex `<div>` grid sized with
`totalSize`, and an absolutely positioned `<div>` grid laid out with
`getHeaderStart` / `getColumnStart`.

-}

import Browser
import Html exposing (Html, button, div, input, label, pre, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, colspan, style, type_, value)
import Html.Events exposing (onClick, onInput)
import Shared.People as People exposing (Person)
import Shared.StateJson as StateJson
import Table
import Table.Value as Value



-- COLUMNS


config : Table.Config Person
config =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
            |> Table.withFooter "firstName"
            |> Table.withSize 120
        , Table.column "lastName" (.lastName >> maybeString)
            |> Table.withHeader "Last Name"
            |> Table.withFooter "lastName"
            |> Table.withSize 120
        , Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
            |> Table.withFooter "age"
            |> Table.withSize 100
        , Table.column "visits" (.visits >> maybeNumber)
            |> Table.withHeader "Visits"
            |> Table.withFooter "visits"
            |> Table.withSize 80
        , Table.column "status" (.status >> People.statusToString >> Value.String)
            |> Table.withHeader "Status"
            |> Table.withFooter "status"
            |> Table.withSize 200
        , Table.column "progress" (.progress >> toFloat >> Value.Number)
            |> Table.withHeader "Profile Progress"
            |> Table.withFooter "progress"
            |> Table.withSize 200
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
    }


init : Model
init =
    { state = Table.initialState
    , data = People.makeData 42 [ 20 ]
    , seed = 42
    }


type Msg
    = RegenerateData
    | StressTest
    | SetSize String String


update : Msg -> Model -> Model
update msg model =
    case msg of
        RegenerateData ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 20 ] }

        StressTest ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 1000 ] }

        SetSize columnId typed ->
            case String.toFloat typed of
                Just size ->
                    { model | state = Table.setColumnSize columnId size model.state }

                Nothing ->
                    model



-- VIEW


view : Model -> Html Msg
view model =
    let
        rowModel : Table.RowModel Person
        rowModel =
            Table.coreRowModelFromList config model.state model.data
    in
    div [ class "demo-root" ]
        [ div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ]
            , button [ onClick StressTest ] [ text "Stress Test (1k rows)" ]
            ]
        , div [ class "spacer-md" ] []
        , Html.h2 [] [ text "Initial Column Sizes" ]
        , div [ class "size-inputs" ] (List.map (viewSizeInput model.state) (Table.allColumns config))
        , div [ class "spacer-md" ] []
        , Html.h2 [] [ text "<table/>" ]
        , div [ class "scroll-container" ]
            [ table [ style "width" (px (Table.centerTotalSize config model.state)) ]
                [ thead [] (List.map (viewHeaderRow model.state) (Table.headerGroups config model.state))
                , tbody [] (List.map (viewRow model.state) rowModel.rows)
                ]
            ]
        , div [ class "spacer-md" ] []
        , Html.h2 [] [ text "<div/> (relative)" ]
        , div [ class "scroll-container" ]
            [ div [ class "divTable", style "width" (px (Table.totalSize config model.state)) ]
                [ div [ class "thead" ] (List.map (viewDivHeaderRow model.state) (Table.headerGroups config model.state))
                , div [ class "tbody" ] (List.map (viewDivRow model.state) rowModel.rows)
                ]
            ]
        , div [ class "spacer-md" ] []
        , Html.h2 [] [ text "<div/> (absolute positioning)" ]
        , div [ class "scroll-container" ]
            [ div [ class "divTable", style "width" (px (Table.totalSize config model.state)) ]
                [ div [ class "thead" ] (List.map (viewAbsHeaderRow model.state) (Table.headerGroups config model.state))
                , div [ class "tbody" ] (List.map (viewAbsRow model.state) rowModel.rows)
                ]
            ]
        , div [ class "spacer-md" ] []
        , pre [ class "state-dump" ] [ text (StateJson.dump model.state) ]
        ]


viewSizeInput : Table.State -> Table.Column Person -> Html Msg
viewSizeInput state column =
    div []
        [ label []
            [ text (Table.columnId column)
            , input
                [ type_ "number"
                , class "column-size-input"
                , value (String.fromFloat (Table.getColumnSize config state column))
                , onInput (SetSize (Table.columnId column))
                ]
                []
            ]
        ]


px : Float -> String
px n =
    String.fromFloat n ++ "px"


viewHeaderRow : Table.State -> Table.HeaderGroup Person -> Html Msg
viewHeaderRow state group =
    tr []
        (List.map
            (\header ->
                th
                    [ colspan (Table.headerColSpan header)
                    , style "width" (px (Table.getHeaderSize config state header))
                    ]
                    [ text (headerLabel header) ]
            )
            group.headers
        )


viewRow : Table.State -> Table.Row Person -> Html Msg
viewRow state row =
    tr []
        (List.map
            (\cell ->
                td [ style "width" (px (columnSize state cell.columnId)) ]
                    [ text (Value.toString cell.value) ]
            )
            (Table.getAllCells config state row)
        )


viewDivHeaderRow : Table.State -> Table.HeaderGroup Person -> Html Msg
viewDivHeaderRow state group =
    div [ class "tr" ]
        (List.map
            (\header ->
                div
                    [ class "th"
                    , style "width" (px (Table.getHeaderSize config state header))
                    ]
                    [ text (headerLabel header) ]
            )
            group.headers
        )


viewDivRow : Table.State -> Table.Row Person -> Html Msg
viewDivRow state row =
    div [ class "tr" ]
        (List.map
            (\cell ->
                div [ class "td", style "width" (px (columnSize state cell.columnId)) ]
                    [ text (Value.toString cell.value) ]
            )
            (Table.getAllCells config state row)
        )


viewAbsHeaderRow : Table.State -> Table.HeaderGroup Person -> Html Msg
viewAbsHeaderRow state group =
    div [ class "tr", style "position" "relative" ]
        (List.map
            (\header ->
                div
                    [ class "th"
                    , style "position" "absolute"
                    , style "left" (px (Table.getHeaderStart config state group.headers header))
                    , style "width" (px (Table.getHeaderSize config state header))
                    ]
                    [ text (headerLabel header) ]
            )
            group.headers
        )


viewAbsRow : Table.State -> Table.Row Person -> Html Msg
viewAbsRow state row =
    div [ class "tr", style "position" "relative" ]
        (List.map
            (\cell ->
                div
                    [ class "td"
                    , style "position" "absolute"
                    , style "left" (px (columnStart state cell.columnId))
                    , style "width" (px (columnSize state cell.columnId))
                    ]
                    [ text (Value.toString cell.value) ]
            )
            (Table.getAllCells config state row)
        )


columnSize : Table.State -> String -> Float
columnSize state columnId =
    Table.findColumn config columnId
        |> Maybe.map (Table.getColumnSize config state)
        |> Maybe.withDefault 0


columnStart : Table.State -> String -> Float
columnStart state columnId =
    Table.findColumn config columnId
        |> Maybe.map (Table.getColumnStart config state Table.allColumnsRegion)
        |> Maybe.withDefault 0


headerLabel : Table.Header Person -> String
headerLabel header =
    Table.findColumn config (Table.headerColumnId header)
        |> Maybe.andThen Table.columnHeader
        |> Maybe.withDefault (Table.headerColumnId header)


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
