module GlobalFilterTest exposing (suite)

{-| Ports
`tests/unit/features/global-filtering/globalFilteringFeature.utils.test.ts`.

The cases that assert which filter fn was resolved use
`FilteringStateTest.filterFnLabel`, because Elm cannot compare two functions.

-}

import Expect
import FilteringStateTest exposing (filterFnLabel)
import Table
import Table.FilterFn as FilterFn
import Table.Value as Value exposing (Value)
import Test exposing (Test, describe, test)


type alias Sample =
    { firstName : String
    , age : Int
    , active : Bool
    }


data : List Sample
data =
    [ { firstName = "alice", age = 30, active = True }
    , { firstName = "bob", age = 40, active = False }
    , { firstName = "amy", age = 20, active = True }
    ]


columns : List (Table.Column Sample)
columns =
    [ Table.column "firstName" (.firstName >> Value.String)
    , Table.column "age" (.age >> toFloat >> Value.Number)
    , Table.column "active" (.active >> Value.Bool)

    -- display column with no accessor
    , Table.display "actions" |> Table.withHeader "Actions"
    ]


config : Table.Config Sample
config =
    Table.config columns


coreModel : Table.Config Sample -> Table.RowModel Sample
coreModel cfg =
    Table.coreRowModelFromList cfg Table.initialState data


canGlobalFilter : Table.Config Sample -> String -> Bool
canGlobalFilter cfg columnId =
    Table.getCanGlobalFilter cfg (coreModel cfg) columnId


withGlobal : Value -> Table.State
withGlobal value =
    let
        state : Table.State
        state =
            Table.initialState
    in
    { state | globalFilter = value }


filteredNames : Table.Config Sample -> Table.State -> List String
filteredNames cfg state =
    Table.coreRowModelFromList cfg state data
        |> Table.filteredRowModel cfg state
        |> .rows
        |> List.map (Table.rowOriginal >> .firstName)


suite : Test
suite =
    describe "globalFilteringFeature.utils"
        [ describe "column_getCanGlobalFilter"
            [ test "should return true for string and number columns by default" <|
                \_ ->
                    Expect.equal ( canGlobalFilter config "firstName", canGlobalFilter config "age" )
                        ( True, True )
            , test "should return false for non-string, non-number values via the default predicate" <|
                \_ ->
                    canGlobalFilter config "active" |> Expect.equal False
            , test "should allow non-string, non-number values to explicitly opt in" <|
                \_ ->
                    let
                        cfg : Table.Config Sample
                        cfg =
                            Table.config
                                [ Table.column "active" (.active >> Value.Bool)
                                    |> Table.withEnableGlobalFilter True
                                ]
                    in
                    canGlobalFilter cfg "active" |> Expect.equal True
            , test "should return false for display columns without an accessor" <|
                \_ ->
                    canGlobalFilter config "actions" |> Expect.equal False
            , test "should return false when global filtering is disabled for the column" <|
                \_ ->
                    let
                        cfg : Table.Config Sample
                        cfg =
                            Table.config
                                [ Table.column "firstName" (.firstName >> Value.String)
                                    |> Table.withEnableGlobalFilter False
                                ]
                    in
                    canGlobalFilter cfg "firstName" |> Expect.equal False
            , test "should return false when global filtering is disabled table-wide" <|
                \_ ->
                    canGlobalFilter { config | enableGlobalFilter = False } "firstName"
                        |> Expect.equal False
            , test "should return false when all filtering is disabled" <|
                \_ ->
                    canGlobalFilter { config | enableFilters = False } "firstName"
                        |> Expect.equal False
            , test "should respect a custom getColumnCanGlobalFilter predicate" <|
                \_ ->
                    let
                        cfg : Table.Config Sample
                        cfg =
                            { config
                                | getColumnCanGlobalFilter =
                                    Just (\col -> Table.columnId col == "age")
                            }
                    in
                    Expect.equal ( canGlobalFilter cfg "firstName", canGlobalFilter cfg "age" )
                        ( False, True )
            , test "should let a custom predicate reject an explicit column opt-in" <|
                \_ ->
                    let
                        cfg : Table.Config Sample
                        cfg =
                            { base | getColumnCanGlobalFilter = Just (always False) }

                        base : Table.Config Sample
                        base =
                            Table.config
                                [ Table.column "active" (.active >> Value.Bool)
                                    |> Table.withEnableGlobalFilter True
                                ]
                    in
                    canGlobalFilter cfg "active" |> Expect.equal False
            ]
        , describe "table_getGlobalAutoFilterFn"
            [ test "should return the includesString filter fn" <|
                \_ ->
                    filterFnLabel Table.globalAutoFilterFn |> Expect.equal "includesString"
            ]
        , describe "table_getGlobalFilterFn"
            [ test "should resolve the default \"auto\" option to includesString" <|
                \_ ->
                    filterFnLabel (Table.getGlobalFilterFn config) |> Expect.equal "includesString"
            , test "should return a function-valued globalFilterFn directly" <|
                \_ ->
                    filterFnLabel (Table.getGlobalFilterFn { config | globalFilterFn = Just FilterFn.equals })
                        |> Expect.equal "equals"
            , test "should look up registered filter fn names" <|
                \_ ->
                    -- Filter fns are values here, not registry names.
                    filterFnLabel (Table.getGlobalFilterFn { config | globalFilterFn = Just FilterFn.weakEquals })
                        |> Expect.equal "weakEquals"

            -- excluded: "should return undefined for unknown filter fn names"
            --   `Config.globalFilterFn` is a `Maybe FilterFn`, so there is no
            --   unregistered name to fail to resolve.
            ]
        , describe "table_setGlobalFilter"
            [ test "should route the updater through onGlobalFilterChange" <|
                \_ ->
                    Table.setGlobalFilter (Value.String "search text") Table.initialState
                        |> .globalFilter
                        |> Expect.equal (Value.String "search text")
            ]
        , describe "table_resetGlobalFilter"
            [ test "should reset to undefined when defaultState is true" <|
                \_ ->
                    Table.resetGlobalFilter (withGlobal (Value.String "initial"))
                        |> .globalFilter
                        |> Expect.equal Value.Null
            , -- adapted: there is no `table.initialState`, so restoring a
              -- remembered initial filter is `setGlobalFilter` (the phase 3
              -- convention for every "reset to the initial X" case).
              test "should reset to the initial global filter by default" <|
                \_ ->
                    Table.setGlobalFilter (Value.String "initial") (withGlobal (Value.String "other"))
                        |> .globalFilter
                        |> Expect.equal (Value.String "initial")
            ]
        , describe "global filtering through the filtered row model"
            [ test "should filter rows across globally filterable columns" <|
                \_ ->
                    filteredNames config (withGlobal (Value.String "ali"))
                        |> Expect.equal [ "alice" ]
            , test "should update the filtered rows when the global filter changes" <|
                \_ ->
                    Expect.equal
                        { none = List.length (filteredNames config Table.initialState)
                        , some = filteredNames config (withGlobal (Value.String "a"))
                        , reset =
                            List.length
                                (filteredNames config (Table.resetGlobalFilter (withGlobal (Value.String "a"))))
                        }
                        { none = 3, some = [ "alice", "amy" ], reset = 3 }
            , test "should match number columns as strings" <|
                \_ ->
                    filteredNames config (withGlobal (Value.String "40"))
                        |> Expect.equal [ "bob" ]
            ]
        ]
