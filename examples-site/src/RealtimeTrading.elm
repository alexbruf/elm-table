module RealtimeTrading exposing (main)

{-| Realtime Trading.

Ports `examples/react/realtime-trading` from TanStack Table: a market
monitor whose quotes tick under a live table while sorting and filtering
stay usable. The React example runs a web worker at up to 100,000 samples
per second behind a virtualizer and a benchmark panel; this is the same
table and the same column layout driven by `Time.every` and a pure
pseudo-random walk (`RealtimeTrading.Feed`), with the feed controls the
React shell puts in its configurator: pause/start, instrument count, and
delivery interval.

Price, change and change% are coloured with the `up` / `down` classes on
every tick, exactly as the React `UpMoveCell` / `DownMoveCell` do.

-}

import Array exposing (Array)
import Browser
import Html exposing (Html, button, div, header, input, label, option, select, span, strong, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, classList, colspan, placeholder, selected, style, value)
import Html.Events exposing (onClick, onInput)
import Random
import RealtimeTrading.Feed as Feed exposing (Quote)
import Table
import Table.FilterFn as FilterFn
import Table.SortFn as SortFn
import Table.Value as Value
import Time



-- COLUMNS


config : Table.Config Quote
config =
    Table.config
        [ Table.group "instrument"
            [ Table.column "market" (.venue >> Value.String)
                |> Table.withHeader "Market"
                |> Table.withSize 72
            , Table.column "name" (.company >> Value.String)
                |> Table.withHeader "Name"
                |> Table.withSize 180
            , Table.column "symbol" (.symbol >> Value.String)
                |> Table.withHeader "Symbol"
                |> Table.withSize 92
                |> Table.withFilterFn FilterFn.includesString
            ]
            |> Table.withHeader "Instrument"
        , Table.group "priceAndChange"
            [ Table.column "price" (.price >> Value.Number)
                |> Table.withHeader "Price"
                |> Table.withSize 96
                |> Table.withSortFn SortFn.basic
            , Table.column "change" (Feed.dayChange >> Value.Number)
                |> Table.withHeader "Chg"
                |> Table.withSize 94
                |> Table.withSortFn SortFn.basic
            , Table.column "changePercent" (Feed.dayChangePercent >> Value.Number)
                |> Table.withHeader "Chg%"
                |> Table.withSize 90
                |> Table.withSortFn SortFn.basic
            ]
            |> Table.withHeader "Price & Change"
        , Table.group "orderBook"
            [ Table.column "bid" (.bid >> Value.Number)
                |> Table.withHeader "Bid"
                |> Table.withSize 90
            , Table.column "bidSize" (.bidSize >> toFloat >> Value.Number)
                |> Table.withHeader "Bid Vol"
                |> Table.withSize 100
            , Table.column "ask" (.ask >> Value.Number)
                |> Table.withHeader "Ask"
                |> Table.withSize 90
            , Table.column "askSize" (.askSize >> toFloat >> Value.Number)
                |> Table.withHeader "Ask Vol"
                |> Table.withSize 100
            ]
            |> Table.withHeader "Order Book"
        , Table.group "session"
            [ Table.column "open" (.open >> Value.Number)
                |> Table.withHeader "Open"
                |> Table.withSize 90
            , Table.column "high" (.high >> Value.Number)
                |> Table.withHeader "High"
                |> Table.withSize 90
            , Table.column "low" (.low >> Value.Number)
                |> Table.withHeader "Low"
                |> Table.withSize 90
            ]
            |> Table.withHeader "Session"
        , Table.group "chart"
            [ Table.column "history" (.history >> List.map Value.Number >> Value.List)
                |> Table.withHeader "Intraday"
                |> Table.withSize 150
                |> Table.withEnableSorting False
            ]
            |> Table.withHeader "Chart"
        ]
        |> Table.withGetRowId (\quote _ _ -> quote.id)



-- MODEL


type alias Model =
    { state : Table.State
    , quotes : Array Quote
    , seed : Random.Seed
    , cursor : Int
    , running : Bool
    , instrumentCount : Int
    , intervalMs : Float
    , updatedRows : Int
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( startModel 100, Cmd.none )


startModel : Int -> Model
startModel count =
    let
        ( quotes, seed ) =
            Feed.reset count 2026
    in
    { state = Table.initialState
    , quotes = quotes
    , seed = seed
    , cursor = 0
    , running = True
    , instrumentCount = count
    , intervalMs = 250
    , updatedRows = 0
    }


type Msg
    = Ticked Time.Posix
    | ToggleFeed
    | SetInstrumentCount String
    | SetInterval String
    | SymbolTyped String
    | SortBy String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Ticked _ ->
            let
                ticks : Int
                ticks =
                    20

                ( quotes, cursor, seed ) =
                    Feed.applyTicks ticks model.cursor model.seed model.quotes
            in
            ( { model | quotes = quotes, cursor = cursor, seed = seed, updatedRows = ticks }
            , Cmd.none
            )

        ToggleFeed ->
            ( { model | running = not model.running }, Cmd.none )

        SetInstrumentCount typed ->
            let
                count : Int
                count =
                    Maybe.withDefault 100 (String.toInt typed)

                fresh : Model
                fresh =
                    startModel count
            in
            ( { fresh | state = model.state, running = model.running, intervalMs = model.intervalMs }
            , Cmd.none
            )

        SetInterval typed ->
            ( { model | intervalMs = Maybe.withDefault 250 (String.toFloat typed) }, Cmd.none )

        SymbolTyped typed ->
            ( { model
                | state =
                    Table.setColumnFilter config
                        (Table.coreRowModelFromList config model.state (Array.toList model.quotes))
                        "symbol"
                        (Value.String typed)
                        model.state
              }
            , Cmd.none
            )

        SortBy columnId ->
            ( { model
                | state =
                    Table.toggleSort config
                        (Table.coreRowModelFromList config model.state (Array.toList model.quotes))
                        columnId
                        { desc = Nothing, multi = False }
                        model.state
              }
            , Cmd.none
            )


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.running then
        Time.every model.intervalMs Ticked

    else
        Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    let
        -- No pagination in this example: the React version renders every
        -- instrument through a virtualizer, so the pipeline stops at sorted.
        rowModel : Table.RowModel Quote
        rowModel =
            Table.coreRowModelFromList config model.state (Array.toList model.quotes)
                |> Table.filteredRowModel config model.state
                |> Table.sortedRowModel config model.state
    in
    div [ class "demo-root" ]
        [ header [ class "app-bar" ]
            [ strong [] [ text "MARKET MONITOR" ]
            , span [ classList [ ( "feed-status", True ), ( "is-running", model.running ) ] ]
                [ span [ class "status-dot" ] []
                , text
                    (if model.running then
                        "FEED LIVE"

                     else
                        "FEED PAUSED"
                    )
                ]
            ]
        , div [ class "controls" ]
            [ button [ onClick ToggleFeed ]
                [ text
                    (if model.running then
                        "PAUSE FEED"

                     else
                        "START FEED"
                    )
                ]
            , label []
                [ text "Instruments (rows) "
                , select [ onInput SetInstrumentCount ]
                    (List.map
                        (\count ->
                            option
                                [ value (String.fromInt count), selected (count == model.instrumentCount) ]
                                [ text (String.fromInt count) ]
                        )
                        [ 25, 50, 100, 200 ]
                    )
                ]
            , label []
                [ text "Delivery interval "
                , select [ onInput SetInterval ]
                    (List.map
                        (\ms ->
                            option
                                [ value (String.fromFloat ms), selected (ms == model.intervalMs) ]
                                [ text (String.fromFloat ms ++ " ms") ]
                        )
                        [ 100, 250, 500, 1000 ]
                    )
                ]
            , input
                [ class "filter"
                , placeholder "Symbol..."
                , value
                    (Table.getFilterValue model.state "symbol"
                        |> Maybe.map Value.toString
                        |> Maybe.withDefault ""
                    )
                , onInput SymbolTyped
                ]
                []
            ]
        , div [ class "spacer-sm" ] []
        , table [ style "width" (String.fromFloat (Table.totalSize config model.state) ++ "px") ]
            [ thead [] (List.map (viewHeaderRow model.state) (Table.headerGroups config model.state))
            , tbody [] (List.map (viewRow model.state) rowModel.rows)
            ]
        , div [ class "spacer-sm" ] []
        , div [ class "market-statusbar muted" ]
            [ span [] [ text (String.fromInt (List.length rowModel.rows) ++ " rows") ]
            , span [] [ text (String.fromInt model.updatedRows ++ " quotes per delivery") ]
            ]
        ]


viewHeaderRow : Table.State -> Table.HeaderGroup Quote -> Html Msg
viewHeaderRow state group =
    tr []
        (List.map
            (\header_ ->
                let
                    columnId : String
                    columnId =
                        Table.headerColumnId header_
                in
                th
                    [ colspan (Table.headerColSpan header_)
                    , classList [ ( "sortable", Table.getCanSort config columnId ) ]
                    , style "width" (String.fromFloat (Table.getHeaderSize config state header_) ++ "px")
                    ]
                    [ if Table.headerIsPlaceholder header_ then
                        text ""

                      else if Table.getCanSort config columnId then
                        button [ onClick (SortBy columnId) ]
                            [ text (headerLabel header_ ++ sortArrow state columnId) ]

                      else
                        text (headerLabel header_)
                    ]
            )
            group.headers
        )


sortArrow : Table.State -> String -> String
sortArrow state columnId =
    case Table.getIsSorted state columnId of
        Nothing ->
            ""

        Just dir ->
            if dir == Table.sortAsc then
                " ▲"

            else
                " ▼"


viewRow : Table.State -> Table.Row Quote -> Html Msg
viewRow state row =
    let
        quote : Quote
        quote =
            Table.rowOriginal row
    in
    tr [] (List.map (viewCell quote) (Table.visibleCells config state row))


viewCell : Quote -> Table.Cell -> Html Msg
viewCell quote cell =
    case cell.columnId of
        "price" ->
            td [ class (moveClass quote.lastMove) ] [ text (fixed2 quote.price) ]

        "change" ->
            td [ class (moveClass (Feed.dayChange quote)) ] [ text (signed (Feed.dayChange quote)) ]

        "changePercent" ->
            td [ class (moveClass (Feed.dayChangePercent quote)) ]
                [ text (signed (Feed.dayChangePercent quote) ++ "%") ]

        "bid" ->
            td [] [ text (fixed2 quote.bid) ]

        "ask" ->
            td [] [ text (fixed2 quote.ask) ]

        "open" ->
            td [] [ text (fixed2 quote.open) ]

        "high" ->
            td [] [ text (fixed2 quote.high) ]

        "low" ->
            td [] [ text (fixed2 quote.low) ]

        "bidSize" ->
            td [] [ text (compact quote.bidSize) ]

        "askSize" ->
            td [] [ text (compact quote.askSize) ]

        "history" ->
            td [ class "sparkline" ] [ text (sparkline quote.history) ]

        _ ->
            td [] [ text (Value.toString cell.value) ]


moveClass : Float -> String
moveClass move =
    if move > 0 then
        "up"

    else if move < 0 then
        "down"

    else
        ""


fixed2 : Float -> String
fixed2 n =
    let
        cents : Int
        cents =
            round (abs n * 100)

        sign : String
        sign =
            if n < 0 then
                "-"

            else
                ""
    in
    sign
        ++ String.fromInt (cents // 100)
        ++ "."
        ++ String.padLeft 2 '0' (String.fromInt (modBy 100 cents))


signed : Float -> String
signed n =
    if n > 0 then
        "+" ++ fixed2 n

    else
        fixed2 n


compact : Int -> String
compact n =
    if n >= 1000000 then
        fixed1 (toFloat n / 1000000) ++ "M"

    else if n >= 1000 then
        fixed1 (toFloat n / 1000) ++ "K"

    else
        String.fromInt n


fixed1 : Float -> String
fixed1 n =
    let
        tenths : Int
        tenths =
            round (n * 10)
    in
    String.fromInt (tenths // 10) ++ "." ++ String.fromInt (modBy 10 tenths)


{-| The React `SparklineCell` draws an SVG path; this draws the same series
with block characters, which needs no extra element.
-}
sparkline : List Float -> String
sparkline values =
    let
        low : Float
        low =
            List.minimum values |> Maybe.withDefault 0

        high : Float
        high =
            List.maximum values |> Maybe.withDefault 0

        span_ : Float
        span_ =
            if high - low <= 0 then
                1

            else
                high - low

        blocks : Array Char
        blocks =
            Array.fromList [ '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█' ]
    in
    values
        |> List.map
            (\v ->
                Array.get (clamp 0 7 (floor ((v - low) / span_ * 7.999))) blocks
                    |> Maybe.withDefault '▁'
            )
        |> String.fromList


headerLabel : Table.Header Quote -> String
headerLabel header_ =
    Table.findColumn config (Table.headerColumnId header_)
        |> Maybe.andThen Table.columnHeader
        |> Maybe.withDefault (Table.headerColumnId header_)


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
