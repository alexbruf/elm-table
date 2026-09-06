module SortingRowModelTest exposing (suite)

{-| Ports
`tests/implementation/features/row-sorting/createSortedRowModel.test.ts`.

Excluded cases are listed in `reports/phase-3.md` and marked with `-- excluded`
comment blocks where they would otherwise sit.

-}

import Expect
import Table
import Table.Value as Value exposing (Value)
import Test exposing (Test, describe, test)



-- FIXTURE


{-| `{ firstName, age, subRows }`. Elm forbids recursive type aliases, so the
children hang off a custom type.
-}
type Person
    = Person String Float (List Person)


person : String -> Float -> Person
person firstName age =
    Person firstName age []


firstNameOf : Person -> String
firstNameOf (Person firstName _ _) =
    firstName


ageOf : Person -> Float
ageOf (Person _ age _) =
    age


subRowsOf : Person -> List Person
subRowsOf (Person _ _ subs) =
    subs


config : Table.Config Person
config =
    Table.config
        [ Table.column "firstName" (firstNameOf >> Value.String)
        , Table.column "age" (ageOf >> Value.Number)
        ]
        |> Table.withSubRows subRowsOf


data : List Person
data =
    [ person "amy" 20, person "bob" 40, person "alice" 30 ]


sortingState : List Table.SortColumn -> Table.State
sortingState sorting =
    let
        state : Table.State
        state =
            Table.initialState
    in
    { state | sorting = sorting }


core : Table.Config Person -> List Person -> Table.RowModel Person
core cfg tableData =
    Table.coreRowModelFromList cfg Table.initialState tableData


sorted : Table.Config Person -> List Table.SortColumn -> List Person -> Table.RowModel Person
sorted cfg sorting tableData =
    Table.sortedRowModel cfg (sortingState sorting) (core cfg tableData)


names : List (Table.Row Person) -> List String
names =
    List.map (Table.rowOriginal >> firstNameOf)


parentWithChildren : List Person -> List Person
parentWithChildren children =
    [ Person "parent" 20 children ]


deepFixture : List Person
deepFixture =
    [ Person "parent"
        20
        [ Person "child-b" 15 [ person "grandchild-b" 4, person "grandchild-a" 2 ]
        , person "child-a" 10
        ]
    ]


recursiveFlatten : List (Table.Row Person) -> List (Table.Row Person)
recursiveFlatten rows =
    List.concatMap (\row -> row :: recursiveFlatten (Table.rowSubRows row)) rows



-- SUITE


suite : Test
suite =
    describe "createSortedRowModel"
        [ test "does not crash when the sorting state references a column that no longer exists" <|
            \_ ->
                -- Elm has no exceptions; the model is simply produced.
                sorted config [ { id = "thisColumnDoesNotExist", desc = False } ] data
                    |> .rows
                    |> List.length
                    |> Expect.equal 3
        , test "falls back to the pre-sorted row order when only unknown columns are sorted" <|
            \_ ->
                sorted config [ { id = "thisColumnDoesNotExist", desc = False } ] data
                    |> .rows
                    |> names
                    |> Expect.equal [ "amy", "bob", "alice" ]
        , test "returns the pre-sorted row model when only unknown columns are sorted" <|
            \_ ->
                sorted config [ { id = "thisColumnDoesNotExist", desc = False } ] data
                    |> Expect.equal (core config data)
        , test "still sorts by the remaining known columns when one sort entry is unknown" <|
            \_ ->
                sorted config
                    [ { id = "thisColumnDoesNotExist", desc = False }
                    , { id = "age", desc = False }
                    ]
                    data
                    |> .rows
                    |> names
                    |> Expect.equal [ "amy", "alice", "bob" ]
        , test "assigns display indexes in the final sorted order" <|
            \_ ->
                let
                    displayed : List Table.SortColumn -> ( List String, List Int )
                    displayed sorting =
                        let
                            state : Table.State
                            state =
                                sortingState sorting

                            pre : Table.RowModel Person
                            pre =
                                Table.sortedRowModel config state (core config data)
                        in
                        ( names pre.rows, List.map (Table.displayIndex config state pre) pre.rows )
                in
                Expect.equal
                    [ displayed [ { id = "age", desc = False } ]
                    , displayed [ { id = "age", desc = True } ]
                    , displayed []
                    ]
                    [ ( [ "amy", "alice", "bob" ], [ 0, 1, 2 ] )
                    , ( [ "bob", "alice", "amy" ], [ 0, 1, 2 ] )
                    , ( [ "amy", "bob", "alice" ], [ 0, 1, 2 ] )
                    ]
        , test "keeps branch row identity when sorted subRows are unchanged" <|
            \_ ->
                -- Elm has no object identity; an untouched branch is the same
                -- value as the pre-sorted one.
                let
                    fixture : List Person
                    fixture =
                        parentWithChildren [ person "child-a" 10, person "child-b" 15 ]
                in
                Expect.equal
                    (List.head (sorted config [ { id = "age", desc = False } ] fixture).rows)
                    (List.head (core config fixture).rows)
        , test "clones branch rows when sorted subRows change" <|
            \_ ->
                let
                    fixture : List Person
                    fixture =
                        parentWithChildren [ person "child-b" 15, person "child-a" 10 ]

                    sortedRow : Maybe (Table.Row Person)
                    sortedRow =
                        List.head (sorted config [ { id = "age", desc = False } ] fixture).rows
                in
                Expect.equal
                    ( sortedRow == List.head (core config fixture).rows
                    , sortedRow |> Maybe.map (Table.rowSubRows >> names)
                    )
                    ( False, Just [ "child-a", "child-b" ] )
        , test "does not copy memoized row APIs from the original row to sorted branch clones" <|
            \_ ->
                -- The vitest case warms a per-row memo and checks that the
                -- clone's cells point back at the clone. Nothing is memoized
                -- here, so this asserts the cells of the sorted branch row.
                let
                    fixture : List Person
                    fixture =
                        parentWithChildren [ person "child-b" 15, person "child-a" 10 ]

                    sortedRow : Maybe (Table.Row Person)
                    sortedRow =
                        List.head (sorted config [ { id = "age", desc = False } ] fixture).rows
                in
                Expect.equal
                    ( sortedRow == List.head (core config fixture).rows
                    , sortedRow
                        |> Maybe.andThen
                            (\row ->
                                Table.getAllCells config Table.initialState row
                                    |> List.head
                                    |> Maybe.map (\cell -> cell.rowId == Table.rowId row)
                            )
                    )
                    ( False, Just True )
        , test "builds leaf-row memos for sorted branch clones from the clone subRows" <|
            \_ ->
                let
                    fixture : List Person
                    fixture =
                        parentWithChildren [ person "child-b" 15, person "child-a" 10 ]

                    leafNames : Table.RowModel Person -> Maybe (List String)
                    leafNames model =
                        List.head model.rows |> Maybe.map (Table.getLeafRows >> names)
                in
                Expect.equal
                    ( leafNames (core config fixture)
                    , leafNames (sorted config [ { id = "age", desc = False } ] fixture)
                    )
                    ( Just [ "child-b", "child-a" ], Just [ "child-a", "child-b" ] )
        , test "flattens each parent ahead of its own sub-rows" <|
            \_ ->
                sorted config
                    [ { id = "age", desc = False } ]
                    [ Person "older-parent"
                        20
                        [ Person "child-b" 15 [ person "grandchild-b" 4, person "grandchild-a" 2 ]
                        , person "child-a" 10
                        ]
                    , Person "younger-parent" 5 [ person "child-c" 1 ]
                    ]
                    |> .flatRows
                    |> names
                    |> Expect.equal
                        [ "younger-parent"
                        , "child-c"
                        , "older-parent"
                        , "child-a"
                        , "child-b"
                        , "grandchild-a"
                        , "grandchild-b"
                        ]
        , test "flattens nested branch clones rather than the rows they replaced" <|
            \_ ->
                let
                    model : Table.RowModel Person
                    model =
                        sorted config [ { id = "age", desc = False } ] deepFixture

                    preModel : Table.RowModel Person
                    preModel =
                        core config deepFixture
                in
                Expect.equal
                    { flatMatchesTree = model.flatRows == recursiveFlatten model.rows
                    , rootChanged = List.head model.rows /= List.head preModel.rows
                    , childChanged =
                        (List.head model.rows |> Maybe.andThen (Table.rowSubRows >> List.drop 1 >> List.head))
                            /= (List.head preModel.rows |> Maybe.andThen (Table.rowSubRows >> List.head))
                    }
                    { flatMatchesTree = True, rootChanged = True, childChanged = True }
        , sortUndefinedSuite
        , invertSortingSuite
        , stableSortSuite
        , maxMultiSortColCountSuite
        , enableSortingSuite
        , multiSortSuite
        , manualSortingSuite
        ]



-- sortUndefined


type alias MaybePerson =
    { firstName : String
    , age : Maybe Float
    }


{-| amy and carl have undefined ages; dan (1) and bob (2) are defined.
-}
undefinedData : List MaybePerson
undefinedData =
    [ { firstName = "amy", age = Nothing }
    , { firstName = "bob", age = Just 2 }
    , { firstName = "carl", age = Nothing }
    , { firstName = "dan", age = Just 1 }
    ]


maybeAge : MaybePerson -> Value
maybeAge row =
    case row.age of
        Just n ->
            Value.Number n

        Nothing ->
            Value.Null


{-| Treats undefined as -Infinity so undefined values participate in the sort
fn deterministically for the `sortUndefined: false` case.
-}
undefinedAwareSort : Table.Row MaybePerson -> Table.Row MaybePerson -> Order
undefinedAwareSort rowA rowB =
    let
        valueOf : Table.Row MaybePerson -> Float
        valueOf row =
            (Table.rowOriginal row).age |> Maybe.withDefault (-1 / 0)
    in
    Basics.compare (valueOf rowA) (valueOf rowB)


sortedNames : Maybe Table.SortUndefined -> Bool -> List String
sortedNames placement desc =
    let
        ageColumn : Table.Column MaybePerson
        ageColumn =
            Table.column "age" maybeAge
                |> Table.withCustomSort undefinedAwareSort
                |> (case placement of
                        Just p ->
                            Table.withSortUndefined p

                        Nothing ->
                            identity
                   )

        cfg : Table.Config MaybePerson
        cfg =
            Table.config
                [ Table.column "firstName" (.firstName >> Value.String)
                , ageColumn
                ]

        state : Table.State
        state =
            sortingState [ { id = "age", desc = desc } ]
    in
    Table.coreRowModelFromList cfg state undefinedData
        |> Table.sortedRowModel cfg state
        |> .rows
        |> List.map (Table.rowOriginal >> .firstName)


sortUndefinedSuite : Test
sortUndefinedSuite =
    describe "sortUndefined"
        [ test "should sort undefined values last for sortUndefined: 1 ascending, first descending" <|
            \_ ->
                Expect.equal
                    ( sortedNames (Just Table.sortNullsAsPlusOne) False
                    , sortedNames (Just Table.sortNullsAsPlusOne) True
                    )
                    ( [ "dan", "bob", "amy", "carl" ], [ "amy", "carl", "bob", "dan" ] )
        , test "should sort undefined values first for sortUndefined: -1 ascending, last descending" <|
            \_ ->
                Expect.equal
                    ( sortedNames (Just Table.sortNullsAsMinusOne) False
                    , sortedNames (Just Table.sortNullsAsMinusOne) True
                    )
                    ( [ "amy", "carl", "dan", "bob" ], [ "bob", "dan", "amy", "carl" ] )
        , test "should sort undefined values first for sortUndefined: \"first\" regardless of direction" <|
            \_ ->
                Expect.equal
                    ( sortedNames (Just Table.sortNullsFirst) False
                    , sortedNames (Just Table.sortNullsFirst) True
                    )
                    ( [ "amy", "carl", "dan", "bob" ], [ "amy", "carl", "bob", "dan" ] )
        , test "should sort undefined values last for sortUndefined: \"last\" regardless of direction" <|
            \_ ->
                Expect.equal
                    ( sortedNames (Just Table.sortNullsLast) False
                    , sortedNames (Just Table.sortNullsLast) True
                    )
                    ( [ "dan", "bob", "amy", "carl" ], [ "bob", "dan", "amy", "carl" ] )
        , test "should let undefined values participate via the sortFn for sortUndefined: false" <|
            \_ ->
                -- `Nothing` is TanStack's `sortUndefined: false` and its
                -- `undefined` default alike: the sort fn sees the null values.
                Expect.equal ( sortedNames Nothing False, sortedNames Nothing True )
                    ( [ "amy", "carl", "dan", "bob" ], [ "bob", "dan", "amy", "carl" ] )
        , test "should keep the relative order of rows that are both undefined" <|
            \_ ->
                Expect.equal
                    ( sortedNames (Just Table.sortNullsAsPlusOne) False
                    , sortedNames (Just Table.sortNullsAsPlusOne) True
                    )
                    ( [ "dan", "bob", "amy", "carl" ], [ "amy", "carl", "bob", "dan" ] )
        ]



-- invertSorting


invertSortingSuite : Test
invertSortingSuite =
    describe "invertSorting"
        [ test "should invert an ascending sort when invertSorting is true" <|
            \_ ->
                invertedNames False |> Expect.equal [ "bob", "alice", "amy" ]
        , test "should double-negate back to ascending when invertSorting is combined with desc" <|
            \_ ->
                invertedNames True |> Expect.equal [ "amy", "alice", "bob" ]
        ]


invertedNames : Bool -> List String
invertedNames desc =
    let
        cfg : Table.Config Person
        cfg =
            Table.config
                [ Table.column "firstName" (firstNameOf >> Value.String)
                , Table.column "age" (ageOf >> Value.Number) |> Table.withInvertSorting True
                ]
    in
    sorted cfg [ { id = "age", desc = desc } ] data |> .rows |> names



-- stable sort


tiedData : List Person
tiedData =
    [ person "amy" 30, person "bob" 30, person "carl" 10, person "dan" 30 ]


stableSortSuite : Test
stableSortSuite =
    describe "stable sort"
        [ test "should preserve original index order for equal sort keys ascending" <|
            \_ ->
                sorted config [ { id = "age", desc = False } ] tiedData
                    |> .rows
                    |> names
                    |> Expect.equal [ "carl", "amy", "bob", "dan" ]
        , test "should preserve original index order for equal sort keys descending" <|
            \_ ->
                -- The index tiebreak is always ascending, even for a
                -- descending sort.
                sorted config [ { id = "age", desc = True } ] tiedData
                    |> .rows
                    |> names
                    |> Expect.equal [ "amy", "bob", "dan", "carl" ]
        ]



-- multi-column fixtures


type alias Triple =
    { name : String, a : Float, b : Float, c : Float }


tripleConfig : Table.Config Triple
tripleConfig =
    Table.config
        [ Table.column "a" (.a >> Value.Number)
        , Table.column "b" (.b >> Value.Number)
        , Table.column "c" (.c >> Value.Number)
        ]


tripleNames : Table.Config Triple -> List Table.SortColumn -> List Triple -> List String
tripleNames cfg sorting tableData =
    Table.coreRowModelFromList cfg (sortingState sorting) tableData
        |> Table.sortedRowModel cfg (sortingState sorting)
        |> .rows
        |> List.map (Table.rowOriginal >> .name)


maxMultiSortColCountSuite : Test
maxMultiSortColCountSuite =
    describe "maxMultiSortColCount"
        [ test "should not trim the sorting state applied by the model" <|
            \_ ->
                -- maxMultiSortColCount only limits how many sort entries a
                -- toggle can add; the sorted row model applies every entry.
                tripleNames { tripleConfig | maxMultiSortColCount = 2 }
                    [ { id = "a", desc = False }
                    , { id = "b", desc = False }
                    , { id = "c", desc = True }
                    ]
                    [ { name = "x", a = 1, b = 1, c = 1 }
                    , { name = "y", a = 1, b = 1, c = 3 }
                    , { name = "z", a = 1, b = 1, c = 2 }
                    ]
                    |> Expect.equal [ "y", "z", "x" ]
        ]


multiSortSuite : Test
multiSortSuite =
    describe "multi-sort"
        [ test "should sort by 3 columns with mixed asc/desc directions" <|
            \_ ->
                tripleNames tripleConfig
                    [ { id = "a", desc = False }
                    , { id = "b", desc = True }
                    , { id = "c", desc = False }
                    ]
                    [ { name = "p", a = 2, b = 1, c = 1 }
                    , { name = "q", a = 1, b = 2, c = 1 }
                    , { name = "r", a = 1, b = 2, c = 2 }
                    , { name = "s", a = 1, b = 1, c = 5 }
                    , { name = "t", a = 2, b = 3, c = 9 }
                    ]
                    |> Expect.equal [ "q", "r", "s", "t", "p" ]
        ]


enableSortingSuite : Test
enableSortingSuite =
    describe "enableSorting: false columns"
        [ test "should skip disabled columns in the sorting state while other sorted columns still apply" <|
            \_ ->
                let
                    cfg : Table.Config Person
                    cfg =
                        Table.config
                            [ Table.column "firstName" (firstNameOf >> Value.String)
                                |> Table.withEnableSorting False
                            , Table.column "age" (ageOf >> Value.Number)
                            ]
                in
                sorted cfg
                    [ { id = "firstName", desc = True }
                    , { id = "age", desc = False }
                    ]
                    data
                    |> .rows
                    |> names
                    |> Expect.equal [ "amy", "alice", "bob" ]
        ]


manualSortingSuite : Test
manualSortingSuite =
    describe "manualSorting"
        [ test "should toggle between identity and sorted output when manualSorting changes at runtime" <|
            \_ ->
                -- There is no `setOptions`; `manualSorting` is a record field
                -- the caller flips, so the two configs stand in for before and
                -- after.
                let
                    sorting : List Table.SortColumn
                    sorting =
                        [ { id = "age", desc = False } ]

                    manual : Table.Config Person
                    manual =
                        { config | manualSorting = True }
                in
                Expect.equal
                    { manualIsIdentity =
                        Table.sortedRowModel manual (sortingState sorting) (core config data) == core config data
                    , autoDiffers = sorted config sorting data /= core config data
                    , autoNames = names (sorted config sorting data).rows
                    }
                    { manualIsIdentity = True
                    , autoDiffers = True
                    , autoNames = [ "amy", "alice", "bob" ]
                    }
        ]
