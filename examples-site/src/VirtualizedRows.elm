module VirtualizedRows exposing (main)

{-| Virtualized Rows.

Ports `examples/react/virtualized-rows/src/main.tsx` from TanStack Table:
50,000 rows in a fixed-height scroll container, with only the rows in view
mounted. TanStack pairs the table with TanStack Virtual; the Elm counterpart
here is `FabienHenon/elm-infinite-list-view`, which owns the scroll position
and the window, while this package owns the rows.

Two things make it work:

  - The pipeline stops at `sortedRowModel`, so the virtual list sees all
    50,000 rows rather than one page of ten. Pagination and virtualization
    both cut the rendered row count, and running them together would leave
    the scroll bar describing a page instead of the table.
  - The row model is computed in `update` and stored in the model. `view`
    runs on every scroll event, and re-sorting 50,000 rows on every frame
    would make scrolling crawl.

The React example also has a row-selection column with shift-click ranges.
Selection is not what this example is about; see the Row Selection example
for it.

-}

import Browser
import Html exposing (Html, button, div, p, span, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, style)
import Html.Events exposing (onClick)
import InfiniteList
import Shared.Controls as Controls
import Shared.People as People exposing (Person)
import Table
import Table.Value as Value exposing (Value)



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



-- MODEL


{-| The React example generates 200,000 rows and offers a one-million-row
stress test. 50,000 is the number this port settles on: enough that the
window is obviously a window, and still a second or so to build.
-}
rowCount : Int
rowCount =
    50000


{-| Both halves of the virtual list have to agree on this: the CSS gives
every row exactly this height, and the list turns a scroll position into a
row index by dividing by it.
-}
rowHeight : Int
rowHeight =
    33


containerHeight : Int
containerHeight =
    600


type alias Model =
    { state : Table.State
    , seed : Int
    , data : List Person
    , core : Table.RowModel Person
    , rows : List (Table.Row Person)
    , list : InfiniteList.Model
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( recompute
        { state = Table.initialState
        , seed = 42
        , data = People.makeData 42 [ rowCount ]
        , core = Table.coreRowModelFromList config Table.initialState []
        , rows = []
        , list = InfiniteList.init
        }
    , Cmd.none
    )


{-| The whole pipeline, run once per `update` rather than once per frame. It
stops at `sortedRowModel`: no `paginatedRowModel`, so `.rows` is every row
there is, which is what the virtual list has to index into.
-}
recompute : Model -> Model
recompute model =
    let
        core : Table.RowModel Person
        core =
            Table.coreRowModelFromList config model.state model.data
    in
    { model
        | core = core
        , rows = (Table.sortedRowModel config model.state core).rows
    }



-- UPDATE


type Msg
    = SortClicked String Bool
    | RegenerateData
    | Scrolled InfiniteList.Model


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
                }
            , Cmd.none
            )

        RegenerateData ->
            let
                seed : Int
                seed =
                    model.seed + 1
            in
            ( recompute { model | seed = seed, data = People.makeData seed [ rowCount ] }
            , Cmd.none
            )

        Scrolled list ->
            ( { model | list = list }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "demo-root" ]
        [ div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ] ]
        , p []
            [ text (Controls.formatInt (List.length model.rows) ++ " rows, ")
            , text (String.fromInt (List.length (Table.visibleLeafColumns config model.state)) ++ " columns. ")
            , text "Click a header to sort, shift-click to add a column to the sort."
            ]
        , div
            [ class "virtual-container"
            , style "height" (px (toFloat containerHeight))
            , InfiniteList.onScroll Scrolled
            ]
            [ table
                [ class "virtual-head", style "width" (px (Table.totalSize config model.state)) ]
                [ thead [] [ tr [] (List.map (viewHeaderCell model) (Table.visibleLeafColumns config model.state)) ] ]
            , InfiniteList.view (listConfig model) model.list model.rows
            ]
        , p [ class "muted" ]
            [ text "Only the rows inside the viewport are in the DOM. Everything above and below them is one empty box the height of the rows it stands in for." ]
        ]


{-| `itemView` is handed the item itself, so a rendered row needs no lookup
back into the 50,000.
-}
listConfig : Model -> InfiniteList.Config (Table.Row Person) Msg
listConfig model =
    InfiniteList.config
        { itemView = \_ _ row -> viewRow model row
        , itemHeight = InfiniteList.withConstantHeight rowHeight
        , containerHeight = containerHeight
        }
        |> InfiniteList.withCustomContainer (bodyTable model)


{-| The list renders a `div` around its items by default. A table wants a
`table` and a `tbody`, and this puts them back.
-}
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
