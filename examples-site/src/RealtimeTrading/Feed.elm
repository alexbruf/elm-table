module RealtimeTrading.Feed exposing
    ( Quote
    , reset, applyTicks
    , dayChange, dayChangePercent
    )

{-| The Elm counterpart of
`examples/react/realtime-trading/src/feed/worker/market-feed-engine.ts`: a
deterministic synthetic market feed.

The React example runs this in a web worker at up to 100,000 samples per
second. Elm has no worker here, so the same walk runs in `update` on a
`Time.every` tick: a cursor strides through the instruments by 97 and moves
one quote per tick, which is exactly what the worker's `applyTicks` does.

@docs Quote
@docs reset, applyTicks
@docs dayChange, dayChangePercent

-}

import Array exposing (Array)
import Random
import RealtimeTrading.Instruments as Instruments


{-| One instrument's live quote. Ports `MarketQuoteSnapshot`.
-}
type alias Quote =
    { id : String
    , symbol : String
    , company : String
    , venue : String
    , previousClose : Float
    , open : Float
    , high : Float
    , low : Float
    , price : Float
    , bid : Float
    , ask : Float
    , bidSize : Int
    , askSize : Int
    , lastMove : Float
    , history : List Float
    }


{-| Today's move against yesterday's close.
-}
dayChange : Quote -> Float
dayChange quote =
    quote.price - quote.previousClose


{-| Today's move as a percentage.
-}
dayChangePercent : Quote -> Float
dayChangePercent quote =
    if quote.previousClose == 0 then
        0

    else
        dayChange quote / quote.previousClose * 100


{-| Build `count` quotes and the seed the live feed continues from.
-}
reset : Int -> Int -> ( Array Quote, Random.Seed )
reset count seedInt =
    let
        universe : Array Instruments.Instrument
        universe =
            Array.fromList Instruments.instruments

        step : Int -> ( List Quote, Random.Seed ) -> ( List Quote, Random.Seed )
        step index ( acc, seed ) =
            let
                ( quote, nextSeed ) =
                    newQuote universe index seed
            in
            ( quote :: acc, nextSeed )

        ( quotes, finalSeed ) =
            List.foldl step ( [], Random.initialSeed seedInt ) (List.range 0 (count - 1))
    in
    ( Array.fromList (List.reverse quotes), finalSeed )


newQuote : Array Instruments.Instrument -> Int -> Random.Seed -> ( Quote, Random.Seed )
newQuote universe index seed0 =
    let
        size : Int
        size =
            max 1 (Array.length universe)

        ( baseSymbol, company, venue ) =
            Array.get (modBy size index) universe
                |> Maybe.withDefault ( "N/A", "Unknown", "US" )

        series : Int
        series =
            index // size

        symbol : String
        symbol =
            if series == 0 then
                baseSymbol

            else
                baseSymbol ++ String.fromInt series

        ( r1, seed1 ) =
            unit seed0

        previousClose : Float
        previousClose =
            round2 (20 + r1 * 480)

        ( r2, seed2 ) =
            unit seed1

        open : Float
        open =
            round2 (previousClose * (1 + (r2 - 0.5) * 0.016))

        ( r3, seed3 ) =
            unit seed2

        spread : Float
        spread =
            max 0.01 (open * (0.0002 + r3 * 0.0004))

        ( history, seed4 ) =
            historySamples open seed3

        ( bidSize, seed5 ) =
            sizeIn seed4

        ( askSize, seed6 ) =
            sizeIn seed5
    in
    ( { id = "instrument-" ++ String.fromInt index
      , symbol = symbol
      , company = company
      , venue = venue
      , previousClose = previousClose
      , open = open
      , high = open
      , low = open
      , price = open
      , bid = round2 (open - spread / 2)
      , ask = round2 (open + spread / 2)
      , bidSize = bidSize
      , askSize = askSize
      , lastMove = 0
      , history = history
      }
    , seed6
    )


historySamples : Float -> Random.Seed -> ( List Float, Random.Seed )
historySamples open seed0 =
    let
        step : Int -> ( List Float, Random.Seed ) -> ( List Float, Random.Seed )
        step index ( acc, seed ) =
            let
                ( r, nextSeed ) =
                    unit seed
            in
            ( round2 (open * (1 + sin (toFloat index / 4) * 0.002 + (r - 0.5) * 0.001)) :: acc
            , nextSeed
            )

        ( samples, finalSeed ) =
            List.foldl step ( [], seed0 ) (List.range 0 23)
    in
    ( List.reverse samples, finalSeed )


sizeIn : Random.Seed -> ( Int, Random.Seed )
sizeIn seed =
    let
        ( r, nextSeed ) =
            unit seed
    in
    ( floor (100 + r * 25000), nextSeed )


{-| Move `tickCount` quotes, striding through the instruments the way the
worker's row cursor does. Returns the new quotes, the new cursor, and the
new seed.
-}
applyTicks : Int -> Int -> Random.Seed -> Array Quote -> ( Array Quote, Int, Random.Seed )
applyTicks tickCount cursor0 seed0 quotes0 =
    let
        count : Int
        count =
            Array.length quotes0

        step : Int -> ( Array Quote, Int, Random.Seed ) -> ( Array Quote, Int, Random.Seed )
        step _ ( quotes, cursor, seed ) =
            let
                next : Int
                next =
                    modBy count (cursor + 97)
            in
            case Array.get next quotes of
                Nothing ->
                    ( quotes, next, seed )

                Just quote ->
                    let
                        ( moved, nextSeed ) =
                            tick quote seed
                    in
                    ( Array.set next moved quotes, next, nextSeed )
    in
    if count == 0 || tickCount <= 0 then
        ( quotes0, cursor0, seed0 )

    else
        List.foldl step ( quotes0, cursor0, seed0 ) (List.range 1 tickCount)


tick : Quote -> Random.Seed -> ( Quote, Random.Seed )
tick quote seed0 =
    let
        ( r1, seed1 ) =
            unit seed0

        volatility : Float
        volatility =
            0.00015 + r1 * 0.0012

        ( r2, seed2 ) =
            unit seed1

        -- The worker applies thousands of these per second, so one tick's
        -- move is tiny there. This feed ticks a few times per second, so
        -- the step is scaled up to keep the same visible drift.
        move : Float
        move =
            quote.price * (r2 - 0.495) * volatility * 40

        nextPrice : Float
        nextPrice =
            round2 (max 0.1 (quote.price + move))

        ( r3, seed3 ) =
            unit seed2

        spread : Float
        spread =
            max 0.01 (nextPrice * (0.00015 + r3 * 0.0005))

        ( bidSize, seed4 ) =
            sizeIn seed3

        ( askSize, seed5 ) =
            sizeIn seed4
    in
    ( { quote
        | lastMove = round2 (nextPrice - quote.price)
        , price = nextPrice
        , bid = round2 (nextPrice - spread / 2)
        , ask = round2 (nextPrice + spread / 2)
        , bidSize = bidSize
        , askSize = askSize
        , high = max quote.high nextPrice
        , low = min quote.low nextPrice
        , history = List.drop 1 quote.history ++ [ nextPrice ]
      }
    , seed5
    )


unit : Random.Seed -> ( Float, Random.Seed )
unit seed =
    Random.step (Random.float 0 1) seed


round2 : Float -> Float
round2 n =
    toFloat (round (n * 100)) / 100
