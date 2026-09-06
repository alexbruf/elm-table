module Table.Internal.Header exposing
    ( colSpan
    , columnId
    , depth
    , flatHeaders
    , footerGroups
    , getLeafHeaders
    , headerGroups
    , id
    , index
    , isPlaceholder
    , leafHeaders
    , placeholderId
    , rowSpan
    , subHeaders
    )

{-| Header groups, including placeholder headers and the column and row spans
of a nested column tree.

Ports `core/headers/buildHeaderGroups.ts`, `core/headers/constructHeader.ts`,
and `core/headers/coreHeadersFeature.utils.ts`.

-}

import Dict exposing (Dict)
import Table.Internal.Column as Column
import Table.Internal.Types exposing (Column, Config, Header(..), HeaderGroup, State)



-- ACCESSORS


{-| The header id. Placeholder headers get a compound id.
-}
id : Header row -> String
id (Header h) =
    h.id


{-| The id of the column this header renders.
-}
columnId : Header row -> String
columnId (Header h) =
    h.columnId


{-| How many leaf columns this header spans.
-}
colSpan : Header row -> Int
colSpan (Header h) =
    h.colSpan


{-| How many header rows this header spans. `0` means another header already
covers this cell.
-}
rowSpan : Header row -> Int
rowSpan (Header h) =
    h.rowSpan


{-| Which header row this header belongs to, counted from `1` at the top.
-}
depth : Header row -> Int
depth (Header h) =
    h.depth


{-| The header's position in its header row.
-}
index : Header row -> Int
index (Header h) =
    h.index


{-| Is this a filler header standing in for a column that has no group at
this level?
-}
isPlaceholder : Header row -> Bool
isPlaceholder (Header h) =
    h.isPlaceholder


{-| How many placeholders for the same column came before this one.
-}
placeholderId : Header row -> Maybe String
placeholderId (Header h) =
    h.placeholderId


{-| The headers nested under this one.
-}
subHeaders : Header row -> List (Header row)
subHeaders (Header h) =
    h.subHeaders



-- GROUPS


{-| The header rows of a table, top row first.
-}
headerGroups : Config row -> State -> List (HeaderGroup row)
headerGroups cfg state =
    let
        byId : Dict String (Column row)
        byId =
            Column.columnsById cfg

        visible : String -> Bool
        visible cid =
            Dict.get cid byId
                |> Maybe.map (Column.isVisible state)
                |> Maybe.withDefault True

        maxDepth : Int
        maxDepth =
            maxHeaderDepth state (Column.allColumns cfg) 1

        bottom : List (Header row)
        bottom =
            List.indexedMap
                (\i col ->
                    Header
                        { id = Column.id col
                        , columnId = Column.id col
                        , colSpan = 0
                        , rowSpan = 0
                        , depth = maxDepth
                        , index = i
                        , isPlaceholder = False
                        , placeholderId = Nothing
                        , subHeaders = []
                        }
                )
                (visibleLeafColumnsToGroup cfg state)

        topRow : List (Header row)
        topRow =
            climb byId (maxDepth - 1) bottom
                |> updateSpans visible
    in
    List.range 0 (maxDepth - 1)
        |> List.map
            (\d ->
                { id = String.fromInt d
                , depth = d
                , headers = atLevel d topRow
                }
            )


{-| The leaf columns the header rows are built from. Column pinning splits
this list into left, center, and right in phase 5.
-}
visibleLeafColumnsToGroup : Config row -> State -> List (Column row)
visibleLeafColumnsToGroup =
    Column.visibleLeafColumns


{-| The footer rows: the header rows bottom row first.
-}
footerGroups : Config row -> State -> List (HeaderGroup row)
footerGroups cfg state =
    List.reverse (headerGroups cfg state)


{-| Every header of every header row.
-}
flatHeaders : Config row -> State -> List (Header row)
flatHeaders cfg state =
    List.concatMap .headers (headerGroups cfg state)


{-| The leaf headers reachable from the top header row.
-}
leafHeaders : Config row -> State -> List (Header row)
leafHeaders cfg state =
    case headerGroups cfg state of
        [] ->
            []

        top :: _ ->
            List.concatMap getLeafHeaders top.headers


{-| The descendants of a header, deepest first, with the header itself last.
-}
getLeafHeaders : Header row -> List (Header row)
getLeafHeaders (Header h) =
    List.concatMap getLeafHeaders h.subHeaders ++ [ Header h ]



-- BUILDING


maxHeaderDepth : State -> List (Column row) -> Int -> Int
maxHeaderDepth state columns atDepth =
    List.foldl
        (\col acc ->
            if Column.isVisible state col && not (List.isEmpty (Column.children col)) then
                Basics.max acc (maxHeaderDepth state (Column.children col) (atDepth + 1))

            else
                acc
        )
        atDepth
        columns


{-| Build the parent header rows until the top row is reached, and return it.
-}
climb : Dict String (Column row) -> Int -> List (Header row) -> List (Header row)
climb byId groupDepth headers =
    if groupDepth > 0 then
        climb byId (groupDepth - 1) (parentsOf byId groupDepth headers)

    else
        headers


parentsOf : Dict String (Column row) -> Int -> List (Header row) -> List (Header row)
parentsOf byId groupDepth headers =
    List.foldl (addToParents byId groupDepth) [] headers
        |> List.reverse
        |> List.map closeSubHeaders


addToParents : Dict String (Column row) -> Int -> Header row -> List (Header row) -> List (Header row)
addToParents byId groupDepth (Header child) pending =
    let
        col : Maybe (Column row)
        col =
            Dict.get child.columnId byId

        isLeafHeader : Bool
        isLeafHeader =
            Maybe.map Column.depth col == Just groupDepth

        parentColumnId : String
        parentColumnId =
            case ( isLeafHeader, Maybe.andThen Column.parentId col ) of
                ( True, Just pid ) ->
                    pid

                _ ->
                    child.columnId

        placeholder : Bool
        placeholder =
            parentColumnId == child.columnId
    in
    case pending of
        (Header latest) :: rest ->
            if latest.columnId == parentColumnId then
                Header { latest | subHeaders = Header child :: latest.subHeaders } :: rest

            else
                newParent groupDepth parentColumnId placeholder (Header child) pending

        [] ->
            newParent groupDepth parentColumnId placeholder (Header child) pending


newParent : Int -> String -> Bool -> Header row -> List (Header row) -> List (Header row)
newParent groupDepth parentColumnId placeholder child pending =
    Header
        { id = formatHeaderId groupDepth parentColumnId (id child)
        , columnId = parentColumnId
        , colSpan = 0
        , rowSpan = 0
        , depth = groupDepth
        , index = List.length pending
        , isPlaceholder = placeholder
        , placeholderId =
            if placeholder then
                Just (String.fromInt (List.length (List.filter (\p -> columnId p == parentColumnId) pending)))

            else
                Nothing
        , subHeaders = [ child ]
        }
        :: pending


closeSubHeaders : Header row -> Header row
closeSubHeaders (Header h) =
    Header { h | subHeaders = List.reverse h.subHeaders }


formatHeaderId : Int -> String -> String -> String
formatHeaderId atDepth cid childId =
    [ if atDepth == 0 then
        ""

      else
        String.fromInt atDepth
    , cid
    , childId
    ]
        |> List.filter (\part -> part /= "")
        |> String.join "_"



-- SPANS


updateSpans : (String -> Bool) -> List (Header row) -> List (Header row)
updateSpans visible headers =
    List.map (updateSpansOf visible) headers


updateSpansOf : (String -> Bool) -> Header row -> Header row
updateSpansOf visible (Header h) =
    if not (visible h.columnId) then
        Header h

    else
        let
            subs : List (Header row)
            subs =
                updateSpans visible h.subHeaders

            span : Int
            span =
                if List.isEmpty subs then
                    1

                else
                    List.sum
                        (List.map
                            (\sub ->
                                if visible (columnId sub) then
                                    colSpan sub

                                else
                                    0
                            )
                            subs
                        )

            plain : Header row
            plain =
                Header { h | colSpan = span, rowSpan = 1, subHeaders = subs }
        in
        case ( h.isPlaceholder, subs ) of
            ( True, [ only ] ) ->
                if columnId only == h.columnId then
                    let
                        covered : ( Header row, Int )
                        covered =
                            coverChain h.columnId only
                    in
                    Header
                        { h
                            | colSpan = span
                            , rowSpan = 1 + Tuple.second covered
                            , subHeaders = [ Tuple.first covered ]
                        }

                else
                    plain

            _ ->
                plain


{-| Walk the chain of same-column headers below a spanning placeholder,
setting each `rowSpan` to `0`, and count them.
-}
coverChain : String -> Header row -> ( Header row, Int )
coverChain cid (Header h) =
    case h.subHeaders of
        [ only ] ->
            if columnId only == cid then
                let
                    covered : ( Header row, Int )
                    covered =
                        coverChain cid only
                in
                ( Header { h | rowSpan = 0, subHeaders = [ Tuple.first covered ] }
                , 1 + Tuple.second covered
                )

            else
                ( Header { h | rowSpan = 0 }, 1 )

        _ ->
            ( Header { h | rowSpan = 0 }, 1 )



-- LEVELS


{-| Every header at one level of the header tree, left to right.
-}
atLevel : Int -> List (Header row) -> List (Header row)
atLevel level headers =
    if level <= 0 then
        headers

    else
        atLevel (level - 1) (List.concatMap subHeaders headers)
