module Shared.Drag exposing
    ( onDragStart, onDragOver, onDrop, onDragEnd
    , move, moveBy
    )

{-| HTML5 drag and drop, the pure-Elm stand-in for the `dnd-kit` sensors the
TanStack `column-dnd` and `row-dnd` examples use.

Put `Html.Attributes.draggable "true"` and `onDragStart` on the handle, and
`onDragOver` / `onDrop` on every possible target. `onDragOver` and `onDrop`
call `preventDefault`, which is what makes an element a drop target at all.

`move` is `arrayMove` from `@dnd-kit/sortable`: the same splice.

Caveat: Elm cannot reach `event.dataTransfer.setData`, so Firefox (which
requires it before it will start a drag) does not drag these tables. Chrome
and Safari do.

@docs onDragStart, onDragOver, onDrop, onDragEnd
@docs move, moveBy

-}

import Html
import Html.Events
import Json.Decode as Decode


{-| The drag is starting on this element.
-}
onDragStart : msg -> Html.Attribute msg
onDragStart msg =
    Html.Events.on "dragstart" (Decode.succeed msg)


{-| Something is being dragged over this element. Calls `preventDefault`, so
the element becomes a drop target.
-}
onDragOver : msg -> Html.Attribute msg
onDragOver msg =
    Html.Events.preventDefaultOn "dragover" (Decode.succeed ( msg, True ))


{-| Something was dropped on this element. Calls `preventDefault`, so the
browser does not try to navigate.
-}
onDrop : msg -> Html.Attribute msg
onDrop msg =
    Html.Events.preventDefaultOn "drop" (Decode.succeed ( msg, True ))


{-| The drag finished, dropped or cancelled.
-}
onDragEnd : msg -> Html.Attribute msg
onDragEnd msg =
    Html.Events.on "dragend" (Decode.succeed msg)


{-| Move the first item to the second one's position, `arrayMove` style.
-}
move : a -> a -> List a -> List a
move from to items =
    moveBy identity from to items


{-| [`move`](#move) over a list whose items are compared by a key.
-}
moveBy : (a -> b) -> b -> b -> List a -> List a
moveBy key from to items =
    case ( indexOf key from items, indexOf key to items ) of
        ( Just oldIndex, Just newIndex ) ->
            let
                without : List a
                without =
                    List.take oldIndex items ++ List.drop (oldIndex + 1) items

                moved : List a
                moved =
                    List.take 1 (List.drop oldIndex items)
            in
            List.take newIndex without ++ moved ++ List.drop newIndex without

        _ ->
            items


indexOf : (a -> b) -> b -> List a -> Maybe Int
indexOf key wanted items =
    List.indexedMap (\i item -> ( i, key item )) items
        |> List.filter (\( _, k ) -> k == wanted)
        |> List.head
        |> Maybe.map Tuple.first
