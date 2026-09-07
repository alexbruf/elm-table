module HeaderGroups exposing (main)

{-| Ports `examples/react/header-groups/src/main.tsx`.

Four column trees over the same five rows:

1.  an even tree of one group per pair of leaf columns,
2.  groups nested inside groups, still even,
3.  a tree that forces placeholder headers,
4.  an uneven tree, where the placeholder at the top of a chain carries the
    chain's `rowSpan` and the headers it covers report `0`.

-}

import Browser
import Html exposing (Html, button, div, h2, section, table, tbody, td, text, tfoot, th, thead, tr)
import Html.Attributes exposing (class, colspan, rowspan)
import Html.Events exposing (onClick)
import Shared.People as People exposing (Person)
import Table
import Table.Value as Value exposing (Value)



-- COLUMN TREES


{-| A traditional header group setup: every leaf column sits under a
top-level group, so the tree is even (2 header rows) and no placeholder
headers are created.
-}
basicConfig : Table.Config Person
basicConfig =
    Table.config
        [ Table.group "name"
            [ firstName |> Table.withHeader "First Name" |> Table.withFooter "First Name"
            , lastName |> Table.withHeader "Last Name" |> Table.withFooter "Last Name"
            ]
            |> Table.withHeader "Name"
        , Table.group "stats"
            [ age |> Table.withHeader "Age" |> Table.withFooter "Age"
            , visits |> Table.withHeader "Visits" |> Table.withFooter "Visits"
            ]
            |> Table.withHeader "Stats"
        , Table.group "profile"
            [ status |> Table.withHeader "Status" |> Table.withFooter "Status"
            , progress
                |> Table.withHeader "Profile Progress"
                |> Table.withFooter "Profile Progress"
            ]
            |> Table.withHeader "Profile"
        ]
        |> withRowId


{-| Groups nested inside groups, with every leaf column at the same depth.
The tree stays even, so there are three header rows and still no
placeholders, and each group's colSpan is the sum of its descendants.
-}
nestedConfig : Table.Config Person
nestedConfig =
    Table.config
        [ Table.group "person"
            [ Table.group "name"
                [ firstName |> Table.withHeader "First Name"
                , lastName |> Table.withHeader "Last Name"
                ]
                |> Table.withHeader "Name"
            , Table.group "demographics"
                [ age |> Table.withHeader "Age" ]
                |> Table.withHeader "Demographics"
            ]
            |> Table.withHeader "Person"
        , Table.group "activity"
            [ Table.group "engagement"
                [ visits |> Table.withHeader "Visits"
                , status |> Table.withHeader "Status"
                ]
                |> Table.withHeader "Engagement"
            , Table.group "progressGroup"
                [ progress |> Table.withHeader "Profile Progress" ]
                |> Table.withHeader "Progress"
            ]
            |> Table.withHeader "Activity"
        ]
        |> withRowId


{-| `More Info` sits one level below `Age`, so the header row above `Age`'s
siblings holds placeholder headers.
-}
placeholderConfig : Table.Config Person
placeholderConfig =
    Table.config
        [ Table.group "hello"
            [ firstName |> Table.withFooter "firstName"
            , lastName |> Table.withHeader "Last Name" |> Table.withFooter "lastName"
            ]
            |> Table.withHeader "Hello"
        , Table.group "Info"
            [ age |> Table.withHeader "Age" |> Table.withFooter "age"
            , Table.group "More Info"
                [ visits |> Table.withHeader "Visits" |> Table.withFooter "visits"
                , status |> Table.withHeader "Status" |> Table.withFooter "status"
                , progress
                    |> Table.withHeader "Profile Progress"
                    |> Table.withFooter "progress"
                ]
                |> Table.withHeader "More Info"
            ]
            |> Table.withHeader "Info"
            |> Table.withFooter "Info"
        ]
        |> withRowId


{-| An uneven column tree: `fullName` and `progress` are top-level leaf
columns while their siblings nest two and three levels deep.
-}
unevenConfig : Table.Config Person
unevenConfig =
    Table.config
        [ Table.column "fullName" fullNameValue
            |> Table.withHeader "Full Name"
        , Table.group "Info"
            [ age |> Table.withHeader "Age"
            , Table.group "More Info"
                [ visits |> Table.withHeader "Visits"
                , status |> Table.withHeader "Status"
                ]
                |> Table.withHeader "More Info"
            ]
            |> Table.withHeader "Info"
        , progress |> Table.withHeader "Profile Progress"
        ]
        |> withRowId


withRowId : Table.Config Person -> Table.Config Person
withRowId =
    Table.withGetRowId (\person _ _ -> person.id)


firstName : Table.Column Person
firstName =
    Table.column "firstName" (.firstName >> Value.String)


lastName : Table.Column Person
lastName =
    Table.column "lastName" (.lastName >> maybeString)


age : Table.Column Person
age =
    Table.column "age" (.age >> toFloat >> Value.Number)


visits : Table.Column Person
visits =
    Table.column "visits" (.visits >> maybeNumber)


status : Table.Column Person
status =
    Table.column "status" (.status >> People.statusToString >> Value.String)


progress : Table.Column Person
progress =
    Table.column "progress" (.progress >> toFloat >> Value.Number)


fullNameValue : Person -> Value
fullNameValue person =
    Value.String
        (String.join " "
            (List.filter (\part -> part /= "")
                [ person.firstName, Maybe.withDefault "" person.lastName ]
            )
        )


maybeString : Maybe String -> Value
maybeString =
    Maybe.map Value.String >> Maybe.withDefault Value.Null


maybeNumber : Maybe Int -> Value
maybeNumber =
    Maybe.map (toFloat >> Value.Number) >> Maybe.withDefault Value.Null



-- MODEL


type alias Model =
    { state : Table.State
    , seed : Int
    , data : List Person
    }


init : Model
init =
    { state = Table.initialState
    , seed = 42
    , data = People.makeData 42 [ 5 ]
    }


type Msg
    = RegenerateData


update : Msg -> Model -> Model
update msg model =
    case msg of
        RegenerateData ->
            let
                seed : Int
                seed =
                    model.seed + 1
            in
            { model | seed = seed, data = People.makeData seed [ 5 ] }



-- VIEW


type Footers
    = NoFooters
    | AllFooters
    | FootersWithText


view : Model -> Html Msg
view model =
    div [ class "demo-root" ]
        [ div [ class "button-row" ]
            [ button [ onClick RegenerateData ] [ text "Regenerate Data" ] ]
        , div [ class "spacer-md" ] []
        , div [ class "example-grid" ]
            [ panel "Basic Header Groups" basicConfig FootersWithText False model
            , panel "Nested Header Groups" nestedConfig NoFooters False model
            , panel "Placeholder Headers" placeholderConfig AllFooters False model
            , panel "Header Row Spanning" unevenConfig NoFooters True model
            ]
        , div [ class "spacer-md" ] []
        ]


panel : String -> Table.Config Person -> Footers -> Bool -> Model -> Html Msg
panel title config footers useRowSpan model =
    section [ class "example-panel" ]
        [ h2 [] [ text title ]
        , viewTable config footers useRowSpan model
        ]


viewTable : Table.Config Person -> Footers -> Bool -> Model -> Html Msg
viewTable config footers useRowSpan model =
    let
        rowModel : Table.RowModel Person
        rowModel =
            Table.rowsFromList config model.state model.data

        body : List (Html Msg)
        body =
            [ thead []
                (List.map (viewHeaderRow config useRowSpan)
                    (Table.headerGroups config model.state)
                )
            , tbody [] (List.map (viewRow config model.state) rowModel.rows)
            ]
    in
    table []
        (case footers of
            NoFooters ->
                body

            AllFooters ->
                body
                    ++ [ tfoot []
                            (List.map (viewFooterRow config)
                                (Table.footerGroups config model.state)
                            )
                       ]

            FootersWithText ->
                body
                    ++ [ tfoot []
                            (Table.footerGroups config model.state
                                -- Only the leaf columns declare footers, so
                                -- skip the group row instead of rendering a
                                -- blank one.
                                |> List.filter (hasFooterText config)
                                |> List.map (viewFooterRow config)
                            )
                       ]
        )


hasFooterText : Table.Config Person -> Table.HeaderGroup Person -> Bool
hasFooterText config group =
    List.any
        (\header ->
            not (Table.headerIsPlaceholder header)
                && footerText config header
                /= ""
        )
        group.headers


viewHeaderRow : Table.Config Person -> Bool -> Table.HeaderGroup Person -> Html Msg
viewHeaderRow config useRowSpan group =
    tr []
        (group.headers
            |> List.filter (\header -> not useRowSpan || Table.headerRowSpan header /= 0)
            |> List.map (viewHeaderCell config useRowSpan)
        )


viewHeaderCell : Table.Config Person -> Bool -> Table.Header Person -> Html Msg
viewHeaderCell config useRowSpan header =
    th
        (colspan (Table.headerColSpan header)
            :: (if useRowSpan then
                    [ rowspan (Table.headerRowSpan header) ]

                else
                    []
               )
        )
        [ if Table.headerIsPlaceholder header && not useRowSpan then
            text ""

          else
            text (headerText config header)
        ]


viewFooterRow : Table.Config Person -> Table.HeaderGroup Person -> Html Msg
viewFooterRow config group =
    tr [] (List.map (viewFooterCell config) group.headers)


viewFooterCell : Table.Config Person -> Table.Header Person -> Html Msg
viewFooterCell config header =
    th [ colspan (Table.headerColSpan header) ]
        [ if Table.headerIsPlaceholder header then
            text ""

          else
            text (footerText config header)
        ]


headerText : Table.Config Person -> Table.Header Person -> String
headerText config header =
    let
        columnId : String
        columnId =
            Table.headerColumnId header
    in
    Table.findColumn config columnId
        |> Maybe.andThen Table.columnHeader
        |> Maybe.withDefault columnId


footerText : Table.Config Person -> Table.Header Person -> String
footerText config header =
    Table.findColumn config (Table.headerColumnId header)
        |> Maybe.andThen Table.columnFooter
        |> Maybe.withDefault ""


viewRow : Table.Config Person -> Table.State -> Table.Row Person -> Html Msg
viewRow config state row =
    tr []
        (List.map (\cell -> td [] [ text (Value.toString cell.value) ])
            (Table.getAllCells config state row)
        )


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }
