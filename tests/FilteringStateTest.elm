module FilteringStateTest exposing (filterFnLabel, suite)

{-| Ports
`tests/unit/features/column-filtering/columnFilteringFeature.utils.test.ts`.

Elm cannot compare two functions, so the cases that assert which built-in
filter fn was picked (`expect(...).toBe(filterFn_arrIncludes)`) compare
[`filterFnLabel`](#filterFnLabel) instead, which probes a `FilterFn` with
inputs only one built-in answers `True` to.

-}

import Expect
import Table
import Table.FilterFn as FilterFn exposing (FilterFn)
import Table.Value as Value exposing (Value)
import Test exposing (Test, describe, test)
import Time



-- FILTER FN IDENTIFICATION


{-| The name of a built-in filter fn, recovered from its behaviour. Only the
six functions the `'auto'` picker can return are told apart.
-}
filterFnLabel : FilterFn -> String
filterFnLabel fn =
    if matches fn (Value.String "hello") (Value.String "ELL") then
        "includesString"

    else if matches fn (date 5) (Value.List [ date 0, date 10 ]) then
        "inDateRange"

    else if matches fn (Value.Number 5) (Value.List [ Value.Number 0, Value.Number 10 ]) then
        "inNumberRange"

    else if matches fn (Value.List [ Value.String "a", Value.String "b" ]) (Value.List [ Value.String "a" ]) then
        "arrIncludes"

    else if matches fn (Value.String "1") (Value.Number 1) then
        "weakEquals"

    else if matches fn (Value.Bool True) (Value.Bool True) then
        "equals"

    else
        "unknown"


matches : FilterFn -> Value -> Value -> Bool
matches fn dataValue filterValue =
    FilterFn.filter fn dataValue (FilterFn.resolveFilterValue fn filterValue)


date : Int -> Value
date millis =
    Value.Date (Time.millisToPosix millis)



-- FIXTURES


type alias Sample =
    { tags : List String
    , active : Bool
    }


sampleConfig : Table.Config Sample
sampleConfig =
    Table.config
        [ Table.column "tags" (.tags >> List.map Value.String >> Value.List)
        , Table.column "details" (.active >> Value.Bool)
        ]


sampleData : List Sample
sampleData =
    [ { tags = [ "a", "b" ], active = True } ]


type alias Person =
    { firstName : String
    , lastName : String
    , age : Int
    }


people : List Person
people =
    [ { firstName = "alice", lastName = "xi", age = 30 }
    , { firstName = "bob", lastName = "young", age = 40 }
    ]


personColumns : List (Table.Column Person)
personColumns =
    [ Table.column "firstName" (.firstName >> Value.String)
    , Table.column "lastName" (.lastName >> Value.String)
    , Table.column "age" (.age >> toFloat >> Value.Number)

    -- display column with no accessor
    , Table.display "actions" |> Table.withHeader "Actions"
    ]


personConfig : Table.Config Person
personConfig =
    Table.config personColumns


modelFor : Table.Config row -> List row -> Table.RowModel row
modelFor cfg data =
    Table.coreRowModelFromList cfg Table.initialState data


personModel : Table.Config Person -> Table.RowModel Person
personModel cfg =
    modelFor cfg people


withFilters : List Table.ColumnFilter -> Table.State
withFilters filters =
    let
        state : Table.State
        state =
            Table.initialState
    in
    { state | columnFilters = filters }


autoFilterLabel : Table.Config row -> List row -> String -> String
autoFilterLabel cfg data columnId =
    filterFnLabel (Table.getAutoFilterFn cfg (modelFor cfg data) columnId)



-- SUITE


suite : Test
suite =
    describe "columnFilteringFeature.utils"
        [ describe "column_getAutoFilterFn"
            [ test "selects arrIncludes for array values" <|
                \_ ->
                    autoFilterLabel sampleConfig sampleData "tags"
                        |> Expect.equal "arrIncludes"
            , test "selects equals for non-array object values" <|
                \_ ->
                    -- `Value` has no object constructor. JavaScript objects and
                    -- booleans both select `equals`, so the boolean column
                    -- stands in for the object one here.
                    autoFilterLabel sampleConfig sampleData "details"
                        |> Expect.equal "equals"
            , test "infers the filter from the first non-null column value" <|
                \_ ->
                    let
                        cfg : Table.Config (Maybe String)
                        cfg =
                            Table.config [ Table.column "name" nullableName ]
                    in
                    autoFilterLabel cfg [ Nothing, Just "hello" ] "name"
                        |> Expect.equal "includesString"
            ]
        , describe "getDefaultColumnFiltersState"
            [ test "should return an empty array and a new instance each time" <|
                \_ ->
                    -- The second half of the vitest case asserts that two calls
                    -- return different objects. Elm values are immutable, so
                    -- only the value is asserted.
                    Table.initialState.columnFilters
                        |> Expect.equal []
            ]
        , describe "column_getFilterFn"
            [ test "should return a function-valued filterFn directly" <|
                \_ ->
                    -- `withFilterFn` is this port's "function-valued filterFn":
                    -- it wins over the automatic choice, which would be
                    -- `includesString` for this string column.
                    let
                        cfg : Table.Config Person
                        cfg =
                            Table.config
                                [ Table.column "firstName" (.firstName >> Value.String)
                                    |> Table.withFilterFn FilterFn.equals
                                ]
                    in
                    Table.getFilterFn cfg (personModel cfg) "firstName"
                        |> Maybe.map filterFnLabel
                        |> Expect.equal (Just "equals")
            , test "should delegate to the auto filter fn for \"auto\"" <|
                \_ ->
                    Table.getFilterFn personConfig (personModel personConfig) "firstName"
                        |> Maybe.map filterFnLabel
                        |> Expect.equal (Just "includesString")
            , test "should look up registered filter fn names" <|
                \_ ->
                    -- Filter fns are values here, not registry names, so this
                    -- is the same shape as the case above.
                    let
                        cfg : Table.Config Person
                        cfg =
                            Table.config
                                [ Table.column "firstName" (.firstName >> Value.String)
                                    |> Table.withFilterFn FilterFn.weakEquals
                                ]
                    in
                    Table.getFilterFn cfg (personModel cfg) "firstName"
                        |> Maybe.map filterFnLabel
                        |> Expect.equal (Just "weakEquals")

            -- excluded: "should return undefined for unknown filter fn names"
            --   `Column.filterFn` is a `Maybe FilterFn`, not a registry name,
            --   so there is no unknown name to fail to resolve.
            ]
        , describe "column_getCanFilter"
            [ test "should return true for accessor columns by default" <|
                \_ ->
                    Table.getCanFilter personConfig "firstName" |> Expect.equal True
            , test "should return false for display columns without an accessor" <|
                \_ ->
                    Table.getCanFilter personConfig "actions" |> Expect.equal False
            , test "should return false when filtering is disabled for the column" <|
                \_ ->
                    let
                        cfg : Table.Config Person
                        cfg =
                            Table.config
                                [ Table.column "firstName" (.firstName >> Value.String)
                                    |> Table.withEnableColumnFilter False
                                ]
                    in
                    Table.getCanFilter cfg "firstName" |> Expect.equal False
            , test "should return false when column filters are disabled table-wide" <|
                \_ ->
                    Table.getCanFilter { personConfig | enableColumnFilters = False } "firstName"
                        |> Expect.equal False
            , test "should return false when all filtering is disabled" <|
                \_ ->
                    Table.getCanFilter { personConfig | enableFilters = False } "firstName"
                        |> Expect.equal False
            ]
        , describe "column filter state readers"
            [ test "should read filter presence, value, and index from the state" <|
                \_ ->
                    let
                        state : Table.State
                        state =
                            withFilters
                                [ { id = "lastName", value = Value.String "y" }
                                , { id = "firstName", value = Value.String "ali" }
                                ]
                    in
                    Expect.equal
                        { isFiltered = ( Table.getIsFiltered state "firstName", Table.getIsFiltered state "age" )
                        , value = ( Table.getFilterValue state "firstName", Table.getFilterValue state "age" )
                        , index =
                            ( Table.getFilterIndex state "lastName"
                            , Table.getFilterIndex state "firstName"
                            , Table.getFilterIndex state "age"
                            )
                        }
                        { isFiltered = ( True, False )
                        , value = ( Just (Value.String "ali"), Nothing )
                        , index = ( 0, 1, -1 )
                        }
            ]
        , describe "column_setFilterValue"
            [ test "should add a filter entry for an unfiltered column" <|
                \_ ->
                    setFilter personConfig "firstName" (Value.String "ali") (withFilters [])
                        |> Expect.equal [ { id = "firstName", value = Value.String "ali" } ]
            , test "should update an existing entry in place" <|
                \_ ->
                    setFilter personConfig
                        "firstName"
                        (Value.String "z")
                        (withFilters
                            [ { id = "firstName", value = Value.String "a" }
                            , { id = "lastName", value = Value.String "b" }
                            ]
                        )
                        |> Expect.equal
                            [ { id = "firstName", value = Value.String "z" }
                            , { id = "lastName", value = Value.String "b" }
                            ]
            , test "should resolve functional updaters against the previous filter value" <|
                \_ ->
                    -- Elm state transitions take a value, not an updater; the
                    -- caller reads the old value with `getFilterValue` and
                    -- writes the new one, which is what the updater did.
                    let
                        state : Table.State
                        state =
                            withFilters [ { id = "firstName", value = Value.String "a" } ]

                        updated : Value
                        updated =
                            Table.getFilterValue state "firstName"
                                |> Maybe.withDefault Value.Null
                                |> (\old -> Value.String (Value.toString old ++ "-updated"))
                    in
                    setFilter personConfig "firstName" updated state
                        |> Expect.equal [ { id = "firstName", value = Value.String "a-updated" } ]
            , test "should remove the filter when the new value should auto-remove" <|
                \_ ->
                    setFilter personConfig
                        "firstName"
                        (Value.String "")
                        (withFilters
                            [ { id = "firstName", value = Value.String "a" }
                            , { id = "lastName", value = Value.String "b" }
                            ]
                        )
                        |> Expect.equal [ { id = "lastName", value = Value.String "b" } ]
            , test "should keep an empty-string filter when a custom autoRemove allows it" <|
                \_ ->
                    let
                        emptyAware : FilterFn
                        emptyAware =
                            FilterFn.equals |> FilterFn.withAutoRemove Value.isNull

                        cfg : Table.Config Person
                        cfg =
                            Table.config
                                [ Table.column "firstName" (.firstName >> Value.String)
                                    |> Table.withFilterFn emptyAware
                                ]
                    in
                    setFilter cfg "firstName" (Value.String "") (withFilters [])
                        |> Expect.equal [ { id = "firstName", value = Value.String "" } ]
            ]
        , describe "table_setColumnFilters"
            [ test "should drop filters that should auto-remove for known columns" <|
                \_ ->
                    Table.setColumnFilters personConfig
                        (personModel personConfig)
                        [ { id = "firstName", value = Value.String "" }
                        , { id = "lastName", value = Value.String "b" }
                        ]
                        Table.initialState
                        |> .columnFilters
                        |> Expect.equal [ { id = "lastName", value = Value.String "b" } ]
            , test "should keep filters for unknown column ids" <|
                \_ ->
                    Table.setColumnFilters personConfig
                        (personModel personConfig)
                        [ { id = "not-a-column", value = Value.String "x" } ]
                        Table.initialState
                        |> .columnFilters
                        |> Expect.equal [ { id = "not-a-column", value = Value.String "x" } ]
            ]
        , describe "table_resetColumnFilters"
            [ test "should reset to an empty array when defaultState is true" <|
                \_ ->
                    Table.resetColumnFilters (withFilters [ { id = "firstName", value = Value.String "a" } ])
                        |> .columnFilters
                        |> Expect.equal []
            , test "should reset to the initial filters by default" <|
                \_ ->
                    -- There is no `initialState` here: the caller keeps the
                    -- filters it wants to restore and writes them back.
                    let
                        initialFilters : List Table.ColumnFilter
                        initialFilters =
                            [ { id = "firstName", value = Value.String "a" } ]
                    in
                    Table.setColumnFilters personConfig (personModel personConfig) initialFilters (withFilters [])
                        |> .columnFilters
                        |> Expect.equal initialFilters
            ]
        , describe "shouldAutoRemoveFilter"
            [ test "should remove undefined and empty-string values" <|
                \_ ->
                    Expect.equal
                        ( Table.shouldAutoRemoveFilter Nothing Value.Null
                        , Table.shouldAutoRemoveFilter Nothing (Value.String "")
                        )
                        ( True, True )
            , test "should keep falsy-but-meaningful values" <|
                \_ ->
                    -- `Value.Null` covers both `null` and `undefined`, so the
                    -- vitest `null` expectation (kept) collapses onto the
                    -- `undefined` one (removed) and is dropped here.
                    Expect.equal
                        ( Table.shouldAutoRemoveFilter Nothing (Value.Number 0)
                        , Table.shouldAutoRemoveFilter Nothing (Value.Bool False)
                        )
                        ( False, False )
            , test "should consult the filter fn's autoRemove hook" <|
                \_ ->
                    Expect.equal
                        ( Table.shouldAutoRemoveFilter (Just FilterFn.arrIncludes) (Value.List [])
                        , Table.shouldAutoRemoveFilter (Just FilterFn.arrIncludes) (Value.List [ Value.String "a" ])
                        )
                        ( True, False )
            , test "should treat a provided autoRemove as authoritative for defined values" <|
                \_ ->
                    let
                        custom : FilterFn
                        custom =
                            FilterFn.equals |> FilterFn.withAutoRemove Value.isNull
                    in
                    Expect.equal
                        { emptyString = Table.shouldAutoRemoveFilter (Just custom) (Value.String "")
                        , null = Table.shouldAutoRemoveFilter (Just custom) Value.Null
                        , text = Table.shouldAutoRemoveFilter (Just custom) (Value.String "x")
                        }
                        { emptyString = False, null = True, text = False }

            -- excluded: "should always remove undefined even when autoRemove
            --   would keep it". `undefined` is the one filter value TanStack
            --   drops before consulting `autoRemove`, and `Value.Null` stands
            --   for both `null` and `undefined`, so the distinction is gone.
            ]
        ]


nullableName : Maybe String -> Value
nullableName name =
    case name of
        Just s ->
            Value.String s

        Nothing ->
            Value.Null


setFilter : Table.Config Person -> String -> Value -> Table.State -> List Table.ColumnFilter
setFilter cfg columnId value state =
    Table.setColumnFilter cfg (personModel cfg) columnId value state
        |> .columnFilters
