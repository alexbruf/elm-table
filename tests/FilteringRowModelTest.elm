module FilteringRowModelTest exposing (suite)

{-| Ports
`tests/implementation/features/column-filtering/createFilteredRowModel.test.ts`,
plus the three cases of `tests/unit/fns/filterFns.test.ts` that phase 1 had to
leave out because they run through the table row model.

Excluded cases are listed in `reports/phase-3.md` and marked with `-- excluded`
comment blocks where they would otherwise sit.

-}

import Dict
import Expect
import FilteringStateTest exposing (filterFnLabel)
import Table
import Table.FilterFn as FilterFn
import Table.Value as Value exposing (Value)
import Test exposing (Test, describe, test)
import Time



-- DATA


type alias TestRow =
    { name : String }


type alias TaggedRow =
    { name : String, tag : String }


{-| The nested fixture of the vitest file. Elm forbids recursive type
aliases, so the children hang off a custom type.
-}
type NestedRow
    = NestedRow String (List NestedRow)


leaf : String -> NestedRow
leaf name =
    NestedRow name []


nestedName : NestedRow -> String
nestedName (NestedRow name _) =
    name


nestedSubRows : NestedRow -> List NestedRow
nestedSubRows (NestedRow _ subs) =
    subs


nestedData : List NestedRow
nestedData =
    [ NestedRow "keep-a"
        [ NestedRow "keep-a1" [ leaf "drop-a1a" ]
        , leaf "drop-a2"
        ]
    , NestedRow "drop-b" [ leaf "keep-b1" ]
    , leaf "keep-c"
    , NestedRow "keep-d" [ leaf "drop-d1" ]
    ]


nestedConfig : Table.Config NestedRow
nestedConfig =
    Table.config [ Table.column "name" (nestedName >> Value.String) ]
        |> Table.withSubRows nestedSubRows


keepFilter : Table.State
keepFilter =
    withColumnFilters [ { id = "name", value = Value.String "keep" } ] Table.initialState


withColumnFilters : List Table.ColumnFilter -> Table.State -> Table.State
withColumnFilters filters state =
    { state | columnFilters = filters }


withGlobal : Value -> Table.State -> Table.State
withGlobal value state =
    { state | globalFilter = value }


rowNames : List (Table.Row NestedRow) -> List String
rowNames =
    List.map (Table.rowOriginal >> nestedName)


{-| The filtered row model of the nested fixture with the `keep` filter.
-}
nestedModel : (Table.Config NestedRow -> Table.Config NestedRow) -> List NestedRow -> Table.RowModel NestedRow
nestedModel tweak data =
    let
        cfg : Table.Config NestedRow
        cfg =
            tweak nestedConfig
    in
    Table.coreRowModelFromList cfg keepFilter data
        |> Table.filteredRowModel cfg keepFilter


preNested : List NestedRow -> Table.RowModel NestedRow
preNested data =
    Table.coreRowModelFromList nestedConfig keepFilter data


fromLeafRows : Table.Config NestedRow -> Table.Config NestedRow
fromLeafRows cfg =
    { cfg | filterFromLeafRows = True }


maxDepth : Int -> Table.Config NestedRow -> Table.Config NestedRow
maxDepth depth cfg =
    { cfg | maxLeafRowFilterDepth = depth }


subRowNamesAt : List Int -> Table.RowModel NestedRow -> List String
subRowNamesAt path model =
    case descend path model.rows of
        Just row ->
            rowNames (Table.rowSubRows row)

        Nothing ->
            [ "<no such row>" ]


descend : List Int -> List (Table.Row NestedRow) -> Maybe (Table.Row NestedRow)
descend path rows =
    case path of
        [] ->
            Nothing

        first :: [] ->
            List.drop first rows |> List.head

        first :: rest ->
            List.drop first rows
                |> List.head
                |> Maybe.andThen (\row -> descend rest (Table.rowSubRows row))



-- SUITE


suite : Test
suite =
    describe "filtered row model"
        [ createFilteredRowModelSuite
        , filterFnsThroughRowModelSuite
        ]


createFilteredRowModelSuite : Test
createFilteredRowModelSuite =
    describe "createFilteredRowModel"
        [ test "allows a filter function to inspect structural parent rows" <|
            \_ ->
                let
                    data : List NestedRow
                    data =
                        [ NestedRow "parent" [ leaf "child" ]
                        , NestedRow "other" [ leaf "nested" ]
                        ]

                    core : Table.RowModel NestedRow
                    core =
                        Table.coreRowModelFromList nestedConfig Table.initialState data

                    parentAware : Table.Config NestedRow
                    parentAware =
                        Table.config
                            [ Table.column "name" (nestedName >> Value.String)
                                |> Table.withCustomFilter
                                    (\row filterValue ->
                                        (row :: parentsOf core row)
                                            |> List.any
                                                (\candidate ->
                                                    String.contains
                                                        (String.toLower (Value.toString filterValue))
                                                        (String.toLower (nestedName (Table.rowOriginal candidate)))
                                                )
                                    )
                            ]
                            |> Table.withSubRows nestedSubRows

                    namesFor : String -> List String
                    namesFor needle =
                        let
                            state : Table.State
                            state =
                                withColumnFilters [ { id = "name", value = Value.String needle } ] Table.initialState
                        in
                        Table.filteredRowModel parentAware state core
                            |> .flatRows
                            |> rowNames
                            |> List.sort
                in
                Expect.equal ( namesFor "parent", namesFor "other" )
                    ( [ "child", "parent" ], [ "nested", "other" ] )
        , test "should assign display indexes in filtered row order" <|
            \_ ->
                let
                    cfg : Table.Config TestRow
                    cfg =
                        Table.config [ Table.column "name" (.name >> Value.String) ]

                    data : List TestRow
                    data =
                        [ { name = "keep" }, { name = "drop" }, { name = "keep" } ]

                    core : Table.RowModel TestRow
                    core =
                        Table.coreRowModelFromList cfg Table.initialState data

                    filteredOutRow : Maybe (Table.Row TestRow)
                    filteredOutRow =
                        List.drop 1 core.rows |> List.head

                    indexes : Table.State -> ( List Int, List Int, Int )
                    indexes state =
                        let
                            pre : Table.RowModel TestRow
                            pre =
                                Table.filteredRowModel cfg state core
                        in
                        ( List.map Table.rowIndex pre.rows
                        , List.map (Table.displayIndex cfg state pre) pre.rows
                        , filteredOutRow
                            |> Maybe.map (Table.displayIndex cfg state pre)
                            |> Maybe.withDefault -99
                        )
                in
                Expect.equal
                    ( indexes (withColumnFilters [ { id = "name", value = Value.String "keep" } ] Table.initialState)
                    , indexes Table.initialState
                    )
                    ( ( [ 0, 2 ], [ 0, 1 ], -1 )
                    , ( [ 0, 1, 2 ], [ 0, 1, 2 ], 1 )
                    )
        , describe "hierarchical filtering from root (default)"
            [ test "should keep a matching parent with recursively filtered subRows" <|
                \_ ->
                    let
                        model : Table.RowModel NestedRow
                        model =
                            nestedModel identity nestedData
                    in
                    Expect.equal
                        { rows = rowNames model.rows
                        , keepASubRows = subRowNamesAt [ 0 ] model
                        , keepA1SubRows = subRowNamesAt [ 0, 0 ] model
                        , keepDSubRows = subRowNamesAt [ 2 ] model
                        }
                        { rows = [ "keep-a", "keep-c", "keep-d" ]
                        , keepASubRows = [ "keep-a1" ]
                        , keepA1SubRows = []
                        , keepDSubRows = []
                        }
            , test "should clone matching parents that have subRows" <|
                \_ ->
                    -- The vitest case asserts object identity. Elm has no
                    -- object identity, so this asserts what the clone is for:
                    -- the same id and datum with a different subRow list.
                    let
                        pre : Maybe (Table.Row NestedRow)
                        pre =
                            List.head (preNested nestedData).rows

                        filtered : Maybe (Table.Row NestedRow)
                        filtered =
                            List.head (nestedModel identity nestedData).rows
                    in
                    Expect.equal
                        { sameRow = pre == filtered
                        , id = Maybe.map Table.rowId filtered
                        , original = Maybe.map (Table.rowOriginal >> nestedName) filtered
                        , preId = Maybe.map Table.rowId pre
                        , preOriginal = Maybe.map (Table.rowOriginal >> nestedName) pre
                        }
                        { sameRow = False
                        , id = Just "0"
                        , original = Just "keep-a"
                        , preId = Just "0"
                        , preOriginal = Just "keep-a"
                        }
            , test "should drop the entire subtree of a non-matching parent even if children match" <|
                \_ ->
                    let
                        model : Table.RowModel NestedRow
                        model =
                            nestedModel identity nestedData
                    in
                    Expect.equal
                        ( List.member "drop-b" (rowNames model.rows)
                        , List.member "keep-b1" (rowNames model.flatRows)
                        )
                        ( False, False )
            , test "should include cloned rows and exclude dropped rows in flatRows and rowsById in pre-order" <|
                \_ ->
                    let
                        model : Table.RowModel NestedRow
                        model =
                            nestedModel identity nestedData
                    in
                    Expect.equal
                        { flatRows = rowNames model.flatRows
                        , byId =
                            model.rowsById
                                |> Dict.values
                                |> rowNames
                                |> List.sort
                        , keepAFromById = Table.findRow model "0" == List.head model.rows
                        , keepA1FromById =
                            Table.findRow model "0.0"
                                == (List.head model.rows |> Maybe.andThen (Table.rowSubRows >> List.head))
                        }
                        { flatRows = [ "keep-a", "keep-a1", "keep-c", "keep-d" ]
                        , byId = [ "keep-a", "keep-a1", "keep-c", "keep-d" ]
                        , keepAFromById = True
                        , keepA1FromById = True
                        }
            ]
        , describe "filterFromLeafRows"
            [ test "should retain a non-matching parent when any descendant matches" <|
                \_ ->
                    let
                        model : Table.RowModel NestedRow
                        model =
                            nestedModel fromLeafRows nestedData
                    in
                    Expect.equal ( rowNames model.rows, subRowNamesAt [ 1 ] model )
                        ( [ "keep-a", "drop-b", "keep-c", "keep-d" ], [ "keep-b1" ] )
            , test "should flatten rows in pre-order with each parent ahead of its sub-rows" <|
                \_ ->
                    nestedModel fromLeafRows nestedData
                        |> .flatRows
                        |> rowNames
                        |> Expect.equal
                            [ "keep-a", "keep-a1", "drop-b", "keep-b1", "keep-c", "keep-d" ]
            , test "should keep a matching parent that has no matching children" <|
                \_ ->
                    nestedModel fromLeafRows nestedData
                        |> subRowNamesAt [ 3 ]
                        |> Expect.equal []
            , test "should drop a non-matching parent whose descendants all fail" <|
                \_ ->
                    nestedModel fromLeafRows [ NestedRow "drop-z" [ leaf "drop-z1" ] ]
                        |> .rows
                        |> Expect.equal []
            , test "should retain a 3-level chain of non-matching ancestors above a matching leaf" <|
                \_ ->
                    let
                        model : Table.RowModel NestedRow
                        model =
                            nestedModel fromLeafRows
                                [ NestedRow "drop-x" [ NestedRow "drop-x1" [ leaf "keep-x1a" ] ] ]
                    in
                    Expect.equal
                        { rows = rowNames model.rows
                        , level1 = subRowNamesAt [ 0 ] model
                        , level2 = subRowNamesAt [ 0, 0 ] model
                        , flatRows = rowNames model.flatRows
                        }
                        { rows = [ "drop-x" ]
                        , level1 = [ "drop-x1" ]
                        , level2 = [ "keep-x1a" ]
                        , flatRows = [ "drop-x", "drop-x1", "keep-x1a" ]
                        }
            , test "should prune matching subRows from a matching parent while filtering" <|
                \_ ->
                    let
                        model : Table.RowModel NestedRow
                        model =
                            nestedModel fromLeafRows nestedData
                    in
                    Expect.equal ( subRowNamesAt [ 0 ] model, subRowNamesAt [ 0, 0 ] model )
                        ( [ "keep-a1" ], [] )
            , test "should skip the parent predicate when matching descendants retain it" <|
                \_ ->
                    -- The vitest case also asserts the predicate call order
                    -- through a `vi.fn` spy. Elm has no spies, so only the
                    -- resulting rows are asserted; the short circuit that the
                    -- spy proves is the `subRows || predicate` branch in
                    -- `Table.Internal.Filtering.keepFromLeafs`.
                    nestedModel fromLeafRows
                        [ NestedRow "drop-parent" [ leaf "keep-child" ]
                        , NestedRow "keep-parent" [ leaf "drop-child" ]
                        ]
                        |> .rows
                        |> rowNames
                        |> Expect.equal [ "drop-parent", "keep-parent" ]
            ]
        , describe "maxLeafRowFilterDepth"
            [ test "should keep subRows unfiltered when maxLeafRowFilterDepth is 0 (from root)" <|
                \_ ->
                    let
                        model : Table.RowModel NestedRow
                        model =
                            nestedModel (maxDepth 0) nestedData
                    in
                    Expect.equal
                        { rows = rowNames model.rows
                        , keepA = subRowNamesAt [ 0 ] model
                        , keepA1 = subRowNamesAt [ 0, 0 ] model
                        , keepD = subRowNamesAt [ 2 ] model
                        }
                        { rows = [ "keep-a", "keep-c", "keep-d" ]
                        , keepA = [ "keep-a1", "drop-a2" ]
                        , keepA1 = [ "drop-a1a" ]
                        , keepD = [ "drop-d1" ]
                        }
            , test "should treat rows as leaves when maxLeafRowFilterDepth is 0 (from leaf)" <|
                \_ ->
                    let
                        model : Table.RowModel NestedRow
                        model =
                            nestedModel (fromLeafRows >> maxDepth 0) nestedData
                    in
                    Expect.equal
                        { rows = rowNames model.rows
                        , keepA = subRowNamesAt [ 0 ] model
                        , keepA1 = subRowNamesAt [ 0, 0 ] model
                        , flatRows = rowNames model.flatRows
                        , descendantById =
                            Table.findRow model "0.0"
                                == (List.head model.rows |> Maybe.andThen (Table.rowSubRows >> List.head))
                        }
                        { rows = [ "keep-a", "keep-c", "keep-d" ]
                        , keepA = [ "keep-a1", "drop-a2" ]
                        , keepA1 = [ "drop-a1a" ]
                        , flatRows =
                            [ "keep-a", "keep-a1", "drop-a1a", "drop-a2", "keep-c", "keep-d", "drop-d1" ]
                        , descendantById = True
                        }
            , test "should include unfiltered descendants of kept rows in flatRows and rowsById (from root, depth 0)" <|
                \_ ->
                    let
                        model : Table.RowModel NestedRow
                        model =
                            nestedModel (maxDepth 0) nestedData
                    in
                    Expect.equal
                        ( rowNames model.flatRows
                        , Table.findRow model "0.0"
                            == (List.head model.rows |> Maybe.andThen (Table.rowSubRows >> List.head))
                        )
                        ( [ "keep-a", "keep-a1", "drop-a1a", "drop-a2", "keep-c", "keep-d", "drop-d1" ]
                        , True
                        )
            , test "should include kept-as-is grandchildren in flatRows when maxLeafRowFilterDepth is 1 (from root)" <|
                \_ ->
                    nestedModel (maxDepth 1) nestedData
                        |> .flatRows
                        |> rowNames
                        |> Expect.equal [ "keep-a", "keep-a1", "drop-a1a", "keep-c", "keep-d" ]
            , test "should stop filtering below depth 1 when maxLeafRowFilterDepth is 1 (from root)" <|
                \_ ->
                    let
                        model : Table.RowModel NestedRow
                        model =
                            nestedModel (maxDepth 1) nestedData
                    in
                    Expect.equal ( subRowNamesAt [ 0 ] model, subRowNamesAt [ 0, 0 ] model )
                        ( [ "keep-a1" ], [ "drop-a1a" ] )
            , test "should stop consulting descendants below depth 1 when maxLeafRowFilterDepth is 1 (from leaf)" <|
                \_ ->
                    nestedModel (fromLeafRows >> maxDepth 1)
                        [ NestedRow "drop-x" [ NestedRow "drop-x1" [ leaf "keep-x1a" ] ]
                        , NestedRow "drop-b" [ leaf "keep-b1" ]
                        ]
                        |> .rows
                        |> rowNames
                        |> Expect.equal [ "drop-b" ]
            , test "should filter deep trees fully with the default depth of 100" <|
                \_ ->
                    Expect.equal
                        ( subRowNamesAt [ 0, 0 ] (nestedModel identity nestedData)
                        , subRowNamesAt [ 0, 0 ] (nestedModel fromLeafRows nestedData)
                        )
                        ( [], [] )
            ]
        , describe "column filter and global filter together"
            [ test "should require rows to pass both filters (AND semantics) in one pass" <|
                \_ ->
                    -- The vitest case also asserts the per-row `columnFilters`
                    -- flags left on the pre-filtered rows. This port has no
                    -- such row field (see reports/phase-3.md), so it asserts
                    -- the surviving rows only.
                    let
                        cfg : Table.Config TaggedRow
                        cfg =
                            Table.config
                                [ Table.column "name" (.name >> Value.String)
                                , Table.column "tag" (.tag >> Value.String)
                                ]

                        state : Table.State
                        state =
                            Table.initialState
                                |> withColumnFilters [ { id = "name", value = Value.String "keep" } ]
                                |> withGlobal (Value.String "x")

                        model : Table.RowModel TaggedRow
                        model =
                            Table.coreRowModelFromList cfg
                                state
                                [ { name = "keep", tag = "x1" }
                                , { name = "keep", tag = "y" }
                                , { name = "drop", tag = "x2" }
                                , { name = "drop", tag = "y" }
                                ]
                                |> Table.filteredRowModel cfg state
                    in
                    Expect.equal
                        ( List.map (Table.rowOriginal >> .tag) model.rows
                        , List.length model.flatRows
                        )
                        ( [ "x1" ], 1 )
            ]
        , describe "columnFilters state edge cases"
            [ test "should skip an unknown column id in columnFilters state" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            Table.config [ Table.column "name" (.name >> Value.String) ]

                        state : Table.State
                        state =
                            withColumnFilters [ { id = "doesNotExist", value = Value.String "z" } ] Table.initialState
                    in
                    Table.coreRowModelFromList cfg state [ { name = "keep" }, { name = "drop" } ]
                        |> Table.filteredRowModel cfg state
                        |> .rows
                        |> List.map (Table.rowOriginal >> .name)
                        |> Expect.equal [ "keep", "drop" ]
            , test "should still filter a column with enableColumnFilter false when state contains an entry" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            Table.config
                                [ Table.column "name" (.name >> Value.String)
                                    |> Table.withEnableColumnFilter False
                                ]

                        state : Table.State
                        state =
                            withColumnFilters [ { id = "name", value = Value.String "keep" } ] Table.initialState
                    in
                    Expect.equal
                        ( Table.getCanFilter cfg "name"
                        , Table.coreRowModelFromList cfg state [ { name = "keep" }, { name = "drop" } ]
                            |> Table.filteredRowModel cfg state
                            |> .rows
                            |> List.map (Table.rowOriginal >> .name)
                        )
                        ( False, [ "keep" ] )
            ]

        -- excluded: describe "columnFiltersMeta"
        --   * "should populate row.columnFiltersMeta via the addMeta callback of
        --     a column filterFn"
        --   * "should populate row.columnFiltersMeta via the addMeta callback of
        --     a custom global filter"
        --   * "should preserve filter flags and metadata on nested
        --     ${leaf-first|root-first} clones"
        --   A `Row` here carries no `columnFilters` / `columnFiltersMeta` map
        --   and a filter fn has no `addMeta` callback.
        --
        -- excluded: describe "row.columnFilters flags"
        --   * "should tag flat rows with per-column pass/fail and the __global__
        --     flag"
        --   * "should reset columnFilters and columnFiltersMeta on rows after all
        --     filters are removed"
        --   Same reason: the flags are mutated onto the pre-filtered rows.
        , describe "global filtering edge cases"
            [ test "should filter a column when its first row value is undefined" <|
                \_ ->
                    let
                        cfg : Table.Config (Maybe String)
                        cfg =
                            Table.config [ Table.column "name" maybeName ]

                        state : Table.State
                        state =
                            withGlobal (Value.String "hello") Table.initialState
                    in
                    Table.coreRowModelFromList cfg state [ Nothing, Just "hello", Just "world" ]
                        |> Table.filteredRowModel cfg state
                        |> .rows
                        |> List.map Table.rowOriginal
                        |> Expect.equal [ Just "hello" ]
            , test "should globally filter an object-valued column that explicitly opts in" <|
                \_ ->
                    -- `Value.List` stands in for the object-valued cell.
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            { base
                                | globalFilterFn =
                                    Just
                                        (FilterFn.custom
                                            (\dataValue filterValue ->
                                                String.contains (Value.toString filterValue) (Value.toString dataValue)
                                            )
                                        )
                            }

                        base : Table.Config TestRow
                        base =
                            Table.config
                                [ Table.column "value" (\row -> Value.List [ Value.String row.name ])
                                    |> Table.withEnableGlobalFilter True
                                ]

                        state : Table.State
                        state =
                            withGlobal (Value.String "keep") Table.initialState
                    in
                    Table.coreRowModelFromList cfg state [ { name = "keep" }, { name = "drop" } ]
                        |> Table.filteredRowModel cfg state
                        |> .rows
                        |> List.map (Table.rowOriginal >> .name)
                        |> Expect.equal [ "keep" ]
            , test "should pass rows through when no columns are globally filterable" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            Table.config
                                [ Table.column "name" (.name >> Value.String)
                                    |> Table.withEnableGlobalFilter False
                                ]

                        state : Table.State
                        state =
                            withGlobal (Value.String "keep") Table.initialState
                    in
                    Table.coreRowModelFromList cfg state [ { name = "keep" }, { name = "drop" } ]
                        |> Table.filteredRowModel cfg state
                        |> .rows
                        |> List.map (Table.rowOriginal >> .name)
                        |> Expect.equal [ "keep", "drop" ]
            , test "should match mixed-case global filter values via includesString value resolution" <|
                \_ ->
                    globalOnly [ { name = "Keep Me" }, { name = "drop" } ] (Value.String "kEeP")
                        |> Expect.equal [ "Keep Me" ]
            , test "should apply a numeric zero global filter value" <|
                \_ ->
                    globalOnly [ { name = "status 0" }, { name = "status 1" } ] (Value.Number 0)
                        |> Expect.equal [ "status 0" ]
            ]
        , test "should auto-filter a nullable string column when the first value is null" <|
            \_ ->
                let
                    cfg : Table.Config (Maybe String)
                    cfg =
                        Table.config [ Table.column "name" maybeName ]

                    state : Table.State
                    state =
                        withColumnFilters [ { id = "name", value = Value.String "ell" } ] Table.initialState
                in
                Table.coreRowModelFromList cfg state [ Nothing, Just "hello", Just "welcome" ]
                    |> Table.filteredRowModel cfg state
                    |> .rows
                    |> List.map Table.rowOriginal
                    |> Expect.equal [ Just "hello" ]

        -- excluded: describe "unresolvable global filter fn"
        --   * "should apply no global filtering and warn in dev when the
        --     globalFilterFn name is not registered"
        --   `Config.globalFilterFn` is a `Maybe FilterFn`, so there is no
        --   unregistered name to fail to resolve and no dev warning to spy on.
        , describe "no active filters"
            [ test "should return the pre-filtered row model identity when no filters are active" <|
                \_ ->
                    let
                        cfg : Table.Config TestRow
                        cfg =
                            Table.config [ Table.column "name" (.name >> Value.String) ]

                        core : Table.RowModel TestRow
                        core =
                            Table.coreRowModelFromList cfg Table.initialState [ { name = "keep" }, { name = "drop" } ]
                    in
                    Table.filteredRowModel cfg Table.initialState core
                        |> Expect.equal core
            ]
        , describe "pre-order flatRows traversal"
            [ test "flattens rows depth-first with each parent preceding its sub-rows (root filtering)" <|
                \_ ->
                    complexFlatRows identity (Value.String "1")
                        |> Expect.equal
                            [ "parent-1", "child-1.1", "grandchild-1.1.1", "grandchild-1.1.2", "child-1.2" ]
            , test "flattens rows depth-first with each parent preceding its sub-rows (leaf filtering)" <|
                \_ ->
                    complexFlatRows fromLeafRows (Value.String ".2")
                        |> Expect.equal
                            [ "parent-1", "child-1.1", "grandchild-1.1.2", "child-1.2" ]
            ]
        ]


maybeName : Maybe String -> Value
maybeName name =
    case name of
        Just s ->
            Value.String s

        Nothing ->
            Value.Null


parentsOf : Table.RowModel NestedRow -> Table.Row NestedRow -> List (Table.Row NestedRow)
parentsOf model row =
    case Table.getParentRow model row of
        Just parent ->
            [ parent ]

        Nothing ->
            []


globalOnly : List TestRow -> Value -> List String
globalOnly data filterValue =
    let
        cfg : Table.Config TestRow
        cfg =
            Table.config [ Table.column "name" (.name >> Value.String) ]

        state : Table.State
        state =
            withGlobal filterValue Table.initialState
    in
    Table.coreRowModelFromList cfg state data
        |> Table.filteredRowModel cfg state
        |> .rows
        |> List.map (Table.rowOriginal >> .name)


complexNestedData : List NestedRow
complexNestedData =
    [ NestedRow "parent-1"
        [ NestedRow "child-1.1" [ leaf "grandchild-1.1.1", leaf "grandchild-1.1.2" ]
        , leaf "child-1.2"
        ]
    , NestedRow "parent-2" [ leaf "child-2.1" ]
    ]


complexFlatRows : (Table.Config NestedRow -> Table.Config NestedRow) -> Value -> List String
complexFlatRows tweak filterValue =
    let
        cfg : Table.Config NestedRow
        cfg =
            tweak nestedConfig

        state : Table.State
        state =
            withColumnFilters [ { id = "name", value = filterValue } ] Table.initialState
    in
    Table.coreRowModelFromList cfg state complexNestedData
        |> Table.filteredRowModel cfg state
        |> .flatRows
        |> rowNames



-- tests/unit/fns/filterFns.test.ts, the cases that need the row model


{-| `String(val ?? '').toLowerCase().normalize('NFD').replace(/\p{Diacritic}/gu, '')`
for the letters the ported tests use. Elm core has no Unicode normalisation.
Kept in step with the copy in `tests/FilterFnTest.elm`.
-}
normalize : Value -> Value
normalize value =
    Value.toString value
        |> String.toLower
        |> String.map
            (\c ->
                case c of
                    'é' ->
                        'e'

                    'ë' ->
                        'e'

                    _ ->
                        c
            )
        |> Value.String


includesStringIgnoreDiacritics : FilterFn.FilterFn
includesStringIgnoreDiacritics =
    FilterFn.includesString
        |> FilterFn.withResolveFilterValue normalize
        |> FilterFn.withResolveDataValue normalize


type alias Event =
    { name : String, when : Value }


eventConfig : Table.Config Event
eventConfig =
    Table.config
        [ Table.column "name" (.name >> Value.String)
        , Table.column "when" .when
        ]


eventData : List Event
eventData =
    [ { name = "too early", when = day 1 }
    , { name = "in range", when = day 10 }
    , { name = "no date", when = Value.Null }
    , { name = "too late", when = day 20 }
    ]


{-| 2026-01-`n` as a `Date` value.
-}
day : Int -> Value
day n =
    Value.Date (Time.millisToPosix (1767225600000 + (n - 1) * 86400000))


filterFnsThroughRowModelSuite : Test
filterFnsThroughRowModelSuite =
    describe "filterFns through the table row model"
        [ describe "constructFilterFn"
            [ test "applies both resolvers when filtering through the table row model" <|
                \_ ->
                    let
                        cfg : Table.Config (Maybe String)
                        cfg =
                            Table.config
                                [ Table.column "name" maybeName
                                    |> Table.withFilterFn includesStringIgnoreDiacritics
                                ]

                        state : Table.State
                        state =
                            withColumnFilters [ { id = "name", value = Value.String "ERIC" } ] Table.initialState
                    in
                    Table.coreRowModelFromList cfg
                        state
                        [ Just "Enrico Toccacelo", Just "Éric Bernard", Just "Eric Brandon", Nothing ]
                        |> Table.filteredRowModel cfg state
                        |> .rows
                        |> List.map (Table.rowOriginal >> Maybe.withDefault "")
                        |> Expect.equal [ "Éric Bernard", "Eric Brandon" ]
            ]
        , describe "auto filter fn for date columns"
            [ test "resolves inDateRange for Date-valued columns" <|
                \_ ->
                    Table.getAutoFilterFn eventConfig
                        (Table.coreRowModelFromList eventConfig Table.initialState eventData)
                        "when"
                        |> filterFnLabel
                        |> Expect.equal "inDateRange"
            , test "filters date rows through the table row model" <|
                \_ ->
                    let
                        state : Table.State
                        state =
                            withColumnFilters
                                [ { id = "when", value = Value.List [ day 5, day 15 ] } ]
                                Table.initialState
                    in
                    Table.coreRowModelFromList eventConfig state eventData
                        |> Table.filteredRowModel eventConfig state
                        |> .rows
                        |> List.map (Table.rowOriginal >> .name)
                        |> Expect.equal [ "in range" ]
            ]
        ]
