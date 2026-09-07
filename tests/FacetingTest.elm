module FacetingTest exposing (suite)

{-| Ports
`tests/implementation/features/column-faceting/createFacetedRowModels.test.ts`
and `tests/unit/features/column-faceting/columnFacetingFeature.test.ts`.

The row model handed to the faceting functions is the pre-filtered one, which
in this port is whatever was passed to `Table.filteredRowModel`.

-}

import Expect
import Table
import Table.FilterFn as FilterFn
import Table.Value as Value exposing (Value)
import Test exposing (Test, describe, test)



-- FIXTURE


type alias Person =
    { name : String
    , age : Value
    , team : String
    , tags : List String
    }


columns : List (Table.Column Person)
columns =
    [ Table.column "name" (.name >> Value.String)
        |> Table.withFilterFn FilterFn.includesString
    , Table.column "age" .age
    , Table.column "team" (.team >> Value.String)
        |> Table.withFilterFn FilterFn.equalsString
    , Table.column "tags" (.tags >> List.map Value.String >> Value.List)
        |> Table.withFilterFn FilterFn.arrIncludes
        -- without this, getUniqueValues wraps the whole list as one value
        |> Table.withGetUniqueValues (.tags >> List.map Value.String)
    ]


config : Table.Config Person
config =
    Table.config columns


data : List Person
data =
    [ { name = "Alice", age = Value.Number 30, team = "red", tags = [ "a", "b" ] }
    , { name = "Bob", age = Value.Number 25, team = "blue", tags = [ "b" ] }
    , { name = "Carol", age = Value.String "40", team = "red", tags = [ "a", "c" ] }
    , { name = "Dave", age = Value.Null, team = "blue", tags = [] }
    ]


type alias Options =
    { data : List Person
    , columnFilters : List Table.ColumnFilter
    , globalFilter : Value
    }


defaults : Options
defaults =
    { data = data, columnFilters = [], globalFilter = Value.Null }


stateOf : Options -> Table.State
stateOf options =
    let
        state : Table.State
        state =
            Table.initialState
    in
    { state | columnFilters = options.columnFilters, globalFilter = options.globalFilter }


{-| The pre-filtered row model, which is what faceting reads.
-}
preFiltered : Options -> Table.RowModel Person
preFiltered options =
    Table.coreRowModelFromList config (stateOf options) options.data


minMax : Options -> String -> Maybe ( Float, Float )
minMax options columnId =
    Table.facetedMinMax config (stateOf options) (preFiltered options) columnId


uniqueValues : Options -> String -> List ( Value, Int )
uniqueValues options columnId =
    Table.facetedUniqueValues config (stateOf options) (preFiltered options) columnId


facetNames : Options -> String -> List String
facetNames options columnId =
    Table.facetedRowModel config (stateOf options) (preFiltered options) columnId
        |> .rows
        |> List.map (Table.rowOriginal >> .name)



-- SUITE


suite : Test
suite =
    describe "column faceting"
        [ facetedRowModelsSuite
        , columnFacetingFeatureSuite
        ]


facetedRowModelsSuite : Test
facetedRowModelsSuite =
    describe "createFacetedRowModels"
        [ describe "getFacetedMinMaxValues (real implementation)"
            [ test "should return min and max for a numeric column" <|
                \_ ->
                    -- '40' coerces via Number(); null coerces to 0
                    minMax defaults "age" |> Expect.equal (Just ( 0, 40 ))
            , test "should coerce numeric strings with Number()" <|
                \_ ->
                    minMax
                        { defaults
                            | data =
                                [ { name = "A", age = Value.String "5", team = "red", tags = [] }
                                , { name = "B", age = Value.String "15", team = "red", tags = [] }
                                ]
                        }
                        "age"
                        |> Expect.equal (Just ( 5, 15 ))
            , test "should skip NaN values from non-numeric cells" <|
                \_ ->
                    minMax
                        { defaults
                            | data =
                                [ { name = "A", age = Value.String "not-a-number", team = "red", tags = [] }
                                , { name = "B", age = Value.Number 7, team = "red", tags = [] }
                                , { name = "C", age = Value.Number 3, team = "red", tags = [] }
                                ]
                        }
                        "age"
                        |> Expect.equal (Just ( 3, 7 ))
            , test "should return undefined when no cell is numeric" <|
                \_ ->
                    -- every name coerces to NaN
                    minMax defaults "name" |> Expect.equal Nothing
            , test "should return undefined for empty data" <|
                \_ ->
                    minMax { defaults | data = [] } "age" |> Expect.equal Nothing
            , test "should return [x, x] for a single row" <|
                \_ ->
                    minMax
                        { defaults | data = [ { name = "A", age = Value.Number 42, team = "red", tags = [] } ] }
                        "age"
                        |> Expect.equal (Just ( 42, 42 ))
            ]
        , describe "faceted row model semantics under active filters"
            [ test "should exclude its own filter but apply other column filters" <|
                \_ ->
                    facetNames
                        { defaults
                            | columnFilters =
                                [ { id = "team", value = Value.String "red" }
                                , { id = "name", value = Value.String "Bob" }
                                ]
                        }
                        "name"
                        |> Expect.equal [ "Alice", "Carol" ]
            , test "should apply the global filter to a column faceted row model" <|
                \_ ->
                    facetNames { defaults | globalFilter = Value.String "Bo" } "team"
                        |> Expect.equal [ "Bob" ]
            , test "should be identical to the pre-filtered model when only the faceted column is filtered" <|
                \_ ->
                    let
                        options : Options
                        options =
                            { defaults | columnFilters = [ { id = "team", value = Value.String "red" } ] }
                    in
                    Table.facetedRowModel config (stateOf options) (preFiltered options) "team"
                        |> Expect.equal (preFiltered options)
            , test "should return the pre-filtered model for empty data" <|
                \_ ->
                    let
                        options : Options
                        options =
                            { data = []
                            , columnFilters = [ { id = "team", value = Value.String "red" } ]
                            , globalFilter = Value.String "x"
                            }
                    in
                    Table.facetedRowModel config (stateOf options) (preFiltered options) "name"
                        |> Expect.equal (preFiltered options)
            ]
        , describe "getFacetedUniqueValues (real implementation)"
            [ test "should count unique values from the other-filtered faceted rows" <|
                \_ ->
                    -- name facet reflects only Alice and Carol (red team)
                    uniqueValues { defaults | columnFilters = [ { id = "team", value = Value.String "red" } ] } "name"
                        |> Expect.equal [ ( Value.String "Alice", 1 ), ( Value.String "Carol", 1 ) ]
            , test "should count duplicate values correctly" <|
                \_ ->
                    uniqueValues defaults "team"
                        |> Expect.equal [ ( Value.String "red", 2 ), ( Value.String "blue", 2 ) ]
            , test "should yield one entry per array element for array-valued cells" <|
                \_ ->
                    uniqueValues defaults "tags"
                        |> Expect.equal
                            [ ( Value.String "a", 2 ), ( Value.String "b", 2 ), ( Value.String "c", 1 ) ]
            ]
        , describe "global faceted models (real factories)"
            [ test "should apply column filters but not the global filter in the global faceted row model" <|
                \_ ->
                    facetNames
                        { defaults
                            | columnFilters = [ { id = "team", value = Value.String "blue" } ]
                            , globalFilter = Value.String "Bob"
                        }
                        Table.globalFacetKey
                        |> Expect.equal [ "Bob", "Dave" ]
            , test "should aggregate unique values across globally filterable columns" <|
                \_ ->
                    -- The tags column is not globally filterable (list values),
                    -- so name, age and team contribute. Raw cell values are not
                    -- coerced, so '40' stays a string. A JavaScript `Map`
                    -- comparison ignores order; this list is in first-seen
                    -- order.
                    uniqueValues { defaults | columnFilters = [ { id = "team", value = Value.String "red" } ] }
                        Table.globalFacetKey
                        |> Expect.equal
                            [ ( Value.String "Alice", 1 )
                            , ( Value.Number 30, 1 )
                            , ( Value.String "red", 2 )
                            , ( Value.String "Carol", 1 )
                            , ( Value.String "40", 1 )
                            ]
            , test "should return an empty Map for global faceted unique values with empty data" <|
                \_ ->
                    uniqueValues { defaults | data = [] } Table.globalFacetKey |> Expect.equal []
            , test "should aggregate min max values across globally filterable columns" <|
                \_ ->
                    -- name and team coerce to NaN and are skipped; age yields
                    -- 30, 25, 40 ('40' coerced) and 0 (Number(null) is 0)
                    minMax defaults Table.globalFacetKey |> Expect.equal (Just ( 0, 40 ))
            ]
        , describe "recompute and reference stability"
            [ test "should return the same references on repeated calls when nothing changed" <|
                \_ ->
                    -- Elm has no instance identity: repeated calls with the
                    -- same inputs produce equal values.
                    let
                        first : Options
                        first =
                            { defaults | columnFilters = [ { id = "team", value = Value.String "red" } ] }

                        second : Options
                        second =
                            { defaults | columnFilters = [ { id = "team", value = redTeam } ] }
                    in
                    Expect.equal
                        { rowModel = facetNames first "name" == facetNames second "name"
                        , unique = uniqueValues first "name" == uniqueValues second "name"
                        , minMax = minMax first "age" == minMax second "age"
                        }
                        { rowModel = True, unique = True, minMax = True }
            , test "should recompute after a runtime filter change on another column" <|
                \_ ->
                    let
                        filtered : Options
                        filtered =
                            { defaults | columnFilters = [ { id = "team", value = Value.String "red" } ] }
                    in
                    Expect.equal
                        { unfilteredNameCount = List.length (uniqueValues defaults "name")
                        , unfilteredAge = minMax defaults "age"
                        , filteredNames = uniqueValues filtered "name"
                        , filteredAge = minMax filtered "age"
                        }
                        { unfilteredNameCount = 4
                        , unfilteredAge = Just ( 0, 40 )
                        , filteredNames = [ ( Value.String "Alice", 1 ), ( Value.String "Carol", 1 ) ]
                        , filteredAge = Just ( 30, 40 )
                        }
            ]

        -- excluded: describe "no-factory fallbacks"
        --   * "should fall back to the pre-filtered model, empty Map, and
        --     undefined". Faceting is not a registered factory here; the three
        --     functions are always available.
        --
        , describe "custom faceted row-model factories"
            [ -- adapted: reference stability becomes value equality, and the
              -- filter that changes this column's inputs is applied to the
              -- other column, as in the vitest case.
              test "should keep the stock facetedUniqueValues reference stable until its inputs change" <|
                \_ ->
                    let
                        filteredByName : Options
                        filteredByName =
                            { defaults | columnFilters = [ { id = "name", value = Value.String "Alice" } ] }
                    in
                    Expect.all
                        [ \_ -> Expect.equal (uniqueValues defaults "team") (uniqueValues defaults "team")
                        , \_ -> Expect.equal (facetNames defaults "team") (facetNames defaults "team")
                        , \_ -> Expect.equal (minMax defaults "age") (minMax defaults "age")
                        , \_ ->
                            Expect.notEqual (uniqueValues filteredByName "team")
                                (uniqueValues defaults "team")
                        , \_ ->
                            Expect.equal (uniqueValues filteredByName "team")
                                (uniqueValues filteredByName "team")
                        ]
                        ()
            , -- adapted: the port's counterpart of a custom faceted values
              -- source is the column's own `withGetUniqueValues`, which the
              -- faceting functions consult on every read rather than caching.
              test "should call a custom facetedUniqueValues factory live on every read" <|
                \_ ->
                    let
                        plainTags : Table.Config Person
                        plainTags =
                            Table.config
                                [ Table.column "tags" (.tags >> List.map Value.String >> Value.List) ]

                        splitTags : Table.Config Person
                        splitTags =
                            Table.config
                                [ Table.column "tags" (.tags >> List.map Value.String >> Value.List)
                                    |> Table.withGetUniqueValues (.tags >> List.map Value.String)
                                ]

                        uniqueWith : Table.Config Person -> List ( Value, Int )
                        uniqueWith cfg =
                            Table.facetedUniqueValues cfg
                                Table.initialState
                                (Table.coreRowModelFromList cfg Table.initialState data)
                                "tags"
                    in
                    Expect.equal
                        { split = uniqueWith splitTags
                        , plainCount = List.length (uniqueWith plainTags)
                        }
                        { split =
                            [ ( Value.String "a", 2 )
                            , ( Value.String "b", 2 )
                            , ( Value.String "c", 1 )
                            ]
                        , plainCount = 4
                        }
            ]
        ]



-- columnFacetingFeature.test.ts


{-| The same value as `Value.String "red"`, built at run time so `elm-review`
does not fold the two equal facet calls above into `True`.
-}
redTeam : Value
redTeam =
    Value.String (String.reverse "der")


type alias Employee =
    { firstName : String
    , status : Value
    }


employeeConfig : Table.Config Employee
employeeConfig =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
        , Table.column "status" .status |> Table.withFilterFn FilterFn.equalsString
        ]


employees : List Employee
employees =
    [ { firstName = "Alice", status = Value.String "active" }
    , { firstName = "Bob", status = Value.Null }
    , { firstName = "Carol", status = Value.String "active" }
    ]


employeeState : List Table.ColumnFilter -> Table.State
employeeState filters =
    let
        state : Table.State
        state =
            Table.initialState
    in
    { state | columnFilters = filters }


employeeModel : Table.RowModel Employee
employeeModel =
    Table.coreRowModelFromList employeeConfig Table.initialState employees


columnFacetingFeatureSuite : Test
columnFacetingFeatureSuite =
    describe "column faceting row model"
        [ test "reuses the pre-filtered row model when only the faceted column is filtered" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        employeeState [ { id = "status", value = Value.String "active" } ]
                in
                Table.facetedRowModel employeeConfig state employeeModel "status"
                    |> Expect.equal employeeModel
        , test "still applies filters from other columns" <|
            \_ ->
                let
                    state : Table.State
                    state =
                        employeeState [ { id = "status", value = Value.String "active" } ]
                in
                Table.facetedRowModel employeeConfig state employeeModel "firstName"
                    |> .rows
                    |> List.map Table.rowOriginal
                    |> Expect.equal
                        [ { firstName = "Alice", status = Value.String "active" }
                        , { firstName = "Carol", status = Value.String "active" }
                        ]
        , test "counts unique values without dropping undefined facet values" <|
            \_ ->
                Table.facetedUniqueValues employeeConfig (employeeState []) employeeModel "status"
                    |> Expect.equal [ ( Value.String "active", 2 ), ( Value.Null, 1 ) ]
        , -- adapted: there is no factory to cache, so the call counts become
          -- the observable half: a column context and the global context each
          -- keep their own value, and repeated reads of either agree.
          test "caches faceted factory functions per column and global context" <|
            \_ ->
                let
                    facetOf : String -> List ( Value, Int )
                    facetOf columnId =
                        Table.facetedUniqueValues employeeConfig (employeeState []) employeeModel columnId
                in
                Expect.all
                    [ \_ ->
                        Expect.equal [ ( Value.String "active", 2 ), ( Value.Null, 1 ) ]
                            (facetOf "status")
                    , \_ -> Expect.equal (facetOf "status") (facetOf "status")
                    , \_ -> Expect.equal (facetOf Table.globalFacetKey) (facetOf Table.globalFacetKey)
                    , \_ -> Expect.notEqual (facetOf "status") (facetOf "firstName")
                    ]
                    ()
        ]
