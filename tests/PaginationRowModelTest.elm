module PaginationRowModelTest exposing (suite)

{-| Ports
`tests/implementation/features/row-pagination/createPaginatedRowModel.test.ts`.

`Table.paginatedRowModel` takes the pre-pagination row model, which in the
standard pipeline is the expanded one. The expanded row model is phase 4's, so
the cases that need expanded rows ahead of pagination build that row list here
with `expandInto`, which is the `expandRows` of
`row-expanding/createExpandedRowModel.ts`.

-}

import Expect
import Set exposing (Set)
import Table
import Table.Value as Value
import Test exposing (Test, describe, test)



-- FIXTURE


type Person
    = Person String (List Person)


personName : Person -> String
personName (Person name _) =
    name


personSubRows : Person -> List Person
personSubRows (Person _ subs) =
    subs


config : Table.Config Person
config =
    Table.config [ Table.column "firstName" (personName >> Value.String) ]
        |> Table.withSubRows personSubRows


flatData : Int -> List Person
flatData count =
    List.range 0 (count - 1)
        |> List.map (\i -> Person ("person-" ++ String.fromInt i) [])


{-| 3 parents, each with 2 children.
-}
nestedData : List Person
nestedData =
    List.range 0 2
        |> List.map
            (\i ->
                Person ("parent-" ++ String.fromInt i)
                    (List.range 0 1
                        |> List.map
                            (\j ->
                                Person
                                    ("child-" ++ String.fromInt i ++ "." ++ String.fromInt j)
                                    []
                            )
                    )
            )


type alias Options =
    { data : List Person
    , pageIndex : Int
    , pageSize : Int
    , expanded : List String
    , paginateExpandedRows : Bool
    , manualPagination : Bool
    }


defaults : Options
defaults =
    { data = flatData 5
    , pageIndex = 0
    , pageSize = 2
    , expanded = []
    , paginateExpandedRows = True
    , manualPagination = False
    }


configOf : Options -> Table.Config Person
configOf options =
    { config
        | paginateExpandedRows = options.paginateExpandedRows
        , manualPagination = options.manualPagination
    }


stateOf : Options -> Table.State
stateOf options =
    let
        state : Table.State
        state =
            Table.initialState
    in
    { state
        | pagination = { pageIndex = options.pageIndex, pageSize = options.pageSize }
        , expanded = Table.expandedIds (Set.fromList options.expanded)
    }


{-| The pre-pagination row model. With `paginateExpandedRows = True` the
expanded row model splices expanded sub-rows into the row list, which is what
`expandInto` does here.
-}
preModel : Options -> Table.RowModel Person
preModel options =
    let
        core : Table.RowModel Person
        core =
            Table.coreRowModelFromList (configOf options) (stateOf options) options.data
    in
    if options.paginateExpandedRows then
        { core | rows = expandInto (Set.fromList options.expanded) core.rows }

    else
        core


expandInto : Set String -> List (Table.Row Person) -> List (Table.Row Person)
expandInto ids rows =
    List.concatMap
        (\row ->
            if not (List.isEmpty (Table.rowSubRows row)) && Set.member (Table.rowId row) ids then
                row :: expandInto ids (Table.rowSubRows row)

            else
                [ row ]
        )
        rows


paginated : Options -> Table.RowModel Person
paginated options =
    Table.paginatedRowModel (configOf options) (stateOf options) (preModel options)


pageIds : Options -> List String
pageIds options =
    List.map Table.rowId (paginated options).rows


flatIds : Options -> List String
flatIds options =
    List.map Table.rowId (paginated options).flatRows



-- SUITE


suite : Test
suite =
    describe "createPaginatedRowModel"
        [ describe "slice math"
            [ test "should return the first page for pageIndex 0" <|
                \_ -> pageIds defaults |> Expect.equal [ "0", "1" ]
            , test "should return a last partial page" <|
                \_ -> pageIds { defaults | pageIndex = 2 } |> Expect.equal [ "4" ]
            , test "should return full pages at an exact page boundary (rows % pageSize === 0)" <|
                \_ ->
                    pageIds { defaults | data = flatData 4, pageIndex = 1 }
                        |> Expect.equal [ "2", "3" ]
            , test "should return no rows for an out-of-range pageIndex" <|
                \_ -> pageIds { defaults | pageIndex = 5 } |> Expect.equal []
            , test "should return all rows when pageSize is larger than the dataset" <|
                \_ ->
                    pageIds { defaults | pageSize = 10 }
                        |> Expect.equal [ "0", "1", "2", "3", "4" ]
            , test "should return all rows when pageSize is Infinity" <|
                \_ ->
                    -- Elm has no `Infinity` for `Int`;
                    -- `Table.unlimitedPageSize` is the stand-in.
                    pageIds { defaults | pageSize = Table.unlimitedPageSize }
                        |> Expect.equal [ "0", "1", "2", "3", "4" ]
            ]
        , describe "empty pre-paginated model"
            [ test "should return the pre-model identity when there is no data" <|
                \_ ->
                    let
                        options : Options
                        options =
                            { defaults | data = [] }
                    in
                    Expect.equal ( paginated options == preModel options, (paginated options).rows )
                        ( True, [] )
            ]
        , describe "paginateExpandedRows: true (default)"
            [ test "should let expanded children consume page slots and spill across page boundaries" <|
                \_ ->
                    let
                        options : Options
                        options =
                            { defaults | data = nestedData, pageSize = 3, expanded = [ "0" ] }
                    in
                    -- Pre-paginated expanded order: 0, 0.0, 0.1, 1, 2
                    Expect.equal
                        ( pageIds options, pageIds { options | pageIndex = 1 } )
                        ( [ "0", "0.0", "0.1" ], [ "1", "2" ] )
            ]
        , describe "paginateExpandedRows: false"
            [ test "should slice unexpanded rows then append expanded children without consuming page slots" <|
                \_ ->
                    let
                        options : Options
                        options =
                            { defaults
                                | data = nestedData
                                , expanded = [ "0", "1" ]
                                , paginateExpandedRows = False
                            }
                    in
                    Expect.equal
                        ( pageIds options, pageIds { options | pageIndex = 1 } )
                        ( [ "0", "0.0", "0.1", "1", "1.0", "1.1" ], [ "2" ] )
            , test "should append expanded children when pageSize is Infinity" <|
                \_ ->
                    pageIds
                        { defaults
                            | data = nestedData
                            , pageSize = Table.unlimitedPageSize
                            , expanded = [ "0" ]
                            , paginateExpandedRows = False
                        }
                        |> Expect.equal [ "0", "0.0", "0.1", "1", "2" ]
            ]
        , describe "flatRows rebuild"
            [ test "should rebuild flatRows from the page rows including all subRows regardless of expanded state" <|
                \_ ->
                    flatIds { defaults | data = nestedData }
                        |> Expect.equal [ "0", "0.0", "0.1", "1", "1.0", "1.1" ]
            , test "should not duplicate expanded sub-rows in flatRows (default paginateExpandedRows)" <|
                \_ ->
                    flatIds { defaults | data = nestedData, pageSize = 3, expanded = [ "0" ] }
                        |> Expect.equal [ "0", "0.0", "0.1" ]
            , test "should not duplicate expanded sub-rows in flatRows with paginateExpandedRows: false" <|
                \_ ->
                    flatIds
                        { defaults
                            | data = nestedData
                            , expanded = [ "0" ]
                            , paginateExpandedRows = False
                        }
                        |> Expect.equal [ "0", "0.0", "0.1", "1", "1.0", "1.1" ]
            ]
        , describe "rowsById passthrough"
            [ test "should pass through the whole pre-model rowsById map, not just the page" <|
                \_ ->
                    let
                        options : Options
                        options =
                            { defaults | data = nestedData }
                    in
                    Expect.equal
                        ( (paginated options).rowsById == (preModel options).rowsById
                        , Table.findRow (paginated options) "2" /= Nothing
                        )
                        ( True, True )
            ]
        , describe "manualPagination"
            [ test "should return the pre-model identity when manualPagination is true" <|
                \_ ->
                    let
                        options : Options
                        options =
                            { defaults | pageIndex = 1, manualPagination = True }

                        result : Table.RowModel Person
                        result =
                            Table.paginatedRowModel (configOf options) (stateOf options) (preModel options)
                    in
                    Expect.equal
                        ( result == preModel options, List.map Table.rowId result.rows )
                        ( True, [ "0", "1", "2", "3", "4" ] )

            -- excluded: "should include expanded children when expanded rows
            --   bypass manual pagination". The assertion is on the full row
            --   model, whose expanding stage lands in phase 4: with
            --   `manualPagination` on, `createExpandedRowModel` is the stage
            --   that splices the expanded children in.
            ]
        ]
