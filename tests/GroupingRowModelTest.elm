module GroupingRowModelTest exposing (suite)

{-| Ports
`tests/implementation/features/column-grouping/createGroupedRowModel.test.ts`
and
`tests/implementation/features/column-grouping/columnGroupingFeature.test.ts`.

Every group key is `String(groupingValue)` in TanStack. `Value.Null` stands
for both `null` and `undefined` here, so both group under `"null"`; see
`reports/phase-4.md`.

-}

import Dict
import Expect
import Set
import Table
import Table.Value as Value exposing (Value)
import Test exposing (Test, describe, test)



-- FIXTURES


type alias TestRow =
    { status : Maybe String
    , firstName : String
    }


testRow : String -> String -> TestRow
testRow status firstName =
    { status = Just status, firstName = firstName }


testColumns : List (Table.Column TestRow)
testColumns =
    [ Table.column "status" (.status >> maybeString)
    , Table.column "firstName" (.firstName >> Value.String)
    ]


maybeString : Maybe String -> Value
maybeString value =
    case value of
        Just s ->
            Value.String s

        Nothing ->
            Value.Null


grouped : Table.Config a -> List String -> List a -> Table.RowModel a
grouped cfg grouping data =
    let
        state : Table.State
        state =
            { initial | grouping = grouping }

        initial : Table.State
        initial =
            Table.initialState
    in
    Table.coreRowModelFromList cfg state data
        |> Table.groupedRowModel cfg state


makeTable : List TestRow -> List String -> Table.RowModel TestRow
makeTable data grouping =
    grouped (Table.config testColumns) grouping data


ids : List (Table.Row a) -> List String
ids =
    List.map Table.rowId


{-| A tree row: `status`, `firstName` and children.
-}
type alias TreeRow =
    { status : String
    , firstName : String
    , subRows : Kids
    }


type Kids
    = Kids (List TreeRow)


kidsOf : TreeRow -> List TreeRow
kidsOf row =
    case row.subRows of
        Kids kids ->
            kids


leaf : String -> String -> TreeRow
leaf status firstName =
    TreeRow status firstName (Kids [])


treeConfig : Table.Config TreeRow
treeConfig =
    Table.config
        [ Table.column "status" (.status >> Value.String)
        , Table.column "firstName" (.firstName >> Value.String)
        ]
        |> Table.withSubRows kidsOf


{-| `generateTestData(2, 2, 2)` with the two roots' statuses overwritten, as
the vitest file does.
-}
nestedPeople : List TreeRow
nestedPeople =
    [ TreeRow "single" "p0" (Kids (branch "0"))
    , TreeRow "complicated" "p1" (Kids (branch "1"))
    ]


branch : String -> List TreeRow
branch prefix =
    List.range 0 1
        |> List.map
            (\i ->
                TreeRow "x"
                    (prefix ++ "." ++ String.fromInt i)
                    (Kids
                        (List.range 0 1
                            |> List.map
                                (\j ->
                                    leaf "x"
                                        (prefix ++ "." ++ String.fromInt i ++ "." ++ String.fromInt j)
                                )
                        )
                    )
            )



-- ABC FIXTURE


type alias AbcRow =
    { a : String
    , b : String
    , c : String
    }


abcConfig : Table.Config AbcRow
abcConfig =
    Table.config
        [ Table.column "a" (.a >> Value.String)
        , Table.column "b" (.b >> Value.String)
        , Table.column "c" (.c >> Value.String)
        ]



-- MIXED FIXTURE


type alias MixedRow =
    { value : Value
    , firstName : String
    }


mixedConfig : Table.Config MixedRow
mixedConfig =
    Table.config
        [ Table.column "value" .value
        , Table.column "firstName" (.firstName >> Value.String)
        ]



-- REGION FIXTURE


type alias RegionRow =
    { region : String
    , level : String
    , firstName : String
    }


regionConfig : Table.Config RegionRow
regionConfig =
    Table.config
        [ Table.column "region" (.region >> Value.String)
        , Table.column "level" (.level >> Value.String)
        , Table.column "firstName" (.firstName >> Value.String)
        ]



-- SUITE


suite : Test
suite =
    describe "createGroupedRowModel"
        [ flatRowsSuite
        , multiLevelSuite
        , customGroupingValueSuite
        , leafRowsSuite
        , keyCoercionSuite
        , inheritanceSuite
        , ungroupingSuite
        , manualGroupingSuite
        , rowsByIdSuite
        , featureSuite
        ]


flatRowsSuite : Test
flatRowsSuite =
    describe "createGroupedRowModel flatRows contain every row exactly once"
        [ test "single-level grouping over flat data" <|
            \_ ->
                let
                    data : List TestRow
                    data =
                        [ testRow "a" "one"
                        , testRow "a" "two"
                        , testRow "a" "three"
                        , testRow "b" "four"
                        , testRow "b" "five"
                        ]

                    cfg : Table.Config TestRow
                    cfg =
                        Table.config testColumns

                    groupedState : Table.State
                    groupedState =
                        { plain | grouping = [ "status" ] }

                    plain : Table.State
                    plain =
                        Table.initialState

                    model : Table.RowModel TestRow
                    model =
                        makeTable data [ "status" ]

                    ungroupedModel : Table.RowModel TestRow
                    ungroupedModel =
                        makeTable data []
                in
                Expect.equal
                    { rows = List.length model.rows
                    , displayIndexes =
                        List.map (Table.displayIndex cfg groupedState model) model.rows
                    , ungroupedDisplayIndexes =
                        List.map (Table.displayIndex cfg plain ungroupedModel)
                            ungroupedModel.rows
                    , flatRows = List.length model.flatRows
                    , uniqueIds = Set.size (Set.fromList (ids model.flatRows))
                    , rowsById = Dict.size model.rowsById
                    , flatIds = ids model.flatRows
                    }
                    { rows = 2
                    , displayIndexes = [ 0, 1 ]
                    , ungroupedDisplayIndexes = [ 0, 1, 2, 3, 4 ]
                    , flatRows = 7
                    , uniqueIds = 7
                    , rowsById = 7
                    , flatIds = [ "status:a", "0", "1", "2", "status:b", "3", "4" ]
                    }
        , test "two-level grouping over flat data" <|
            \_ ->
                let
                    model : Table.RowModel TestRow
                    model =
                        makeTable
                            [ testRow "a" "x"
                            , testRow "a" "x"
                            , testRow "a" "y"
                            , testRow "b" "x"
                            ]
                            [ "status", "firstName" ]
                in
                Expect.equal
                    { flatRows = List.length model.flatRows
                    , uniqueIds = Set.size (Set.fromList (ids model.flatRows))
                    , flatIds = ids model.flatRows
                    }
                    { flatRows = 9
                    , uniqueIds = 9
                    , flatIds =
                        [ "status:a"
                        , "status:a>firstName:x"
                        , "0"
                        , "1"
                        , "status:a>firstName:y"
                        , "2"
                        , "status:b"
                        , "status:b>firstName:x"
                        , "3"
                        ]
                    }
        , test "single-level grouping over tree data keeps descendants below the terminal depth exactly once" <|
            \_ ->
                let
                    model : Table.RowModel TreeRow
                    model =
                        grouped treeConfig [ "status" ] nestedPeople

                    depthOf : String -> Int
                    depthOf rowId =
                        Table.findRow model rowId
                            |> Maybe.map Table.rowDepth
                            |> Maybe.withDefault -1
                in
                Expect.equal
                    { flatRows = List.length model.flatRows
                    , uniqueIds = Set.size (Set.fromList (ids model.flatRows))
                    , depths = [ depthOf "0", depthOf "0.0", depthOf "0.0.0" ]
                    , topDepth = List.map Table.rowDepth (List.take 1 model.rows)
                    , flatIds = ids model.flatRows
                    }
                    { flatRows = 16
                    , uniqueIds = 16
                    , depths = [ 1, 2, 3 ]
                    , topDepth = [ 0 ]
                    , flatIds =
                        [ "status:single"
                        , "0"
                        , "0.0"
                        , "0.0.0"
                        , "0.0.1"
                        , "0.1"
                        , "0.1.0"
                        , "0.1.1"
                        , "status:complicated"
                        , "1"
                        , "1.0"
                        , "1.0.0"
                        , "1.0.1"
                        , "1.1"
                        , "1.1.0"
                        , "1.1.1"
                        ]
                    }
        , test "groups rows with undefined grouping values exactly once" <|
            \_ ->
                -- TanStack keys this bucket `status:undefined`. `Value.Null`
                -- stands for both `null` and `undefined` here, so the key is
                -- `status:null`; see `reports/phase-4.md`.
                let
                    model : Table.RowModel TestRow
                    model =
                        makeTable
                            [ testRow "a" "one"
                            , testRow "a" "two"
                            , { status = Nothing, firstName = "three" }
                            ]
                            [ "status" ]
                in
                Expect.equal
                    { hasNullGroup = Dict.member "status:null" model.rowsById
                    , flatRows = List.length model.flatRows
                    , uniqueIds = Set.size (Set.fromList (ids model.flatRows))
                    }
                    { hasNullGroup = True, flatRows = 5, uniqueIds = 5 }
        , test "grouping on a nonexistent column keeps every top-level row exactly once" <|
            \_ ->
                let
                    model : Table.RowModel TestRow
                    model =
                        makeTable
                            [ testRow "a" "one"
                            , testRow "b" "two"
                            , testRow "c" "three"
                            ]
                            [ "nope" ]
                in
                Expect.equal
                    { rows = List.length model.rows
                    , flatRows = List.length model.flatRows
                    , uniqueIds = Set.size (Set.fromList (ids model.flatRows))
                    }
                    { rows = 3, flatRows = 3, uniqueIds = 3 }
        ]


multiLevelSuite : Test
multiLevelSuite =
    describe "createGroupedRowModel multi-level structure"
        [ test "should build the full 3-level group structure with composite ids, depths, subRows, and leafRows" <|
            \_ ->
                let
                    model : Table.RowModel AbcRow
                    model =
                        grouped abcConfig
                            [ "a", "b", "c" ]
                            [ AbcRow "a1" "b1" "c1"
                            , AbcRow "a1" "b1" "c2"
                            , AbcRow "a1" "b2" "c1"
                            , AbcRow "a2" "b1" "c1"
                            ]

                    at : List Int -> Maybe (Table.Row AbcRow)
                    at path =
                        List.foldl
                            (\i acc ->
                                acc
                                    |> Maybe.andThen
                                        (\row -> List.head (List.drop i (Table.rowSubRows row)))
                            )
                            (List.head model.rows)
                            path

                    a1 : Maybe (Table.Row AbcRow)
                    a1 =
                        List.head model.rows

                    a2 : Maybe (Table.Row AbcRow)
                    a2 =
                        List.head (List.drop 1 model.rows)

                    subIds : Maybe (Table.Row AbcRow) -> List String
                    subIds =
                        Maybe.map (Table.rowSubRows >> ids) >> Maybe.withDefault []

                    subDepths : Maybe (Table.Row AbcRow) -> List Int
                    subDepths =
                        Maybe.map (Table.rowSubRows >> List.map Table.rowDepth)
                            >> Maybe.withDefault []

                    leafCount : Maybe (Table.Row AbcRow) -> Int
                    leafCount =
                        Maybe.map (Table.rowLeafRows >> List.length) >> Maybe.withDefault -1
                in
                Expect.equal
                    { topIds = ids model.rows
                    , topDepths = List.map Table.rowDepth model.rows
                    , a1Subs = subIds a1
                    , a2Subs = subIds a2
                    , a1SubDepths = subDepths a1
                    , a1b1Subs = subIds (at [ 0 ])
                    , a1b1SubDepths = subDepths (at [ 0 ])
                    , a1b1c1Subs = subIds (at [ 0, 0 ])
                    , a1b1c1SubDepths = subDepths (at [ 0, 0 ])
                    , a1b1c1SubParent =
                        at [ 0, 0, 0 ] |> Maybe.andThen Table.rowParentId
                    , leaves = [ leafCount a1, leafCount (at [ 0 ]), leafCount (at [ 0, 0 ]), leafCount a2 ]
                    , flatRows = List.length model.flatRows
                    , uniqueIds = Set.size (Set.fromList (ids model.flatRows))
                    , rowsById = Dict.size model.rowsById
                    }
                    { topIds = [ "a:a1", "a:a2" ]
                    , topDepths = [ 0, 0 ]
                    , a1Subs = [ "a:a1>b:b1", "a:a1>b:b2" ]
                    , a2Subs = [ "a:a2>b:b1" ]
                    , a1SubDepths = [ 1, 1 ]
                    , a1b1Subs = [ "a:a1>b:b1>c:c1", "a:a1>b:b1>c:c2" ]
                    , a1b1SubDepths = [ 2, 2 ]
                    , a1b1c1Subs = [ "0" ]
                    , a1b1c1SubDepths = [ 3 ]
                    , a1b1c1SubParent = Just "a:a1>b:b1>c:c1"
                    , leaves = [ 3, 2, 1, 1 ]
                    , flatRows = 13
                    , uniqueIds = 13
                    , rowsById = 13
                    }
        ]


customGroupingValueSuite : Test
customGroupingValueSuite =
    describe "createGroupedRowModel custom getGroupingValue"
        [ test "should merge rows into shared buckets and call getGroupingValue once per row via the grouping values cache" <|
            \_ ->
                -- The `_groupingValuesCache` call-count half has no
                -- counterpart: `Table.rowGroupingValueFor` is a pure function
                -- and the grouped row model reads each row once by
                -- construction.
                let
                    cfg : Table.Config TestRow
                    cfg =
                        Table.config
                            [ Table.column "status" (.status >> maybeString)
                                |> Table.withGetGroupingValue
                                    (\row _ ->
                                        Value.String
                                            (String.left 1 (Maybe.withDefault "" row.status))
                                    )
                            , Table.column "firstName" (.firstName >> Value.String)
                            ]

                    model : Table.RowModel TestRow
                    model =
                        grouped cfg
                            [ "status" ]
                            [ testRow "apple" "one"
                            , testRow "avocado" "two"
                            , testRow "banana" "three"
                            , testRow "apricot" "four"
                            ]

                    statusesOf : Maybe (Table.Row TestRow) -> List (Maybe String)
                    statusesOf =
                        Maybe.map (Table.rowLeafRows >> List.map (Table.rowOriginal >> .status))
                            >> Maybe.withDefault []
                in
                Expect.equal
                    { topIds = ids model.rows
                    , aStatuses = statusesOf (List.head model.rows)
                    , bCount =
                        List.drop 1 model.rows
                            |> List.head
                            |> Maybe.map (Table.rowLeafRows >> List.length)
                            |> Maybe.withDefault -1
                    , cached =
                        List.head model.rows
                            |> Maybe.map
                                (Table.rowLeafRows
                                    >> List.map (\row -> Table.rowGroupingValueFor cfg row "status")
                                )
                            |> Maybe.withDefault []
                    }
                    { topIds = [ "status:a", "status:b" ]
                    , aStatuses = [ Just "apple", Just "avocado", Just "apricot" ]
                    , bCount = 1
                    , cached =
                        [ Value.String "a", Value.String "a", Value.String "a" ]
                    }
        ]


leafRowsSuite : Test
leafRowsSuite =
    describe "createGroupedRowModel leafRows vs subRows over tree data"
        [ test "should flatten terminal descendants into leafRows while subRows keep direct children" <|
            \_ ->
                let
                    model : Table.RowModel TreeRow
                    model =
                        grouped treeConfig
                            [ "status" ]
                            [ TreeRow "x"
                                "parent1"
                                (Kids [ leaf "x" "child1", leaf "x" "child2" ])
                            , TreeRow "x" "parent2" (Kids [ leaf "x" "child3" ])
                            ]

                    group : Maybe (Table.Row TreeRow)
                    group =
                        List.head model.rows

                    names : (Table.Row TreeRow -> List (Table.Row TreeRow)) -> List String
                    names pick =
                        group
                            |> Maybe.map (pick >> List.map (Table.rowOriginal >> .firstName))
                            |> Maybe.withDefault []
                in
                Expect.equal
                    { rows = List.length model.rows
                    , subRows = names Table.rowSubRows
                    , leafRows = names Table.rowLeafRows
                    }
                    { rows = 1
                    , subRows = [ "parent1", "parent2" ]
                    , leafRows = [ "child1", "child2", "child3" ]
                    }
        ]


keyCoercionSuite : Test
keyCoercionSuite =
    describe "createGroupedRowModel grouping key coercion"
        [ test "should collide numeric 1 and string \"1\" into the same group (keys are string-coerced)" <|
            \_ ->
                let
                    model : Table.RowModel MixedRow
                    model =
                        grouped mixedConfig
                            [ "value" ]
                            [ MixedRow (Value.Number 1) "numeric"
                            , MixedRow (Value.String "1") "string"
                            , MixedRow (Value.Number 2) "other"
                            ]
                in
                Expect.equal
                    { topIds = ids model.rows
                    , firstLeaves =
                        List.head model.rows
                            |> Maybe.map (Table.rowLeafRows >> List.length)
                            |> Maybe.withDefault -1
                    }
                    { topIds = [ "value:1", "value:2" ], firstLeaves = 2 }
        , test "should group null values under the \"null\" key" <|
            \_ ->
                let
                    model : Table.RowModel MixedRow
                    model =
                        grouped mixedConfig
                            [ "value" ]
                            [ MixedRow Value.Null "one"
                            , MixedRow Value.Null "two"
                            , MixedRow (Value.String "x") "three"
                            ]
                in
                Expect.equal
                    (Dict.get "value:null" model.rowsById
                        |> Maybe.map (Table.rowLeafRows >> List.length)
                    )
                    (Just 2)
        ]


inheritanceSuite : Test
inheritanceSuite =
    describe "createGroupedRowModel ancestor grouping-value inheritance"
        [ test "should expose the parent region value on depth-1 group rows via getValue" <|
            \_ ->
                let
                    model : Table.RowModel RegionRow
                    model =
                        grouped regionConfig
                            [ "region", "level" ]
                            [ RegionRow "east" "high" "one"
                            , RegionRow "east" "low" "two"
                            , RegionRow "west" "high" "three"
                            ]

                    valueAt : List Int -> String -> Value
                    valueAt path columnId =
                        rowAt path
                            |> Maybe.map (\row -> Table.getValue regionConfig row columnId)
                            |> Maybe.withDefault Value.Null

                    rowAt : List Int -> Maybe (Table.Row RegionRow)
                    rowAt path =
                        case path of
                            [] ->
                                Nothing

                            top :: rest ->
                                List.foldl
                                    (\i acc ->
                                        acc
                                            |> Maybe.andThen
                                                (\row ->
                                                    List.head (List.drop i (Table.rowSubRows row))
                                                )
                                    )
                                    (List.head (List.drop top model.rows))
                                    rest
                in
                Expect.equal
                    { eastRegion = valueAt [ 0 ] "region"
                    , eastHighId = Maybe.map Table.rowId (rowAt [ 0, 0 ])
                    , eastHighLevel = valueAt [ 0, 0 ] "level"
                    , eastHighRegion = valueAt [ 0, 0 ] "region"
                    , eastHighRegionAgain = valueAt [ 0, 0 ] "region"
                    , westHighRegion = valueAt [ 1, 0 ] "region"
                    }
                    { eastRegion = Value.String "east"
                    , eastHighId = Just "region:east>level:high"
                    , eastHighLevel = Value.String "high"
                    , eastHighRegion = Value.String "east"
                    , eastHighRegionAgain = Value.String "east"
                    , westHighRegion = Value.String "west"
                    }
        ]


ungroupingSuite : Test
ungroupingSuite =
    describe "createGroupedRowModel ungrouping reset"
        [ test "should reset depth and parentId on flat rows after setGrouping([])" <|
            \_ ->
                let
                    data : List TestRow
                    data =
                        [ testRow "a" "one", testRow "a" "two", testRow "b" "three" ]

                    groupedModel : Table.RowModel TestRow
                    groupedModel =
                        makeTable data [ "status" ]

                    ungrouped : Table.RowModel TestRow
                    ungrouped =
                        makeTable data []
                in
                Expect.equal
                    { groupedDepth = Maybe.map Table.rowDepth (Table.findRow groupedModel "0")
                    , groupedParent = Maybe.andThen Table.rowParentId (Table.findRow groupedModel "0")
                    , rows = List.length ungrouped.rows
                    , depths = List.map Table.rowDepth ungrouped.rows
                    , parents = List.map Table.rowParentId ungrouped.rows
                    }
                    { groupedDepth = Just 1
                    , groupedParent = Just "status:a"
                    , rows = 3
                    , depths = [ 0, 0, 0 ]
                    , parents = [ Nothing, Nothing, Nothing ]
                    }
        , test "should reset depth and parentId on nested tree rows after setGrouping([])" <|
            \_ ->
                let
                    data : List TreeRow
                    data =
                        [ TreeRow "x"
                            "parent1"
                            (Kids
                                [ TreeRow "x" "child1" (Kids [ leaf "x" "grandchild1" ]) ]
                            )
                        , leaf "y" "parent2"
                        ]

                    groupedModel : Table.RowModel TreeRow
                    groupedModel =
                        grouped treeConfig [ "status" ] data

                    ungrouped : Table.RowModel TreeRow
                    ungrouped =
                        grouped treeConfig [] data

                    info : Table.RowModel TreeRow -> String -> ( Maybe Int, Maybe String )
                    info model rowId =
                        ( Table.findRow model rowId |> Maybe.map Table.rowDepth
                        , Table.findRow model rowId |> Maybe.andThen Table.rowParentId
                        )
                in
                Expect.equal
                    { grouped0 = info groupedModel "0"
                    , grouped00 = Tuple.first (info groupedModel "0.0")
                    , grouped000 = Tuple.first (info groupedModel "0.0.0")
                    , topDepths = List.map Table.rowDepth ungrouped.rows
                    , topParents = List.map Table.rowParentId ungrouped.rows
                    , plain00 = info ungrouped "0.0"
                    , plain000 = info ungrouped "0.0.0"
                    }
                    { grouped0 = ( Just 1, Just "status:x" )
                    , grouped00 = Just 2
                    , grouped000 = Just 3
                    , topDepths = [ 0, 0 ]
                    , topParents = [ Nothing, Nothing ]
                    , plain00 = ( Just 1, Just "0" )
                    , plain000 = ( Just 2, Just "0.0" )
                    }
        ]


manualGroupingSuite : Test
manualGroupingSuite =
    describe "createGroupedRowModel manualGrouping"
        [ test "should bypass a registered grouped row model when manualGrouping is true" <|
            \_ ->
                let
                    cfg : Table.Config TestRow
                    cfg =
                        { base | manualGrouping = True }

                    base : Table.Config TestRow
                    base =
                        Table.config testColumns

                    state : Table.State
                    state =
                        { plain | grouping = [ "status" ] }

                    plain : Table.State
                    plain =
                        Table.initialState

                    pre : Table.RowModel TestRow
                    pre =
                        Table.coreRowModelFromList cfg
                            state
                            [ testRow "a" "one", testRow "b" "two" ]

                    model : Table.RowModel TestRow
                    model =
                        Table.groupedRowModel cfg state pre
                in
                Expect.equal ( model == pre, List.length model.rows ) ( True, 2 )
        ]


rowsByIdSuite : Test
rowsByIdSuite =
    describe "createGroupedRowModel rowsById"
        [ test "should contain group row ids and leaf ids exactly once" <|
            \_ ->
                let
                    model : Table.RowModel TestRow
                    model =
                        makeTable
                            [ testRow "a" "one", testRow "a" "two", testRow "b" "three" ]
                            [ "status" ]
                in
                Expect.equal
                    { keys = List.sort (Dict.keys model.rowsById)
                    , sameLength = Dict.size model.rowsById == List.length model.flatRows
                    , uniqueIds = Set.size (Set.fromList (ids model.flatRows))
                    }
                    { keys = [ "0", "1", "2", "status:a", "status:b" ]
                    , sameLength = True
                    , uniqueIds = 5
                    }
        ]



-- columnGroupingFeature.test.ts


type alias BucketRow =
    { bucket : String
    , label : String
    }


featureSuite : Test
featureSuite =
    describe "columnGroupingFeature"
        [ test "passes the original row, row index, and row instance to getGroupingValue" <|
            \_ ->
                -- `withGetGroupingValue` takes `original` and `index`, not the
                -- `Row` itself, so `row.id` is the one argument of TanStack's
                -- `(originalRow, index, row)` with no counterpart here;
                -- `row.index` and `row.original` are the two it does take.
                let
                    data : List BucketRow
                    data =
                        [ BucketRow "alpha" "first", BucketRow "alpha" "second" ]

                    cfg : Table.Config BucketRow
                    cfg =
                        Table.config
                            [ Table.column "bucket" (.bucket >> Value.String)
                                |> Table.withGetGroupingValue
                                    (\original index ->
                                        Value.String
                                            (original.bucket ++ "-" ++ String.fromInt index)
                                    )
                            , Table.column "label" (.label >> Value.String)
                            ]

                    model : Table.RowModel BucketRow
                    model =
                        grouped cfg [ "bucket" ] data
                in
                Expect.equal
                    { groupingValues = List.map Table.rowGroupingValue model.rows
                    , calls =
                        Table.coreRowModelFromList cfg Table.initialState data
                            |> .rows
                            |> List.map
                                (\row ->
                                    { original = Table.rowOriginal row
                                    , index = Table.rowIndex row
                                    }
                                )
                    }
                    { groupingValues =
                        [ Value.String "alpha-0", Value.String "alpha-1" ]
                    , calls =
                        [ { original = BucketRow "alpha" "first", index = 0 }
                        , { original = BucketRow "alpha" "second", index = 1 }
                        ]
                    }
        ]
