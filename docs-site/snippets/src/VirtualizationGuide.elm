module VirtualizationGuide exposing (..)

import Html exposing (Html)
import Html.Attributes exposing (class, style)
import InfiniteList
import Shared.People exposing (Person, people)
import Table
import Table.Value as Value


columns : List (Table.Column Person)
columns =
    [ Table.column "firstName" (.firstName >> Value.String)
        |> Table.withHeader "First name"
        |> Table.withSize 160
    , Table.column "department" (.department >> Value.String)
        |> Table.withHeader "Department"
        |> Table.withSize 160
    ]


config : Table.Config Person
config =
    Table.config columns
        |> Table.withGetRowId (\person _ _ -> person.id)


everyRowOnOnePage : Table.State
everyRowOnOnePage =
    Table.setPageSize Table.unlimitedPageSize Table.initialState


stopBeforePagination : Table.State -> List (Table.Row Person)
stopBeforePagination state =
    Table.coreRowModelFromList config state people
        |> Table.filteredRowModel config state
        |> Table.groupedRowModel config state
        |> Table.sortedRowModel config state
        |> Table.prePaginationRowModel config state
        |> .rows


rowsToVirtualize : Table.State -> List (Table.Row Person)
rowsToVirtualize state =
    Table.rowsFromList config state people
        |> Table.rowsInDisplayOrder config state


rowKeys : Table.State -> List String
rowKeys state =
    List.map Table.rowId (rowsToVirtualize state)


type alias Model =
    { state : Table.State
    , rows : List (Table.Row Person)
    , list : InfiniteList.Model
    }


init : Model
init =
    recompute { state = Table.initialState, rows = [], list = InfiniteList.init }


{-| Run the pipeline once, here, rather than once per scroll event in `view`.
-}
recompute : Model -> Model
recompute model =
    { model | rows = stopBeforePagination model.state }


type Msg
    = Scrolled InfiniteList.Model
    | SortClicked String Bool


update : Msg -> Model -> Model
update msg model =
    case msg of
        Scrolled list ->
            { model | list = list }

        SortClicked columnId multi ->
            recompute
                { model
                    | state =
                        Table.toggleSort config
                            (Table.coreRowModelFromList config model.state people)
                            columnId
                            { desc = Nothing, multi = multi }
                            model.state
                }


rowHeight : Int
rowHeight =
    33


listConfig : InfiniteList.Config (Table.Row Person) Msg
listConfig =
    InfiniteList.config
        { itemView = \_ _ row -> viewRow row
        , itemHeight = InfiniteList.withConstantHeight rowHeight
        , containerHeight = 400
        }


viewRows : Model -> Html Msg
viewRows model =
    Html.div
        [ class "virtual-container"
        , style "height" "400px"
        , style "overflow" "auto"
        , InfiniteList.onScroll Scrolled
        ]
        [ InfiniteList.view listConfig model.list model.rows ]


viewRow : Table.Row Person -> Html Msg
viewRow row =
    let
        person : Person
        person =
            Table.rowOriginal row
    in
    Html.tr [] [ Html.td [] [ Html.text person.firstName ], Html.td [] [ Html.text person.department ] ]


stopAfterExpanding : Table.State -> List (Table.Row Person)
stopAfterExpanding state =
    Table.coreRowModelFromList config state people
        |> Table.filteredRowModel config state
        |> Table.groupedRowModel config state
        |> Table.sortedRowModel config state
        |> Table.expandedRowModel config state
        |> .rows


{-| One entry per column, plus a last entry for the whole table: the same
running sum `getColumnStart` and `totalSize` already describe, computed once
instead of once per rendered cell.
-}
columnBounds : Table.State -> List Float
columnBounds state =
    Table.visibleLeafColumns config state
        |> List.map (Table.getColumnSize config state)
        |> runningSum


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


leftSpacerWidth : Table.State -> Table.Column Person -> Float
leftSpacerWidth state column =
    Table.getColumnStart config state Table.allColumnsRegion column


rightSpacerWidth : Table.State -> Table.Column Person -> Float
rightSpacerWidth state column =
    Table.totalSize config state
        - Table.getColumnStart config state Table.allColumnsRegion column
        - Table.getColumnSize config state column


fetchThreshold : Float
fetchThreshold =
    500


{-| TanStack's whole `fetchMoreOnBottomReached`, as a function of the numbers
a scroll event already carries rather than a DOM measurement.
-}
shouldFetchMore :
    { loadedRows : Int, rowHeight : Float, scrollTop : Float, viewportHeight : Float, totalRows : Int }
    -> Bool
shouldFetchMore args =
    let
        remaining : Float
        remaining =
            (toFloat args.loadedRows * args.rowHeight) - args.scrollTop - args.viewportHeight
    in
    args.loadedRows < args.totalRows && remaining < fetchThreshold
