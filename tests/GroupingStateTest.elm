module GroupingStateTest exposing (suite)

{-| Ports
`tests/unit/features/column-grouping/columnGroupingFeature.utils.test.ts`.

Elm cannot compare functions, so the `column_getAutoAggregationFn` cases
compare a label recovered by running the aggregation, exactly as phase 3's
`filterFnLabel` and `sortFnLabel` do.

-}

import Expect
import Table
import Table.AggregationFn as AggregationFn exposing (AggregationFn)
import Table.Value as Value exposing (Value)
import Test exposing (Test, describe, test)
import Time



-- THE SALE FIXTURE


type alias Sale =
    { status : String
    , label : String
    , amount : Float
    , soldAt : Time.Posix
    }


sales : List Sale
sales =
    [ Sale "a" "one" 10 (day 1)
    , Sale "a" "two" 20 (day 32)
    , Sale "b" "one" 30 (day 61)
    , Sale "b" "two" 40 (day 92)
    ]


day : Int -> Time.Posix
day n =
    Time.millisToPosix (n * 86400000)


columns : List (Table.Column Sale)
columns =
    [ Table.column "status" (.status >> Value.String)
    , Table.column "label" (.label >> Value.String)
    , Table.column "amount" (.amount >> Value.Number)
    , Table.column "soldAt" (.soldAt >> Value.Date)

    -- display column with no accessor
    , Table.display "actions" |> Table.withHeader "Actions"
    ]


config : Table.Config Sale
config =
    Table.config columns


coreModel : Table.Config Sale -> Table.RowModel Sale
coreModel cfg =
    Table.coreRowModelFromList cfg Table.initialState sales


groupedBy : List String -> Table.RowModel Sale
groupedBy grouping =
    let
        state : Table.State
        state =
            { plain | grouping = grouping }

        plain : Table.State
        plain =
            Table.initialState
    in
    Table.groupedRowModel config state (coreModel config)


stateWith : List String -> Table.State
stateWith grouping =
    let
        plain : Table.State
        plain =
            Table.initialState
    in
    { plain | grouping = grouping }


{-| The name of a built-in aggregation fn, recovered from its behaviour.
`sum` folds two numbers into their total, `extent` into a two-item list.
-}
aggregationFnLabel : AggregationFn -> String
aggregationFnLabel fn =
    let
        folded : Value
        folded =
            AggregationFn.aggregate fn [ Value.Number 1, Value.Number 3 ]
    in
    if folded == Value.Number 4 then
        "sum"

    else if folded == Value.List [ Value.Number 1, Value.Number 3 ] then
        "extent"

    else
        "other"


labelOf : Maybe AggregationFn -> Maybe String
labelOf =
    Maybe.map aggregationFnLabel



-- SUITE


suite : Test
suite =
    describe "columnGroupingFeature.utils"
        [ describe "getDefaultGroupingState"
            [ test "should return an empty array and a new instance each time" <|
                \_ ->
                    -- The "new instance" half is JavaScript object identity;
                    -- Elm lists are values. `resetGrouping` is TanStack's
                    -- `table_resetGrouping(table, true)`.
                    Expect.equal (Table.resetGrouping (stateWith [ "status" ])).grouping []
            ]
        , describe "column_toggleGrouping"
            [ test "should append an ungrouped column to the grouping state" <|
                \_ ->
                    (Table.toggleGrouping "status" (stateWith [ "label" ])).grouping
                        |> Expect.equal [ "label", "status" ]
            , test "should remove a grouped column and keep the rest in order" <|
                \_ ->
                    (Table.toggleGrouping "status" (stateWith [ "label", "status", "amount" ])).grouping
                        |> Expect.equal [ "label", "amount" ]
            ]
        , describe "column_getCanGroup"
            [ test "should return true for accessor columns by default" <|
                \_ ->
                    Table.getCanGroup config "status" |> Expect.equal True
            , test "should return false for display columns without an accessor" <|
                \_ ->
                    Table.getCanGroup config "actions" |> Expect.equal False
            , test "should return true for display columns that provide getGroupingValue" <|
                \_ ->
                    let
                        cfg : Table.Config Sale
                        cfg =
                            Table.config
                                [ Table.display "derived"
                                    |> Table.withHeader "Derived"
                                    |> Table.withGetGroupingValue
                                        (\row _ -> Value.String row.status)
                                ]
                    in
                    Table.getCanGroup cfg "derived" |> Expect.equal True
            , test "should return false when grouping is disabled for the column" <|
                \_ ->
                    let
                        cfg : Table.Config Sale
                        cfg =
                            Table.config
                                [ Table.column "status" (.status >> Value.String)
                                    |> Table.withEnableGrouping False
                                ]
                    in
                    Table.getCanGroup cfg "status" |> Expect.equal False
            , test "should return false when grouping is disabled table-wide" <|
                \_ ->
                    Table.getCanGroup { config | enableGrouping = False } "status"
                        |> Expect.equal False
            ]
        , describe "column_getIsGrouped / column_getGroupedIndex"
            [ test "should read the grouping state for this column" <|
                \_ ->
                    let
                        state : Table.State
                        state =
                            stateWith [ "label", "status" ]
                    in
                    Expect.equal
                        { statusGrouped = Table.getIsGrouped state "status"
                        , amountGrouped = Table.getIsGrouped state "amount"
                        , labelIndex = Table.getGroupedIndex state "label"
                        , statusIndex = Table.getGroupedIndex state "status"
                        , amountIndex = Table.getGroupedIndex state "amount"
                        }
                        { statusGrouped = True
                        , amountGrouped = False
                        , labelIndex = 0
                        , statusIndex = 1
                        , amountIndex = -1
                        }
            ]
        , describe "column_getToggleGroupingHandler"
            [ test "should toggle grouping for groupable columns" <|
                \_ ->
                    handle config "status" [] |> Expect.equal [ "status" ]
            , test "should be a no-op when the column cannot group" <|
                \_ ->
                    handle { config | enableGrouping = False } "status" []
                        |> Expect.equal []
            ]
        , describe "column_getAutoAggregationFn"
            [ test "should choose sum for number columns" <|
                \_ ->
                    labelOf (Table.getAutoAggregationFn config (coreModel config) "amount")
                        |> Expect.equal (Just "sum")
            , test "should choose extent for date columns" <|
                \_ ->
                    labelOf (Table.getAutoAggregationFn config (coreModel config) "soldAt")
                        |> Expect.equal (Just "extent")
            , test "should leave other value types unspecified" <|
                \_ ->
                    labelOf (Table.getAutoAggregationFn config (coreModel config) "status")
                        |> Expect.equal Nothing
            ]
        , describe "table_setGrouping / table_resetGrouping"
            [ test "should route the updater through onGroupingChange" <|
                \_ ->
                    (Table.setGrouping [ "status" ] (stateWith [])).grouping
                        |> Expect.equal [ "status" ]
            , test "should reset to an empty array when defaultState is true" <|
                \_ ->
                    (Table.resetGrouping (stateWith [ "status" ])).grouping
                        |> Expect.equal []
            , test "should reset to the initial grouping by default" <|
                \_ ->
                    -- There is no `initialState` in this port, so a caller
                    -- that wants its own starting grouping back writes it with
                    -- `setGrouping`; see `reports/phase-3.md`.
                    (Table.setGrouping [ "status" ] (stateWith [])).grouping
                        |> Expect.equal [ "status" ]
            ]
        , describe "row_getIsGrouped"
            [ test "should distinguish grouped rows from leaf rows" <|
                \_ ->
                    let
                        model : Table.RowModel Sale
                        model =
                            groupedBy [ "status" ]

                        groupRow : Maybe (Table.Row Sale)
                        groupRow =
                            List.head model.rows

                        leafRow : Maybe (Table.Row Sale)
                        leafRow =
                            groupRow |> Maybe.andThen (Table.rowSubRows >> List.head)
                    in
                    Expect.equal
                        ( Maybe.map Table.rowIsGrouped groupRow
                        , Maybe.map Table.rowIsGrouped leafRow
                        )
                        ( Just True, Just False )
            ]
        , describe "row_getGroupingValue"
            [ test "should fall back to the accessor value" <|
                \_ ->
                    (coreModel config).rows
                        |> List.head
                        |> Maybe.map (\row -> Table.rowGroupingValueFor config row "status")
                        |> Expect.equal (Just (Value.String "a"))
            , test "should prefer getGroupingValue and cache the result per row" <|
                \_ ->
                    -- The call-count half of this case is memoization;
                    -- `rowGroupingValueFor` is pure, so repeated reads are
                    -- asserted to give the same value instead.
                    let
                        cfg : Table.Config Sale
                        cfg =
                            Table.config
                                [ Table.column "status" (.status >> Value.String)
                                    |> Table.withGetGroupingValue
                                        (\row _ -> Value.String (String.toUpper row.status))
                                ]

                        read : Maybe Value
                        read =
                            (coreModel cfg).rows
                                |> List.head
                                |> Maybe.map (\row -> Table.rowGroupingValueFor cfg row "status")
                    in
                    Expect.equal ( read, read ) ( Just (Value.String "A"), Just (Value.String "A") )
            ]
        , cellSuite
        ]


{-| `column_getToggleGroupingHandler`: the handler is a `getCanGroup` guard in
front of `toggleGrouping`.
-}
handle : Table.Config Sale -> String -> List String -> List String
handle cfg columnId grouping =
    if Table.getCanGroup cfg columnId then
        (Table.toggleGrouping columnId (stateWith grouping)).grouping

    else
        grouping


cellSuite : Test
cellSuite =
    let
        state : Table.State
        state =
            stateWith [ "status", "label" ]

        model : Table.RowModel Sale
        model =
            groupedBy [ "status", "label" ]

        groupRow : Maybe (Table.Row Sale)
        groupRow =
            List.head model.rows

        leafRow : Maybe (Table.Row Sale)
        leafRow =
            groupRow
                |> Maybe.andThen (Table.rowSubRows >> List.head)
                |> Maybe.andThen (Table.rowSubRows >> List.head)

        on : Maybe (Table.Row Sale) -> (Table.Row Sale -> String -> Bool) -> String -> Maybe Bool
        on row check columnId =
            Maybe.map (\r -> check r columnId) row
    in
    describe "cell grouping states"
        [ test "cell_getIsGrouped should be true only for the row grouping column cell" <|
            \_ ->
                Expect.equal
                    { status = on groupRow (Table.cellIsGrouped state) "status"
                    , label = on groupRow (Table.cellIsGrouped state) "label"
                    , amount = on groupRow (Table.cellIsGrouped state) "amount"
                    }
                    { status = Just True, label = Just False, amount = Just False }
        , test "cell_getIsPlaceholder should be true for other grouped column cells" <|
            \_ ->
                Expect.equal
                    { label = on groupRow (Table.cellIsPlaceholder state) "label"
                    , status = on groupRow (Table.cellIsPlaceholder state) "status"
                    , amount = on groupRow (Table.cellIsPlaceholder state) "amount"
                    }
                    { label = Just True, status = Just False, amount = Just False }
        , test "cell_getIsAggregated should be true for ungrouped cells on rows with subRows" <|
            \_ ->
                Expect.equal
                    { amount =
                        on groupRow
                            (Table.cellIsAggregated config (coreModel config) state)
                            "amount"
                    , status =
                        on groupRow
                            (Table.cellIsAggregated config (coreModel config) state)
                            "status"
                    }
                    { amount = Just True, status = Just False }
        , test "should report no aggregated cells on leaf rows" <|
            \_ ->
                Expect.equal
                    { status = on leafRow (Table.cellIsGrouped state) "status"
                    , amount =
                        on leafRow
                            (Table.cellIsAggregated config (coreModel config) state)
                            "amount"
                    }
                    { status = Just False, amount = Just False }
        ]
