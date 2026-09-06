module ColumnPinningTest exposing (suite)

{-| Ports `tests/unit/features/column-pinning/columnPinningFeature.utils.test.ts`.

The last `describe` re-homes the two cases of
`tests/unit/core/headers/coreHeadersFeature.utils.test.ts` that phase 2
excluded because they need column pinning.

Excluded cases are listed in `reports/phase-5.md`.

-}

import Dict
import Expect
import Fixtures exposing (Person)
import Table
import Table.Value as Value
import Test exposing (Test, describe, test)


cfg : Table.Config Person
cfg =
    Fixtures.config


state : Table.State
state =
    Table.initialState


pinning : List String -> List String -> Table.State
pinning left right =
    { state | columnPinning = { left = left, right = right } }


hidingIn : Table.State -> List String -> Table.State
hidingIn base hidden =
    { base | columnVisibility = Dict.fromList (List.map (\columnId -> ( columnId, False )) hidden) }


columnNamed : Table.Config Person -> String -> Table.Column Person
columnNamed config columnId =
    Table.findColumn config columnId
        |> Maybe.withDefault (Table.display "missing")


ids : List (Table.Column Person) -> List String
ids =
    List.map Table.columnId


leafIds : List String
leafIds =
    ids (Table.leafColumns cfg)


withFirstRow : (Table.Row Person -> Expect.Expectation) -> Expect.Expectation
withFirstRow fn =
    case Table.coreRowModelFromList cfg state (Fixtures.makeData [ 1 ]) |> .rows |> List.head of
        Just row ->
            fn row

        Nothing ->
            Expect.fail "the fixture row model is empty"


groupedConfig : Table.Config Person
groupedConfig =
    Table.config
        [ Table.group "identity"
            [ Table.column "firstName" (.firstName >> Value.String)
            , Table.column "age" (.age >> toFloat >> Value.Number)
            , Table.column "lastName" (.lastName >> Value.String)
            ]
        ]


groupIds : List (Table.HeaderGroup Person) -> List String
groupIds =
    List.map .id


headerIdAt : Int -> Int -> List (Table.HeaderGroup Person) -> Maybe String
headerIdAt groupIndex headerIndex groups =
    groups
        |> List.drop groupIndex
        |> List.head
        |> Maybe.andThen (\group -> group.headers |> List.drop headerIndex |> List.head)
        |> Maybe.map Table.headerId


headerColumnIdsAt : Int -> List (Table.HeaderGroup Person) -> List String
headerColumnIdsAt groupIndex groups =
    groups
        |> List.drop groupIndex
        |> List.head
        |> Maybe.map (.headers >> List.map Table.headerColumnId)
        |> Maybe.withDefault []



-- The re-homed phase 2 header cases use their own three column fixture.


type alias Item =
    { a : String
    , b : String
    , c : String
    }


itemConfig : Table.Config Item
itemConfig =
    Table.config
        [ Table.group "group"
            [ Table.column "a" (.a >> Value.String)
            , Table.column "b" (.b >> Value.String)
            ]
            |> Table.withHeader "Group"
        , Table.column "c" (.c >> Value.String)
        ]


suite : Test
suite =
    describe "columnPinningFeature.utils"
        [ describe "getDefaultColumnPinningState"
            [ test "should return default column pinning state" <|
                \_ ->
                    Expect.equal { left = [], right = [] } Table.initialState.columnPinning
            ]
        , describe "column_pin"
            [ test "should pin column to the start" <|
                \_ ->
                    Table.pinColumn Table.pinnedLeft (columnNamed cfg "id") state
                        |> .columnPinning
                        |> Expect.equal { left = [ "id" ], right = [] }
            , test "should pin column to the end" <|
                \_ ->
                    Table.pinColumn Table.pinnedRight (columnNamed cfg "id") state
                        |> .columnPinning
                        |> Expect.equal { left = [], right = [ "id" ] }
            , test "should unpin column when false is passed" <|
                \_ ->
                    Table.pinColumn Table.columnUnpinned (columnNamed cfg "id") (pinning [ "id" ] [])
                        |> .columnPinning
                        |> Expect.equal { left = [], right = [] }
            ]
        , describe "column_getCanPin"
            [ test "should return true when column pinning is enabled" <|
                \_ ->
                    Table.columnCanPin cfg (columnNamed cfg "id") |> Expect.equal True
            , test "should return false when column pinning is disabled globally" <|
                \_ ->
                    Table.columnCanPin { cfg | enableColumnPinning = False } (columnNamed cfg "id")
                        |> Expect.equal False
            , test "should return false when column pinning is disabled for specific column" <|
                \_ ->
                    let
                        config : Table.Config Person
                        config =
                            Table.config
                                [ Table.column "firstName" (.firstName >> Value.String)
                                    |> Table.withEnablePinning False
                                ]
                    in
                    Table.columnCanPin config (columnNamed config "firstName") |> Expect.equal False
            ]
        , describe "column_getIsPinned"
            [ test "should return start when column is pinned start" <|
                \_ ->
                    Table.columnIsPinned (pinning [ "firstName" ] []) (columnNamed cfg "firstName")
                        |> Expect.equal Table.pinnedLeft
            , test "should return end when column is pinned end" <|
                \_ ->
                    Table.columnIsPinned (pinning [] [ "firstName" ]) (columnNamed cfg "firstName")
                        |> Expect.equal Table.pinnedRight
            , test "should return false when column is not pinned" <|
                \_ ->
                    Table.columnIsPinned state (columnNamed cfg "firstName")
                        |> Expect.equal Table.columnUnpinned
            , test "should prefer start when column is pinned in both regions" <|
                \_ ->
                    Table.columnIsPinned (pinning [ "firstName" ] [ "firstName" ]) (columnNamed cfg "firstName")
                        |> Expect.equal Table.pinnedLeft
            , test "should report the pinned region of a group column from its leaf columns" <|
                \_ ->
                    Table.columnIsPinned (pinning [] [ "lastName" ]) (columnNamed groupedConfig "identity")
                        |> Expect.equal Table.pinnedRight
            ]
        , describe "table_setColumnPinning"
            [ test "should call onColumnPinningChange with updater" <|
                \_ ->
                    Table.setColumnPinning { left = [ "firstName" ], right = [] } state
                        |> .columnPinning
                        |> Expect.equal { left = [ "firstName" ], right = [] }
            ]
        , describe "table_resetColumnPinning"
            [ test "should reset to default state when defaultState is true" <|
                \_ ->
                    Table.resetColumnPinning (pinning [ "firstName" ] [])
                        |> .columnPinning
                        |> Expect.equal { left = [], right = [] }
            , test "should reset to initial state when defaultState is false" <|
                \_ ->
                    Table.setColumnPinning { left = [ "firstName" ], right = [] } state
                        |> .columnPinning
                        |> Expect.equal { left = [ "firstName" ], right = [] }
            ]
        , describe "table_getIsSomeColumnsPinned"
            [ test "should return true when columns are pinned start" <|
                \_ ->
                    Table.isSomeColumnsPinned (pinning [ "firstName" ] []) |> Expect.equal True
            , test "should return true when columns are pinned end" <|
                \_ ->
                    Table.isSomeColumnsPinned (pinning [] [ "firstName" ]) |> Expect.equal True
            , test "should return false when no columns are pinned" <|
                \_ ->
                    Table.isSomeColumnsPinned state |> Expect.equal False
            , test "should check specific position when position parameter is provided" <|
                \_ ->
                    Expect.all
                        [ \pinned -> Expect.equal True (Table.isSomeColumnsPinnedLeft pinned)
                        , \pinned -> Expect.equal False (Table.isSomeColumnsPinnedRight pinned)
                        ]
                        (pinning [ "firstName" ] [])
            ]
        , describe "column_getPinnedIndex"
            [ test "should return index of pinned column" <|
                \_ ->
                    Table.columnPinnedIndex (pinning [ "firstName", "lastName" ] []) (columnNamed cfg "lastName")
                        |> Expect.equal 1
            , test "should return 0 when column is not pinned" <|
                \_ ->
                    Table.columnPinnedIndex state (columnNamed cfg "firstName") |> Expect.equal 0
            ]
        , describe "row_getCenterVisibleCells"
            [ test "should return only unpinned visible cells" <|
                \_ ->
                    withFirstRow
                        (\row ->
                            Expect.all
                                [ \cells -> Expect.equal False (List.member "firstName" cells)
                                , \cells -> Expect.equal False (List.member "lastName" cells)
                                , \cells -> Expect.greaterThan 0 (List.length cells)
                                ]
                                (Table.centerVisibleCells cfg (pinning [ "firstName" ] [ "lastName" ]) row
                                    |> List.map .columnId
                                )
                        )
            , test "should return the shared visible cells array when nothing is pinned" <|
                \_ ->
                    withFirstRow
                        (\row ->
                            Expect.equal (Table.visibleCells cfg state row)
                                (Table.centerVisibleCells cfg state row)
                        )
            ]
        , describe "row_getStartVisibleCells"
            [ test "should return only start pinned cells" <|
                \_ ->
                    withFirstRow
                        (\row ->
                            Table.leftVisibleCells cfg (pinning [ "firstName" ] [ "lastName" ]) row
                                |> List.map .columnId
                                |> Expect.equal [ "firstName" ]
                        )
            , test "should return empty array when no columns are pinned start" <|
                \_ ->
                    withFirstRow
                        (\row -> Table.leftVisibleCells cfg state row |> Expect.equal [])
            ]
        , describe "row_getEndVisibleCells"
            [ test "should return only end pinned cells" <|
                \_ ->
                    withFirstRow
                        (\row ->
                            Table.rightVisibleCells cfg (pinning [ "firstName" ] [ "lastName" ]) row
                                |> List.map .columnId
                                |> Expect.equal [ "lastName" ]
                        )
            , test "should return empty array when no columns are pinned end" <|
                \_ ->
                    withFirstRow
                        (\row -> Table.rightVisibleCells cfg state row |> Expect.equal [])
            ]
        , describe "table_getStartHeaderGroups"
            [ test "should return header groups for start pinned columns" <|
                \_ ->
                    Table.leftHeaderGroups cfg (pinning [ "firstName" ] [])
                        |> headerColumnIdsAt 0
                        |> List.head
                        |> Expect.equal (Just "firstName")
            ]
        , describe "table_getEndHeaderGroups"
            [ test "should return header groups for end pinned columns" <|
                \_ ->
                    Table.rightHeaderGroups cfg (pinning [] [ "lastName" ])
                        |> headerColumnIdsAt 0
                        |> List.head
                        |> Expect.equal (Just "lastName")
            ]
        , describe "table_getCenterHeaderGroups"
            [ test "should return header groups for unpinned columns" <|
                \_ ->
                    Expect.all
                        [ \found -> Expect.equal False (List.member "firstName" found)
                        , \found -> Expect.equal False (List.member "lastName" found)
                        , \found -> Expect.greaterThan 0 (List.length found)
                        ]
                        (Table.centerHeaderGroups cfg (pinning [ "firstName" ] [ "lastName" ])
                            |> headerColumnIdsAt 0
                        )
            , test "should include all visible columns when nothing is pinned" <|
                \_ ->
                    Table.centerHeaderGroups cfg state
                        |> headerColumnIdsAt 0
                        |> Expect.equal (ids (Table.visibleLeafColumns cfg state))
            ]
        , describe "header group ids"
            [ test "should preserve depth and family prefixes for grouped columns" <|
                \_ ->
                    let
                        pinned : Table.State
                        pinned =
                            pinning [ "firstName" ] [ "lastName" ]

                        start : List (Table.HeaderGroup Person)
                        start =
                            Table.leftHeaderGroups groupedConfig pinned

                        center : List (Table.HeaderGroup Person)
                        center =
                            Table.centerHeaderGroups groupedConfig pinned

                        end : List (Table.HeaderGroup Person)
                        end =
                            Table.rightHeaderGroups groupedConfig pinned
                    in
                    Expect.all
                        [ \_ -> Expect.equal [ "start_0", "start_1" ] (groupIds start)
                        , \_ -> Expect.equal [ "center_0", "center_1" ] (groupIds center)
                        , \_ -> Expect.equal [ "end_0", "end_1" ] (groupIds end)
                        , \_ -> Expect.equal (Just "start_1_identity_firstName") (headerIdAt 0 0 start)
                        , \_ -> Expect.equal (Just "center_1_identity_age") (headerIdAt 0 0 center)
                        , \_ -> Expect.equal (Just "end_1_identity_lastName") (headerIdAt 0 0 end)
                        , \_ -> Expect.equal (Just "firstName") (headerIdAt 1 0 start)
                        , \_ -> Expect.equal (Just "age") (headerIdAt 1 0 center)
                        , \_ -> Expect.equal (Just "lastName") (headerIdAt 1 0 end)
                        ]
                        ()
            ]
        , describe "table_getStartLeafColumns"
            [ test "should return start pinned leaf columns" <|
                \_ ->
                    Table.leftLeafColumns cfg (pinning [ "firstName" ] [])
                        |> ids
                        |> Expect.equal [ "firstName" ]
            ]
        , describe "table_getEndLeafColumns"
            [ test "should return end pinned leaf columns" <|
                \_ ->
                    Table.rightLeafColumns cfg (pinning [] [ "lastName" ])
                        |> ids
                        |> Expect.equal [ "lastName" ]
            ]
        , describe "table_getCenterLeafColumns"
            [ test "should return unpinned leaf columns" <|
                \_ ->
                    Expect.all
                        [ \found -> Expect.equal False (List.member "firstName" found)
                        , \found -> Expect.equal False (List.member "lastName" found)
                        , \found -> Expect.greaterThan 0 (List.length found)
                        ]
                        (ids (Table.centerLeafColumns cfg (pinning [ "firstName" ] [ "lastName" ])))
            , test "should return the shared leaf columns array when nothing is pinned" <|
                \_ ->
                    Table.centerLeafColumns cfg state
                        |> ids
                        |> Expect.equal leafIds
            ]
        , describe "table_getPinnedLeafColumns"
            [ test "should return start pinned leaf columns when position is start" <|
                \_ ->
                    Table.pinnedLeafColumns cfg (pinning [ "firstName" ] []) Table.leftColumnsRegion
                        |> ids
                        |> Expect.equal [ "firstName" ]
            , test "should return end pinned leaf columns when position is end" <|
                \_ ->
                    Table.pinnedLeafColumns cfg (pinning [] [ "lastName" ]) Table.rightColumnsRegion
                        |> ids
                        |> Expect.equal [ "lastName" ]
            , test "should return center leaf columns when position is center" <|
                \_ ->
                    Expect.all
                        [ \found -> Expect.greaterThan 0 (List.length found)
                        , \found -> Expect.equal False (List.member "firstName" found)
                        , \found -> Expect.equal False (List.member "lastName" found)
                        ]
                        (ids (Table.pinnedLeafColumns cfg (pinning [ "firstName" ] [ "lastName" ]) Table.centerColumnsRegion))
            ]
        , describe "table_getPinnedVisibleLeafColumns"
            [ test "should return visible leaf columns for specified position" <|
                \_ ->
                    let
                        pinned : Table.State
                        pinned =
                            hidingIn (pinning [ "firstName" ] [ "lastName" ]) [ "age" ]
                    in
                    Expect.all
                        [ \_ ->
                            Table.pinnedVisibleLeafColumns cfg pinned Table.leftColumnsRegion
                                |> ids
                                |> List.head
                                |> Expect.equal (Just "firstName")
                        , \_ ->
                            Table.pinnedVisibleLeafColumns cfg pinned Table.rightColumnsRegion
                                |> ids
                                |> List.head
                                |> Expect.equal (Just "lastName")
                        , \_ ->
                            Table.pinnedVisibleLeafColumns cfg pinned Table.centerColumnsRegion
                                |> ids
                                |> List.member "age"
                                |> Expect.equal False
                        ]
                        ()
            , test "should return all visible leaf columns when no position specified" <|
                \_ ->
                    let
                        hidden : Table.State
                        hidden =
                            hidingIn state [ "age" ]
                    in
                    Expect.all
                        [ \found -> Expect.equal False (List.member "age" (ids found))
                        , \found ->
                            Expect.equal (List.length (Table.visibleLeafColumns cfg hidden)) (List.length found)
                        ]
                        (Table.pinnedVisibleLeafColumns cfg hidden Table.allColumnsRegion)
            ]
        , describe "column pinning table instance APIs"
            [ test "should expose pinned leaf column APIs on the table instance" <|
                \_ ->
                    let
                        pinned : Table.State
                        pinned =
                            hidingIn (pinning [ "firstName" ] [ "lastName" ]) [ "age" ]
                    in
                    Expect.all
                        [ \_ ->
                            Table.pinnedLeafColumns cfg pinned Table.leftColumnsRegion
                                |> ids
                                |> Expect.equal [ "firstName" ]
                        , \_ ->
                            Table.pinnedVisibleLeafColumns cfg pinned Table.centerColumnsRegion
                                |> ids
                                |> List.member "age"
                                |> Expect.equal False
                        ]
                        ()
            , test "should pass method arguments into memoized prototype API dependencies" <|
                \_ ->
                    Table.getColumnStart cfg (pinning [ "firstName" ] []) Table.leftColumnsRegion (columnNamed cfg "firstName")
                        |> Expect.within (Expect.Absolute 0.0001) 0
            , test "should update center visible columns when column order changes" <|
                \_ ->
                    let
                        reordered : Table.State
                        reordered =
                            Table.setColumnOrder
                                [ "lastName", "firstName", "id", "age", "visits", "progress", "status" ]
                                state
                    in
                    Expect.all
                        [ \_ ->
                            Table.centerVisibleLeafColumns cfg state
                                |> ids
                                |> Expect.equal [ "id", "firstName", "lastName", "age", "visits", "progress", "status" ]
                        , \_ ->
                            Table.getColumnStart cfg state Table.centerColumnsRegion (columnNamed cfg "lastName")
                                |> Expect.within (Expect.Absolute 0.0001) 300
                        , \_ ->
                            Table.centerVisibleLeafColumns cfg reordered
                                |> ids
                                |> Expect.equal [ "lastName", "firstName", "id", "age", "visits", "progress", "status" ]
                        , \_ ->
                            Table.getColumnStart cfg reordered Table.centerColumnsRegion (columnNamed cfg "lastName")
                                |> Expect.within (Expect.Absolute 0.0001) 0
                        ]
                        ()
            ]
        , describe "table_getFooterGroups"
            [ test "should return footer groups for start pinned columns" <|
                \_ ->
                    Table.leftFooterGroups cfg (pinning [ "firstName" ] [])
                        |> headerColumnIdsAt 0
                        |> List.head
                        |> Expect.equal (Just "firstName")
            , test "should return footer groups for end pinned columns" <|
                \_ ->
                    Table.rightFooterGroups cfg (pinning [] [ "lastName" ])
                        |> headerColumnIdsAt 0
                        |> List.head
                        |> Expect.equal (Just "lastName")
            , test "should return footer groups for center columns" <|
                \_ ->
                    Expect.all
                        [ \found -> Expect.equal False (List.member "firstName" found)
                        , \found -> Expect.equal False (List.member "lastName" found)
                        , \found -> Expect.greaterThan 0 (List.length found)
                        ]
                        (Table.centerFooterGroups cfg (pinning [ "firstName" ] [ "lastName" ])
                            |> headerColumnIdsAt 0
                        )
            ]
        , describe "table_getFlatHeaders"
            [ test "should return flat headers for start pinned columns" <|
                \_ ->
                    Table.leftFlatHeaders cfg (pinning [ "firstName" ] [])
                        |> List.map Table.headerColumnId
                        |> Expect.equal [ "firstName" ]
            , test "should return flat headers for end pinned columns" <|
                \_ ->
                    Table.rightFlatHeaders cfg (pinning [] [ "lastName" ])
                        |> List.map Table.headerColumnId
                        |> Expect.equal [ "lastName" ]
            , test "should return flat headers for center columns" <|
                \_ ->
                    Expect.all
                        [ \found -> Expect.equal False (List.member "firstName" found)
                        , \found -> Expect.equal False (List.member "lastName" found)
                        , \found -> Expect.greaterThan 0 (List.length found)
                        ]
                        (Table.centerFlatHeaders cfg (pinning [ "firstName" ] [ "lastName" ])
                            |> List.map Table.headerColumnId
                        )
            ]
        , describe "pinned leaf headers and visible leaf columns"
            [ test "table_getStartLeafHeaders should return headers for start pinned columns" <|
                \_ ->
                    Table.leftLeafHeaders cfg pinnedAndHidden
                        |> List.map Table.headerColumnId
                        |> Expect.equal [ "firstName" ]
            , test "table_getEndLeafHeaders should return headers for end pinned columns" <|
                \_ ->
                    Table.rightLeafHeaders cfg pinnedAndHidden
                        |> List.map Table.headerColumnId
                        |> Expect.equal [ "lastName" ]
            , test "table_getCenterLeafHeaders should return headers for unpinned columns" <|
                \_ ->
                    Expect.all
                        [ \found -> Expect.equal False (List.member "firstName" found)
                        , \found -> Expect.equal False (List.member "lastName" found)
                        , \found -> Expect.greaterThan 0 (List.length found)
                        ]
                        (Table.centerLeafHeaders cfg pinnedAndHidden |> List.map Table.headerColumnId)
            , test "table_getStartVisibleLeafColumns should return visible start pinned columns" <|
                \_ ->
                    Table.leftVisibleLeafColumns cfg pinnedAndHidden |> ids |> Expect.equal [ "firstName" ]
            , test "table_getEndVisibleLeafColumns should return visible end pinned columns" <|
                \_ ->
                    Table.rightVisibleLeafColumns cfg pinnedAndHidden |> ids |> Expect.equal [ "lastName" ]
            , test "table_getCenterVisibleLeafColumns should exclude pinned and hidden columns" <|
                \_ ->
                    Expect.all
                        [ \found -> Expect.equal False (List.member "firstName" found)
                        , \found -> Expect.equal False (List.member "lastName" found)
                        , \found -> Expect.equal False (List.member "age" found)
                        , \found -> Expect.greaterThan 0 (List.length found)
                        ]
                        (ids (Table.centerVisibleLeafColumns cfg pinnedAndHidden))
            ]
        , describe "table_getHeaderGroups (re-homed from unit/core/headers)"
            [ test "should order pinned columns first via the pin partitioning path" <|
                \_ ->
                    Table.headerGroups itemConfig { state | columnPinning = { left = [ "c" ], right = [] } }
                        |> List.drop 1
                        |> List.head
                        |> Maybe.map (.headers >> List.map Table.headerColumnId)
                        |> Expect.equal (Just [ "c", "a", "b" ])
            , test "should keep rowSpans consistent through the pin partitioning path" <|
                \_ ->
                    let
                        groups : List (Table.HeaderGroup Item)
                        groups =
                            Table.headerGroups itemConfig { state | columnPinning = { left = [ "c" ], right = [] } }

                        placeholder : Maybe (Table.Header Item)
                        placeholder =
                            groups
                                |> List.head
                                |> Maybe.andThen
                                    (\group ->
                                        group.headers
                                            |> List.filter (\header -> Table.headerColumnId header == "c")
                                            |> List.head
                                    )
                    in
                    Expect.all
                        [ \_ ->
                            Expect.equal (Just True) (Maybe.map Table.headerIsPlaceholder placeholder)
                        , \_ ->
                            Expect.equal (Just 2) (Maybe.map Table.headerRowSpan placeholder)
                        , \_ ->
                            groups
                                |> List.drop 1
                                |> List.head
                                |> Maybe.map
                                    (.headers
                                        >> List.map
                                            (\header ->
                                                ( Table.headerColumnId header
                                                , Table.headerIsPlaceholder header
                                                , Table.headerRowSpan header
                                                )
                                            )
                                    )
                                |> Expect.equal
                                    (Just
                                        [ ( "c", False, 0 )
                                        , ( "a", False, 1 )
                                        , ( "b", False, 1 )
                                        ]
                                    )
                        ]
                        ()
            ]
        ]


pinnedAndHidden : Table.State
pinnedAndHidden =
    hidingIn (pinning [ "firstName" ] [ "lastName" ]) [ "age" ]
