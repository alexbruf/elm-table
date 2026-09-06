module Table.Internal.Header exposing
    ( centerFlatHeaders
    , centerFooterGroups
    , centerHeaderGroups
    , centerLeafHeaders
    , colSpan
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
    , leftFlatHeaders
    , leftFooterGroups
    , leftHeaderGroups
    , leftLeafHeaders
    , placeholderId
    , rightFlatHeaders
    , rightFooterGroups
    , rightHeaderGroups
    , rightLeafHeaders
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
import Table.Internal.ColumnPinning as Pinning
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
    buildHeaderGroups cfg state Nothing (visibleLeafColumnsToGroup cfg state)


{-| The header rows of the left-pinned columns. Ports
`table_getStartHeaderGroups`.
-}
leftHeaderGroups : Config row -> State -> List (HeaderGroup row)
leftHeaderGroups cfg state =
    buildHeaderGroups cfg state (Just "start") (Pinning.leftVisibleLeafColumns cfg state)


{-| The header rows of the unpinned columns. Ports
`table_getCenterHeaderGroups`.
-}
centerHeaderGroups : Config row -> State -> List (HeaderGroup row)
centerHeaderGroups cfg state =
    buildHeaderGroups cfg state (Just "center") (Pinning.centerVisibleLeafColumns cfg state)


{-| The header rows of the right-pinned columns. Ports
`table_getEndHeaderGroups`.
-}
rightHeaderGroups : Config row -> State -> List (HeaderGroup row)
rightHeaderGroups cfg state =
    buildHeaderGroups cfg state (Just "end") (Pinning.rightVisibleLeafColumns cfg state)


{-| Build the header rows over one list of leaf columns. `family` prefixes
the header group ids and the parent header ids, the way `buildHeaderGroups`
does for the pinned regions.
-}
buildHeaderGroups : Config row -> State -> Maybe String -> List (Column row) -> List (HeaderGroup row)
buildHeaderGroups cfg state family columnsToGroup =
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
                columnsToGroup

        topRow : List (Header row)
        topRow =
            climb family byId (maxDepth - 1) bottom
                |> updateSpans visible
    in
    List.range 0 (maxDepth - 1)
        |> List.map
            (\d ->
                { id = formatHeaderGroupId family d
                , depth = d
                , headers = atLevel d topRow
                }
            )


{-| The leaf columns the header rows are built from: left-pinned first, then
the unpinned columns in table order, then the right-pinned ones. Ports the
pin partitioning path of `table_getHeaderGroups`.
-}
visibleLeafColumnsToGroup : Config row -> State -> List (Column row)
visibleLeafColumnsToGroup cfg state =
    if Pinning.isSomeColumnsPinned state then
        Pinning.leftVisibleLeafColumns cfg state
            ++ Pinning.centerVisibleLeafColumns cfg state
            ++ Pinning.rightVisibleLeafColumns cfg state

    else
        Column.visibleLeafColumns cfg state


{-| The footer rows: the header rows bottom row first.
-}
footerGroups : Config row -> State -> List (HeaderGroup row)
footerGroups cfg state =
    List.reverse (headerGroups cfg state)


{-| The footer rows of the left-pinned columns. Ports
`table_getStartFooterGroups`.
-}
leftFooterGroups : Config row -> State -> List (HeaderGroup row)
leftFooterGroups cfg state =
    List.reverse (leftHeaderGroups cfg state)


{-| The footer rows of the unpinned columns. Ports
`table_getCenterFooterGroups`.
-}
centerFooterGroups : Config row -> State -> List (HeaderGroup row)
centerFooterGroups cfg state =
    List.reverse (centerHeaderGroups cfg state)


{-| The footer rows of the right-pinned columns. Ports
`table_getEndFooterGroups`.
-}
rightFooterGroups : Config row -> State -> List (HeaderGroup row)
rightFooterGroups cfg state =
    List.reverse (rightHeaderGroups cfg state)


{-| Every header of every header row.
-}
flatHeaders : Config row -> State -> List (Header row)
flatHeaders cfg state =
    List.concatMap .headers (headerGroups cfg state)


{-| Every header of the left-pinned header rows. Ports
`table_getStartFlatHeaders`.
-}
leftFlatHeaders : Config row -> State -> List (Header row)
leftFlatHeaders cfg state =
    List.concatMap .headers (leftHeaderGroups cfg state)


{-| Every header of the center header rows. Ports
`table_getCenterFlatHeaders`.
-}
centerFlatHeaders : Config row -> State -> List (Header row)
centerFlatHeaders cfg state =
    List.concatMap .headers (centerHeaderGroups cfg state)


{-| Every header of the right-pinned header rows. Ports
`table_getEndFlatHeaders`.
-}
rightFlatHeaders : Config row -> State -> List (Header row)
rightFlatHeaders cfg state =
    List.concatMap .headers (rightHeaderGroups cfg state)


{-| The leaf headers reachable from the top header row.
-}
leafHeaders : Config row -> State -> List (Header row)
leafHeaders cfg state =
    case headerGroups cfg state of
        [] ->
            []

        top :: _ ->
            List.concatMap getLeafHeaders top.headers


{-| The left-pinned headers that have no sub-headers. Ports
`table_getStartLeafHeaders`.
-}
leftLeafHeaders : Config row -> State -> List (Header row)
leftLeafHeaders cfg state =
    List.filter noSubHeaders (leftFlatHeaders cfg state)


{-| The center headers that have no sub-headers. Ports
`table_getCenterLeafHeaders`.
-}
centerLeafHeaders : Config row -> State -> List (Header row)
centerLeafHeaders cfg state =
    List.filter noSubHeaders (centerFlatHeaders cfg state)


{-| The right-pinned headers that have no sub-headers. Ports
`table_getEndLeafHeaders`.
-}
rightLeafHeaders : Config row -> State -> List (Header row)
rightLeafHeaders cfg state =
    List.filter noSubHeaders (rightFlatHeaders cfg state)


noSubHeaders : Header row -> Bool
noSubHeaders (Header h) =
    List.isEmpty h.subHeaders


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
climb : Maybe String -> Dict String (Column row) -> Int -> List (Header row) -> List (Header row)
climb family byId groupDepth headers =
    if groupDepth > 0 then
        climb family byId (groupDepth - 1) (parentsOf family byId groupDepth headers)

    else
        headers


parentsOf : Maybe String -> Dict String (Column row) -> Int -> List (Header row) -> List (Header row)
parentsOf family byId groupDepth headers =
    List.foldl (addToParents family byId groupDepth) [] headers
        |> List.reverse
        |> List.map closeSubHeaders


addToParents : Maybe String -> Dict String (Column row) -> Int -> Header row -> List (Header row) -> List (Header row)
addToParents family byId groupDepth (Header child) pending =
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
                newParent family groupDepth parentColumnId placeholder (Header child) pending

        [] ->
            newParent family groupDepth parentColumnId placeholder (Header child) pending


newParent : Maybe String -> Int -> String -> Bool -> Header row -> List (Header row) -> List (Header row)
newParent family groupDepth parentColumnId placeholder child pending =
    Header
        { id = formatHeaderId family groupDepth parentColumnId (id child)
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


formatHeaderId : Maybe String -> Int -> String -> String -> String
formatHeaderId family atDepth cid childId =
    [ Maybe.withDefault "" family
    , if atDepth == 0 then
        ""

      else
        String.fromInt atDepth
    , cid
    , childId
    ]
        |> List.filter (\part -> part /= "")
        |> String.join "_"


formatHeaderGroupId : Maybe String -> Int -> String
formatHeaderGroupId family atDepth =
    case family of
        Just name ->
            name ++ "_" ++ String.fromInt atDepth

        Nothing ->
            String.fromInt atDepth



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
