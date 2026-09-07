module Shared.Virtual exposing
    ( Window, fixed, variable, slice
    , Scroll, onScroll
    )

{-| A window over one axis of a scrolling list.

`FabienHenon/elm-infinite-list-view` covers the vertical axis of an ordinary
list, and the Virtualized Rows and Infinite Scrolling examples use it. It has
no horizontal mode, so the Virtualized Columns example windows both axes with
this module instead, which keeps the two axes of that table symmetrical.

The whole idea fits in three numbers: which item comes first, how many to
render, and how much empty space stands in for the items on either side.

@docs Window, fixed, variable, slice
@docs Scroll, onScroll

-}

import Array exposing (Array)
import Html
import Html.Events exposing (on)
import Json.Decode as Decode


{-| The items to render and the space the skipped ones leave behind.

`before` and `after` are pixels: the size of everything before `first`, and
the size of everything after the last rendered item. Put them in a spacer and
the scroll bar keeps the geometry of the whole list.

-}
type alias Window =
    { first : Int
    , count : Int
    , before : Float
    , after : Float
    }


{-| The window of a list whose items are all the same size.

    fixed { itemSize = 33, itemCount = 50000, viewport = 600, overscan = 5 } 9900

-}
fixed :
    { itemSize : Float, itemCount : Int, viewport : Float, overscan : Int }
    -> Float
    -> Window
fixed options scroll =
    let
        atScroll : Int
        atScroll =
            floor (scroll / options.itemSize)

        spanning : Int
        spanning =
            ceiling (options.viewport / options.itemSize) + 1

        first : Int
        first =
            clamp 0 options.itemCount (atScroll - options.overscan)

        last : Int
        last =
            clamp first options.itemCount (atScroll + spanning + options.overscan)
    in
    { first = first
    , count = last - first
    , before = toFloat first * options.itemSize
    , after = toFloat (options.itemCount - last) * options.itemSize
    }


{-| The window of a list whose items have their own sizes.

`bounds` holds one more entry than there are items: the offset of item `i` is
`bounds[i]`, and the last entry is the size of the whole list. For a table's
columns that is a running sum of
[`getColumnSize`](https://package.elm-lang.org/packages/alexbruf/elm-table/latest/Table#getColumnSize),
ending at
[`totalSize`](https://package.elm-lang.org/packages/alexbruf/elm-table/latest/Table#totalSize).

-}
variable :
    { bounds : Array Float, viewport : Float, overscan : Int }
    -> Float
    -> Window
variable options scroll =
    let
        itemCount : Int
        itemCount =
            Array.length options.bounds - 1

        totalSize : Float
        totalSize =
            at itemCount options.bounds

        first : Int
        first =
            clamp 0 itemCount (lowestIndexWhere (\b -> b > scroll) options.bounds - 1 - options.overscan)

        last : Int
        last =
            clamp first itemCount (lowestIndexWhere (\b -> b >= scroll + options.viewport) options.bounds + options.overscan)
    in
    { first = first
    , count = last - first
    , before = at first options.bounds
    , after = totalSize - at last options.bounds
    }


{-| The items a window names.
-}
slice : Window -> List a -> List a
slice window items =
    List.take window.count (List.drop window.first items)


at : Int -> Array Float -> Float
at index bounds =
    Maybe.withDefault 0 (Array.get index bounds)


{-| The lowest index whose entry satisfies the test, or the length of the
array when none does. The array is a running sum, so it is sorted and a
binary search finds that index without walking a thousand columns on every
scroll event.
-}
lowestIndexWhere : (Float -> Bool) -> Array Float -> Int
lowestIndexWhere isPast bounds =
    let
        search : Int -> Int -> Int
        search low high =
            if low >= high then
                low

            else
                let
                    middle : Int
                    middle =
                        low + (high - low) // 2
                in
                if isPast (at middle bounds) then
                    search low middle

                else
                    search (middle + 1) high
    in
    search 0 (Array.length bounds)


{-| Where a scroll container is scrolled to, both ways at once.
-}
type alias Scroll =
    { top : Float
    , left : Float
    }


{-| The scroll position of the element the event fired on. One listener
reports both axes, because an element only takes one `scroll` handler.
-}
onScroll : (Scroll -> msg) -> Html.Attribute msg
onScroll toMsg =
    on "scroll"
        (Decode.map2 (\top left -> toMsg (Scroll top left))
            (Decode.at [ "target", "scrollTop" ] Decode.float)
            (Decode.at [ "target", "scrollLeft" ] Decode.float)
        )
