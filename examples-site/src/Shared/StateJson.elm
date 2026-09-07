module Shared.StateJson exposing (dump, encode, encodeValue)

{-| `JSON.stringify(table.state, null, 2)`, the state dump every TanStack
example prints under its table, for `Table.State`.

@docs dump, encode, encodeValue

-}

import Dict exposing (Dict)
import Json.Encode as Encode
import Set exposing (Set)
import Table
import Table.Value as Value exposing (Value)
import Time


{-| The whole state as pretty-printed JSON.
-}
dump : Table.State -> String
dump state =
    Encode.encode 2 (encode state)


{-| The whole state as a JSON value.
-}
encode : Table.State -> Encode.Value
encode state =
    Encode.object
        [ ( "sorting"
          , Encode.list
                (\s ->
                    Encode.object
                        [ ( "id", Encode.string s.id )
                        , ( "desc", Encode.bool s.desc )
                        ]
                )
                state.sorting
          )
        , ( "columnFilters"
          , Encode.list
                (\f ->
                    Encode.object
                        [ ( "id", Encode.string f.id )
                        , ( "value", encodeValue f.value )
                        ]
                )
                state.columnFilters
          )
        , ( "globalFilter", encodeValue state.globalFilter )
        , ( "grouping", Encode.list Encode.string state.grouping )
        , ( "expanded"
          , case Table.expandedIdsOf state.expanded of
                Nothing ->
                    Encode.bool True

                Just ids ->
                    encodeIdSet ids
          )
        , ( "rowSelection", encodeIdSet state.rowSelection )
        , ( "pagination"
          , Encode.object
                [ ( "pageIndex", Encode.int state.pagination.pageIndex )
                , ( "pageSize", Encode.int state.pagination.pageSize )
                ]
          )
        , ( "columnOrder", Encode.list Encode.string state.columnOrder )
        , ( "columnVisibility", Encode.dict identity Encode.bool state.columnVisibility )
        , ( "columnPinning"
          , Encode.object
                [ ( "left", Encode.list Encode.string state.columnPinning.left )
                , ( "right", Encode.list Encode.string state.columnPinning.right )
                ]
          )
        , ( "columnSizing", encodeFloatDict state.columnSizing )
        , ( "rowPinning"
          , Encode.object
                [ ( "top", Encode.list Encode.string state.rowPinning.top )
                , ( "bottom", Encode.list Encode.string state.rowPinning.bottom )
                ]
          )
        , ( "cellSelection"
          , Encode.list
                (\range ->
                    Encode.object
                        [ ( "anchorRowId", Encode.string range.anchorRowId )
                        , ( "anchorColumnId", Encode.string range.anchorColumnId )
                        , ( "focusRowId", Encode.string range.focusRowId )
                        , ( "focusColumnId", Encode.string range.focusColumnId )
                        , ( "operation"
                          , Encode.string
                                (if range.operation == Table.excludeCells then
                                    "exclude"

                                 else
                                    "include"
                                )
                          )
                        ]
                )
                state.cellSelection
          )
        ]


{-| One cell value, the way `JSON.stringify` would write it.
-}
encodeValue : Value -> Encode.Value
encodeValue value =
    case value of
        Value.String s ->
            Encode.string s

        Value.Number n ->
            Encode.float n

        Value.Bool b ->
            Encode.bool b

        Value.Date posix ->
            Encode.int (Time.posixToMillis posix)

        Value.List items ->
            Encode.list encodeValue items

        Value.Null ->
            Encode.null


encodeIdSet : Set String -> Encode.Value
encodeIdSet ids =
    Encode.object (List.map (\id -> ( id, Encode.bool True )) (Set.toList ids))


encodeFloatDict : Dict String Float -> Encode.Value
encodeFloatDict sizes =
    Encode.dict identity Encode.float sizes
