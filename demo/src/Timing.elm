module Timing exposing
    ( Measured
    , Stages
    , Timings
    , measure
    , run
    , zeroTimings
    )

{-| Run the six pipeline stages once, with a clock read between each pair.

Every stage runs inside a `Task` callback, so the stage before it has already
been evaluated when the next clock is read. The row models the stages produce
are kept and handed back, so `view` never runs a stage itself.

-}

import Array exposing (Array)
import Table exposing (Config, RowModel, State)
import Task exposing (Task)
import Time


{-| The row model each stage produced, in pipeline order.
-}
type alias Stages row =
    { core : RowModel row
    , filtered : RowModel row
    , grouped : RowModel row
    , sorted : RowModel row
    , expanded : RowModel row
    , paginated : RowModel row
    }


{-| How long each stage took, in milliseconds.
-}
type alias Timings =
    { core : Int
    , filtered : Int
    , grouped : Int
    , sorted : Int
    , expanded : Int
    , paginated : Int
    }


{-| One measured run.
-}
type alias Measured row =
    { stages : Stages row
    , timings : Timings
    }


{-| All six timings at zero, for the first frame.
-}
zeroTimings : Timings
zeroTimings =
    Timings 0 0 0 0 0 0


{-| The same six stages without a clock, for the very first frame.
-}
run : Config row -> State -> Array row -> Stages row
run config state data =
    let
        core : RowModel row
        core =
            Table.coreRowModel config state data

        filtered : RowModel row
        filtered =
            Table.filteredRowModel config state core

        grouped : RowModel row
        grouped =
            Table.groupedRowModel config state filtered

        sorted : RowModel row
        sorted =
            Table.sortedRowModel config state grouped

        expanded : RowModel row
        expanded =
            Table.expandedRowModel config state sorted
    in
    { core = core
    , filtered = filtered
    , grouped = grouped
    , sorted = sorted
    , expanded = expanded
    , paginated = Table.paginatedRowModel config state expanded
    }


{-| Read the clock, then run the whole pipeline stage by stage.

`clockAfter` takes the size of the stage that just ran, which keeps the stage
in the task callback that owns it: the minifier cannot move the work past the
clock read that ends it.

-}
measure : Config row -> State -> Array row -> Task Never (Measured row)
measure config state data =
    Time.now
        |> Task.andThen
            (\t0 ->
                let
                    core : RowModel row
                    core =
                        Table.coreRowModel config state data
                in
                clockAfter (sizeOf core)
                    |> Task.andThen
                        (\t1 ->
                            let
                                filtered : RowModel row
                                filtered =
                                    Table.filteredRowModel config state core
                            in
                            clockAfter (sizeOf filtered)
                                |> Task.andThen
                                    (\t2 ->
                                        let
                                            grouped : RowModel row
                                            grouped =
                                                Table.groupedRowModel config state filtered
                                        in
                                        clockAfter (sizeOf grouped)
                                            |> Task.andThen
                                                (\t3 ->
                                                    let
                                                        sorted : RowModel row
                                                        sorted =
                                                            Table.sortedRowModel config state grouped
                                                    in
                                                    clockAfter (sizeOf sorted)
                                                        |> Task.andThen
                                                            (\t4 ->
                                                                let
                                                                    expanded : RowModel row
                                                                    expanded =
                                                                        Table.expandedRowModel config state sorted
                                                                in
                                                                clockAfter (sizeOf expanded)
                                                                    |> Task.andThen
                                                                        (\t5 ->
                                                                            let
                                                                                paginated : RowModel row
                                                                                paginated =
                                                                                    Table.paginatedRowModel config state expanded
                                                                            in
                                                                            clockAfter (sizeOf paginated)
                                                                                |> Task.map
                                                                                    (\t6 ->
                                                                                        { stages =
                                                                                            { core = core
                                                                                            , filtered = filtered
                                                                                            , grouped = grouped
                                                                                            , sorted = sorted
                                                                                            , expanded = expanded
                                                                                            , paginated = paginated
                                                                                            }
                                                                                        , timings =
                                                                                            { core = gap t0 t1
                                                                                            , filtered = gap t1 t2
                                                                                            , grouped = gap t2 t3
                                                                                            , sorted = gap t3 t4
                                                                                            , expanded = gap t4 t5
                                                                                            , paginated = gap t5 t6
                                                                                            }
                                                                                        }
                                                                                    )
                                                                        )
                                                            )
                                                )
                                    )
                        )
            )


clockAfter : Int -> Task Never Time.Posix
clockAfter forced =
    Task.succeed forced
        |> Task.andThen (\_ -> Time.now)


sizeOf : RowModel row -> Int
sizeOf model =
    List.length model.rows + List.length model.flatRows


gap : Time.Posix -> Time.Posix -> Int
gap from to =
    Time.posixToMillis to - Time.posixToMillis from
