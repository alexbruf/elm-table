module VirtualizedColumns exposing (main)

{-| Virtualized Columns.

Ports `examples/react/virtualized-columns/src/main.tsx` from TanStack Table:
a table 1,000 columns wide, windowed on both axes, so the DOM holds a few
dozen cells rather than hundreds of thousands.

The two axes are windowed differently, which is what the TanStack example
does too:

  - Rows are positioned by leaving one empty row above the window and one
    below it, each as tall as the rows it stands in for.
  - Columns are positioned by leaving one empty cell to the left of the
    window and one to the right, each as wide as the columns it stands in
    for. TanStack calls these the virtual padding cells.

`FabienHenon/elm-infinite-list-view`, which the Virtualized Rows example
uses, has no horizontal mode and owns its own scroll container, so both axes
here go through `Shared.Virtual` instead. The offsets come from the package:
`getColumnSize` for the width of each rendered column, `getColumnStart` for
the width of the left spacer, and `totalSize` for the width of the table.

The React example uses 1,000 rows and adds drag-to-resize handles. This port
uses 200 rows, because 200,000 generated cells is already past the point the
windowing is demonstrating, and leaves resizing to the Column Sizing example.

-}

import Array exposing (Array)
import Browser
import Html exposing (Html, button, div, p, span, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, colspan, style)
import Html.Events exposing (onClick)
import Shared.Controls as Controls
import Shared.People as People
import Shared.Virtual as Virtual
import Table
import Table.Value as Value



-- DATA


columnCount : Int
columnCount =
    1000


rowCount : Int
rowCount =
    200


{-| A row is one string per column, so the columns are built at runtime the
way `makeColumns` does in the React example.
-}
type alias WideRow =
    { id : String
    , values : Array String
    }


names : Array String
names =
    Array.fromList People.firstNames


{-| `faker.person.firstName()` in the React example. A hash of the two
indexes stands in for it here, so the data is the same on every load without
generating 200,000 random numbers.
-}
nameAt : Int -> Int -> String
nameAt rowIndex columnIndex =
    Array.get (modBy (Array.length names) (rowIndex * 7919 + columnIndex * 104729))
        names
        |> Maybe.withDefault "Tanner"


makeRows : Int -> List WideRow
makeRows salt =
    List.map
        (\index ->
            { id = String.fromInt index
            , values = Array.initialize columnCount (nameAt (index + salt))
            }
        )
        (List.range 0 (rowCount - 1))



-- CONFIG


{-| `Math.floor(Math.random() * 150) + 100` in the React example, made
deterministic.
-}
columnWidth : Int -> Float
columnWidth index =
    toFloat (100 + modBy 150 (index * 37 + 11))


config : Table.Config WideRow
config =
    Table.config (List.map wideColumn (List.range 0 (columnCount - 1)))
        |> Table.withGetRowId (\row _ _ -> row.id)


wideColumn : Int -> Table.Column WideRow
wideColumn index =
    Table.column (String.fromInt index)
        (\row -> Value.String (Maybe.withDefault "" (Array.get index row.values)))
        |> Table.withHeader ("Column " ++ String.fromInt index)
        |> Table.withSize (columnWidth index)



-- MODEL


rowHeight : Float
rowHeight =
    33


containerHeight : Float
containerHeight =
    600


{-| The width of the scroll container. The window has to know how much of
the table is on screen, and nothing here measures the DOM, so the container
is given a width rather than asked for one.
-}
containerWidth : Float
containerWidth =
    1000


overscan : Int
overscan =
    3


type alias Model =
    { state : Table.State
    , salt : Int
    , core : Table.RowModel WideRow
    , rows : List (Table.Row WideRow)
    , columns : List (Table.Column WideRow)
    , bounds : Array Float
    , totalWidth : Float
    , scroll : Virtual.Scroll
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( recompute (makeRows 0)
        { state = Table.initialState
        , salt = 0
        , core = Table.coreRowModelFromList config Table.initialState []
        , rows = []
        , columns = []
        , bounds = Array.empty
        , totalWidth = 0
        , scroll = { top = 0, left = 0 }
        }
    , Cmd.none
    )


{-| Everything the two windows need, computed once per `update` rather than
once per scroll event: the sorted rows, the visible columns, and the running
sum of their widths.

`bounds` holds one entry per column plus a last entry for the whole width, so
`bounds[i]` is the same number
[`getColumnStart`](https://package.elm-lang.org/packages/viewengine/elm-table/latest/Table#getColumnStart)
returns for column `i` and the last entry is
[`totalSize`](https://package.elm-lang.org/packages/viewengine/elm-table/latest/Table#totalSize).
Summing them all at once means the search for the first visible column does
not re-add a thousand widths on every frame.

-}
recompute : List WideRow -> Model -> Model
recompute data model =
    let
        core : Table.RowModel WideRow
        core =
            Table.coreRowModelFromList config model.state data

        columns : List (Table.Column WideRow)
        columns =
            Table.visibleLeafColumns config model.state
    in
    { model
        | core = core
        , rows = (Table.sortedRowModel config model.state core).rows
        , columns = columns
        , bounds =
            columns
                |> List.map (Table.getColumnSize config model.state)
                |> runningSum
                |> Array.fromList
        , totalWidth = Table.totalSize config model.state
    }


{-| `[ 0, w0, w0 + w1, ... ]`, one entry longer than the widths handed in.
-}
runningSum : List Float -> List Float
runningSum widths =
    List.foldl
        (\width totals ->
            case totals of
                previous :: _ ->
                    (previous + width) :: totals

                [] ->
                    [ width ]
        )
        [ 0 ]
        widths
        |> List.reverse



-- UPDATE


type Msg
    = SortClicked String Bool
    | RegenerateData
    | Scrolled Virtual.Scroll


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SortClicked columnId multi ->
            ( recompute (currentData model)
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
                salt : Int
                salt =
                    model.salt + 1
            in
            ( recompute (makeRows salt) { model | salt = salt }, Cmd.none )

        Scrolled scroll ->
            ( { model | scroll = scroll }, Cmd.none )


currentData : Model -> List WideRow
currentData model =
    List.map Table.rowOriginal model.core.rows



-- VIEW


view : Model -> Html Msg
view model =
    let
        columnWindow : Virtual.Window
        columnWindow =
            Virtual.variable
                { bounds = model.bounds, viewport = containerWidth, overscan = overscan }
                model.scroll.left

        rowWindow : Virtual.Window
        rowWindow =
            Virtual.fixed
                { itemSize = rowHeight
                , itemCount = List.length model.rows
                , viewport = containerHeight
                , overscan = overscan
                }
                model.scroll.top

        renderedColumns : List (Table.Column WideRow)
        renderedColumns =
            Virtual.slice columnWindow model.columns

        -- The left spacer is exactly `getColumnStart` of the first rendered
        -- column, and the right one is whatever is left of `totalSize` after
        -- the last rendered column ends. Both are computed once here rather
        -- than once per row.
        spacers : ( Float, Float )
        spacers =
            spacerWidths model renderedColumns
    in
    div [ class "demo-root" ]
        [ div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ] ]
        , p []
            [ text (Controls.formatInt (List.length model.columns) ++ " columns, ")
            , text (Controls.formatInt (List.length model.rows) ++ " rows. ")
            , text
                ("Showing "
                    ++ String.fromInt columnWindow.count
                    ++ " columns and "
                    ++ String.fromInt rowWindow.count
                    ++ " rows."
                )
            ]
        , div
            [ class "virtual-container"
            , style "height" (px containerHeight)
            , style "width" (px containerWidth)
            , Virtual.onScroll Scrolled
            ]
            [ table [ class "virtual-grid", style "width" (px model.totalWidth) ]
                [ thead [] [ tr [] (viewHeaderRow model spacers renderedColumns) ]
                , tbody []
                    (spacerRow renderedColumns rowWindow.before
                        :: List.map (viewRow model spacers renderedColumns) (Virtual.slice rowWindow model.rows)
                        ++ [ spacerRow renderedColumns rowWindow.after ]
                    )
                ]
            ]
        , p [ class "muted" ]
            [ text "Scroll sideways as well as down. The empty cell on each side of the row is as wide as the columns it stands in for, which is what keeps the scroll bar honest." ]
        ]


{-| The rendered header cells with a spacer on either side.
-}
viewHeaderRow : Model -> ( Float, Float ) -> List (Table.Column WideRow) -> List (Html Msg)
viewHeaderRow model ( before, after ) renderedColumns =
    spacerCell before
        :: List.map (viewHeaderCell model) renderedColumns
        ++ [ spacerCell after ]


spacerWidths : Model -> List (Table.Column WideRow) -> ( Float, Float )
spacerWidths model renderedColumns =
    case ( List.head renderedColumns, List.head (List.reverse renderedColumns) ) of
        ( Just firstColumn, Just lastColumn ) ->
            ( Table.getColumnStart config model.state Table.allColumnsRegion firstColumn
            , model.totalWidth
                - Table.getColumnStart config model.state Table.allColumnsRegion lastColumn
                - Table.getColumnSize config model.state lastColumn
            )

        _ ->
            ( 0, model.totalWidth )


spacerCell : Float -> Html Msg
spacerCell width =
    th [ class "virtual-spacer", style "width" (px width) ] []


{-| One empty row standing in for the rows above or below the window. It
spans every cell in the row, spacers included, so the fixed table layout
still takes its widths from the header.
-}
spacerRow : List (Table.Column WideRow) -> Float -> Html Msg
spacerRow renderedColumns height =
    tr [ style "height" (px height) ]
        [ td
            [ class "virtual-spacer"
            , colspan (List.length renderedColumns + 2)
            , style "height" (px height)
            ]
            []
        ]


viewHeaderCell : Model -> Table.Column WideRow -> Html Msg
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


viewRow : Model -> ( Float, Float ) -> List (Table.Column WideRow) -> Table.Row WideRow -> Html Msg
viewRow model ( before, after ) renderedColumns row =
    tr []
        (bodySpacer before
            :: List.map (viewCell model row) renderedColumns
            ++ [ bodySpacer after ]
        )


bodySpacer : Float -> Html Msg
bodySpacer width =
    td [ class "virtual-spacer", style "width" (px width) ] []


viewCell : Model -> Table.Row WideRow -> Table.Column WideRow -> Html Msg
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
