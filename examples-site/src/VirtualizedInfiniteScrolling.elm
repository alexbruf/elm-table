module VirtualizedInfiniteScrolling exposing (main)

{-| Infinite Scrolling.

Ports `examples/react/virtualized-infinite-scrolling/src/main.tsx` from
TanStack Table: rows arrive a page at a time as the reader nears the bottom
of a virtualized list, and each page is appended to the data the pipeline
runs over.

The React example fetches from a fake API with TanStack Query's
`useInfiniteQuery`. There is no query library here and no server, so the
fetch is `Process.sleep 200` followed by a slice of a list that stands in for
the database. Everything else is the same shape: a page counter, a
`Fetching More...` indicator, a count of what has been loaded against the
total, and a scroll handler that asks for the next page once the reader is
within 500 pixels of the end.

Sorting is client-side here, so it re-runs the pipeline over every row
loaded so far rather than refetching. The React example sorts on the server
with `manualSorting`; see the Client-Side vs Server-Side guide for that
split. As in the React example, sorting scrolls back to the top, because the
row under the reader is no longer the row that was there.

-}

import Browser
import Browser.Dom
import Html exposing (Html, div, p, span, strong, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, id, style)
import Html.Events exposing (on)
import InfiniteList
import Json.Decode as Decode
import Process
import Shared.Controls as Controls
import Shared.People as People exposing (Person)
import Table
import Table.Value as Value exposing (Value)
import Task



-- CONFIG


config : Table.Config Person
config =
    Table.config
        [ Table.column "id" (.id >> Value.String)
            |> Table.withHeader "ID"
            |> Table.withSize 70
        , Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First Name"
            |> Table.withSize 150
        , Table.column "lastName" (.lastName >> maybeString)
            |> Table.withHeader "Last Name"
            |> Table.withSize 150
        , Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
            |> Table.withSize 60
        , Table.column "visits" (.visits >> maybeNumber)
            |> Table.withHeader "Visits"
            |> Table.withSize 70
        , Table.column "status" (.status >> People.statusToString >> Value.String)
            |> Table.withHeader "Status"
            |> Table.withSize 130
        , Table.column "progress" (.progress >> toFloat >> Value.Number)
            |> Table.withHeader "Profile Progress"
            |> Table.withSize 140
        , Table.column "createdAt" (.createdAt >> Value.Date)
            |> Table.withHeader "Created At"
            |> Table.withSize 140
        ]
        |> Table.withGetRowId (\person _ _ -> person.id)


maybeString : Maybe String -> Value
maybeString =
    Maybe.map Value.String >> Maybe.withDefault Value.Null


maybeNumber : Maybe Int -> Value
maybeNumber =
    Maybe.map (toFloat >> Value.Number) >> Maybe.withDefault Value.Null



-- THE STAND-IN BACKEND


{-| `makeData.ts` in the React example builds 1,000 people once and slices
them; so does this.
-}
database : List Person
database =
    People.makeData 42 [ totalRowCount ]


totalRowCount : Int
totalRowCount =
    1000


fetchSize : Int
fetchSize =
    50


fetchLatency : Float
fetchLatency =
    200


{-| One page of the fake API, after the fake latency.
-}
fetchPage : Int -> Cmd Msg
fetchPage pageIndex =
    Process.sleep fetchLatency
        |> Task.perform (\_ -> PageArrived (List.take fetchSize (List.drop (pageIndex * fetchSize) database)))



-- MODEL


rowHeight : Int
rowHeight =
    33


containerHeight : Int
containerHeight =
    600


{-| How close to the end the reader has to get before the next page is asked
for, in pixels. TanStack's `scrollHeight - scrollTop - clientHeight < 500`.
-}
fetchThreshold : Float
fetchThreshold =
    500


containerId : String
containerId =
    "infinite-scroll-container"


type alias Model =
    { state : Table.State
    , loaded : List Person
    , fetching : Bool
    , scrollTop : Float
    , core : Table.RowModel Person
    , rows : List (Table.Row Person)
    , list : InfiniteList.Model
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( recompute
        { state = Table.initialState
        , loaded = []
        , fetching = True
        , scrollTop = 0
        , core = Table.coreRowModelFromList config Table.initialState []
        , rows = []
        , list = InfiniteList.init
        }
    , fetchPage 0
    )


{-| The pipeline over everything loaded so far, stopping at
`sortedRowModel`. Stored in the model, because `view` runs on every scroll
event and every arriving page.
-}
recompute : Model -> Model
recompute model =
    let
        core : Table.RowModel Person
        core =
            Table.coreRowModelFromList config model.state model.loaded
    in
    { model
        | core = core
        , rows = (Table.sortedRowModel config model.state core).rows
    }



-- UPDATE


type Msg
    = SortClicked String Bool
    | Scrolled InfiniteList.Model Float
    | PageArrived (List Person)
    | ScrolledToTop


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SortClicked columnId multi ->
            ( recompute
                { model
                    | state =
                        Table.toggleSort config
                            model.core
                            columnId
                            { desc = Nothing, multi = multi }
                            model.state
                    , list = InfiniteList.init
                    , scrollTop = 0
                }
            , Task.attempt (\_ -> ScrolledToTop) (Browser.Dom.setViewportOf containerId 0 0)
            )

        Scrolled list scrollTop ->
            fetchIfNearBottom { model | list = list, scrollTop = scrollTop }

        PageArrived people ->
            -- A page can land while the reader is already at the bottom, so
            -- check again as soon as one arrives, the way the React example
            -- re-runs its check after every fetch.
            fetchIfNearBottom
                (recompute { model | loaded = model.loaded ++ people, fetching = False })

        ScrolledToTop ->
            ( model, Cmd.none )


{-| The whole of TanStack's `fetchMoreOnBottomReached`. The scroll height is
the row count times the row height, because every row is the same height.
-}
fetchIfNearBottom : Model -> ( Model, Cmd Msg )
fetchIfNearBottom model =
    let
        loadedCount : Int
        loadedCount =
            List.length model.loaded

        remaining : Float
        remaining =
            toFloat (loadedCount * rowHeight) - model.scrollTop - toFloat containerHeight
    in
    if not model.fetching && loadedCount < totalRowCount && remaining < fetchThreshold then
        ( { model | fetching = True }, fetchPage (loadedCount // fetchSize) )

    else
        ( model, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "demo-root" ]
        [ p []
            [ text "("
            , strong [] [ text (Controls.formatInt (List.length model.loaded)) ]
            , text (" of " ++ Controls.formatInt totalRowCount ++ " rows fetched)")
            ]
        , div
            [ class "virtual-container"
            , id containerId
            , style "height" (px (toFloat containerHeight))
            , onScrollWithTop Scrolled
            ]
            [ table
                [ class "virtual-head", style "width" (px (Table.totalSize config model.state)) ]
                [ thead [] [ tr [] (List.map (viewHeaderCell model) (Table.visibleLeafColumns config model.state)) ] ]
            , InfiniteList.view (listConfig model) model.list model.rows
            ]
        , p []
            [ if model.fetching then
                text "Fetching More..."

              else
                text "Scroll to the bottom to fetch the next page."
            ]
        ]


{-| `InfiniteList.onScroll` reports only its own model, and the fetch check
needs the scroll position as a number. An element takes one `scroll`
listener, so this decodes the event once and hands over both.
-}
onScrollWithTop : (InfiniteList.Model -> Float -> msg) -> Html.Attribute msg
onScrollWithTop toMsg =
    on "scroll"
        (Decode.map2 (\event scrollTop -> toMsg (InfiniteList.updateScroll event InfiniteList.init) scrollTop)
            Decode.value
            (Decode.at [ "target", "scrollTop" ] Decode.float)
        )


listConfig : Model -> InfiniteList.Config (Table.Row Person) Msg
listConfig model =
    InfiniteList.config
        { itemView = \_ _ row -> viewRow model row
        , itemHeight = InfiniteList.withConstantHeight rowHeight
        , containerHeight = containerHeight
        }
        |> InfiniteList.withCustomContainer (bodyTable model)


bodyTable : Model -> List ( String, String ) -> List (Html Msg) -> Html Msg
bodyTable model styles rows =
    table
        (class "virtual-body"
            :: style "width" (px (Table.totalSize config model.state))
            :: List.map (\( name, value ) -> style name value) styles
        )
        [ tbody [] rows ]


viewHeaderCell : Model -> Table.Column Person -> Html Msg
viewHeaderCell model column =
    let
        columnId : String
        columnId =
            Table.columnId column

        label : String
        label =
            Maybe.withDefault columnId (Table.columnHeader column)
                ++ Controls.sortArrow (Table.getIsSorted model.state columnId)
    in
    th
        [ class "sortable"
        , style "width" (px (Table.getColumnSize config model.state column))
        , Controls.onClickShift (SortClicked columnId)
        ]
        [ span [] [ text label ] ]


viewRow : Model -> Table.Row Person -> Html Msg
viewRow model row =
    tr [] (List.map (viewCell model row) (Table.visibleLeafColumns config model.state))


viewCell : Model -> Table.Row Person -> Table.Column Person -> Html Msg
viewCell model row column =
    td [ style "width" (px (Table.getColumnSize config model.state column)) ]
        [ text (Controls.valueToString (Table.getValue config row (Table.columnId column))) ]


px : Float -> String
px value =
    String.fromFloat value ++ "px"


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }
