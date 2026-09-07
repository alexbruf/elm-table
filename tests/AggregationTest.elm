module AggregationTest exposing (suite)

{-| Ports
`tests/implementation/features/row-aggregation/rowAggregationFeature.test.ts`.

`Table.AggregationFn` is a single fold plus an optional merge. TanStack's
keyed `aggregationFn: ['sum', 'mean', …]` option is `Table.withAggregationFns`
and produces a `Dict` rather than a `Value`, read back with
`Table.aggregationResults` and `Table.rowAggregationResults`; its
`AggregationFnDef.aggregate(context)` form is
`Table.aggregationFnWithContext`. `columnDef.getAggregationValue` and
`manualAggregation` are `Table.withGetAggregationValue` and
`Table.withManualAggregation`. Nothing in this file is excluded any more.

The cases that used to substitute a scalar column for a keyed one and still
do say so at the case; the keyed form itself is asserted by "aggregates
scalar and keyed root values without grouping" and by "computes nested
scalar/keyed values and aggregates deeper grouping columns".

-}

import Dict
import Expect
import Table
import Table.AggregationFn as AggregationFn exposing (AggregationFn)
import Table.Value as Value exposing (Value)
import Test exposing (Test, describe, test)
import Time


{-| Elm has no `Infinity` for `Int`; `Number.MAX_SAFE_INTEGER` reaches every
level of any row tree, which is what `maxDepth: Infinity` means.
-}
unlimitedDepth : Int
unlimitedDepth =
    9007199254740991


plain : Table.State
plain =
    Table.initialState


groupingState : List String -> Table.State
groupingState grouping =
    { plain | grouping = grouping }


core : Table.Config a -> List a -> Table.RowModel a
core cfg =
    Table.coreRowModelFromList cfg plain



-- SUITE


suite : Test
suite =
    describe "rowAggregationFeature"
        [ rootSuite
        , groupingSuite
        ]



-- ROOT AGGREGATION


type alias AmountRow =
    { amount : Value }


type alias Node =
    { amount : Float
    , label : String
    , subRows : Kids
    }


type Kids
    = Kids (List Node)


kidsOf : Node -> List Node
kidsOf row =
    case row.subRows of
        Kids kids ->
            kids


node : Float -> String -> List Node -> Node
node amount label kids =
    Node amount label (Kids kids)


nodeConfig : List (Table.Column Node) -> Table.Config Node
nodeConfig columns =
    Table.config columns |> Table.withSubRows kidsOf


rootSuite : Test
rootSuite =
    describe "rowAggregationFeature root values"
        [ -- adapted: `getAggregationFns().map(fn => fn.id)` becomes the keys of
          -- the keyed result, which a `Dict` orders alphabetically; the three
          -- ids of the vitest case are already in that order.
          test "aggregates scalar and keyed root values without grouping" <|
            \_ ->
                let
                    cfg : Table.Config AmountRow
                    cfg =
                        Table.config
                            [ Table.column "scalar" .amount
                                |> Table.withAggregationFn AggregationFn.sum
                            , Table.column "multiple" .amount
                                |> Table.withAggregationFns
                                    [ ( "count", AggregationFn.count )
                                    , ( "mean", AggregationFn.mean )
                                    , ( "range", AggregationFn.extent )
                                    ]
                            , Table.column "empty" .amount
                                |> Table.withAggregationFns []
                            ]

                    data : List AmountRow
                    data =
                        [ AmountRow (Value.Number 10)
                        , AmountRow (Value.Number 20)
                        , AmountRow Value.Null
                        ]

                    model : Table.RowModel AmountRow
                    model =
                        core cfg data
                in
                Expect.equal
                    { total = Table.aggregationValue cfg model "scalar"
                    , empty =
                        Table.aggregationValueOf cfg model "scalar" { maxDepth = 0, rows = [] }
                    , multiple = Dict.toList (Table.aggregationResults cfg model "multiple")
                    , multipleIds = Dict.keys (Table.aggregationResults cfg model "multiple")
                    , emptyKeyed = Dict.toList (Table.aggregationResults cfg model "empty")
                    , firstCellAggregated =
                        List.head model.rows
                            |> Maybe.map
                                (\row -> Table.cellIsAggregated cfg model plain row "scalar")
                    }
                    { total = Value.Number 30
                    , empty = Value.Number 0
                    , multiple =
                        [ ( "count", Value.Number 3 )
                        , ( "mean", Value.Number 15 )
                        , ( "range", Value.List [ Value.Number 10, Value.Number 20 ] )
                        ]
                    , multipleIds = [ "count", "mean", "range" ]
                    , emptyKeyed = []
                    , firstCellAggregated = Just False
                    }
        , test "infers auto aggregation from the first core row value" <|
            \_ ->
                -- The `vi.spyOn(row, 'getValue')` half is memoization.
                let
                    cfg : Table.Config AmountRow
                    cfg =
                        Table.config [ Table.column "amount" .amount ]

                    model : Table.RowModel AmountRow
                    model =
                        core cfg [ AmountRow (Value.Number 2), AmountRow (Value.Number 3) ]
                in
                Expect.equal
                    { auto =
                        Table.getAutoAggregationFn cfg model "amount"
                            |> Maybe.map (\fn -> AggregationFn.aggregate fn [ Value.Number 1, Value.Number 1 ])
                    , total = Table.aggregationValue cfg model "amount"
                    }
                    { auto = Just (Value.Number 2), total = Value.Number 5 }
        , -- adapted: nothing is cached in a pure port, so the call counts
          -- become "the same inputs give the same value" and the `setOptions`
          -- data swap becomes a second row model built from the new list.
          test "caches the default rows, invalidates with data, and recomputes explicit rows" <|
            \_ ->
                let
                    sized : AggregationFn
                    sized =
                        AggregationFn.custom
                            (\values -> Value.Number (toFloat (List.length values)))

                    cfg : Table.Config AmountRow
                    cfg =
                        Table.config
                            [ Table.column "value" .amount
                                |> Table.withAggregationFn sized
                            ]

                    model : Table.RowModel AmountRow
                    model =
                        core cfg [ AmountRow (Value.Number 1), AmountRow (Value.Number 2) ]

                    grown : Table.RowModel AmountRow
                    grown =
                        core cfg
                            [ AmountRow (Value.Number 1)
                            , AmountRow (Value.Number 2)
                            , AmountRow (Value.Number 3)
                            ]
                in
                Expect.equal
                    { first = Table.aggregationValue cfg model "value"
                    , second = Table.aggregationValue cfg model "value"
                    , explicit =
                        Table.aggregationValueOf cfg model "value" { maxDepth = 0, rows = model.rows }
                    , explicitAgain =
                        Table.aggregationValueOf cfg model "value" { maxDepth = 0, rows = model.rows }
                    , afterDataChange = Table.aggregationValue cfg grown "value"
                    }
                    { first = Value.Number 2
                    , second = Value.Number 2
                    , explicit = Value.Number 2
                    , explicitAgain = Value.Number 2
                    , afterDataChange = Value.Number 3
                    }
        , -- adapted: the cache key is not observable, so the assertion is that
          -- each depth keeps its own value across repeated reads.
          test "includes aggregation depth in the default-row cache key" <|
            \_ ->
                let
                    sized : AggregationFn
                    sized =
                        AggregationFn.custom
                            (\values -> Value.Number (toFloat (List.length values)))

                    cfg : Table.Config Node
                    cfg =
                        nodeConfig
                            [ Table.column "value" (.amount >> Value.Number)
                                |> Table.withAggregationFn sized
                            ]

                    model : Table.RowModel Node
                    model =
                        core cfg [ node 10 "root" [ node 1 "a" [], node 2 "b" [] ] ]

                    at : Int -> Value
                    at maxDepth =
                        Table.aggregationValueOf cfg model "value" { maxDepth = maxDepth, rows = model.rows }
                in
                Expect.equal
                    { default_ = at 0
                    , defaultAgain = at 0
                    , deeper = at 1
                    , deeperAgain = at 1
                    , backToDefault = at 0
                    }
                    { default_ = Value.Number 1
                    , defaultAgain = Value.Number 1
                    , deeper = Value.Number 2
                    , deeperAgain = Value.Number 2
                    , backToDefault = Value.Number 1
                    }
        , test "accepts rows from any row model or custom selection" <|
            \_ ->
                -- The `getFilteredSelectedRowModel` line needs row selection,
                -- which is phase 5's; the four other row sources are here.
                let
                    cfg : Table.Config Category
                    cfg =
                        Table.config
                            [ Table.column "category" (.category >> Value.String)
                            , Table.column "amount" (.amount >> Value.Number)
                                |> Table.withAggregationFn AggregationFn.sum
                            ]

                    data : List Category
                    data =
                        [ Category "a" 1, Category "a" 2, Category "b" 4, Category "a" 8 ]

                    state : Table.State
                    state =
                        { plain
                            | columnFilters = [ { id = "category", value = Value.String "a" } ]
                            , pagination = { pageIndex = 0, pageSize = 2 }
                        }

                    coreModel : Table.RowModel Category
                    coreModel =
                        Table.coreRowModelFromList cfg state data

                    filtered : Table.RowModel Category
                    filtered =
                        Table.filteredRowModel cfg state coreModel

                    final : Table.RowModel Category
                    final =
                        Table.rowsFromList cfg state data
                in
                Expect.equal
                    { preGrouped = Table.aggregationValue cfg filtered "amount"
                    , fromCore =
                        Table.aggregationValueOf cfg coreModel "amount" { maxDepth = 0, rows = coreModel.rows }
                    , fromFinal =
                        Table.aggregationValueOf cfg coreModel "amount" { maxDepth = 0, rows = final.rows }
                    , oneRow =
                        Table.aggregationValueOf cfg
                            coreModel
                            "amount"
                            { maxDepth = 0, rows = List.take 1 (List.drop 2 coreModel.rows) }
                    }
                    { preGrouped = Value.Number 11
                    , fromCore = Value.Number 15
                    , fromFinal = Value.Number 3
                    , oneRow = Value.Number 4
                    }
        , test "selects a unique depth frontier and keeps shorter ragged branches" <|
            \_ ->
                let
                    cfg : Table.Config Node
                    cfg =
                        nodeConfig
                            [ Table.column "amount" (.amount >> Value.Number)
                                |> Table.withAggregationFn AggregationFn.sum
                            ]

                    model : Table.RowModel Node
                    model =
                        core cfg
                            [ node 100 "parent" [ node 2 "a" [], node 3 "b" [] ]
                            , node 200 "other" []
                            ]

                    parent : List (Table.Row Node)
                    parent =
                        List.take 1 model.rows

                    parentAndFirstChild : List (Table.Row Node)
                    parentAndFirstChild =
                        parent
                            ++ (List.head parent
                                    |> Maybe.map (Table.rowSubRows >> List.take 1)
                                    |> Maybe.withDefault []
                               )
                in
                Expect.equal
                    { flat = Table.aggregationValue cfg model "amount"
                    , depthOne =
                        Table.aggregationValueOf cfg model "amount" { maxDepth = 1, rows = model.rows }
                    , unlimited =
                        Table.aggregationValueOf cfg model "amount" { maxDepth = unlimitedDepth, rows = model.rows }
                    , overlapping =
                        Table.aggregationValueOf cfg model "amount" { maxDepth = 1, rows = parentAndFirstChild }
                    , maxSubRowDepth = Table.maxSubRowDepth model
                    }
                    { flat = Value.Number 300
                    , depthOne = Value.Number 205
                    , unlimited = Value.Number 205
                    , overlapping = Value.Number 5
                    , maxSubRowDepth = 1
                    }
        , test "preserves ragged frontier order and deduplicates overlapping row inputs" <|
            \_ ->
                let
                    collectLabels : AggregationFn
                    collectLabels =
                        AggregationFn.custom Value.List

                    cfg : Table.Config Node
                    cfg =
                        nodeConfig
                            [ Table.column "label" (.label >> Value.String)
                                |> Table.withAggregationFn collectLabels
                            ]

                    model : Table.RowModel Node
                    model =
                        core cfg
                            [ node 0 "a" [ node 0 "a0" [ node 0 "a00" [], node 0 "a01" [] ] ]
                            , node 0 "b" []
                            ]

                    firstBranch : List (Table.Row Node)
                    firstBranch =
                        List.take 1 model.rows
                            ++ (List.head model.rows
                                    |> Maybe.map (Table.rowSubRows >> List.take 1)
                                    |> Maybe.withDefault []
                               )

                    labelsAt : Int -> List (Table.Row Node) -> Value
                    labelsAt maxDepth rows =
                        Table.aggregationValueOf cfg model "label" { maxDepth = maxDepth, rows = rows }
                in
                Expect.equal
                    { depthZero = labelsAt 0 model.rows
                    , depthOne = labelsAt 1 model.rows
                    , unlimited = labelsAt unlimitedDepth model.rows
                    , overlapping = labelsAt unlimitedDepth firstBranch
                    }
                    { depthZero = Value.List [ Value.String "a", Value.String "b" ]
                    , depthOne = Value.List [ Value.String "a0", Value.String "b" ]
                    , unlimited =
                        Value.List [ Value.String "a00", Value.String "a01", Value.String "b" ]
                    , overlapping =
                        Value.List [ Value.String "a00", Value.String "a01" ]
                    }
        , -- adapted: a provider always handles the request here, since
          -- returning `Value.Null` is TanStack's handled `{ value: undefined }`
          -- and there is no third answer for "not handled". The declining half
          -- of the vitest resolver becomes a column with no provider at all,
          -- which is the local fallback it falls through to.
          test "uses handled column values and configurable local fallback" <|
            \_ ->
                let
                    resolver : Table.AggregationContext AmountRow -> Value
                    resolver ctx =
                        if List.isEmpty ctx.rows then
                            Value.Null

                        else
                            Value.Number 99

                    columns : Table.Config AmountRow
                    columns =
                        Table.config
                            [ Table.column "handled" .amount
                                |> Table.withAggregationFn AggregationFn.sum
                                |> Table.withGetAggregationValue resolver
                            , Table.column "local" .amount
                                |> Table.withAggregationFn AggregationFn.sum
                            , Table.column "handledUndefined" .amount
                                |> Table.withAggregationFn AggregationFn.sum
                                |> Table.withGetAggregationValue (\_ -> Value.Null)
                            ]

                    data : List AmountRow
                    data =
                        [ AmountRow (Value.Number 1), AmountRow (Value.Number 2) ]

                    model : Table.RowModel AmountRow
                    model =
                        core columns data

                    manual : Table.Config AmountRow
                    manual =
                        Table.withManualAggregation True columns
                in
                Expect.equal
                    { handledExplicitRows =
                        Table.aggregationValueOf columns model "handled" { maxDepth = 0, rows = model.rows }
                    , localFallback = Table.aggregationValue columns model "local"
                    , manualLocal = Table.aggregationValue manual model "local"
                    , manualHandled = Table.aggregationValue manual model "handled"
                    , handledUndefined = Table.aggregationValue columns model "handledUndefined"
                    }
                    { handledExplicitRows = Value.Number 99
                    , localFallback = Value.Number 3
                    , manualLocal = Value.Null
                    , manualHandled = Value.Number 99
                    , handledUndefined = Value.Null
                    }
        , -- adapted: `Config.defaultColumn` is sizing only here, so the shared
          -- provider is one function attached to each column rather than one
          -- default the columns inherit; it still branches on the column it is
          -- asked about, which is the point of the case.
          test "supports a shared aggregation value provider through defaultColumn" <|
            \_ ->
                let
                    shared : Table.AggregationContext AmountRow -> Value
                    shared ctx =
                        if ctx.columnId == "amount" then
                            Value.Number 42

                        else
                            Value.Null

                    cfg : Table.Config AmountRow
                    cfg =
                        Table.config
                            [ Table.column "amount" .amount
                                |> Table.withAggregationFn AggregationFn.sum
                                |> Table.withGetAggregationValue shared
                            , Table.column "other" .amount
                                |> Table.withAggregationFn AggregationFn.sum
                                |> Table.withGetAggregationValue shared
                            ]

                    model : Table.RowModel AmountRow
                    model =
                        core cfg [ AmountRow (Value.Number 1) ]
                in
                Expect.equal
                    ( Table.aggregationValue cfg model "amount"
                    , Table.aggregationValue cfg model "other"
                    )
                    ( Value.Number 42, Value.Null )
        , -- adapted: `withAggregationFns` takes the functions themselves, so
          -- there is no unregistered `'missing'` name to warn about and no
          -- `console.warn` to spy on; the duplicated id is the half that has a
          -- counterpart, and it keeps its key with `Null` for `undefined`.
          test "warns and preserves undefined keys for invalid multi configurations" <|
            \_ ->
                let
                    cfg : Table.Config AmountRow
                    cfg =
                        Table.config
                            [ Table.column "amount" .amount
                                |> Table.withAggregationFns
                                    [ ( "sum", AggregationFn.sum )
                                    , ( "sum", AggregationFn.sum )
                                    , ( "kept", AggregationFn.count )
                                    ]
                            ]

                    model : Table.RowModel AmountRow
                    model =
                        core cfg [ AmountRow (Value.Number 1) ]
                in
                Dict.toList (Table.aggregationResults cfg model "amount")
                    |> Expect.equal
                        [ ( "kept", Value.Number 1 )
                        , ( "sum", Value.Null )
                        ]
        ]


type alias Category =
    { category : String
    , amount : Float
    }



-- AGGREGATION AND GROUPING


type alias Sale =
    { region : String
    , team : String
    , amount : Float
    , subRows : Sales
    }


type Sales
    = Sales (List Sale)


salesOf : Sale -> List Sale
salesOf row =
    case row.subRows of
        Sales rows ->
            rows


sale : String -> String -> Float -> List Sale -> Sale
sale region team amount kids =
    Sale region team amount (Sales kids)


saleConfig : List (Table.Column Sale) -> Table.Config Sale
saleConfig columns =
    Table.config columns |> Table.withSubRows salesOf


groupSales : Table.Config Sale -> List String -> List Sale -> Table.RowModel Sale
groupSales cfg grouping data =
    Table.groupedRowModel cfg
        (groupingState grouping)
        (Table.coreRowModelFromList cfg (groupingState grouping) data)


groupingSuite : Test
groupingSuite =
    describe "aggregation and grouping integration"
        [ test "preserves direct sub-row semantics for reaggregatable built-ins" <|
            \_ ->
                -- The two keyed columns (`['sum', 'mean', 'count']`) are
                -- replaced by one scalar `sum` column carrying the same
                -- `maxAggregationDepth`, since keyed aggregation has no
                -- counterpart here.
                let
                    cfg : Table.Config Sale
                    cfg =
                        saleConfig
                            [ Table.column "region" (.region >> Value.String)
                            , Table.column "team" (.team >> Value.String)
                            , Table.column "sum" (.amount >> Value.Number)
                                |> Table.withAggregationFn AggregationFn.sum
                            , Table.column "min" (.amount >> Value.Number)
                                |> Table.withAggregationFn AggregationFn.min
                            , Table.column "max" (.amount >> Value.Number)
                                |> Table.withAggregationFn AggregationFn.max
                            , Table.column "extent" (.amount >> Value.Number)
                                |> Table.withAggregationFn AggregationFn.extent
                            , Table.column "subRowSum" (.amount >> Value.Number)
                                |> Table.withAggregationFn AggregationFn.sum
                                |> Table.withMaxAggregationDepth 1
                            ]

                    data : List Sale
                    data =
                        [ sale "a" "x" 100 [ sale "a" "x" 1 [], sale "a" "x" 2 [] ]
                        , sale "a" "y" 200 [ sale "a" "y" 3 [], sale "a" "y" 4 [] ]
                        ]

                    model : Table.RowModel Sale
                    model =
                        groupSales cfg [ "region", "team" ] data

                    coreModel : Table.RowModel Sale
                    coreModel =
                        core cfg data

                    region : Maybe (Table.Row Sale)
                    region =
                        List.head model.rows

                    valueOf : String -> Value
                    valueOf columnId =
                        region
                            |> Maybe.map (\row -> Table.getValue cfg row columnId)
                            |> Maybe.withDefault Value.Null
                in
                Expect.equal
                    { teamSums =
                        region
                            |> Maybe.map
                                (Table.rowSubRows >> List.map (\row -> Table.getValue cfg row "sum"))
                            |> Maybe.withDefault []
                    , sum = valueOf "sum"
                    , min = valueOf "min"
                    , max = valueOf "max"
                    , extent = valueOf "extent"
                    , subRowSum = valueOf "subRowSum"
                    , columnSum = Table.aggregationValue cfg coreModel "sum"
                    , columnSumDepthOne =
                        Table.aggregationValueOf cfg coreModel "sum" { maxDepth = 1, rows = coreModel.rows }
                    }
                    { teamSums = [ Value.Number 100, Value.Number 200 ]
                    , sum = Value.Number 300
                    , min = Value.Number 100
                    , max = Value.Number 200
                    , extent = Value.List [ Value.Number 100, Value.Number 200 ]
                    , subRowSum = Value.Number 10
                    , columnSum = Value.Number 300
                    , columnSumDepthOne = Value.Number 10
                    }
        , test "keeps grouping structural when rowAggregationFeature is absent" <|
            \_ ->
                -- There is no feature registry here, so the case is ported as
                -- the one column kind the automatic aggregation leaves alone:
                -- a string column with no `withAggregationFn` reads `Null` on
                -- a group row, which is TanStack's `undefined`.
                let
                    cfg : Table.Config Sale
                    cfg =
                        saleConfig
                            [ Table.column "region" (.region >> Value.String)
                            , Table.column "team" (.team >> Value.String)
                            ]

                    model : Table.RowModel Sale
                    model =
                        groupSales cfg [ "region" ] [ sale "a" "x" 1 [], sale "a" "y" 2 [] ]
                in
                List.head model.rows
                    |> Maybe.map (\row -> Table.getValue cfg row "team")
                    |> Expect.equal (Just Value.Null)
        , test "computes nested scalar/keyed values and aggregates deeper grouping columns" <|
            \_ ->
                -- The `aggregatedCell` assertion is rendering, which is out of
                -- scope; the rest of the case is here.
                let
                    cfg : Table.Config Order
                    cfg =
                        Table.config
                            [ Table.column "region" (.region >> Value.String)
                            , Table.column "level" (.level >> Value.Number)
                                |> Table.withAggregationFn AggregationFn.sum
                            , Table.column "amount" (.amount >> Value.Number)
                                |> Table.withAggregationFns
                                    [ ( "sum", AggregationFn.sum )
                                    , ( "mean", AggregationFn.mean )
                                    , ( "extent", AggregationFn.extent )
                                    ]
                            , Table.column "soldAt" (.soldAt >> Value.Date)
                                |> Table.withAggregationFn AggregationFn.extent
                            ]

                    data : List Order
                    data =
                        [ Order "north" 1 10 (day 1)
                        , Order "north" 1 20 (day 32)
                        , Order "north" 2 100 (day 61)
                        ]

                    state : Table.State
                    state =
                        groupingState [ "region", "level" ]

                    coreModel : Table.RowModel Order
                    coreModel =
                        Table.coreRowModelFromList cfg state data

                    model : Table.RowModel Order
                    model =
                        Table.groupedRowModel cfg state coreModel

                    region : Maybe (Table.Row Order)
                    region =
                        List.head model.rows

                    level : Maybe (Table.Row Order)
                    level =
                        region |> Maybe.andThen (Table.rowSubRows >> List.head)

                    valueOf : Maybe (Table.Row Order) -> String -> Value
                    valueOf row columnId =
                        row
                            |> Maybe.map (\r -> Table.getValue cfg r columnId)
                            |> Maybe.withDefault Value.Null
                in
                Expect.equal
                    { regionLevel = valueOf region "level"
                    , levelLevel = valueOf level "level"
                    , regionAmount =
                        region
                            |> Maybe.map (\r -> Dict.toList (Table.rowAggregationResults r "amount"))
                            |> Maybe.withDefault []
                    , regionAmountSum =
                        Maybe.andThen (\r -> Table.aggregationValueById r "amount" "sum") region
                    , regionSoldAt = valueOf region "soldAt"
                    , amountAggregated =
                        region
                            |> Maybe.map
                                (\row -> Table.cellIsAggregated cfg coreModel state row "amount")
                    , levelAggregated =
                        region
                            |> Maybe.map
                                (\row -> Table.cellIsAggregated cfg coreModel state row "level")
                    }
                    { regionLevel = Value.Number 4
                    , levelLevel = Value.Number 1
                    , regionAmount =
                        [ ( "extent", Value.List [ Value.Number 10, Value.Number 100 ] )
                        , ( "mean", Value.Number (130 / 3) )
                        , ( "sum", Value.Number 130 )
                        ]
                    , regionAmountSum = Just (Value.Number 130)
                    , regionSoldAt = Value.List [ Value.Date (day 1), Value.Date (day 61) ]
                    , amountAggregated = Just True
                    , levelAggregated = Just False
                    }
        , test "caches grouped values and merges sub-row results without rescanning parent leaves" <|
            \_ ->
                -- The `vi.fn` call counts are memoization. `negatedSize` has
                -- the same `aggregate` as `size` and a `merge` that negates
                -- the total, so a group whose children are groups can only
                -- reach `-3` through the merge path; that stands in for the
                -- `subRowResults` spy.
                let
                    size : AggregationFn
                    size =
                        AggregationFn.custom
                            (\values -> Value.Number (toFloat (List.length values)))

                    sized : AggregationFn
                    sized =
                        size |> AggregationFn.withMerge sumOf

                    negatedSize : AggregationFn
                    negatedSize =
                        size |> AggregationFn.withMerge (sumOf >> negateValue)

                    sumOf : List Value -> Value
                    sumOf values =
                        Value.Number (List.sum (List.map Value.toNumber values))

                    negateValue : Value -> Value
                    negateValue value =
                        Value.Number (negate (Value.toNumber value))

                    cfg : Table.Config Sale
                    cfg =
                        saleConfig
                            [ Table.column "region" (.region >> Value.String)
                            , Table.column "team" (.team >> Value.String)
                            , Table.column "amount" (.amount >> Value.Number)
                                |> Table.withAggregationFn sized
                            , Table.column "probe" (.amount >> Value.Number)
                                |> Table.withAggregationFn negatedSize
                            ]

                    model : Table.RowModel Sale
                    model =
                        groupSales cfg
                            [ "region", "team" ]
                            [ sale "a" "x" 1 [], sale "a" "x" 2 [], sale "a" "y" 3 [] ]

                    region : Maybe (Table.Row Sale)
                    region =
                        List.head model.rows
                in
                Expect.equal
                    { amount = region |> Maybe.map (\row -> Table.getValue cfg row "amount")
                    , teamAmounts =
                        region
                            |> Maybe.map
                                (Table.rowSubRows >> List.map (\row -> Table.getValue cfg row "amount"))
                            |> Maybe.withDefault []
                    , merged = region |> Maybe.map (\row -> Table.getValue cfg row "probe")
                    }
                    { amount = Just (Value.Number 3)
                    , teamAmounts = [ Value.Number 2, Value.Number 1 ]
                    , merged = Just (Value.Number -3)
                    }
        , test "rebuilds grouped aggregation values when column definitions change" <|
            \_ ->
                -- `setOptions` has no counterpart; the case is ported as two
                -- configs, as phase 3 ported its runtime-toggle cases.
                let
                    configWith : AggregationFn -> Table.Config Sale
                    configWith fn =
                        saleConfig
                            [ Table.column "region" (.region >> Value.String)
                            , Table.column "amount" (.amount >> Value.Number)
                                |> Table.withAggregationFn fn
                            ]

                    data : List Sale
                    data =
                        [ sale "a" "x" 1 [], sale "a" "x" 2 [] ]

                    valueWith : AggregationFn -> Maybe Value
                    valueWith fn =
                        groupSales (configWith fn) [ "region" ] data
                            |> .rows
                            |> List.head
                            |> Maybe.map (\row -> Table.getValue (configWith fn) row "amount")
                in
                Expect.equal
                    ( valueWith AggregationFn.sum, valueWith AggregationFn.count )
                    ( Just (Value.Number 3), Just (Value.Number 2) )
        , test "applies depth selection to supplied grouped and expanded rows" <|
            \_ ->
                let
                    cfg : Table.Config Sale
                    cfg =
                        saleConfig
                            [ Table.column "region" (.region >> Value.String)
                            , Table.column "amount" (.amount >> Value.Number)
                                |> Table.withAggregationFn AggregationFn.sum
                            ]

                    data : List Sale
                    data =
                        [ sale "a" "x" 1 [], sale "a" "x" 2 [] ]

                    collapsed : Table.State
                    collapsed =
                        groupingState [ "region" ]

                    expanded : Table.State
                    expanded =
                        { collapsed | expanded = Table.expandAll }

                    coreModel : Table.RowModel Sale
                    coreModel =
                        Table.coreRowModelFromList cfg collapsed data

                    finalWith : Table.State -> Table.RowModel Sale
                    finalWith state =
                        Table.rowsFromList cfg state data
                in
                Expect.equal
                    { collapsed =
                        Table.aggregationValueOf cfg
                            coreModel
                            "amount"
                            { maxDepth = 0, rows = (finalWith collapsed).rows }
                    , expanded =
                        Table.aggregationValueOf cfg
                            coreModel
                            "amount"
                            { maxDepth = 0, rows = (finalWith expanded).rows }
                    , deepest =
                        Table.aggregationValueOf cfg
                            coreModel
                            "amount"
                            { maxDepth = unlimitedDepth, rows = (finalWith expanded).rows }
                    }
                    { collapsed = Value.Number 3
                    , expanded = Value.Number 6
                    , deepest = Value.Number 3
                    }
        , -- adapted: there is no spy on the aggregation, so the context is
          -- asserted through what the aggregation returns: the sizes of `rows`
          -- and `subRows` and the id and depth of `groupingRow`. `Nothing`
          -- stands for TanStack omitting the `groupingRow` property and an
          -- empty `subRows` for it omitting that one; `source` has no
          -- counterpart and never existed here.
          test "provides groupingRow only for grouped aggregation contexts" <|
            \_ ->
                let
                    sized : Table.ContextAggregationFn Sale
                    sized =
                        Table.aggregationFnWithContext contextProbe

                    cfg : Table.Config Sale
                    cfg =
                        saleConfig
                            [ Table.column "region" (.region >> Value.String)
                            , Table.column "amount" (.amount >> Value.Number)
                                |> Table.withContextAggregationFn sized
                            ]

                    data : List Sale
                    data =
                        [ sale "a" "x" 1 [], sale "a" "x" 2 [] ]

                    coreModel : Table.RowModel Sale
                    coreModel =
                        core cfg data

                    groupingRow : Maybe (Table.Row Sale)
                    groupingRow =
                        List.head (groupSales cfg [ "region" ] data).rows
                in
                Expect.equal
                    { root = Table.aggregationValue cfg coreModel "amount"
                    , grouped = groupingRow |> Maybe.map (\row -> Table.getValue cfg row "amount")
                    }
                    { root = probe 2 0 "" -1
                    , grouped = Just (probe 2 2 "region:a" 0)
                    }
        , -- adapted: same, with the counts the vitest reads off the two
          -- recorded contexts returned as the aggregated value itself.
          test "lets aggregate choose immediate sub-rows instead of terminal rows" <|
            \_ ->
                let
                    childCount : Table.ContextAggregationFn Sale
                    childCount =
                        Table.aggregationFnWithContext
                            (\ctx ->
                                if List.isEmpty ctx.subRows then
                                    Value.Number (toFloat (List.length ctx.rows))

                                else
                                    Value.Number (toFloat (List.length ctx.subRows))
                            )

                    cfg : Table.Config Sale
                    cfg =
                        saleConfig
                            [ Table.column "region" (.region >> Value.String)
                            , Table.column "team" (.team >> Value.String)
                            , Table.column "amount" (.amount >> Value.Number)
                                |> Table.withContextAggregationFn childCount
                            , Table.column "context" (.amount >> Value.Number)
                                |> Table.withContextAggregationFn
                                    (Table.aggregationFnWithContext contextProbe)
                            ]

                    model : Table.RowModel Sale
                    model =
                        groupSales cfg
                            [ "region", "team" ]
                            [ sale "a" "x" 1 [], sale "a" "x" 2 [], sale "a" "y" 3 [] ]

                    region : Maybe (Table.Row Sale)
                    region =
                        List.head model.rows

                    team : Maybe (Table.Row Sale)
                    team =
                        region |> Maybe.andThen (Table.rowSubRows >> List.head)

                    valueOf : Maybe (Table.Row Sale) -> String -> Maybe Value
                    valueOf row columnId =
                        Maybe.map (\r -> Table.getValue cfg r columnId) row
                in
                Expect.equal
                    { teamAmount = valueOf team "amount"
                    , regionAmount = valueOf region "amount"
                    , teamContext = valueOf team "context"
                    , regionContext = valueOf region "context"
                    }
                    { teamAmount = Just (Value.Number 2)
                    , regionAmount = Just (Value.Number 2)
                    , teamContext = Just (probe 2 2 "region:a>team:x" 1)
                    , regionContext = Just (probe 3 2 "region:a" 0)
                    }
        ]


{-| What the two `AggregationContext` cases read off the context: how many
rows and immediate sub-rows it holds, and the id and depth of its grouping
row. The empty id and the depth of `-1` stand for TanStack omitting the
`groupingRow` property.
-}
contextProbe : Table.AggregationContext Sale -> Value
contextProbe ctx =
    probe (List.length ctx.rows)
        (List.length ctx.subRows)
        (Maybe.withDefault "" (Maybe.map Table.rowId ctx.groupingRow))
        (Maybe.withDefault -1 (Maybe.map Table.rowDepth ctx.groupingRow))


probe : Int -> Int -> String -> Int -> Value
probe rowCount subRowCount groupingRowId groupingRowDepth =
    Value.List
        [ Value.Number (toFloat rowCount)
        , Value.Number (toFloat subRowCount)
        , Value.String groupingRowId
        , Value.Number (toFloat groupingRowDepth)
        ]


type alias Order =
    { region : String
    , level : Float
    , amount : Float
    , soldAt : Time.Posix
    }


day : Int -> Time.Posix
day n =
    Time.millisToPosix (n * 86400000)
