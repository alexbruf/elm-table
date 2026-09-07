module CoreTableTest exposing (suite)

{-| Ports
`tests/unit/core/table/stockFeaturesInitialState.test.ts`.

The other two files in `tests/unit/core/table/` test the table instance,
the feature registry, and TypeScript type slots, none of which this port
has. They are listed as excluded in `reports/phase-2.md`.

-}

import Dict
import Expect
import Set
import Table
import Table.Value as Value
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "constructTable with stockFeatures"
        [ test "should include all feature states in initial state" <|
            \_ ->
                Expect.equal Table.initialState
                    { sorting = []
                    , columnFilters = []
                    , globalFilter = Value.Null
                    , grouping = []
                    , expanded = Table.expandedIds Set.empty
                    , rowSelection = Set.empty
                    , pagination = { pageIndex = 0, pageSize = 10 }
                    , columnOrder = []
                    , columnVisibility = Dict.empty
                    , columnPinning = { left = [], right = [] }
                    , columnSizing = Dict.empty
                    , rowPinning = { top = [], bottom = [] }
                    , cellSelection = []
                    , columnResizing =
                        { columnSizingStart = []
                        , deltaOffset = Nothing
                        , deltaPercentage = Nothing
                        , isResizingColumn = Nothing
                        , startOffset = Nothing
                        , startSize = Nothing
                        }
                    }
        ]
