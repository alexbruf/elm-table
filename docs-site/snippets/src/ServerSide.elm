module ServerSide exposing (..)

import Shared.People exposing (Person)
import Table
import Table.FilterFn as FilterFn
import Table.Value as Value


type alias Model =
    { state : Table.State
    , page : List Person
    , totalRows : Maybe Int
    , loading : Bool
    }


type Msg
    = SortBy String
    | GoToPage Int
    | GotPage (List Person) Int


columns : List (Table.Column Person)
columns =
    [ Table.column "firstName" (.firstName >> Value.String)
        |> Table.withHeader "First name"
        |> Table.withFilterFn FilterFn.includesString
    , Table.column "department" (.department >> Value.String)
        |> Table.withHeader "Department"
    , Table.column "salary" (.salary >> Value.Number)
        |> Table.withHeader "Salary"
    ]


serverConfig : Maybe Int -> Table.Config Person
serverConfig totalRows =
    let
        base : Table.Config Person
        base =
            Table.config columns
                |> Table.withGetRowId (\person _ _ -> person.id)
    in
    { base
        | manualFiltering = True
        , manualSorting = True
        , manualPagination = True
        , rowCount = totalRows
    }


{-| Stand-in for your own request. Swap it for whatever your application
uses; the package never fetches anything.
-}
fetchPage : Table.State -> Cmd Msg
fetchPage _ =
    Cmd.none


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        cfg : Table.Config Person
        cfg =
            serverConfig model.totalRows
    in
    case msg of
        SortBy columnId ->
            let
                next : Table.State
                next =
                    Table.toggleSort cfg
                        (Table.coreRowModelFromList cfg model.state model.page)
                        columnId
                        { desc = Nothing, multi = False }
                        model.state
                        |> Table.resetPageIndex cfg
            in
            ( { model | state = next, loading = True }, fetchPage next )

        GoToPage index ->
            let
                next : Table.State
                next =
                    Table.setPage cfg index model.state
            in
            ( { model | state = next, loading = True }, fetchPage next )

        GotPage rows total ->
            ( { model | page = rows, totalRows = Just total, loading = False }
            , Cmd.none
            )


currentRows : Model -> Table.RowModel Person
currentRows model =
    Table.rowsFromList (serverConfig model.totalRows) model.state model.page
