module SortingStateTest exposing (suite)

{-| Ports
`tests/unit/features/row-sorting/rowSortingFeature.utils.test.ts`.

Elm cannot compare two functions, so the cases that assert which built-in sort
fn was picked (`expect(...).toBe(sortFn_text)`) compare `sortFnLabel` instead,
which probes a `SortFn` with inputs only one built-in answers the same way to.

The `column_getToggleSortingHandler` cases are ported against
`Table.toggleSort`, since the handler is only a `canSort` guard plus a call to
it.

-}

import Expect
import Table
import Table.SortFn as SortFn exposing (SortFn)
import Table.Value as Value exposing (Value)
import Test exposing (Test, describe, test)
import Time



-- SORT FN IDENTIFICATION


{-| The name of a built-in sort fn, recovered from its behaviour.
-}
sortFnLabel : SortFn -> String
sortFnLabel fn =
    if SortFn.compare fn (Value.String "item2") (Value.String "item10") == LT then
        "alphanumeric"

    else if SortFn.compare fn (Value.String "B") (Value.String "a") == GT then
        "text"

    else if SortFn.compare fn Value.Null (Value.Bool False) == EQ then
        "datetime"

    else
        "basic"



-- FIXTURES


type alias Sample =
    { plainText : String
    , alphaNum : String
    , createdAt : Value
    , amount : Float
    }


sampleConfig : Table.Config Sample
sampleConfig =
    Table.config
        [ Table.column "plainText" (.plainText >> Value.String)
        , Table.column "alphaNum" (.alphaNum >> Value.String)
        , Table.column "createdAt" .createdAt
        , Table.column "amount" (.amount >> Value.Number)
        ]


sampleData : List Sample
sampleData =
    [ { plainText = "apple"
      , alphaNum = "item1"
      , createdAt = Value.Date (Time.millisToPosix 1704067200000)
      , amount = 1
      }
    , { plainText = "banana"
      , alphaNum = "item10"
      , createdAt = Value.Date (Time.millisToPosix 1706745600000)
      , amount = 2
      }
    ]


autoSortLabel : List Sample -> String -> String
autoSortLabel rows columnId =
    sortFnLabel (Table.getAutoSortFn sampleConfig (modelOf sampleConfig rows) columnId)


type alias Person =
    { firstName : Maybe String
    , lastName : String
    , age : Float
    }


named : String -> String -> Float -> Person
named firstName lastName age =
    { firstName = Just firstName, lastName = lastName, age = age }


people : List Person
people =
    [ named "amy" "zulu" 20
    , named "bob" "young" 40
    , named "alice" "xi" 30
    ]


firstNameValue : Person -> Value
firstNameValue row =
    case row.firstName of
        Just s ->
            Value.String s

        Nothing ->
            Value.Null


personColumns : List (Table.Column Person)
personColumns =
    [ Table.column "firstName" firstNameValue
    , Table.column "lastName" (.lastName >> Value.String)
    , Table.column "age" (.age >> Value.Number)

    -- display column with no accessor
    , Table.display "actions" |> Table.withHeader "Actions"
    ]


config : Table.Config Person
config =
    Table.config personColumns


modelOf : Table.Config row -> List row -> Table.RowModel row
modelOf cfg rows =
    Table.coreRowModelFromList cfg Table.initialState rows


model : Table.RowModel Person
model =
    modelOf config people


sortingState : List Table.SortColumn -> Table.State
sortingState sorting =
    let
        state : Table.State
        state =
            Table.initialState
    in
    { state | sorting = sorting }


toggle : Table.Config Person -> { desc : Maybe Bool, multi : Bool } -> String -> List Table.SortColumn -> List Table.SortColumn
toggle cfg options columnId sorting =
    Table.toggleSort cfg (modelOf cfg people) columnId options (sortingState sorting)
        |> .sorting


plain : { desc : Maybe Bool, multi : Bool }
plain =
    { desc = Nothing, multi = False }



-- SUITE


suite : Test
suite =
    describe "rowSortingFeature.utils"
        [ describe "column_getAutoSortFn"
            [ test "selects datetime for Date values" <|
                \_ -> autoSortLabel sampleData "createdAt" |> Expect.equal "datetime"
            , test "selects alphanumeric for strings mixing text and numbers" <|
                \_ -> autoSortLabel sampleData "alphaNum" |> Expect.equal "alphanumeric"
            , test "selects text for plain strings" <|
                \_ -> autoSortLabel sampleData "plainText" |> Expect.equal "text"
            , test "falls back to basic for non-string, non-date values" <|
                \_ -> autoSortLabel sampleData "amount" |> Expect.equal "basic"
            , test "falls back to basic when no rows exist" <|
                \_ -> autoSortLabel [] "plainText" |> Expect.equal "basic"

            -- excluded: "falls back to text when alphanumeric is not
            --   registered". Sort fns are values here, not registry names, so
            --   the automatic choice can never be missing.
            ]
        , describe "getDefaultSortingState"
            [ test "should return an empty array and a new instance each time" <|
                \_ ->
                    -- The second half of the vitest case asserts that two calls
                    -- return different objects; Elm values are immutable.
                    Table.initialState.sorting |> Expect.equal []
            ]
        , describe "table_setSorting"
            [ test "should route the updater through onSortingChange" <|
                \_ ->
                    Table.setSorting [ { id = "age", desc = True } ] Table.initialState
                        |> .sorting
                        |> Expect.equal [ { id = "age", desc = True } ]
            ]
        , describe "table_resetSorting"
            [ test "should reset to an empty array when defaultState is true" <|
                \_ ->
                    Table.resetSorting (sortingState [ { id = "age", desc = True } ])
                        |> .sorting
                        |> Expect.equal []
            , test "should reset to the initial state by default" <|
                \_ ->
                    -- There is no `initialState` here: the caller keeps the
                    -- sorting it wants to restore and writes it back.
                    let
                        initialSorting : List Table.SortColumn
                        initialSorting =
                            [ { id = "age", desc = True } ]
                    in
                    Table.setSorting initialSorting (sortingState [])
                        |> .sorting
                        |> Expect.equal initialSorting
            ]
        , describe "column_getIsSorted"
            [ test "should return false when the column is not sorted" <|
                \_ ->
                    Table.getIsSorted Table.initialState "firstName" |> Expect.equal Nothing
            , test "should return the sort direction when sorted" <|
                \_ ->
                    let
                        state : Table.State
                        state =
                            sortingState
                                [ { id = "firstName", desc = False }
                                , { id = "age", desc = True }
                                ]
                    in
                    Expect.equal
                        ( Table.getIsSorted state "firstName", Table.getIsSorted state "age" )
                        ( Just Table.sortAsc, Just Table.sortDesc )
            ]
        , describe "column_getSortIndex"
            [ test "should return the position in the sorting state" <|
                \_ ->
                    let
                        state : Table.State
                        state =
                            sortingState
                                [ { id = "age", desc = True }
                                , { id = "firstName", desc = False }
                                ]
                    in
                    Expect.equal
                        ( Table.getSortIndex state "age"
                        , Table.getSortIndex state "firstName"
                        , Table.getSortIndex state "lastName"
                        )
                        ( 0, 1, -1 )
            ]
        , describe "column_getCanSort"
            [ test "should return true for accessor columns by default" <|
                \_ -> Table.getCanSort config "firstName" |> Expect.equal True
            , test "should return false for display columns without an accessor" <|
                \_ -> Table.getCanSort config "actions" |> Expect.equal False
            , test "should return false when sorting is disabled globally" <|
                \_ -> Table.getCanSort { config | enableSorting = False } "firstName" |> Expect.equal False
            , test "should return false when sorting is disabled for the column" <|
                \_ ->
                    let
                        cfg : Table.Config Person
                        cfg =
                            Table.config
                                [ Table.column "firstName" firstNameValue |> Table.withEnableSorting False ]
                    in
                    Table.getCanSort cfg "firstName" |> Expect.equal False
            ]
        , describe "column_getCanMultiSort"
            [ test "should return true for accessor columns by default" <|
                \_ -> Table.getCanMultiSort config "firstName" |> Expect.equal True
            , test "should respect the table-level enableMultiSort option" <|
                \_ ->
                    Table.getCanMultiSort { config | enableMultiSort = False } "firstName"
                        |> Expect.equal False
            , test "should let the columnDef win over the table option" <|
                \_ ->
                    let
                        cfg : Table.Config Person
                        cfg =
                            Table.config
                                [ Table.column "firstName" firstNameValue |> Table.withEnableMultiSort True ]
                    in
                    Table.getCanMultiSort { cfg | enableMultiSort = False } "firstName"
                        |> Expect.equal True
            ]
        , describe "column_getAutoSortDir"
            [ test "should return asc for string columns" <|
                \_ -> Table.getAutoSortDir config model "firstName" |> Expect.equal Table.sortAsc
            , test "should return desc for non-string columns" <|
                \_ -> Table.getAutoSortDir config model "age" |> Expect.equal Table.sortDesc
            , test "should return desc when there are no rows" <|
                \_ ->
                    Table.getAutoSortDir config (modelOf config []) "firstName"
                        |> Expect.equal Table.sortDesc
            , test "should skip leading nullish values when inferring the direction" <|
                \_ ->
                    Table.getAutoSortDir config (modelOf config nullishLeadingPeople) "firstName"
                        |> Expect.equal Table.sortAsc
            , test "should return desc when all sampled values are nullish" <|
                \_ ->
                    Table.getAutoSortDir config (modelOf config allNullishPeople) "firstName"
                        |> Expect.equal Table.sortDesc
            ]
        , describe "column_getFirstSortDir"
            [ test "should derive from the auto sort direction by default" <|
                \_ ->
                    Expect.equal
                        ( Table.getFirstSortDir config model "firstName"
                        , Table.getFirstSortDir config model "age"
                        )
                        ( Table.sortAsc, Table.sortDesc )
            , test "should respect the table-level sortDescFirst option" <|
                \_ ->
                    Table.getFirstSortDir { config | sortDescFirst = Just True } model "firstName"
                        |> Expect.equal Table.sortDesc
            , test "should let columnDef.sortDescFirst win over the table option" <|
                \_ ->
                    let
                        cfg : Table.Config Person
                        cfg =
                            Table.config
                                [ Table.column "firstName" firstNameValue |> Table.withSortDescFirst False ]
                    in
                    Table.getFirstSortDir { cfg | sortDescFirst = Just True } (modelOf cfg people) "firstName"
                        |> Expect.equal Table.sortAsc
            ]
        , describe "column_getSortFn"
            [ test "should return a function-valued sortFn directly" <|
                \_ ->
                    -- `withSortFn` is this port's "function-valued sortFn": it
                    -- wins over the automatic choice, which would be `text`.
                    let
                        cfg : Table.Config Person
                        cfg =
                            Table.config
                                [ Table.column "firstName" firstNameValue |> Table.withSortFn SortFn.basic ]
                    in
                    sortFnLabel (Table.getSortFn cfg (modelOf cfg people) "firstName")
                        |> Expect.equal "basic"
            , test "should delegate to the auto sort fn for \"auto\"" <|
                \_ ->
                    sortFnLabel (Table.getSortFn config model "firstName") |> Expect.equal "text"
            , test "should look up registered sort fn names" <|
                \_ ->
                    -- Sort fns are values here, not registry names.
                    let
                        cfg : Table.Config Person
                        cfg =
                            Table.config
                                [ Table.column "firstName" firstNameValue |> Table.withSortFn SortFn.datetime ]
                    in
                    sortFnLabel (Table.getSortFn cfg (modelOf cfg people) "firstName")
                        |> Expect.equal "datetime"

            -- excluded: "should fall back to basic for unknown sort fn names".
            --   `Column.sortFn` is a `Maybe SortFn`, not a registry name.
            ]
        , describe "column_getNextSortingOrder"
            [ test "should return the first sort direction when unsorted" <|
                \_ ->
                    Expect.equal
                        ( nextOrder config [] False "firstName", nextOrder config [] False "age" )
                        ( Just Table.sortAsc, Just Table.sortDesc )
            , test "should flip direction after the first sort direction" <|
                \_ ->
                    nextOrder config [ { id = "firstName", desc = False } ] False "firstName"
                        |> Expect.equal (Just Table.sortDesc)
            , test "should return false (remove) after the full cycle" <|
                \_ ->
                    nextOrder config [ { id = "firstName", desc = True } ] False "firstName"
                        |> Expect.equal Nothing
            , test "should keep flipping when sorting removal is disabled" <|
                \_ ->
                    nextOrder { config | enableSortingRemoval = False }
                        [ { id = "firstName", desc = True } ]
                        False
                        "firstName"
                        |> Expect.equal (Just Table.sortAsc)
            , test "should not remove in multi mode when enableMultiRemove is false" <|
                \_ ->
                    nextOrder { config | enableMultiRemove = False }
                        [ { id = "firstName", desc = True } ]
                        True
                        "firstName"
                        |> Expect.equal (Just Table.sortAsc)
            ]
        , describe "column_toggleSorting"
            [ test "should sort by the first direction from an unsorted state" <|
                \_ ->
                    toggle config plain "firstName" []
                        |> Expect.equal [ { id = "firstName", desc = False } ]
            , test "should flip the direction when already sorted by the first direction" <|
                \_ ->
                    toggle config plain "firstName" [ { id = "firstName", desc = False } ]
                        |> Expect.equal [ { id = "firstName", desc = True } ]
            , test "should remove the sort at the end of the cycle" <|
                \_ ->
                    toggle config plain "firstName" [ { id = "firstName", desc = True } ]
                        |> Expect.equal []
            , test "should apply an explicit desc value without cycling" <|
                \_ ->
                    toggle config { desc = Just True, multi = False } "firstName" []
                        |> Expect.equal [ { id = "firstName", desc = True } ]
            , test "should replace the existing sort in single-sort mode" <|
                \_ ->
                    toggle config plain "firstName" [ { id = "age", desc = True } ]
                        |> Expect.equal [ { id = "firstName", desc = False } ]
            , test "should discard other sorts when toggling the last column in single-sort mode" <|
                \_ ->
                    toggle config
                        plain
                        "firstName"
                        [ { id = "age", desc = True }, { id = "firstName", desc = False } ]
                        |> Expect.equal [ { id = "firstName", desc = True } ]
            , test "should append to the sorting state in multi mode" <|
                \_ ->
                    toggle config
                        { desc = Nothing, multi = True }
                        "firstName"
                        [ { id = "age", desc = True } ]
                        |> Expect.equal
                            [ { id = "age", desc = True }, { id = "firstName", desc = False } ]
            , test "should flip instead of removing in multi mode when enableMultiRemove is false" <|
                \_ ->
                    toggle { config | enableMultiRemove = False }
                        { desc = Nothing, multi = True }
                        "firstName"
                        [ { id = "firstName", desc = True } ]
                        |> Expect.equal [ { id = "firstName", desc = False } ]
            , test "should remove at the end of the cycle in multi mode by default" <|
                \_ ->
                    toggle config
                        { desc = Nothing, multi = True }
                        "firstName"
                        [ { id = "age", desc = True }, { id = "firstName", desc = True } ]
                        |> Expect.equal [ { id = "age", desc = True } ]
            , test "should ignore enableMultiRemove when the column cannot multi-sort" <|
                \_ ->
                    -- Falls back to single-sort semantics, where
                    -- enableSortingRemoval governs.
                    toggle { config | enableMultiRemove = False, enableMultiSort = False }
                        { desc = Nothing, multi = True }
                        "firstName"
                        [ { id = "firstName", desc = True } ]
                        |> Expect.equal []
            , test "should keep only the latest maxMultiSortColCount columns" <|
                \_ ->
                    toggle { config | maxMultiSortColCount = 2 }
                        { desc = Nothing, multi = True }
                        "firstName"
                        [ { id = "age", desc = True }, { id = "lastName", desc = False } ]
                        |> Expect.equal
                            [ { id = "lastName", desc = False }, { id = "firstName", desc = False } ]
            ]
        , describe "column_clearSorting"
            [ test "should remove only this column from the sorting state" <|
                \_ ->
                    Table.clearSorting "firstName"
                        (sortingState
                            [ { id = "age", desc = True }, { id = "firstName", desc = False } ]
                        )
                        |> .sorting
                        |> Expect.equal [ { id = "age", desc = True } ]
            ]
        , describe "column_getToggleSortingHandler"
            [ test "should toggle sorting" <|
                \_ ->
                    handle config { desc = Nothing, multi = False } "firstName" []
                        |> Expect.equal [ { id = "firstName", desc = False } ]
            , test "should be a no-op when the column cannot sort" <|
                \_ ->
                    handle { config | enableSorting = False } { desc = Nothing, multi = False } "firstName" []
                        |> Expect.equal []

            -- excluded: "should consult isMultiSortEvent to decide on multi
            --   sorting". `isMultiSortEvent` inspects a DOM event; `multi` is a
            --   plain argument of `Table.toggleSort` here.
            ]
        ]


nullishLeadingPeople : List Person
nullishLeadingPeople =
    [ { firstName = Nothing, lastName = "young", age = 40 }
    , { firstName = Nothing, lastName = "xi", age = 30 }
    , named "amy" "zulu" 20
    ]


allNullishPeople : List Person
allNullishPeople =
    [ { firstName = Nothing, lastName = "young", age = 40 }
    , { firstName = Nothing, lastName = "xi", age = 30 }
    ]


nextOrder : Table.Config Person -> List Table.SortColumn -> Bool -> String -> Maybe Table.SortDir
nextOrder cfg sorting multi columnId =
    Table.getNextSortingOrder cfg (modelOf cfg people) (sortingState sorting) columnId multi


{-| `column_getToggleSortingHandler`: the handler is a `getCanSort` guard in
front of `toggleSort`.
-}
handle : Table.Config Person -> { desc : Maybe Bool, multi : Bool } -> String -> List Table.SortColumn -> List Table.SortColumn
handle cfg options columnId sorting =
    if Table.getCanSort cfg columnId then
        toggle cfg options columnId sorting

    else
        sorting
