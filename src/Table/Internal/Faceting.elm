module Table.Internal.Faceting exposing
    ( facetedMinMax
    , facetedRowModel
    , facetedUniqueValues
    , globalFacetKey
    )

{-| Faceting: ports `column-faceting/createFacetedRowModel.ts`,
`createFacetedUniqueValues.ts`, and `createFacetedMinMaxValues.ts`.

The row model these three read is the **pre-filtered** one, that is the row
model that was handed to `filteredRowModel`. A column's faceted model applies
every active filter except that column's own, so a filter UI can keep showing
the values the user could switch to.

-}

import Table.Internal.Column as Column
import Table.Internal.Filtering as Filtering
import Table.Internal.GlobalFiltering as GlobalFiltering
import Table.Internal.Row as Row
import Table.Internal.Types exposing (ColumnFilter, Config, Row, RowModel, State)
import Table.Value as Value exposing (Value)


{-| The column id TanStack uses for the global filter's own facet context.
-}
globalFacetKey : String
globalFacetKey =
    "__global__"


{-| `_createFacetedRowModel`: the pre-filtered rows with every active filter
applied except the one belonging to `columnId`. Passing
[`globalFacetKey`](#globalFacetKey) excludes the global filter instead.
-}
facetedRowModel : Config row -> State -> RowModel row -> String -> RowModel row
facetedRowModel cfg state model columnId =
    let
        hasGlobal : Bool
        hasGlobal =
            GlobalFiltering.hasGlobalFilter state
    in
    if List.isEmpty model.rows || (List.isEmpty state.columnFilters && not hasGlobal) then
        model

    else
        let
            otherFilters : List ColumnFilter
            otherFilters =
                List.filter (\f -> f.id /= columnId) state.columnFilters

            appliesGlobal : Bool
            appliesGlobal =
                hasGlobal && columnId /= globalFacetKey
        in
        if List.isEmpty otherFilters && not appliesGlobal then
            model

        else
            let
                columnFilters : List (Filtering.ResolvedFilter row)
                columnFilters =
                    Filtering.resolveColumnFilters cfg model { state | columnFilters = otherFilters }

                globalFilters : List (Filtering.ResolvedFilter row)
                globalFilters =
                    if appliesGlobal then
                        Filtering.resolveGlobalFilters cfg model state

                    else
                        []
            in
            Filtering.filterRows cfg
                (\row ->
                    Filtering.rowPassesColumnFilters columnFilters row
                        && Filtering.rowPassesGlobalFilters globalFilters row
                )
                model.rows


{-| `_createFacetedUniqueValues`: every distinct value of one column with the
number of rows that carry it, first-seen order preserved.

`Value` is not `comparable`, so the counts come back as an association list
instead of a `Dict`.

-}
facetedUniqueValues : Config row -> State -> RowModel row -> String -> List ( Value, Int )
facetedUniqueValues cfg state model columnId =
    let
        faceted : RowModel row
        faceted =
            facetedRowModel cfg state model columnId

        columnIds : List String
        columnIds =
            facetColumnIds cfg model columnId
    in
    List.foldl (countRow cfg columnIds) [] faceted.flatRows
        |> List.reverse


countRow : Config row -> List String -> Row row -> List ( Value, Int ) -> List ( Value, Int )
countRow cfg columnIds row counts =
    List.foldl
        (\cid acc -> List.foldl bump acc (Row.getUniqueValues cfg row cid))
        counts
        columnIds


{-| The counts are accumulated reversed, so the newest entry sits in front.
-}
bump : Value -> List ( Value, Int ) -> List ( Value, Int )
bump value counts =
    if List.any (\( v, _ ) -> v == value) counts then
        List.map
            (\( v, n ) ->
                if v == value then
                    ( v, n + 1 )

                else
                    ( v, n )
            )
            counts

    else
        ( value, 1 ) :: counts


{-| `_createFacetedMinMaxValues`: the smallest and largest numeric value of
one column. Cells that do not coerce to a number are skipped.
-}
facetedMinMax : Config row -> State -> RowModel row -> String -> Maybe ( Float, Float )
facetedMinMax cfg state model columnId =
    let
        faceted : RowModel row
        faceted =
            facetedRowModel cfg state model columnId

        columnIds : List String
        columnIds =
            facetColumnIds cfg model columnId
    in
    List.foldl (extendRange cfg columnIds) Nothing faceted.flatRows


extendRange : Config row -> List String -> Row row -> Maybe ( Float, Float ) -> Maybe ( Float, Float )
extendRange cfg columnIds row range =
    List.foldl
        (\cid acc ->
            let
                value : Float
                value =
                    Value.toNumber (Row.getValue cfg row cid)
            in
            if isNaN value then
                acc

            else
                case acc of
                    Nothing ->
                        Just ( value, value )

                    Just ( low, high ) ->
                        Just ( min low value, max high value )
        )
        range
        columnIds


facetColumnIds : Config row -> RowModel row -> String -> List String
facetColumnIds cfg model columnId =
    if columnId == globalFacetKey then
        List.map Column.id (GlobalFiltering.globallyFilterableColumns cfg model)

    else
        [ columnId ]
