module Table.Internal.ColumnResizing exposing
    ( canResize
    , endResize
    , headerCanResize
    , headerIsResizing
    , isResizing
    , resetResizing
    , setResizing
    , startResize
    , updateResize
    )

{-| Column resizing: the transient state of one drag and the three
transitions that move it along.

Ports `features/column-resizing/columnResizingFeature.utils.ts`. TanStack
does all of this inside the closure `header_getResizeHandler` returns, which
installs `mousemove` / `mouseup` / `touchmove` / `touchend` listeners on the
document and writes state from them. This package touches no DOM, so the
closure is split into the three state transitions it performs -
`startResize`, `updateResize`, `endResize` - and the caller wires the events.

Everything else in the source file is DOM plumbing with no counterpart:
`passiveEventSupported`, `isTouchStartEvent`, the listener registration and
removal, and the `requestAnimationFrame` coalescing of pointer moves.

-}

import Dict exposing (Dict)
import Table.Internal.Column as Column
import Table.Internal.ColumnSizing as ColumnSizing
import Table.Internal.Config as Config
import Table.Internal.Header as Header
import Table.Internal.Types exposing (Column, ColumnResizeDirection(..), ColumnResizeMode(..), ColumnResizingState, Config, Header, State)



-- QUERIES


{-| Can this column be resized? Both the column's `enableResizing` and the
table's `enableColumnResizing` default to `True`. Ports
`column_getCanResize`.
-}
canResize : Config row -> Column row -> Bool
canResize cfg col =
    (Column.fields col).enableResizing && cfg.enableColumnResizing


{-| Is this column the one being dragged? Ports `column_getIsResizing`.
-}
isResizing : State -> Column row -> Bool
isResizing state col =
    state.columnResizing.isResizingColumn == Just (Column.id col)


{-| Can this header's column be resized? A header of a column that is not in
the config cannot.
-}
headerCanResize : Config row -> Header row -> Bool
headerCanResize cfg header =
    Column.findColumn cfg (Header.columnId header)
        |> Maybe.map (canResize cfg)
        |> Maybe.withDefault False


{-| Is this header's column the one being dragged?
-}
headerIsResizing : State -> Header row -> Bool
headerIsResizing state header =
    state.columnResizing.isResizingColumn == Just (Header.columnId header)



-- STATE


{-| Replace the whole transient slice. Ports `table_setColumnResizing`.
-}
setResizing : ColumnResizingState -> State -> State
setResizing resizing state =
    { state | columnResizing = resizing }


{-| Drop the transient slice back to "no drag in progress". Ports
`table_resetHeaderSizeInfo(table, true)`.
-}
resetResizing : State -> State
resetResizing state =
    { state | columnResizing = Config.defaultColumnResizing }



-- TRANSITIONS


{-| Begin a drag on a header at a pointer position, in the same client
coordinates `getSize` is measured in. Records the pointer offset the drag
started at, the header's width at that moment, the width of every leaf header
under it, and the column being resized.

A column that cannot be resized leaves the state alone, which is the early
`return` of the handler TanStack's `header_getResizeHandler` returns.

-}
startResize : Config row -> State -> Header row -> Float -> State
startResize cfg state header clientX =
    if not (headerCanResize cfg header) then
        state

    else
        let
            resizing : ColumnResizingState
            resizing =
                state.columnResizing
        in
        { state
            | columnResizing =
                { resizing
                    | startOffset = Just clientX
                    , startSize = Just (ColumnSizing.headerSize cfg state header)
                    , deltaOffset = Just 0
                    , deltaPercentage = Just 0
                    , columnSizingStart = leafSizes cfg state header
                    , isResizingColumn = Just (Header.columnId header)
                }
        }


{-| Move the drag to a new pointer position. Writes `deltaOffset`, which is
the distance from `startOffset` with the sign
`Config.columnResizeDirection` gives it, and `deltaPercentage`, that distance
as a fraction of the starting width, floored at `-0.999999` so a column can
never be dragged past zero.

In `ResizeOnChange` mode it also commits the new widths to
`State.columnSizing`; in `ResizeOnEnd` mode the widths are only computed at
the end of the drag.

With no drag in progress the state is returned unchanged. TanStack has no
such guard because its listeners only exist for the length of a drag.

-}
updateResize : Config row -> Float -> State -> State
updateResize cfg clientX state =
    case state.columnResizing.isResizingColumn of
        Nothing ->
            state

        Just _ ->
            let
                moved : State
                moved =
                    { state | columnResizing = movedTo cfg clientX state.columnResizing }
            in
            case cfg.columnResizeMode of
                ResizeOnChange ->
                    commitSizes moved

                ResizeOnEnd ->
                    moved


{-| End the drag: commit the widths the last `updateResize` computed, then
clear the transient slice.

TanStack commits at the end of a drag in both modes, from the position of the
event that ended it. Call `updateResize` with that position first when it
carries one, as a `mouseup` does; the commit here reads the deltas already in
state, so a `touchend`, which carries none, still commits the last position
seen.

-}
endResize : Config row -> State -> State
endResize _ state =
    case state.columnResizing.isResizingColumn of
        Nothing ->
            state

        Just _ ->
            resetResizing (commitSizes state)



-- INTERNALS


movedTo : Config row -> Float -> ColumnResizingState -> ColumnResizingState
movedTo cfg clientX old =
    let
        deltaDirection : Float
        deltaDirection =
            case cfg.columnResizeDirection of
                Rtl ->
                    -1

                Ltr ->
                    1

        deltaOffset : Float
        deltaOffset =
            (clientX - Maybe.withDefault 0 old.startOffset) * deltaDirection

        startSize : Float
        startSize =
            Maybe.withDefault 0 old.startSize

        deltaPercentage : Float
        deltaPercentage =
            Basics.max
                (if startSize > 0 then
                    deltaOffset / startSize

                 else
                    0
                )
                -0.999999
    in
    { old
        | deltaOffset = Just deltaOffset
        , deltaPercentage = Just deltaPercentage
    }


commitSizes : State -> State
commitSizes state =
    let
        info : ColumnResizingState
        info =
            state.columnResizing

        count : Int
        count =
            List.length info.columnSizingStart

        deltaOffset : Float
        deltaOffset =
            Maybe.withDefault 0 info.deltaOffset

        deltaPercentage : Float
        deltaPercentage =
            Maybe.withDefault 0 info.deltaPercentage

        newSize : Float -> Float
        newSize startWidth =
            roundTo2
                (Basics.max
                    (if startWidth > 0 then
                        startWidth + startWidth * deltaPercentage

                     else
                        deltaOffset / toFloat count
                    )
                    0
                )

        commit : ( String, Float ) -> Dict String Float -> Dict String Float
        commit ( columnId, startWidth ) sizing =
            Dict.insert columnId (newSize startWidth) sizing
    in
    { state | columnSizing = List.foldl commit state.columnSizing info.columnSizingStart }


leafSizes : Config row -> State -> Header row -> List ( String, Float )
leafSizes cfg state header =
    Header.getLeafHeaders header
        |> List.map
            (\leaf ->
                ( Header.columnId leaf
                , Column.findColumn cfg (Header.columnId leaf)
                    |> Maybe.map (ColumnSizing.getSize cfg state)
                    |> Maybe.withDefault 0
                )
            )


roundTo2 : Float -> Float
roundTo2 n =
    toFloat (round (n * 100)) / 100
