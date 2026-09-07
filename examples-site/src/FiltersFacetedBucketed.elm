module FiltersFacetedBucketed exposing (main)

{-| Ports `examples/react/filters-faceted-bucketed/src/main.tsx`.

Continuous values (a login time, a byte count) are bucketed without a hidden
derived column: one set of bucket definitions feeds both

  - `Table.withGetUniqueValues`, so `Table.facetedUniqueValues` counts
    buckets instead of raw values, and
  - a `FilterFn` whose `resolveDataValue` maps a cell to its bucket key,

which is exactly what `constructFilterFn` does in the React example. Tick
more than one bucket to match either; the counts react to the filters on the
other columns.

-}

import Browser
import FiltersFacetedBucketed.Accounts as Accounts exposing (Account)
import Html exposing (Html, button, div, fieldset, h1, input, label, p, span, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (checked, class, colspan, placeholder, type_, value)
import Html.Events exposing (onClick, onInput)
import Shared.Controls as Controls
import Table
import Table.FilterFn as FilterFn exposing (FilterFn)
import Table.Value as Value exposing (Value)
import Time



-- BUCKETS


type alias Bucket =
    { value : String
    , label : String
    , test : Value -> Bool
    }


{-| Relative date buckets need a stable reference time.
-}
now : Int
now =
    Time.posixToMillis Accounts.referenceDate


day : Int
day =
    24 * 60 * 60 * 1000


startOfToday : Int
startOfToday =
    now - modBy day now


startOfYesterday : Int
startOfYesterday =
    startOfToday - day


startOfWeek : Int
startOfWeek =
    startOfToday - (daysSinceMonday * day)


daysSinceMonday : Int
daysSinceMonday =
    case Time.toWeekday Time.utc Accounts.referenceDate of
        Time.Mon ->
            0

        Time.Tue ->
            1

        Time.Wed ->
            2

        Time.Thu ->
            3

        Time.Fri ->
            4

        Time.Sat ->
            5

        Time.Sun ->
            6


startOfMonth : Int
startOfMonth =
    startOfToday - ((Time.toDay Time.utc Accounts.referenceDate - 1) * day)


lastLoginBuckets : List Bucket
lastLoginBuckets =
    [ Bucket "today" "Today" (atOrAfter startOfToday)
    , Bucket "yesterday" "Yesterday" (atOrAfter startOfYesterday)
    , Bucket "this-week" "This week" (atOrAfter startOfWeek)
    , Bucket "this-month" "This month" (atOrAfter startOfMonth)
    , Bucket "older" "Older" (always True)
    ]


atOrAfter : Int -> Value -> Bool
atOrAfter millis v =
    case v of
        Value.Date posix ->
            Time.posixToMillis posix >= millis

        _ ->
            False


gigabyte : Float
gigabyte =
    1024 * 1024 * 1024


storageBuckets : List Bucket
storageBuckets =
    [ Bucket "under-1-gb" "< 1 GB" (below gigabyte)
    , Bucket "1-to-10-gb" "1–10 GB" (below (10 * gigabyte))
    , Bucket "10-to-100-gb" "10–100 GB" (below (100 * gigabyte))
    , Bucket "100-gb-plus" "100+ GB" (always True)
    ]


below : Float -> Value -> Bool
below limit v =
    Value.toNumber v < limit


{-| The first bucket whose test passes, as its key.
-}
bucketKey : List Bucket -> Value -> String
bucketKey buckets v =
    List.filter (\bucket -> bucket.test v) buckets
        |> List.head
        |> Maybe.map .value
        |> Maybe.withDefault ""


{-| Faceting and filtering deliberately share the same bucket definitions.
The column keeps its raw value for rendering and every other operation.
-}
bucketFilter : List Bucket -> FilterFn
bucketFilter buckets =
    FilterFn.custom (\bucketValue selected -> List.member bucketValue (itemsOf selected))
        |> FilterFn.withResolveDataValue (bucketKey buckets >> Value.String)
        |> FilterFn.withAutoRemove (itemsOf >> List.isEmpty)


itemsOf : Value -> List Value
itemsOf v =
    case v of
        Value.List items ->
            items

        _ ->
            []



-- CONFIG


config : Table.Config Account
config =
    Table.config
        [ Table.column "name" (.name >> Value.String)
            |> Table.withHeader "Account"
            |> Table.withFilterFn FilterFn.includesString
        , Table.column "lastLogin" (.lastLogin >> Value.Date)
            |> Table.withHeader "Last login"
            |> Table.withGetUniqueValues
                (\row -> [ Value.String (bucketKey lastLoginBuckets (Value.Date row.lastLogin)) ])
            |> Table.withFilterFn (bucketFilter lastLoginBuckets)
        , Table.column "storageBytes" (.storageBytes >> Value.Number)
            |> Table.withHeader "Storage"
            |> Table.withGetUniqueValues
                (\row -> [ Value.String (bucketKey storageBuckets (Value.Number row.storageBytes)) ])
            |> Table.withFilterFn (bucketFilter storageBuckets)
        , Table.column "files" (.files >> toFloat >> Value.Number)
            |> Table.withHeader "Files"
            |> Table.withEnableColumnFilter False
        ]
        |> Table.withGetRowId (\a _ _ -> a.id)


bucketsFor : String -> Maybe (List Bucket)
bucketsFor columnId =
    case columnId of
        "lastLogin" ->
            Just lastLoginBuckets

        "storageBytes" ->
            Just storageBuckets

        _ ->
            Nothing



-- MODEL


rowCount : Int
rowCount =
    5000


type alias Model =
    { state : Table.State
    , seed : Int
    , data : List Account
    }


init : Model
init =
    { state = Table.initialState
    , seed = 42
    , data = Accounts.makeData 42 rowCount
    }


type alias Stages =
    { core : Table.RowModel Account
    , prePaginated : Table.RowModel Account
    , paginated : Table.RowModel Account
    }


stages : Model -> Stages
stages model =
    let
        core : Table.RowModel Account
        core =
            Table.coreRowModelFromList config model.state model.data

        prePaginated : Table.RowModel Account
        prePaginated =
            core
                |> Table.filteredRowModel config model.state
                |> Table.groupedRowModel config model.state
                |> Table.sortedRowModel config model.state
                |> Table.expandedRowModel config model.state
    in
    { core = core
    , prePaginated = prePaginated
    , paginated = Table.paginatedRowModel config model.state prePaginated
    }



-- UPDATE


type Msg
    = RegenerateData
    | ClearFilters
    | FilterChanged String Value
    | BucketToggled String String
    | FirstPage
    | PreviousPage
    | NextPage
    | LastPage
    | GoToPage String
    | SetPageSize String


update : Msg -> Model -> Model
update msg model =
    case msg of
        RegenerateData ->
            let
                seed : Int
                seed =
                    model.seed + 1
            in
            { model | seed = seed, data = Accounts.makeData seed rowCount }

        ClearFilters ->
            { model | state = Table.resetColumnFilters model.state }

        FilterChanged columnId v ->
            { model
                | state =
                    Table.setColumnFilter config (stages model).core columnId v model.state
            }

        BucketToggled columnId bucket ->
            let
                selected : List Value
                selected =
                    Table.getFilterValue model.state columnId
                        |> Maybe.map itemsOf
                        |> Maybe.withDefault []

                next : List Value
                next =
                    if List.member (Value.String bucket) selected then
                        List.filter (\v -> v /= Value.String bucket) selected

                    else
                        selected ++ [ Value.String bucket ]
            in
            { model
                | state =
                    Table.setColumnFilter config
                        (stages model).core
                        columnId
                        (Value.List next)
                        model.state
            }

        FirstPage ->
            { model | state = Table.firstPage config model.state }

        PreviousPage ->
            { model | state = Table.previousPage config model.state }

        NextPage ->
            { model | state = Table.nextPage config model.state }

        LastPage ->
            { model | state = Table.lastPage config model.state (stages model).prePaginated }

        GoToPage text ->
            { model
                | state =
                    Table.setPage config
                        (Maybe.withDefault 1 (String.toInt text) - 1)
                        model.state
            }

        SetPageSize text ->
            { model
                | state = Table.setPageSize (Maybe.withDefault 10 (String.toInt text)) model.state
            }



-- VIEW


view : Model -> Html Msg
view model =
    let
        current : Stages
        current =
            stages model

        state : Table.State
        state =
            model.state
    in
    div [ class "demo-root" ]
        [ h1 [] [ text "Bucketed faceted filters" ]
        , p [ class "muted" ]
            [ text "Bucket continuous values without a hidden derived column. Select more than one bucket to match either value; counts react to filters on the other columns." ]
        , div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ]
            , button [ onClick ClearFilters ] [ text "Clear all filters" ]
            ]
        , div [ class "spacer-sm" ] []
        , table []
            [ thead []
                [ tr []
                    (List.map (viewHeaderCell model current) (Table.flatHeaders config state))
                ]
            , tbody [] (List.map (viewRow model) current.paginated.rows)
            ]
        , div [ class "spacer-sm" ] []
        , Controls.pager
            { first = FirstPage
            , previous = PreviousPage
            , next = NextPage
            , last = LastPage
            , goToPage = GoToPage
            , setPageSize = SetPageSize
            , canPrevious = Table.getCanPreviousPage state
            , canNext = Table.getCanNextPage config state current.prePaginated
            , canLast = Table.getCanLastPage config state current.prePaginated
            , pageIndex = state.pagination.pageIndex
            , pageCount = Table.getPageCount config state current.prePaginated
            , pageSize = state.pagination.pageSize
            , pageSizes = [ 10, 20, 30, 40, 50 ]
            , showAll = False
            }
        , div [] [ text (Controls.formatInt (List.length current.prePaginated.rows) ++ " Rows") ]
        , Controls.stateDump state
        ]


viewHeaderCell : Model -> Stages -> Table.Header Account -> Html Msg
viewHeaderCell model current header =
    let
        columnId : String
        columnId =
            Table.headerColumnId header
    in
    th [ colspan (Table.headerColSpan header) ]
        [ div []
            [ text
                (Table.findColumn config columnId
                    |> Maybe.andThen Table.columnHeader
                    |> Maybe.withDefault columnId
                )
            ]
        , if Table.getCanFilter config columnId then
            viewFilter model current columnId

          else
            text ""
        ]


viewFilter : Model -> Stages -> String -> Html Msg
viewFilter model current columnId =
    let
        filterValue : Value
        filterValue =
            Maybe.withDefault Value.Null (Table.getFilterValue model.state columnId)
    in
    case bucketsFor columnId of
        Just buckets ->
            let
                counts : List ( Value, Int )
                counts =
                    Table.facetedUniqueValues config model.state current.core columnId
            in
            fieldset [ class "facet-options" ]
                (List.map (viewBucket columnId (itemsOf filterValue) counts) buckets)

        Nothing ->
            input
                [ type_ "text"
                , class "filter"
                , placeholder "Search…"
                , value (Value.toString filterValue)
                , onInput (Value.String >> FilterChanged columnId)
                ]
                []


viewBucket : String -> List Value -> List ( Value, Int ) -> Bucket -> Html Msg
viewBucket columnId selected counts bucket =
    let
        count : Int
        count =
            counts
                |> List.filter (\( v, _ ) -> v == Value.String bucket.value)
                |> List.head
                |> Maybe.map Tuple.second
                |> Maybe.withDefault 0
    in
    label []
        [ input
            [ type_ "checkbox"
            , checked (List.member (Value.String bucket.value) selected)
            , onClick (BucketToggled columnId bucket.value)
            ]
            []
        , span [] [ text bucket.label ]
        , span [ class "count" ] [ text (Controls.formatInt count) ]
        ]


viewRow : Model -> Table.Row Account -> Html Msg
viewRow model row =
    tr [] (List.map viewCell (Table.getAllCells config model.state row))


viewCell : Table.Cell -> Html Msg
viewCell cell =
    td []
        [ text
            (case cell.columnId of
                "storageBytes" ->
                    Accounts.formatBytes (Value.toNumber cell.value)

                "files" ->
                    Controls.formatInt (round (Value.toNumber cell.value))

                _ ->
                    Controls.valueToString cell.value
            )
        ]


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
