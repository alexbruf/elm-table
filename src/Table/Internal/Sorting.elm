module Table.Internal.Sorting exposing
    ( clearSorting
    , getAutoSortDir
    , getAutoSortFn
    , getCanMultiSort
    , getCanSort
    , getFirstSortDir
    , getIsSorted
    , getNextSortingOrder
    , getSortFn
    , getSortIndex
    , resetSorting
    , setSorting
    , sortedRowModel
    , toggleSort
    )

{-| Sorting: ports `row-sorting/createSortedRowModel.ts` and
`row-sorting/rowSortingFeature.utils.ts`.

`State.sorting` is applied in order: the first entry decides, the next breaks
its ties, and `rowA.index - rowB.index` breaks the last tie so the sort is
stable.

-}

import Dict
import Table.Internal.Column as Column
import Table.Internal.Row as Row
import Table.Internal.Types
    exposing
        ( Column
        , Config
        , Row(..)
        , RowModel
        , SortColumn
        , SortDir(..)
        , SortUndefined(..)
        , State
        )
import Table.SortFn as SortFn exposing (SortFn)
import Table.Value as Value exposing (Value)



-- THE ROW MODEL


type alias Resolved row =
    { read : Row row -> Value
    , desc : Bool
    , sortUndefined : Maybe SortUndefined
    , invertSorting : Bool
    , compare : Row row -> Row row -> Order
    }


{-| A cell reader for one column with the column looked up once, so the
comparator does not rebuild the column index on every comparison.
-}
valueReader : Config row -> String -> (Row row -> Value)
valueReader cfg columnId =
    case Maybe.andThen Column.accessorFn (Column.findColumn cfg columnId) of
        Just accessor ->
            \row ->
                case Dict.get columnId (Row.aggregatedValues row) of
                    Just aggregated ->
                        aggregated

                    Nothing ->
                        accessor (Row.original row)

        Nothing ->
            \row ->
                Dict.get columnId (Row.aggregatedValues row)
                    |> Maybe.withDefault Value.Null


{-| Sort every level of the row tree by `State.sorting`.
-}
sortedRowModel : Config row -> State -> RowModel row -> RowModel row
sortedRowModel cfg state model =
    if List.isEmpty model.rows || List.isEmpty state.sorting then
        model

    else
        let
            resolved : List (Resolved row)
            resolved =
                state.sorting
                    |> List.filter (\entry -> getCanSort cfg entry.id)
                    |> List.filterMap (resolve cfg model)
        in
        if List.isEmpty resolved then
            model

        else
            let
                compareRows : Row row -> Row row -> Order
                compareRows =
                    rowComparison resolved

                tree : List (Row row)
                tree =
                    sortTree compareRows model.rows
            in
            { rows = tree
            , flatRows = Row.flattenRows tree
            , rowsById = model.rowsById
            }


resolve : Config row -> RowModel row -> SortColumn -> Maybe (Resolved row)
resolve cfg model entry =
    Column.findColumn cfg entry.id
        |> Maybe.map
            (\col ->
                let
                    f : Table.Internal.Types.ColumnFields row
                    f =
                        Column.fields col
                in
                { read = valueReader cfg entry.id
                , desc = entry.desc
                , sortUndefined = f.sortUndefined
                , invertSorting = f.invertSorting
                , compare = comparisonFor cfg model col entry.id
                }
            )


comparisonFor : Config row -> RowModel row -> Column row -> String -> (Row row -> Row row -> Order)
comparisonFor cfg model col columnId =
    case (Column.fields col).customSort of
        Just fn ->
            fn

        Nothing ->
            let
                fn : SortFn
                fn =
                    sortFnOf cfg model col

                read : Row row -> Value
                read =
                    valueReader cfg columnId
            in
            \a b -> SortFn.compare fn (read a) (read b)


rowComparison : List (Resolved row) -> Row row -> Row row -> Order
rowComparison resolved rowA rowB =
    case resolved of
        [] ->
            Basics.compare (Row.index rowA) (Row.index rowB)

        entry :: rest ->
            case nullOrder entry rowA rowB of
                Skip ->
                    rowComparison rest rowA rowB

                Decided order ->
                    order

                Undecided ->
                    case directed entry (entry.compare rowA rowB) of
                        EQ ->
                            rowComparison rest rowA rowB

                        order ->
                            order


type NullOrder
    = Skip
    | Undecided
    | Decided Order


{-| The `sortUndefined` block of `compareRows`. `Skip` is the `continue` of
two `Null` values, which moves on to the next sort entry without letting the
sort fn see them.
-}
nullOrder : Resolved row -> Row row -> Row row -> NullOrder
nullOrder entry rowA rowB =
    case entry.sortUndefined of
        Nothing ->
            Undecided

        Just placement ->
            let
                aNull : Bool
                aNull =
                    Value.isNull (entry.read rowA)

                bNull : Bool
                bNull =
                    Value.isNull (entry.read rowB)
            in
            if aNull && bNull then
                Skip

            else if not aNull && not bNull then
                Undecided

            else
                case placement of
                    SortNullsFirst ->
                        Decided
                            (if aNull then
                                LT

                             else
                                GT
                            )

                    SortNullsLast ->
                        Decided
                            (if aNull then
                                GT

                             else
                                LT
                            )

                    SortNullsAsMinusOne ->
                        Decided (directed entry (nullSortInt aNull LT GT))

                    SortNullsAsPlusOne ->
                        Decided (directed entry (nullSortInt aNull GT LT))


nullSortInt : Bool -> Order -> Order -> Order
nullSortInt aNull whenANull whenBNull =
    if aNull then
        whenANull

    else
        whenBNull


{-| `desc` and `invertSorting` each flip a non-zero comparison.
-}
directed : Resolved row -> Order -> Order
directed entry order =
    let
        flips : Bool
        flips =
            xor entry.desc entry.invertSorting
    in
    if flips then
        flip order

    else
        order


flip : Order -> Order
flip order =
    case order of
        LT ->
            GT

        GT ->
            LT

        EQ ->
            EQ


sortTree : (Row row -> Row row -> Order) -> List (Row row) -> List (Row row)
sortTree compareRows rows =
    List.sortWith compareRows rows
        |> List.map (sortSubRows compareRows)


sortSubRows : (Row row -> Row row -> Order) -> Row row -> Row row
sortSubRows compareRows (Row f) =
    if List.isEmpty f.subRows then
        Row f

    else
        Row { f | subRows = sortTree compareRows f.subRows }



-- SORT FN RESOLUTION


{-| `column_getAutoSortFn`: sample the first ten rows of the row model and
pick `datetime` for dates, `alphanumeric` for strings that carry numeric
chunks, `text` for other strings, and `basic` for everything else.
-}
getAutoSortFn : Config row -> RowModel row -> String -> SortFn
getAutoSortFn cfg model columnId =
    sample cfg columnId False (List.take 10 model.flatRows)


sample : Config row -> String -> Bool -> List (Row row) -> SortFn
sample cfg columnId sawString rows =
    case rows of
        [] ->
            if sawString then
                SortFn.text

            else
                SortFn.basic

        first :: rest ->
            case Row.getValue cfg first columnId of
                Value.Date _ ->
                    SortFn.datetime

                Value.String s ->
                    if List.length (SortFn.splitAlphaNumeric s) > 1 then
                        SortFn.alphanumeric

                    else
                        sample cfg columnId True rest

                _ ->
                    sample cfg columnId sawString rest


{-| `column_getSortFn`: the column's own sort function, or the automatic one.
A column set up with a custom row comparison has no `SortFn`, so this reports
the automatic choice for it; the row model uses the comparison itself.
-}
getSortFn : Config row -> RowModel row -> String -> SortFn
getSortFn cfg model columnId =
    case Column.findColumn cfg columnId of
        Nothing ->
            SortFn.basic

        Just col ->
            sortFnOf cfg model col


sortFnOf : Config row -> RowModel row -> Column row -> SortFn
sortFnOf cfg model col =
    case (Column.fields col).sortFn of
        Just fn ->
            fn

        Nothing ->
            getAutoSortFn cfg model (Column.id col)



-- SORTING STATE


{-| `column_getCanSort`.
-}
getCanSort : Config row -> String -> Bool
getCanSort cfg columnId =
    case Column.findColumn cfg columnId of
        Nothing ->
            False

        Just col ->
            (Column.fields col).enableSorting && cfg.enableSorting && hasAccessor col


{-| `column_getCanMultiSort`: the column setting wins over the table setting,
and an accessor column can multi-sort when neither is set.
-}
getCanMultiSort : Config row -> String -> Bool
getCanMultiSort cfg columnId =
    case Column.findColumn cfg columnId of
        Nothing ->
            False

        Just col ->
            case (Column.fields col).enableMultiSort of
                Just flag ->
                    flag

                Nothing ->
                    cfg.enableMultiSort && hasAccessor col


hasAccessor : Column row -> Bool
hasAccessor col =
    case Column.accessorFn col of
        Just _ ->
            True

        Nothing ->
            False


{-| `column_getIsSorted`: `Nothing` when the column is not sorted.
-}
getIsSorted : State -> String -> Maybe SortDir
getIsSorted state columnId =
    List.filter (\entry -> entry.id == columnId) state.sorting
        |> List.head
        |> Maybe.map
            (\entry ->
                if entry.desc then
                    Desc

                else
                    Asc
            )


{-| `column_getSortIndex`: the column's position in `State.sorting`, or `-1`.
-}
getSortIndex : State -> String -> Int
getSortIndex state columnId =
    indexOf columnId 0 state.sorting


indexOf : String -> Int -> List SortColumn -> Int
indexOf columnId at entries =
    case entries of
        [] ->
            -1

        first :: rest ->
            if first.id == columnId then
                at

            else
                indexOf columnId (at + 1) rest


{-| `column_getAutoSortDir`: the first non-null value among the first ten
rows decides. Strings start ascending, everything else descending.
-}
getAutoSortDir : Config row -> RowModel row -> String -> SortDir
getAutoSortDir cfg model columnId =
    sampleDir cfg columnId (List.take 10 model.flatRows)


sampleDir : Config row -> String -> List (Row row) -> SortDir
sampleDir cfg columnId rows =
    case rows of
        [] ->
            Desc

        first :: rest ->
            case Row.getValue cfg first columnId of
                Value.Null ->
                    sampleDir cfg columnId rest

                Value.String _ ->
                    Asc

                _ ->
                    Desc


{-| `column_getFirstSortDir`: the column's `sortDescFirst` wins, then the
table's, then the automatic direction.
-}
getFirstSortDir : Config row -> RowModel row -> String -> SortDir
getFirstSortDir cfg model columnId =
    let
        descFirst : Maybe Bool
        descFirst =
            Column.findColumn cfg columnId
                |> Maybe.andThen (\col -> (Column.fields col).sortDescFirst)
    in
    case orElse descFirst cfg.sortDescFirst of
        Just True ->
            Desc

        Just False ->
            Asc

        Nothing ->
            getAutoSortDir cfg model columnId


orElse : Maybe a -> Maybe a -> Maybe a
orElse first second =
    case first of
        Just _ ->
            first

        Nothing ->
            second


{-| `column_getNextSortingOrder`: the next step of the toggle cycle.
`Nothing` means "remove the sort".
-}
getNextSortingOrder : Config row -> RowModel row -> State -> String -> Bool -> Maybe SortDir
getNextSortingOrder cfg model state columnId multi =
    let
        firstDir : SortDir
        firstDir =
            getFirstSortDir cfg model columnId
    in
    case getIsSorted state columnId of
        Nothing ->
            Just firstDir

        Just current ->
            if
                current
                    /= firstDir
                    && cfg.enableSortingRemoval
                    && (if multi then
                            cfg.enableMultiRemove

                        else
                            True
                       )
            then
                Nothing

            else
                Just
                    (case current of
                        Desc ->
                            Asc

                        Asc ->
                            Desc
                    )


{-| `column_toggleSorting`: add, replace, flip, or remove this column's entry
in `State.sorting`.

`desc = Just d` sets the direction outright instead of stepping the cycle.
`multi = True` asks for a multi-sort, which only happens when the column and
the table allow it.

-}
toggleSort : Config row -> RowModel row -> String -> { desc : Maybe Bool, multi : Bool } -> State -> State
toggleSort cfg model columnId options state =
    let
        canMulti : Bool
        canMulti =
            getCanMultiSort cfg columnId

        nextOrder : Maybe SortDir
        nextOrder =
            getNextSortingOrder cfg model state columnId (options.multi && canMulti)

        existing : Bool
        existing =
            getSortIndex state columnId > -1

        isMultiMode : Bool
        isMultiMode =
            not (List.isEmpty state.sorting) && canMulti && options.multi

        removes : Bool
        removes =
            existing && options.desc == Nothing && nextOrder == Nothing
    in
    if removes then
        setSorting
            (if isMultiMode then
                List.filter (\entry -> entry.id /= columnId) state.sorting

             else
                []
            )
            state

    else if existing then
        setSorting
            (if isMultiMode then
                List.map
                    (\entry ->
                        if entry.id == columnId then
                            { entry | desc = nextDescOf options.desc nextOrder }

                        else
                            entry
                    )
                    state.sorting

             else
                [ { id = columnId, desc = nextDescOf options.desc nextOrder } ]
            )
            state

    else if isMultiMode then
        setSorting
            (takeLast cfg.maxMultiSortColCount
                (state.sorting ++ [ { id = columnId, desc = nextDescOf options.desc nextOrder } ])
            )
            state

    else
        setSorting [ { id = columnId, desc = nextDescOf options.desc nextOrder } ] state


nextDescOf : Maybe Bool -> Maybe SortDir -> Bool
nextDescOf manual nextOrder =
    case manual of
        Just d ->
            d

        Nothing ->
            nextOrder == Just Desc


takeLast : Int -> List a -> List a
takeLast count list =
    List.drop (List.length list - count) list


{-| `table_setSorting`.
-}
setSorting : List SortColumn -> State -> State
setSorting sorting state =
    { state | sorting = sorting }


{-| `column_clearSorting`: drop only this column's entry.
-}
clearSorting : String -> State -> State
clearSorting columnId state =
    { state | sorting = List.filter (\entry -> entry.id /= columnId) state.sorting }


{-| `table_resetSorting table true`: back to the feature default of no
sorting.
-}
resetSorting : State -> State
resetSorting state =
    { state | sorting = [] }
