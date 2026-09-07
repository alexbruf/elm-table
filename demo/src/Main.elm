module Main exposing (main)

{-| A keyword report on 5,000 generated rows, wired to `alexbruf/elm-table`.

Every feature on the page reads and writes the package's `State`. The six row
models come from one measured pipeline run per update, kept in the model so
`view` never runs a stage.

-}

import Array exposing (Array)
import Browser
import Data exposing (Keyword)
import Html exposing (Html)
import Report exposing (Bound(..), Model, Msg(..))
import Table
import Table.Value as Value exposing (Value)
import Task
import Time
import Timing
import View


{-| `now` anchors the crawl dates: they land in the 90 days before it.
-}
type alias Flags =
    { now : Int
    }


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = always Sub.none
        }


defaultSeed : Int
defaultSeed =
    1987


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        now : Time.Posix
        now =
            Time.millisToPosix flags.now

        data : Array Keyword
        data =
            Data.generate defaultSeed now

        state : Table.State
        state =
            Table.setPageSize 25 Table.initialState
    in
    recompute
        { seed = defaultSeed
        , seedField = String.fromInt defaultSeed
        , now = now
        , data = data
        , state = state
        , stages = Timing.run Report.config state data
        , timings = Timing.zeroTimings
        }


view : Model -> Html Msg
view =
    View.view


recompute : Model -> ( Model, Cmd Msg )
recompute model =
    ( model
    , Task.perform Measured (Timing.measure Report.config model.state model.data)
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Measured measured ->
            ( { model | stages = measured.stages, timings = measured.timings }
            , Cmd.none
            )

        SeedTyped text ->
            ( { model | seedField = text }, Cmd.none )

        RegenerateClicked ->
            let
                seed : Int
                seed =
                    String.toInt (String.trim model.seedField)
                        |> Maybe.withDefault model.seed
            in
            recompute
                { model
                    | seed = seed
                    , seedField = String.fromInt seed
                    , data = Data.generate seed model.now
                    , state =
                        model.state
                            |> Table.resetRowSelection
                            |> Table.resetExpanded
                            |> Table.setPage Report.config 0
                }

        _ ->
            recompute { model | state = applyToState msg model }


applyToState : Msg -> Model -> Table.State
applyToState msg model =
    let
        state : Table.State
        state =
            model.state
    in
    case msg of
        HeaderClicked id shift ->
            if Table.getCanSort Report.config id then
                Table.toggleSort Report.config
                    model.stages.core
                    id
                    { desc = Nothing, multi = shift }
                    state

            else
                state

        GlobalFilterTyped text ->
            state
                |> Table.setGlobalFilter (stringValue text)
                |> firstPage

        TextFilterTyped id text ->
            setFilter model id (stringValue text)

        EnumFilterPicked id label ->
            setFilter model id (stringValue label)

        RangeTyped id bound text ->
            let
                entered : Value
                entered =
                    String.toFloat (String.trim text)
                        |> Maybe.map Value.Number
                        |> Maybe.withDefault Value.Null
            in
            setFilter model id (writeBound state id bound entered)

        DateTyped id bound text ->
            let
                parsed : Maybe Time.Posix
                parsed =
                    case bound of
                        Lower ->
                            Report.dayStart text

                        Upper ->
                            Report.dayEnd text

                entered : Value
                entered =
                    parsed
                        |> Maybe.map Value.Date
                        |> Maybe.withDefault Value.Null
            in
            setFilter model id (writeBound state id bound entered)

        FiltersCleared ->
            state
                |> Table.resetColumnFilters
                |> Table.resetGlobalFilter
                |> firstPage

        GroupToggled id ->
            if Table.getCanGroup Report.config id then
                Table.toggleGrouping id state |> firstPage

            else
                state

        RowExpandToggled id ->
            case Report.findDisplayedRow model id of
                Just row ->
                    Table.toggleExpanded Report.config model.stages.sorted row Nothing state

                Nothing ->
                    state

        AllRowsExpandToggled ->
            Table.toggleAllRowsExpanded Report.config model.stages.sorted Nothing state

        RowSelectToggled id ->
            case Report.findDisplayedRow model id of
                Just row ->
                    Table.toggleRowSelected Report.config model.stages.paginated row Nothing state

                Nothing ->
                    state

        PageRowsSelectToggled ->
            Table.toggleAllPageRowsSelected Report.config model.stages.paginated Nothing state

        SelectionCleared ->
            Table.resetRowSelection state

        PageSizePicked text ->
            Table.setPageSize (String.toInt text |> Maybe.withDefault 25) state

        PrevPageClicked ->
            Table.previousPage Report.config state

        NextPageClicked ->
            if Table.getCanNextPage Report.config state model.stages.expanded then
                Table.nextPage Report.config state

            else
                state

        ColumnVisibilityToggled id ->
            case Table.findColumn Report.config id of
                Just column ->
                    Table.toggleColumnVisibility Report.config column Nothing state

                Nothing ->
                    state

        KeywordPinToggled ->
            case Table.findColumn Report.config "keyword" of
                Just column ->
                    if Table.columnIsPinned state column == Table.pinnedLeft then
                        Table.pinColumn Table.columnUnpinned column state

                    else
                        Table.pinColumn Table.pinnedLeft column state

                Nothing ->
                    state

        SeedTyped _ ->
            state

        RegenerateClicked ->
            state

        Measured _ ->
            state


setFilter : Model -> String -> Value -> Table.State
setFilter model id value =
    Table.setColumnFilter Report.config model.stages.core id value model.state
        |> firstPage


writeBound : Table.State -> String -> Bound -> Value -> Value
writeBound state id bound entered =
    let
        keep : Int -> Value
        keep index =
            case Table.getFilterValue state id of
                Just (Value.List items) ->
                    List.drop index items |> List.head |> Maybe.withDefault Value.Null

                _ ->
                    Value.Null
    in
    case bound of
        Lower ->
            Value.List [ entered, keep 1 ]

        Upper ->
            Value.List [ keep 0, entered ]


stringValue : String -> Value
stringValue text =
    if String.isEmpty (String.trim text) then
        Value.Null

    else
        Value.String text


firstPage : Table.State -> Table.State
firstPage =
    Table.setPage Report.config 0
