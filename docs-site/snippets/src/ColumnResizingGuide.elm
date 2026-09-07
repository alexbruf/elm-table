module ColumnResizingGuide exposing (..)

import Browser.Events
import Dict
import Html exposing (Html, div, table, td, text, th)
import Html.Attributes exposing (attribute, class, classList, style)
import Html.Events
import Html.Lazy
import Json.Decode as Decode
import Shared.People exposing (Person)
import Table
import Table.Value as Value


config : Table.Config Person
config =
    let
        base : Table.Config Person
        base =
            Table.config
                [ Table.column "firstName" (.firstName >> Value.String)
                    |> Table.withHeader "First name"
                , Table.column "lastName" (.lastName >> Value.String)
                    |> Table.withHeader "Last name"
                , Table.column "age" (.age >> toFloat >> Value.Number)
                    |> Table.withHeader "Age"
                    |> Table.withEnableResizing False
                ]
                |> Table.withDefaultColumn { size = 150, minSize = 60, maxSize = 800 }
    in
    { base
        | enableColumnResizing = True
        , columnResizeMode = Table.resizeOnChange
        , columnResizeDirection = Table.resizeLtr
    }


onEndConfig : Table.Config Person -> Table.Config Person
onEndConfig cfg =
    { cfg | columnResizeMode = Table.resizeOnEnd }


rtlConfig : Table.Config Person -> Table.Config Person
rtlConfig cfg =
    { cfg | columnResizeDirection = Table.resizeRtl }


type alias Model =
    { state : Table.State
    , data : List Person
    }


type Msg
    = ResizeStarted (Table.Header Person) Float
    | ResizeMoved Float
    | ResizeEnded Float
    | ResizeReleased
    | SizeReset String


update : Msg -> Model -> Model
update msg model =
    case msg of
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


clientX : Decode.Decoder Float
clientX =
    Decode.field "clientX" Decode.float


touchClientX : Decode.Decoder Float
touchClientX =
    Decode.at [ "touches", "0", "clientX" ] Decode.float
        |> Decode.map (round >> toFloat)


resizeHandle : Table.State -> Table.Header Person -> Html Msg
resizeHandle state header =
    if not (Table.headerCanResize config header) then
        text ""

    else
        div
            [ class "resizer"
            , classList [ ( "is-resizing", Table.headerIsResizing state header ) ]
            , Html.Events.onDoubleClick (SizeReset (Table.headerColumnId header))
            , Html.Events.on "mousedown" (Decode.map (ResizeStarted header) clientX)
            , Html.Events.on "touchstart" (Decode.map (ResizeStarted header) touchClientX)
            , Html.Events.preventDefaultOn "touchmove"
                (Decode.map (\x -> ( ResizeMoved x, True )) touchClientX)
            , Html.Events.on "touchend" (Decode.succeed ResizeReleased)
            , Html.Events.on "touchcancel" (Decode.succeed ResizeReleased)
            ]
            []


viewHeaderCell : Table.State -> Table.Header Person -> Html Msg
viewHeaderCell state header =
    th
        [ style "width" (String.fromFloat (Table.getHeaderSize config state header) ++ "px")
        , style "position" "relative"
        ]
        [ text (Maybe.withDefault "" (headerText header))
        , resizeHandle state header
        ]


headerText : Table.Header Person -> Maybe String
headerText header =
    Table.findColumn config (Table.headerColumnId header)
        |> Maybe.andThen Table.columnHeader


resizeIndicator : Table.State -> Table.Header Person -> Html msg
resizeIndicator state header =
    let
        offset : Float
        offset =
            if Table.headerIsResizing state header then
                Maybe.withDefault 0 state.columnResizing.deltaOffset

            else
                0
    in
    div
        [ class "resize-indicator"
        , style "transform" ("translateX(" ++ String.fromFloat offset ++ "px)")
        ]
        []


{-| `--header-<id>-size` and `--col-<id>-size` for every header, as one style
attribute on the table element.
-}
sizeVariables : Table.State -> String
sizeVariables state =
    let
        forHeader : Table.Header Person -> List String
        forHeader header =
            [ "--header-" ++ Table.headerId header ++ "-size:" ++ px (Table.getHeaderSize config state header)
            , "--col-" ++ Table.headerColumnId header ++ "-size:" ++ px (columnWidth state (Table.headerColumnId header))
            ]
    in
    String.join ";"
        (("width:" ++ px (Table.totalSize config state))
            :: List.concatMap forHeader (Table.flatHeaders config state)
        )


columnWidth : Table.State -> String -> Float
columnWidth state columnId =
    Table.findColumn config columnId
        |> Maybe.map (Table.getColumnSize config state)
        |> Maybe.withDefault 0


px : Float -> String
px n =
    String.fromFloat n ++ "px"


viewTable : Model -> Html Msg
viewTable model =
    table [ attribute "style" (sizeVariables model.state) ]
        [ Html.thead []
            (List.map
                (\group -> Html.tr [] (List.map (viewHeaderCell model.state) group.headers))
                (Table.headerGroups config model.state)
            )
        , Html.Lazy.lazy viewBody model.data
        ]


viewBody : List Person -> Html Msg
viewBody data =
    let
        rowModel : Table.RowModel Person
        rowModel =
            Table.coreRowModelFromList config Table.initialState data
    in
    Html.tbody []
        (List.map
            (\row ->
                Html.tr []
                    (List.map viewCell (Table.getAllCells config Table.initialState row))
            )
            rowModel.rows
        )


viewCell : Table.Cell -> Html Msg
viewCell cell =
    td [ style "width" ("calc(var(--col-" ++ cell.columnId ++ "-size) * 1px)") ]
        [ text (Value.toString cell.value) ]


startingWidths : Table.State -> Table.State
startingWidths state =
    Table.setColumnSizing (Dict.fromList [ ( "firstName", 220 ), ( "lastName", 180 ) ]) state


clearDrag : Table.State -> Table.State
clearDrag state =
    Table.resetColumnResizing state
