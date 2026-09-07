module Report exposing
    ( Bound(..)
    , Model
    , Msg(..)
    , columnLabel
    , config
    , dateBound
    , dayEnd
    , dayStart
    , findDisplayedRow
    , formatDate
    , formatDay
    , formatInt
    , groupableColumns
    , parseDay
    , rangeBound
    , textFilter
    )

{-| The pieces `Main` and `View` share: the model, the messages, the column
set, and the small formatting helpers.
-}

import Array exposing (Array)
import Data exposing (Keyword)
import Table exposing (Config, Row, State)
import Table.AggregationFn as AggregationFn
import Table.FilterFn as FilterFn
import Table.SortFn as SortFn
import Table.Value as Value exposing (Value)
import Time
import Timing


{-| Everything the page owns. The table's own state lives in `state`; the
row models in `stages` are the ones the last measured run produced.
-}
type alias Model =
    { seed : Int
    , seedField : String
    , now : Time.Posix
    , data : Array Keyword
    , state : State
    , stages : Timing.Stages Keyword
    , timings : Timing.Timings
    }


{-| Which end of a range an input writes.
-}
type Bound
    = Lower
    | Upper


{-| Everything the page can do.
-}
type Msg
    = HeaderClicked String Bool
    | GlobalFilterTyped String
    | TextFilterTyped String String
    | EnumFilterPicked String String
    | RangeTyped String Bound String
    | DateTyped String Bound String
    | FiltersCleared
    | GroupToggled String
    | RowExpandToggled String
    | AllRowsExpandToggled
    | RowSelectToggled String
    | PageRowsSelectToggled
    | SelectionCleared
    | PageSizePicked String
    | PrevPageClicked
    | NextPageClicked
    | ColumnVisibilityToggled String
    | KeywordPinToggled
    | SeedTyped String
    | RegenerateClicked
    | Measured (Timing.Measured Keyword)



-- COLUMNS


{-| The ten columns of the report.
-}
config : Config Keyword
config =
    Table.config columns
        |> Table.withSubRows Data.subRows


columns : List (Table.Column Keyword)
columns =
    [ Table.column "keyword" (.keyword >> Value.String)
        |> Table.withHeader "Keyword"
        |> Table.withFilterFn FilterFn.includesString
        |> Table.withEnableGrouping False
        |> Table.withEnableHiding False
    , Table.column "cluster" (.cluster >> Value.String)
        |> Table.withHeader "Cluster"
        |> Table.withFilterFn FilterFn.includesString
    , Table.column "intent" (.intent >> Data.intentLabel >> Value.String)
        |> Table.withHeader "Intent"
        |> Table.withFilterFn FilterFn.equals
    , Table.column "volume" (.searchVolume >> toFloat >> Value.Number)
        |> Table.withHeader "Volume"
        |> Table.withFilterFn FilterFn.inNumberRange
        |> Table.withAggregationFn AggregationFn.sum
        |> Table.withEnableGrouping False
    , Table.column "difficulty" (.difficulty >> toFloat >> Value.Number)
        |> Table.withHeader "Difficulty"
        |> Table.withFilterFn FilterFn.inNumberRange
        |> Table.withAggregationFn AggregationFn.mean
        |> Table.withEnableGrouping False
    , Table.column "position" (.position >> toFloat >> Value.Number)
        |> Table.withHeader "Position"
        |> Table.withFilterFn FilterFn.inNumberRange
        |> Table.withAggregationFn AggregationFn.mean
        |> Table.withEnableGrouping False
    , Table.column "previous" (.previousPosition >> toFloat >> Value.Number)
        |> Table.withHeader "Previous"
        |> Table.withAggregationFn AggregationFn.mean
        |> Table.withEnableGrouping False
    , Table.column "change" (.change >> toFloat >> Value.Number)
        |> Table.withHeader "Change"
        |> Table.withAggregationFn AggregationFn.mean
        |> Table.withEnableGrouping False
    , Table.column "url" (.url >> Value.String)
        |> Table.withHeader "URL"
        |> Table.withEnableGrouping False
    , Table.column "crawled" (.lastCrawled >> Value.Date)
        |> Table.withHeader "Crawled"
        |> Table.withFilterFn FilterFn.inDateRange
        |> Table.withSortFn SortFn.datetime
        |> Table.withEnableGrouping False
    ]


{-| The two columns the report can group by.
-}
groupableColumns : List String
groupableColumns =
    [ "cluster", "intent" ]


{-| The header text of a column id, for the toolbar toggles.
-}
columnLabel : String -> String
columnLabel id =
    Table.findColumn config id
        |> Maybe.andThen Table.columnHeader
        |> Maybe.withDefault id



-- READING FILTER STATE BACK


{-| The text a `String` filter holds, or `""`.
-}
textFilter : State -> String -> String
textFilter state id =
    case Table.getFilterValue state id of
        Just (Value.String text) ->
            text

        _ ->
            ""


{-| One end of a numeric range filter, as the text its input shows.
-}
rangeBound : State -> String -> Bound -> String
rangeBound state id bound =
    case boundValue state id bound of
        Value.Number n ->
            String.fromInt (round n)

        _ ->
            ""


{-| One end of a date range filter, as `YYYY-MM-DD`.
-}
dateBound : State -> String -> Bound -> String
dateBound state id bound =
    case boundValue state id bound of
        Value.Date posix ->
            formatDay posix

        _ ->
            ""


boundValue : State -> String -> Bound -> Value
boundValue state id bound =
    let
        index : Int
        index =
            case bound of
                Lower ->
                    0

                Upper ->
                    1
    in
    case Table.getFilterValue state id of
        Just (Value.List items) ->
            List.drop index items |> List.head |> Maybe.withDefault Value.Null

        _ ->
            Value.Null



-- ROWS


{-| The row behind a row id on the current page.
-}
findDisplayedRow : Model -> String -> Maybe (Row Keyword)
findDisplayedRow model id =
    case Table.findRow model.stages.paginated id of
        Just row ->
            Just row

        Nothing ->
            model.stages.paginated.flatRows
                |> List.filter (\row -> Table.rowId row == id)
                |> List.head



-- FORMATTING


{-| An integer with thin spaces between thousands.
-}
formatInt : Int -> String
formatInt n =
    let
        sign : String
        sign =
            if n < 0 then
                "-"

            else
                ""
    in
    sign ++ groupDigits (String.fromInt (abs n))


groupDigits : String -> String
groupDigits digits =
    let
        head : Int
        head =
            modBy 3 (String.length digits)

        chunks : List String
        chunks =
            splitEvery 3 (String.dropLeft head digits)
    in
    if head == 0 then
        String.join "," chunks

    else
        String.join "," (String.left head digits :: chunks)


splitEvery : Int -> String -> List String
splitEvery size text =
    if String.isEmpty text then
        []

    else
        String.left size text :: splitEvery size (String.dropLeft size text)


{-| `6 Mar 2026`.
-}
formatDate : Time.Posix -> String
formatDate posix =
    String.fromInt (Time.toDay Time.utc posix)
        ++ " "
        ++ monthName (Time.toMonth Time.utc posix)
        ++ " "
        ++ String.fromInt (Time.toYear Time.utc posix)


{-| `2026-03-06`, the value an `input type="date"` reads.
-}
formatDay : Time.Posix -> String
formatDay posix =
    String.fromInt (Time.toYear Time.utc posix)
        ++ "-"
        ++ pad (monthNumber (Time.toMonth Time.utc posix))
        ++ "-"
        ++ pad (Time.toDay Time.utc posix)


pad : Int -> String
pad n =
    String.padLeft 2 '0' (String.fromInt n)


monthName : Time.Month -> String
monthName month =
    case month of
        Time.Jan ->
            "Jan"

        Time.Feb ->
            "Feb"

        Time.Mar ->
            "Mar"

        Time.Apr ->
            "Apr"

        Time.May ->
            "May"

        Time.Jun ->
            "Jun"

        Time.Jul ->
            "Jul"

        Time.Aug ->
            "Aug"

        Time.Sep ->
            "Sep"

        Time.Oct ->
            "Oct"

        Time.Nov ->
            "Nov"

        Time.Dec ->
            "Dec"


monthNumber : Time.Month -> Int
monthNumber month =
    case month of
        Time.Jan ->
            1

        Time.Feb ->
            2

        Time.Mar ->
            3

        Time.Apr ->
            4

        Time.May ->
            5

        Time.Jun ->
            6

        Time.Jul ->
            7

        Time.Aug ->
            8

        Time.Sep ->
            9

        Time.Oct ->
            10

        Time.Nov ->
            11

        Time.Dec ->
            12



-- DATES


{-| `YYYY-MM-DD` to the first millisecond of that day, UTC.
-}
parseDay : String -> Maybe Time.Posix
parseDay text =
    case String.split "-" text of
        [ y, m, d ] ->
            Maybe.map3 (\year month day -> Time.millisToPosix (daysFromCivil year month day * 86400000))
                (String.toInt y)
                (String.toInt m)
                (String.toInt d)

        _ ->
            Nothing


{-| The first millisecond of the day a date input names.
-}
dayStart : String -> Maybe Time.Posix
dayStart =
    parseDay


{-| The last millisecond of the day a date input names, so an upper bound
covers the whole day.
-}
dayEnd : String -> Maybe Time.Posix
dayEnd text =
    parseDay text
        |> Maybe.map (\posix -> Time.millisToPosix (Time.posixToMillis posix + 86399999))


daysFromCivil : Int -> Int -> Int -> Int
daysFromCivil year month day =
    let
        y : Int
        y =
            if month <= 2 then
                year - 1

            else
                year

        era : Int
        era =
            if y >= 0 then
                y // 400

            else
                (y - 399) // 400

        yoe : Int
        yoe =
            y - era * 400

        mp : Int
        mp =
            modBy 12 (month + 9)

        doy : Int
        doy =
            (153 * mp + 2) // 5 + day - 1

        doe : Int
        doe =
            yoe * 365 + yoe // 4 - yoe // 100 + doy
    in
    era * 146097 + doe - 719468
