module ColumnResizing exposing (main)

{-| Column Resizing.

Ports `examples/react/column-resizing/src/main.tsx` from TanStack Table: a
grouped header tree whose every header carries a drag handle, the resize mode
select (`onChange` / `onEnd`), the resize direction select (`ltr` / `rtl`),
and the state dump.

The package has no DOM, so `header.getResizeHandler()` is split into the
three transitions the React handler performs internally:

  - `Table.startColumnResize` on `mousedown` and `touchstart`,
  - `Table.updateColumnResize` on every `mousemove` / `touchmove`,
  - `Table.endColumnResize` on `mouseup`, `touchend` and `touchcancel`.

Mouse moves arrive through `Browser.Events` subscriptions, which are only
installed while a drag is running, because the pointer leaves the 5-pixel
handle immediately. Touch moves are listened for on the handle itself: a
touch gesture keeps firing at the element its `touchstart` hit.

-}

import Browser
import Browser.Events
import Html exposing (Html, button, div, h2, option, pre, select, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, classList, colspan, selected, style, value)
import Html.Events exposing (on, onClick, onDoubleClick, preventDefaultOn)
import Json.Decode as Decode exposing (Decoder)
import Shared.People as People exposing (Person)
import Shared.StateJson as StateJson
import Table
import Table.Value as Value



-- COLUMNS


columns : List (Table.Column Person)
columns =
    [ Table.group "name"
        [ Table.column "firstName" (.firstName >> Value.String)
            |> Table.withHeader "firstName"
            |> Table.withFooter "firstName"

        -- , Table.withEnableResizing False   -- prevent this column from being resized
        -- , Table.withSize 180 |> Table.withMinSize 80 |> Table.withMaxSize 400
        , Table.column "lastName" (.lastName >> maybeString)
            |> Table.withHeader "Last Name"
            |> Table.withFooter "lastName"
        ]
        |> Table.withHeader "Name"
        |> Table.withFooter "name"
    , Table.group "info"
        [ Table.column "age" (.age >> toFloat >> Value.Number)
            |> Table.withHeader "Age"
            |> Table.withFooter "age"
        , Table.group "moreInfo"
            [ Table.column "visits" (.visits >> maybeNumber)
                |> Table.withHeader "Visits"
                |> Table.withFooter "visits"
            , Table.column "status" (.status >> People.statusToString >> Value.String)
                |> Table.withHeader "Status"
                |> Table.withFooter "status"
            , Table.column "progress" (.progress >> toFloat >> Value.Number)
                |> Table.withHeader "Profile Progress"
                |> Table.withFooter "progress"
            ]
            |> Table.withHeader "More Info"
        ]
        |> Table.withHeader "Info"
        |> Table.withFooter "info"
    ]


{-| The mode and the direction are table options, so the config is rebuilt
from the model rather than being a constant.
-}
configFor : Model -> Table.Config Person
configFor model =
    let
        base : Table.Config Person
        base =
            Table.config columns
                |> Table.withGetRowId (\person _ _ -> person.id)
    in
    { base
        | columnResizeMode = model.mode
        , columnResizeDirection = model.direction
    }


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
    , mode : Table.ColumnResizeMode
    , direction : Table.ColumnResizeDirection
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { state = Table.initialState
      , data = People.makeData 42 [ 10 ]
      , seed = 42
      , mode = Table.resizeOnChange
      , direction = Table.resizeLtr
      }
    , Cmd.none
    )


type Msg
    = RegenerateData
    | StressTest
    | ModeChanged String
    | DirectionChanged String
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
    let
        config : Table.Config Person
        config =
            configFor model
    in
    case msg of
        RegenerateData ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 10 ] }

        StressTest ->
            { model | seed = model.seed + 1, data = People.makeData (model.seed + 1) [ 100 ] }

        ModeChanged raw ->
            { model
                | mode =
                    if raw == "onEnd" then
                        Table.resizeOnEnd

                    else
                        Table.resizeOnChange
            }

        DirectionChanged raw ->
            { model
                | direction =
                    if raw == "rtl" then
                        Table.resizeRtl

                    else
                        Table.resizeLtr
            }

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

        -- `touchend` carries no position, so the drag ends at the last
        -- position `touchmove` reported, exactly as the source does.
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


{-| `Math.round(event.touches[0].clientX)`, the rounding the source applies
to a touch position.
-}
touchClientX : Decoder Float
touchClientX =
    Decode.at [ "touches", "0", "clientX" ] Decode.float
        |> Decode.map (round >> toFloat)



-- VIEW


view : Model -> Html Msg
view model =
    let
        config : Table.Config Person
        config =
            configFor model

        rowModel : Table.RowModel Person
        rowModel =
            Table.coreRowModelFromList config model.state model.data
    in
    div [ class "demo-root" ]
        [ div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ]
            , button [ onClick StressTest ] [ text "Stress Test (100 rows)" ]
            ]
        , div [ class "spacer-md" ] []
        , div [ class "controls" ]
            [ select [ class "outlined-control", onChange ModeChanged ]
                [ option [ value "onEnd", selected (model.mode == Table.resizeOnEnd) ]
                    [ text "Resize: \"onEnd\"" ]
                , option [ value "onChange", selected (model.mode == Table.resizeOnChange) ]
                    [ text "Resize: \"onChange\"" ]
                ]
            , select [ class "outlined-control", onChange DirectionChanged ]
                [ option [ value "ltr", selected (model.direction == Table.resizeLtr) ]
                    [ text "Resize Direction: \"ltr\"" ]
                , option [ value "rtl", selected (model.direction == Table.resizeRtl) ]
                    [ text "Resize Direction: \"rtl\"" ]
                ]
            ]
        , div [ style "direction" (directionName model.direction) ]
            [ div [ class "spacer-md" ] []
            , h2 [] [ text "<table/>" ]
            , div [ class "scroll-container" ]
                [ table [ style "width" (px (Table.centerTotalSize config model.state)) ]
                    [ thead []
                        (List.map (viewHeaderRow model config) (Table.headerGroups config model.state))
                    , tbody []
                        (List.map (viewRow model config) rowModel.rows)
                    ]
                ]
            , div [ class "spacer-md" ] []
            , h2 [] [ text "<div/> (CSS variables)" ]

            -- The same widths, written once as custom properties on the
            -- container instead of on every cell. Elm sets them through the
            -- `style` attribute as a whole, because `Html.Attributes.style`
            -- assigns a style property, which custom properties are not.
            , div [ class "scroll-container" ]
                [ div
                    [ class "divTable"
                    , Html.Attributes.attribute "style" (sizeVariables model config)
                    ]
                    [ div [ class "thead" ]
                        (List.map (viewVarHeaderRow model config) (Table.headerGroups config model.state))
                    , div [ class "tbody" ]
                        (List.map (viewVarRow config model.state) rowModel.rows)
                    ]
                ]
            ]
        , div [ class "spacer-md" ] []
        , pre [ class "state-dump" ] [ text (StateJson.dump model.state) ]
        ]


viewHeaderRow : Model -> Table.Config Person -> Table.HeaderGroup Person -> Html Msg
viewHeaderRow model config group =
    tr []
        (List.map
            (\header ->
                th
                    [ colspan (Table.headerColSpan header)
                    , style "width" (px (Table.getHeaderSize config model.state header))
                    ]
                    [ text (headerLabel config header)
                    , resizer model config header
                    ]
            )
            group.headers
        )


viewRow : Model -> Table.Config Person -> Table.Row Person -> Html Msg
viewRow model config row =
    tr []
        (List.map
            (\cell ->
                td [ style "width" (px (columnSize config model.state cell.columnId)) ]
                    [ text (Value.toString cell.value) ]
            )
            (Table.getAllCells config model.state row)
        )


viewVarHeaderRow : Model -> Table.Config Person -> Table.HeaderGroup Person -> Html Msg
viewVarHeaderRow model config group =
    div [ class "tr" ]
        (List.map
            (\header ->
                div
                    [ class "th"
                    , style "width" (varWidth "header" (Table.headerId header))
                    ]
                    [ text (headerLabel config header)
                    , resizer model config header
                    ]
            )
            group.headers
        )


viewVarRow : Table.Config Person -> Table.State -> Table.Row Person -> Html Msg
viewVarRow config state row =
    div [ class "tr" ]
        (List.map
            (\cell ->
                div
                    [ class "td"
                    , style "width" (varWidth "col" cell.columnId)
                    ]
                    [ text (Value.toString cell.value) ]
            )
            (Table.getAllCells config state row)
        )


{-| The drag handle. `mousedown` and `touchstart` both start the drag;
`touchmove` and `touchend` stay on the handle because a touch gesture keeps
firing at the element it started on. In `onEnd` mode the handle is offset by
the running `deltaOffset`, which is the preview line the React example draws.
-}
resizer : Model -> Table.Config Person -> Table.Header Person -> Html Msg
resizer model config header =
    if not (Table.headerCanResize config header) then
        text ""

    else
        div
            [ class "resizer"
            , class (directionName model.direction)
            , classList [ ( "isResizing", Table.headerIsResizing model.state header ) ]
            , style "transform" (previewOffset model header)
            , onDoubleClick (SizeReset (Table.headerColumnId header))
            , on "mousedown" (Decode.map (ResizeStarted header) clientX)
            , on "touchstart" (Decode.map (ResizeStarted header) touchClientX)
            , preventDefaultOn "touchmove" (Decode.map (\x -> ( ResizeMoved x, True )) touchClientX)
            , on "touchend" (Decode.succeed ResizeReleased)
            , on "touchcancel" (Decode.succeed ResizeReleased)
            ]
            []


previewOffset : Model -> Table.Header Person -> String
previewOffset model header =
    if model.mode == Table.resizeOnEnd && Table.headerIsResizing model.state header then
        let
            sign : Float
            sign =
                if model.direction == Table.resizeRtl then
                    -1

                else
                    1
        in
        "translateX("
            ++ px (sign * Maybe.withDefault 0 model.state.columnResizing.deltaOffset)
            ++ ")"

    else
        ""


{-| `--header-<id>-size` and `--col-<id>-size` for every header, the way the
performant example writes them, as one style attribute.
-}
sizeVariables : Model -> Table.Config Person -> String
sizeVariables model config =
    let
        forHeader : Table.Header Person -> List String
        forHeader header =
            [ "--header-" ++ Table.headerId header ++ "-size:" ++ px (Table.getHeaderSize config model.state header)
            , "--col-" ++ Table.headerColumnId header ++ "-size:" ++ px (columnSize config model.state (Table.headerColumnId header))
            ]
    in
    String.join ";"
        (("width:" ++ px (Table.totalSize config model.state))
            :: List.concatMap forHeader (Table.flatHeaders config model.state)
        )


varWidth : String -> String -> String
varWidth prefix id =
    "var(--" ++ prefix ++ "-" ++ id ++ "-size)"


onChange : (String -> Msg) -> Html.Attribute Msg
onChange toMsg =
    on "change" (Decode.map toMsg (Decode.at [ "target", "value" ] Decode.string))


directionName : Table.ColumnResizeDirection -> String
directionName direction =
    if direction == Table.resizeRtl then
        "rtl"

    else
        "ltr"


px : Float -> String
px n =
    String.fromFloat n ++ "px"


columnSize : Table.Config Person -> Table.State -> String -> Float
columnSize config state columnId =
    Table.findColumn config columnId
        |> Maybe.map (Table.getColumnSize config state)
        |> Maybe.withDefault 0


headerLabel : Table.Config Person -> Table.Header Person -> String
headerLabel config header =
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
