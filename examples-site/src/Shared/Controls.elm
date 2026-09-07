module Shared.Controls exposing
    ( stateToString, stateDump
    , sortArrow, formatInt, round2, formatFloat, isoDate, valueToString
    , Pager, pager
    , onChange, onClickShift
    )

{-| The bits of chrome every example page repeats.

React examples end with `<pre>{JSON.stringify(table.state, null, 2)}</pre>`
and a row of pagination buttons. Elm has no `JSON.stringify` for an opaque
record and `Debug.toString` is out (the site builds with `--optimize`), so
[`stateToString`](#stateToString) encodes `Table.State` by hand.

@docs stateToString, stateDump
@docs sortArrow, formatInt, round2, formatFloat, isoDate, valueToString
@docs Pager, pager
@docs onChange, onClickShift

-}

import Dict exposing (Dict)
import Html exposing (Html, button, div, input, option, pre, select, span, strong, text)
import Html.Attributes exposing (class, disabled, selected, type_, value)
import Html.Events exposing (on, onClick, onInput, targetValue)
import Json.Decode as Decode
import Json.Encode as Encode
import Set exposing (Set)
import Table
import Table.Value as Value exposing (Value)
import Time



-- STATE DUMP


{-| `JSON.stringify(table.state, null, 2)`, written out by hand.
-}
stateToString : Table.State -> String
stateToString state =
    Encode.encode 2 (encodeState state)


{-| The dump in the `<pre>` every React example ends with.
-}
stateDump : Table.State -> Html msg
stateDump state =
    pre [ class "state-dump" ] [ text (stateToString state) ]


encodeState : Table.State -> Encode.Value
encodeState state =
    Encode.object
        [ ( "sorting"
          , Encode.list
                (\s ->
                    Encode.object
                        [ ( "id", Encode.string s.id )
                        , ( "desc", Encode.bool s.desc )
                        ]
                )
                state.sorting
          )
        , ( "columnFilters"
          , Encode.list
                (\f ->
                    Encode.object
                        [ ( "id", Encode.string f.id )
                        , ( "value", encodeValue f.value )
                        ]
                )
                state.columnFilters
          )
        , ( "globalFilter", encodeValue state.globalFilter )
        , ( "grouping", Encode.list Encode.string state.grouping )
        , ( "expanded", encodeExpanded state.expanded )
        , ( "rowSelection", encodeSet state.rowSelection )
        , ( "pagination"
          , Encode.object
                [ ( "pageIndex", Encode.int state.pagination.pageIndex )
                , ( "pageSize", Encode.int state.pagination.pageSize )
                ]
          )
        , ( "columnOrder", Encode.list Encode.string state.columnOrder )
        , ( "columnVisibility", encodeDict Encode.bool state.columnVisibility )
        , ( "columnPinning"
          , Encode.object
                [ ( "left", Encode.list Encode.string state.columnPinning.left )
                , ( "right", Encode.list Encode.string state.columnPinning.right )
                ]
          )
        , ( "columnSizing", encodeDict Encode.float state.columnSizing )
        , ( "rowPinning"
          , Encode.object
                [ ( "top", Encode.list Encode.string state.rowPinning.top )
                , ( "bottom", Encode.list Encode.string state.rowPinning.bottom )
                ]
          )
        ]


encodeExpanded : Table.Expanded -> Encode.Value
encodeExpanded expanded =
    case Table.expandedIdsOf expanded of
        Nothing ->
            Encode.bool True

        Just ids ->
            encodeSet ids


encodeSet : Set String -> Encode.Value
encodeSet ids =
    Encode.list Encode.string (Set.toList ids)


encodeDict : (a -> Encode.Value) -> Dict String a -> Encode.Value
encodeDict encode dict =
    Encode.object (List.map (\( k, v ) -> ( k, encode v )) (Dict.toList dict))


encodeValue : Value -> Encode.Value
encodeValue v =
    case v of
        Value.String s ->
            Encode.string s

        Value.Number n ->
            Encode.float n

        Value.Bool b ->
            Encode.bool b

        Value.Date posix ->
            Encode.string (isoDate posix)

        Value.List items ->
            Encode.list encodeValue items

        Value.Null ->
            Encode.null



-- FORMATTING


{-| The `🔼` / `🔽` the React examples append to a sorted header.
-}
sortArrow : Maybe Table.SortDir -> String
sortArrow sorted =
    case sorted of
        Nothing ->
            ""

        Just dir ->
            if dir == Table.sortAsc then
                " 🔼"

            else
                " 🔽"


{-| `Number.prototype.toLocaleString` for the counts the examples print.
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
    if String.length digits <= 3 then
        digits

    else
        groupDigits (String.dropRight 3 digits) ++ "," ++ String.right 3 digits


{-| `Math.round(value * 100) / 100` as a string.
-}
round2 : Float -> String
round2 value =
    String.fromFloat (toFloat (round (value * 100)) / 100)


{-| `toLocaleString(undefined, { maximumFractionDigits: 2 })`: thousands
separators and at most two decimals.
-}
formatFloat : Float -> String
formatFloat value =
    case String.split "." (round2 value) of
        whole :: rest ->
            String.join "."
                (formatInt (Maybe.withDefault 0 (String.toInt whole)) :: rest)

        [] ->
            round2 value


{-| `YYYY-MM-DD` in UTC, the locale-independent date the examples render.
-}
isoDate : Time.Posix -> String
isoDate posix =
    String.fromInt (Time.toYear Time.utc posix)
        ++ "-"
        ++ pad (monthNumber (Time.toMonth Time.utc posix))
        ++ "-"
        ++ pad (Time.toDay Time.utc posix)


pad : Int -> String
pad n =
    String.padLeft 2 '0' (String.fromInt n)


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


{-| `Value.toString`, except that a `Date` prints as `YYYY-MM-DD`.
-}
valueToString : Value -> String
valueToString v =
    case v of
        Value.Date posix ->
            isoDate posix

        _ ->
            Value.toString v



-- PAGER


{-| Everything the pagination row of a React example needs.
-}
type alias Pager msg =
    { first : msg
    , previous : msg
    , next : msg
    , last : msg
    , goToPage : String -> msg
    , setPageSize : String -> msg
    , canPrevious : Bool
    , canNext : Bool
    , canLast : Bool
    , pageIndex : Int
    , pageCount : Int
    , pageSize : Int
    , pageSizes : List Int
    , showAll : Bool
    }


{-| The `<< < > >>`, "Page x of y", "Go to page", and page-size select row.
-}
pager : Pager msg -> Html msg
pager conf =
    div [ class "controls" ]
        [ pagerButton conf.first (not conf.canPrevious) "<<"
        , pagerButton conf.previous (not conf.canPrevious) "<"
        , pagerButton conf.next (not conf.canNext) ">"
        , pagerButton conf.last (not conf.canLast) ">>"
        , span [ class "inline-controls" ]
            [ div [] [ text "Page" ]
            , strong []
                [ text (formatInt (conf.pageIndex + 1) ++ " of " ++ formatInt conf.pageCount) ]
            ]
        , span [ class "inline-controls" ]
            [ text "| Go to page:"
            , input
                [ type_ "number"
                , class "small"
                , value (String.fromInt (conf.pageIndex + 1))
                , onInput conf.goToPage
                ]
                []
            ]
        , select [ onInput conf.setPageSize, onChange conf.setPageSize ]
            (List.map (pageSizeOption conf.pageSize) conf.pageSizes
                ++ (if conf.showAll then
                        [ option
                            [ value (String.fromInt Table.unlimitedPageSize)
                            , selected (conf.pageSize == Table.unlimitedPageSize)
                            ]
                            [ text "Show All" ]
                        ]

                    else
                        []
                   )
            )
        ]


pagerButton : msg -> Bool -> String -> Html msg
pagerButton msg isDisabled label =
    button [ class "small", onClick msg, disabled isDisabled ] [ text label ]


pageSizeOption : Int -> Int -> Html msg
pageSizeOption current size =
    option [ value (String.fromInt size), selected (current == size) ]
        [ text ("Show " ++ String.fromInt size) ]


{-| `onInput` does not fire for a `<select>` in every browser; this listens
for `change` as well.
-}
onChange : (String -> msg) -> Html.Attribute msg
onChange toMsg =
    on "change" (Decode.map toMsg targetValue)


{-| A click that reports whether Shift was held, which is how TanStack's
`getToggleSortingHandler` decides between single and multi-sort.
-}
onClickShift : (Bool -> msg) -> Html.Attribute msg
onClickShift toMsg =
    on "click" (Decode.map toMsg (Decode.field "shiftKey" Decode.bool))
