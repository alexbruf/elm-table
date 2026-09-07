module ColumnResizingPerformant exposing (main)

{-| Performant Column Resizing.

Ports `examples/react/column-resizing-performant/src/main.tsx` from TanStack
Table: the same drag as the Column Resizing example, with the body's widths
read from CSS custom properties instead of from the state.

The variables are `--header-<header id>-size` and `--col-<column id>-size`,
written once on the `<table>` element, exactly as the React example writes
them. Cells ask for `calc(var(--col-firstName-size) * 1px)`, so a drag
changes one style attribute on one element and the browser lays the rest out.

React needs this to keep a drag off its render path. Elm does not have that
problem: the virtual DOM diff of an unchanged subtree produces no DOM
patches, so an `onChange` drag is already cheap. What the CSS variables buy
here is that the body markup no longer mentions the state at all, which lets
`Html.Lazy.lazy2` skip rebuilding it altogether: during a drag the only
virtual DOM built is the header row. That is the Elm counterpart of the
React example's "subscribe to nothing" table body.

-}

import Browser
import Browser.Events
import Html exposing (Html, button, div, pre, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (attribute, class, classList, colspan)
import Html.Events exposing (on, onClick, onDoubleClick, preventDefaultOn)
import Html.Lazy exposing (lazy2)
import Json.Decode as Decode exposing (Decoder)
import Shared.People as People exposing (Person)
import Shared.StateJson as StateJson
import Table
import Table.Value as Value



-- COLUMNS


config : Table.Config Person
config =
    Table.config
        [ Table.group "name"
            [ Table.column "firstName" (.firstName >> Value.String)
                |> Table.withHeader "firstName"
            , Table.column "lastName" (.lastName >> maybeString)
                |> Table.withHeader "Last Name"
            ]
            |> Table.withHeader "Name"
        , Table.group "info"
            [ Table.column "age" (.age >> toFloat >> Value.Number)
                |> Table.withHeader "Age"
            , Table.column "visits" (.visits >> maybeNumber)
                |> Table.withHeader "Visits"
            , Table.column "status" (.status >> People.statusToString >> Value.String)
                |> Table.withHeader "Status"
            , Table.column "progress" (.progress >> toFloat >> Value.Number)
                |> Table.withHeader "Profile Progress"
            ]
            |> Table.withHeader "Info"
        ]
        |> Table.withGetRowId (\person _ _ -> person.id)
        |> Table.withDefaultColumn { size = 150, minSize = 60, maxSize = 800 }


maybeString : Maybe String -> Value.Value
maybeString =
    Maybe.map Value.String >> Maybe.withDefault Value.Null


maybeNumber : Maybe Int -> Value.Value
maybeNumber =
    Maybe.map (toFloat >> Value.Number) >> Maybe.withDefault Value.Null



-- MODEL


type alias Model =
    { state : Table.State
    , data : List Person
    , seed : Int
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { state = Table.initialState
      , data = People.makeData 42 [ 200 ]
      , seed = 42
      }
    , Cmd.none
    )


type Msg
    = RegenerateData
    | StressTest
    | ResizeStarted (Table.Header Person) Float
    | ResizeMoved Float
    | ResizeEnded Float
    | ResizeReleased
    | SizeReset String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( updateModel msg model, Cmd.none )


updateModel : Msg -> Model -> Model
updateModel msg model =
    case msg of
        RegenerateData ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 200 ] }

        StressTest ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 5000 ] }

        ResizeStarted header x ->
            { model | state = Table.startColumnResize config model.state header x }

        ResizeMoved x ->
            { model | state = Table.updateColumnResize config x model.state }

        ResizeEnded x ->
            { model
                | state =
                    model.state
                        |> Table.updateColumnResize config x
                        |> Table.endColumnResize config
            }

        ResizeReleased ->
            { model | state = Table.endColumnResize config model.state }

        SizeReset columnId ->
            { model | state = Table.resetColumnSize columnId model.state }


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.state.columnResizing.isResizingColumn of
        Nothing ->
            Sub.none

        Just _ ->
            Sub.batch
                [ Browser.Events.onMouseMove (Decode.map ResizeMoved clientX)
                , Browser.Events.onMouseUp (Decode.map ResizeEnded clientX)
                ]


clientX : Decoder Float
clientX =
    Decode.field "clientX" Decode.float


touchClientX : Decoder Float
touchClientX =
    Decode.at [ "touches", "0", "clientX" ] Decode.float
        |> Decode.map (round >> toFloat)



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "demo-root" ]
        [ div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ]
            , button [ onClick StressTest ] [ text "Stress Test (5k rows)" ]
            ]
        , div [ class "spacer-md" ] []
        , pre [ class "state-dump state-dump-short" ] [ text (StateJson.dump model.state) ]
        , div [ class "spacer-md" ] []
        , text ("(" ++ String.fromInt (List.length model.data) ++ " rows)")
        , div [ class "scroll-container" ]
            [ table [ attribute "style" (tableStyle model.state) ]
                [ thead [ attribute "style" "display:grid" ]
                    (List.map (viewHeaderRow model.state) (Table.headerGroups config model.state))

                -- The body never mentions the resize state, so `lazy2` skips
                -- rebuilding it while a column is being dragged.
                , lazy2 viewBody config model.data
                ]
            ]
        ]


{-| `display: grid`, the total width, and the two CSS variables per header,
written as one style attribute. `Html.Attributes.style` assigns a style
property, which a custom property is not, so the whole attribute is set at
once.
-}
tableStyle : Table.State -> String
tableStyle state =
    let
        variables : Table.Header Person -> List String
        variables header =
            [ "--header-" ++ Table.headerId header ++ "-size:" ++ sizeOf (Table.getHeaderSize config state header)
            , "--col-" ++ Table.headerColumnId header ++ "-size:" ++ sizeOf (columnSize state (Table.headerColumnId header))
            ]

        sizeOf : Float -> String
        sizeOf n =
            String.fromFloat n
    in
    String.join ";"
        ([ "display:grid"
         , "width:" ++ String.fromFloat (Table.totalSize config state) ++ "px"
         ]
            ++ List.concatMap variables (Table.flatHeaders config state)
        )


viewHeaderRow : Table.State -> Table.HeaderGroup Person -> Html Msg
viewHeaderRow state group =
    tr [ attribute "style" "display:flex;width:100%;height:30px" ]
        (List.map (viewHeaderCell state) group.headers)


viewHeaderCell : Table.State -> Table.Header Person -> Html Msg
viewHeaderCell state header =
    th
        [ colspan (Table.headerColSpan header)
        , attribute "style"
            ("display:flex;flex-shrink:0;width:calc(var(--header-"
                ++ Table.headerId header
                ++ "-size) * 1px)"
            )
        ]
        [ text (headerLabel header)
        , resizer state header
        ]


viewBody : Table.Config Person -> List Person -> Html Msg
viewBody cfg data =
    let
        -- Nothing in this example sorts, filters or paginates, so the row
        -- model is built from the initial state. That keeps the argument of
        -- `lazy2` stable while `model.state.columnSizing` changes.
        rowModel : Table.RowModel Person
        rowModel =
            Table.coreRowModelFromList cfg Table.initialState data
    in
    tbody [ attribute "style" "display:grid" ]
        (List.map (viewRow cfg) rowModel.rows)


viewRow : Table.Config Person -> Table.Row Person -> Html Msg
viewRow cfg row =
    tr
        [ attribute "style"
            -- Offscreen rows skip style recalculation and layout, so a live
            -- resize only lays out the rows actually on screen.
            "display:flex;width:100%;height:30px;content-visibility:auto;contain-intrinsic-height:auto 30px"
        ]
        (List.map viewCell (Table.getAllCells cfg Table.initialState row))


viewCell : Table.Cell -> Html Msg
viewCell cell =
    td
        [ attribute "style"
            ("display:flex;flex-shrink:0;width:calc(var(--col-"
                ++ cell.columnId
                ++ "-size) * 1px)"
            )
        ]
        [ text (Value.toString cell.value) ]


resizer : Table.State -> Table.Header Person -> Html Msg
resizer state header =
    if not (Table.headerCanResize config header) then
        text ""

    else
        div
            [ class "resizer"
            , classList [ ( "isResizing", Table.headerIsResizing state header ) ]
            , onDoubleClick (SizeReset (Table.headerColumnId header))
            , on "mousedown" (Decode.map (ResizeStarted header) clientX)
            , on "touchstart" (Decode.map (ResizeStarted header) touchClientX)
            , preventDefaultOn "touchmove" (Decode.map (\x -> ( ResizeMoved x, True )) touchClientX)
            , on "touchend" (Decode.succeed ResizeReleased)
            , on "touchcancel" (Decode.succeed ResizeReleased)
            ]
            []


columnSize : Table.State -> String -> Float
columnSize state columnId =
    Table.findColumn config columnId
        |> Maybe.map (Table.getColumnSize config state)
        |> Maybe.withDefault 0


headerLabel : Table.Header Person -> String
headerLabel header =
    if Table.headerIsPlaceholder header then
        ""

    else
        Table.findColumn config (Table.headerColumnId header)
            |> Maybe.andThen Table.columnHeader
            |> Maybe.withDefault (Table.headerColumnId header)


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
