module BasicDynamicColumns exposing (main)

{-| Ports `examples/react/basic-dynamic-columns/src/main.tsx`.

The columns are built at runtime from a list of field names instead of a
hard-coded column list. For each field the example

1.  detects the value's data type,
2.  picks a sort fn and a filter fn that suit that type,
3.  renders a different filter control per type,

and the distinct values / min-max behind those controls come from
`Table.facetedUniqueValues` and `Table.facetedMinMax`, not from a hand-rolled
scan of the data. The checkboxes add and remove fields, which rebuilds the
whole column list.

-}

import Browser
import Html exposing (Html, button, div, input, label, option, p, select, span, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (checked, class, colspan, placeholder, selected, type_, value)
import Html.Events exposing (onCheck, onClick, onInput)
import Shared.Controls as Controls
import Shared.People as People exposing (Person)
import Table
import Table.FilterFn as FilterFn exposing (FilterFn)
import Table.SortFn as SortFn exposing (SortFn)
import Table.Value as Value exposing (Value)
import Time



-- THE DATA, AS FIELDS


{-| The runtime-detected data type of a field.
-}
type DataType
    = TypeString
    | TypeNumber
    | TypeBoolean
    | TypeDate


type alias Field =
    { key : String
    , dataType : DataType
    , read : Person -> Value
    }


{-| Elm records have no `Object.keys`, so the "shape of the data" is this
list. Everything below is derived from it at runtime.
-}
fields : List Field
fields =
    [ Field "firstName" TypeString (.firstName >> Value.String)
    , Field "lastName" TypeString (.lastName >> maybeString)
    , Field "status" TypeString (.status >> People.statusToString >> Value.String)
    , Field "age" TypeNumber (.age >> toFloat >> Value.Number)
    , Field "visits" TypeNumber (.visits >> maybeNumber)
    , Field "progress" TypeNumber (.progress >> toFloat >> Value.Number)

    -- `Shared.People.Person` has no boolean field; `rank` stands in for the
    -- React example's `isActive` so the boolean branch has something to show.
    , Field "isActive" TypeBoolean (\person -> Value.Bool (person.rank >= 50))
    , Field "createdAt" TypeDate (.createdAt >> Value.Date)
    ]


maybeString : Maybe String -> Value
maybeString =
    Maybe.map Value.String >> Maybe.withDefault Value.Null


maybeNumber : Maybe Int -> Value
maybeNumber =
    Maybe.map (toFloat >> Value.Number) >> Maybe.withDefault Value.Null


fieldFor : String -> Maybe Field
fieldFor key =
    List.head (List.filter (\field -> field.key == key) fields)



-- DERIVING COLUMNS


config : List String -> Table.Config Person
config keys =
    Table.config (List.filterMap columnFor keys)
        |> Table.withGetRowId (\person _ _ -> person.id)


columnFor : String -> Maybe (Table.Column Person)
columnFor key =
    fieldFor key
        |> Maybe.map
            (\field ->
                Table.column field.key field.read
                    |> Table.withHeader (formatHeader field.key)
                    |> Table.withSortFn (sortFnFor field.dataType)
                    |> Table.withFilterFn (filterFnFor field.dataType)
            )


{-| Turn a data key like "firstName" into a readable header like
"First Name".
-}
formatHeader : String -> String
formatHeader key =
    let
        withSpaces : String
        withSpaces =
            String.foldl
                (\char acc ->
                    if Char.isUpper char && acc /= "" then
                        acc ++ " " ++ String.fromChar char

                    else
                        acc ++ String.fromChar char
                )
                ""
                key
    in
    String.toUpper (String.left 1 withSpaces) ++ String.dropLeft 1 withSpaces


sortFnFor : DataType -> SortFn
sortFnFor dataType =
    case dataType of
        TypeNumber ->
            SortFn.basic

        TypeBoolean ->
            SortFn.basic

        TypeDate ->
            SortFn.datetime

        TypeString ->
            SortFn.alphanumeric


{-| Unlike the React example this needs no hand-written filter fns: the
package ships the boolean and date-range cases as `equalsString` and
`inDateRange`.
-}
filterFnFor : DataType -> FilterFn
filterFnFor dataType =
    case dataType of
        TypeNumber ->
            FilterFn.inNumberRange

        TypeBoolean ->
            FilterFn.equalsString

        TypeDate ->
            FilterFn.inDateRange

        TypeString ->
            FilterFn.includesString


renderValue : DataType -> Value -> String
renderValue dataType v =
    case ( dataType, v ) of
        ( _, Value.Null ) ->
            ""

        ( TypeDate, _ ) ->
            Controls.isoDate (dateOf v)

        ( TypeBoolean, Value.Bool True ) ->
            "✅"

        ( TypeBoolean, _ ) ->
            "❌"

        _ ->
            Value.toString v


dateOf : Value -> Time.Posix
dateOf v =
    case v of
        Value.Date posix ->
            posix

        _ ->
            Time.millisToPosix 0



-- MODEL


rowCount : Int
rowCount =
    1000


type alias Model =
    { state : Table.State
    , seed : Int
    , data : List Person
    , keys : List String
    }


init : Model
init =
    { state = Table.initialState
    , seed = 42
    , data = People.makeData 42 [ rowCount ]
    , keys = List.map .key fields
    }


type alias Stages =
    { core : Table.RowModel Person
    , filtered : Table.RowModel Person
    , sorted : Table.RowModel Person
    }


stages : Model -> Stages
stages model =
    let
        cfg : Table.Config Person
        cfg =
            config model.keys

        core : Table.RowModel Person
        core =
            Table.coreRowModelFromList cfg model.state model.data

        filtered : Table.RowModel Person
        filtered =
            Table.filteredRowModel cfg model.state core
    in
    { core = core
    , filtered = filtered
    , sorted = Table.sortedRowModel cfg model.state filtered
    }



-- UPDATE


type Msg
    = RegenerateData
    | ColumnToggled String Bool
    | SortClicked String Bool
    | FilterChanged String Value


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

        ColumnToggled key on ->
            { model
                | keys =
                    if on then
                        List.filter (\k -> List.member k model.keys || k == key)
                            (List.map .key fields)

                    else
                        List.filter (\k -> k /= key) model.keys
            }

        SortClicked columnId multi ->
            { model
                | state =
                    Table.toggleSort (config model.keys)
                        (stages model).filtered
                        columnId
                        { desc = Nothing, multi = multi }
                        model.state
            }

        FilterChanged columnId v ->
            { model
                | state =
                    Table.setColumnFilter (config model.keys)
                        (stages model).core
                        columnId
                        v
                        model.state
            }



-- VIEW


view : Model -> Html Msg
view model =
    let
        cfg : Table.Config Person
        cfg =
            config model.keys

        current : Stages
        current =
            stages model
    in
    div [ class "demo-root" ]
        [ p [ class "muted" ]
            [ text "Columns, sort fns, filter fns, and filter controls are all derived from the data type of each field, not from a hard-coded column definition." ]
        , div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ] ]
        , div [ class "button-row" ] (List.map (fieldToggle model) fields)
        , div [ class "spacer-sm" ] []
        , table []
            [ thead []
                [ tr []
                    (List.map (viewHeaderCell model cfg current)
                        (Table.flatHeaders cfg model.state)
                    )
                ]
            , tbody []
                (List.map (viewRow model cfg) (List.take 15 current.sorted.rows))
            ]
        , div [ class "spacer-sm" ] []
        , div [] [ text (Controls.formatInt (List.length current.sorted.rows) ++ " Rows") ]
        ]


fieldToggle : Model -> Field -> Html Msg
fieldToggle model field =
    label [ class "inline-controls" ]
        [ input
            [ type_ "checkbox"
            , checked (List.member field.key model.keys)
            , onCheck (ColumnToggled field.key)
            ]
            []
        , text (formatHeader field.key)
        ]


viewHeaderCell : Model -> Table.Config Person -> Stages -> Table.Header Person -> Html Msg
viewHeaderCell model cfg current header =
    let
        columnId : String
        columnId =
            Table.headerColumnId header
    in
    th [ colspan (Table.headerColSpan header) ]
        [ span
            [ class "sortable", Controls.onClickShift (SortClicked columnId) ]
            [ text
                (formatHeader columnId
                    ++ Controls.sortArrow (Table.getIsSorted model.state columnId)
                )
            ]
        , viewFilter model cfg current columnId
        ]


viewFilter : Model -> Table.Config Person -> Stages -> String -> Html Msg
viewFilter model cfg current columnId =
    let
        filterValue : Value
        filterValue =
            Maybe.withDefault Value.Null (Table.getFilterValue model.state columnId)

        dataType : DataType
        dataType =
            fieldFor columnId
                |> Maybe.map .dataType
                |> Maybe.withDefault TypeString
    in
    case dataType of
        TypeNumber ->
            let
                minMax : Maybe ( Float, Float )
                minMax =
                    Table.facetedMinMax cfg model.state current.core columnId
            in
            div [ class "filter-row" ]
                [ rangeInput "number" columnId filterValue 0 (bound "Min" (Maybe.map Tuple.first minMax))
                , rangeInput "number" columnId filterValue 1 (bound "Max" (Maybe.map Tuple.second minMax))
                ]

        TypeDate ->
            div [ class "filter-row" ]
                [ rangeInput "date" columnId filterValue 0 ""
                , rangeInput "date" columnId filterValue 1 ""
                ]

        TypeBoolean ->
            select
                [ onInput (Value.String >> FilterChanged columnId)
                , Controls.onChange (Value.String >> FilterChanged columnId)
                ]
                (List.map (filterOption (Value.toString filterValue))
                    [ ( "", "All" ), ( "true", "Yes" ), ( "false", "No" ) ]
                )

        TypeString ->
            let
                uniqueValues : List String
                uniqueValues =
                    Table.facetedUniqueValues cfg model.state current.core columnId
                        |> List.map (Tuple.first >> Value.toString)
                        |> List.sort
            in
            if not (List.isEmpty uniqueValues) && List.length uniqueValues <= 10 then
                select
                    [ onInput (Value.String >> FilterChanged columnId)
                    , Controls.onChange (Value.String >> FilterChanged columnId)
                    ]
                    (List.map (filterOption (Value.toString filterValue))
                        (( "", "All" ) :: List.map (\v -> ( v, v )) uniqueValues)
                    )

            else
                input
                    [ type_ "text"
                    , class "filter"
                    , value (Value.toString filterValue)
                    , placeholder
                        ("Search... (" ++ String.fromInt (List.length uniqueValues) ++ ")")
                    , onInput (Value.String >> FilterChanged columnId)
                    ]
                    []


bound : String -> Maybe Float -> String
bound name limit =
    case limit of
        Nothing ->
            name

        Just n ->
            name ++ " (" ++ Controls.round2 n ++ ")"


filterOption : String -> ( String, String ) -> Html Msg
filterOption current ( optionValue, label_ ) =
    option [ value optionValue, selected (current == optionValue) ] [ text label_ ]


{-| One end of a two-part range filter value, `Value.List [ min, max ]`.
-}
rangeInput : String -> String -> Value -> Int -> String -> Html Msg
rangeInput inputType columnId filterValue index hint =
    input
        [ type_ inputType
        , class "filter"
        , placeholder hint
        , value (rangeEnd index filterValue)
        , onInput (\typed -> FilterChanged columnId (setRangeEnd index typed filterValue))
        ]
        []


rangeEnd : Int -> Value -> String
rangeEnd index v =
    case v of
        Value.List items ->
            List.drop index items
                |> List.head
                |> Maybe.map Value.toString
                |> Maybe.withDefault ""

        _ ->
            ""


setRangeEnd : Int -> String -> Value -> Value
setRangeEnd index typed v =
    let
        other : String
        other =
            rangeEnd (1 - index) v
    in
    if index == 0 then
        Value.List [ Value.String typed, Value.String other ]

    else
        Value.List [ Value.String other, Value.String typed ]


viewRow : Model -> Table.Config Person -> Table.Row Person -> Html Msg
viewRow model cfg row =
    tr []
        (List.map (viewCell >> td []) (Table.getAllCells cfg model.state row))


viewCell : Table.Cell -> List (Html Msg)
viewCell cell =
    [ text
        (renderValue
            (fieldFor cell.columnId |> Maybe.map .dataType |> Maybe.withDefault TypeString)
            cell.value
        )
    ]


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
