module AggregationTest exposing (suite)

{-| Ports
`tests/implementation/features/row-aggregation/rowAggregationFeature.test.ts`.

`Table.AggregationFn` is a single fold plus an optional merge, so TanStack's
keyed `aggregationFn: ['sum', 'mean', …]` option has no counterpart. The
cases that are only about the keyed form are excluded in
`reports/phase-4.md`; the mixed ones keep their scalar half with a comment.

-}

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
        [ test "aggregates scalar and keyed root values without grouping" <|
            \_ ->
                -- The keyed (`aggregationFn: [...]`) half of this case has no
                -- counterpart; the scalar half is asserted here.
                let
                    cfg : Table.Config AmountRow
                    cfg =
                        Table.config
                            [ Table.column "scalar" .amount
                                |> Table.withAggregationFn AggregationFn.sum
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
                    , firstCellAggregated =
                        List.head model.rows
                            |> Maybe.map
                                (\row -> Table.cellIsAggregated cfg model plain row "scalar")
                    }
                    { total = Value.Number 30
                    , empty = Value.Number 0
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
                -- The keyed `amount` column becomes a scalar `sum` one and the
                -- `aggregatedCell` assertion is rendering, which is out of
                -- scope; the rest of the case is here.
                let
                    cfg : Table.Config Order
                    cfg =
                        Table.config
                            [ Table.column "region" (.region >> Value.String)
                            , Table.column "level" (.level >> Value.Number)
                                |> Table.withAggregationFn AggregationFn.sum
                            , Table.column "amount" (.amount >> Value.Number)
                                |> Table.withAggregationFn AggregationFn.sum
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
                    , regionAmount = valueOf region "amount"
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
                    , regionAmount = Value.Number 130
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
