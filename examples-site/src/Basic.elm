module Basic exposing (main)

{-| Ports `examples/react/basic-use-table/src/main.tsx`.

The smallest possible table: four literal rows, six columns, no feature
state at all. `Table.rowsFromList` still runs the whole pipeline; with an
empty `Table.State` every stage is the identity.

-}

import Browser
import Html exposing (Html, div, i, table, tbody, td, text, tfoot, th, thead, tr)
import Html.Attributes exposing (class, colspan)
import Table
import Table.Value as Value



-- DATA


type alias Person =
    { firstName : String
    , lastName : String
    , age : Int
    , visits : Int
    , status : String
    , progress : Int
    }


defaultData : List Person
defaultData =
    [ Person "tanner" "linsley" 24 100 "In Relationship" 50
    , Person "tandy" "miller" 40 40 "Single" 80
    , Person "joe" "dirte" 45 20 "Complicated" 10
    , Person "kevin" "vandy" 12 100 "Single" 70
    ]



-- CONFIG


config : Table.Config Person
config =
    Table.config
        [ Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "First Name"
        , Table.column "lastName" (.lastName >> Value.String)
            |> Table.withHeader "Last Name"
        , Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
        , Table.column "visits" (.visits >> toFloat >> Value.Number)
            |> Table.withHeader "Visits"
        , Table.column "status" (.status >> Value.String)
            |> Table.withHeader "Status"
        , Table.column "progress" (.progress >> toFloat >> Value.Number)
            |> Table.withHeader "Profile Progress"
        ]



-- MODEL


type alias Model =
    { state : Table.State
    , data : List Person
    }


init : Model
init =
    { state = Table.initialState
    , data = defaultData
    }


type Msg
    = NoOp


update : Msg -> Model -> Model
update _ model =
    model



-- VIEW


view : Model -> Html Msg
view model =
    let
        rowModel : Table.RowModel Person
        rowModel =
            Table.rowsFromList config model.state model.data
    in
    div [ class "demo-root" ]
        [ table []
            [ thead [] (List.map viewHeaderRow (Table.headerGroups config model.state))
            , tbody [] (List.map (viewRow model.state) rowModel.rows)
            , tfoot [] (List.map viewFooterRow (Table.footerGroups config model.state))
            ]
        , div [ class "spacer-md" ] []
        ]


viewHeaderRow : Table.HeaderGroup Person -> Html Msg
viewHeaderRow group =
    tr [] (List.map viewHeaderCell group.headers)


viewHeaderCell : Table.Header Person -> Html Msg
viewHeaderCell header =
    th [ colspan (Table.headerColSpan header) ]
        [ if Table.headerIsPlaceholder header then
            text ""

          else
            text (headerLabel (Table.headerColumnId header))
        ]


viewFooterRow : Table.HeaderGroup Person -> Html Msg
viewFooterRow group =
    tr [] (List.map viewFooterCell group.headers)


viewFooterCell : Table.Header Person -> Html Msg
viewFooterCell header =
    -- No column in this example declares a footer, so, exactly like the
    -- React example, the `<tfoot>` row renders empty cells.
    th [ colspan (Table.headerColSpan header) ]
        [ text
            (Table.findColumn config (Table.headerColumnId header)
                |> Maybe.andThen Table.columnFooter
                |> Maybe.withDefault ""
            )
        ]


headerLabel : String -> String
headerLabel columnId =
    Table.findColumn config columnId
        |> Maybe.andThen Table.columnHeader
        |> Maybe.withDefault columnId


viewRow : Table.State -> Table.Row Person -> Html Msg
viewRow state row =
    tr [] (List.map viewCell (Table.getAllCells config state row))


viewCell : Table.Cell -> Html Msg
viewCell cell =
    td []
        [ if cell.columnId == "lastName" then
            i [] [ text (Value.toString cell.value) ]

          else
            text (Value.toString cell.value)
        ]


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
