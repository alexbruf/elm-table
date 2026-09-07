module RealtimeTrading.Instruments exposing (Instrument, instruments)

{-| The instrument universe of
`examples/react/realtime-trading/src/feed/market-instruments.ts`: current
S&P 500 constituents with international listings interleaved every third
row, so the Market column exercises several symbol formats and market
labels. The React file carries 606 of them; this is the first 100, which is
the example's default `instrumentCount`.

Source snapshot: <https://github.com/datasets/s-and-p-500-companies>.

@docs Instrument, instruments

-}


{-| Symbol, company, market code.
-}
type alias Instrument =
    ( String, String, String )


{-| The universe, in feed order.
-}
instruments : List Instrument
instruments =
    [ ( "MMM", "3M", "US" )
    , ( "ASML", "ASML Holding", "NL" )
    , ( "AOS", "A. O. Smith", "US" )
    , ( "ABT", "Abbott Laboratories", "US" )
    , ( "INGA", "ING Group", "NL" )
    , ( "ABBV", "AbbVie", "US" )
    , ( "ACN", "Accenture", "US" )
    , ( "ADYEN", "Adyen", "NL" )
    , ( "ADBE", "Adobe Inc.", "US" )
    , ( "AMD", "Advanced Micro Devices", "US" )
    , ( "PHIA", "Philips", "NL" )
    , ( "AES", "AES Corporation", "US" )
    , ( "AFL", "Aflac", "US" )
    , ( "HEIA", "Heineken", "NL" )
    , ( "A", "Agilent Technologies", "US" )
    , ( "APD", "Air Products", "US" )
    , ( "SAP", "SAP", "DE" )
    , ( "ABNB", "Airbnb", "US" )
    , ( "AKAM", "Akamai Technologies", "US" )
    , ( "SIE", "Siemens", "DE" )
    , ( "ALB", "Albemarle Corporation", "US" )
    , ( "ARE", "Alexandria Real Estate Equities", "US" )
    , ( "ALV", "Allianz", "DE" )
    , ( "ALGN", "Align Technology", "US" )
    , ( "ALLE", "Allegion", "US" )
    , ( "DTE", "Deutsche Telekom", "DE" )
    , ( "LNT", "Alliant Energy", "US" )
    , ( "ALL", "Allstate", "US" )
    , ( "MBG", "Mercedes-Benz Group", "DE" )
    , ( "GOOGL", "Alphabet Inc. (Class A)", "US" )
    , ( "GOOG", "Alphabet Inc. (Class C)", "US" )
    , ( "BMW", "BMW", "DE" )
    , ( "MO", "Altria", "US" )
    , ( "AMZN", "Amazon", "US" )
    , ( "BAS", "BASF", "DE" )
    , ( "AMCR", "Amcor", "US" )
    , ( "AEE", "Ameren", "US" )
    , ( "MUV2", "Munich Re", "DE" )
    , ( "AEP", "American Electric Power", "US" )
    , ( "AXP", "American Express", "US" )
    , ( "VOW3", "Volkswagen Preference", "DE" )
    , ( "AIG", "American International Group", "US" )
    , ( "AMT", "American Tower", "US" )
    , ( "IFX", "Infineon Technologies", "DE" )
    , ( "AWK", "American Water Works", "US" )
    , ( "AMP", "Ameriprise Financial", "US" )
    , ( "MC", "LVMH", "FR" )
    , ( "AME", "Ametek", "US" )
    , ( "AMGN", "Amgen", "US" )
    , ( "AIR", "Airbus", "FR" )
    , ( "APH", "Amphenol", "US" )
    , ( "ADI", "Analog Devices", "US" )
    , ( "SU", "Schneider Electric", "FR" )
    , ( "AON", "Aon plc", "US" )
    , ( "APA", "APA Corporation", "US" )
    , ( "TTE", "TotalEnergies", "FR" )
    , ( "APO", "Apollo Global Management", "US" )
    , ( "AAPL", "Apple Inc.", "US" )
    , ( "SAN", "Sanofi", "FR" )
    , ( "AMAT", "Applied Materials", "US" )
    , ( "APP", "AppLovin", "US" )
    , ( "BNP", "BNP Paribas", "FR" )
    , ( "APTV", "Aptiv", "US" )
    , ( "ACGL", "Arch Capital Group", "US" )
    , ( "CS", "AXA", "FR" )
    , ( "ADM", "Archer Daniels Midland", "US" )
    , ( "ARES", "Ares Management", "US" )
    , ( "DG", "Vinci", "FR" )
    , ( "ANET", "Arista Networks", "US" )
    , ( "AJG", "Arthur J. Gallagher & Co.", "US" )
    , ( "ENEL", "Enel", "IT" )
    , ( "AIZ", "Assurant", "US" )
    , ( "T", "AT&T", "US" )
    , ( "ENI", "Eni", "IT" )
    , ( "ATO", "Atmos Energy", "US" )
    , ( "ADSK", "Autodesk", "US" )
    , ( "ISP", "Intesa Sanpaolo", "IT" )
    , ( "ADP", "Automatic Data Processing", "US" )
    , ( "AZO", "AutoZone", "US" )
    , ( "UCG", "UniCredit", "IT" )
    , ( "AVB", "AvalonBay Communities", "US" )
    , ( "AVY", "Avery Dennison", "US" )
    , ( "STLAM", "Stellantis", "IT" )
    , ( "AXON", "Axon Enterprise", "US" )
    , ( "BKR", "Baker Hughes", "US" )
    , ( "SAN", "Banco Santander", "ES" )
    , ( "BALL", "Ball Corporation", "US" )
    , ( "BAC", "Bank of America", "US" )
    , ( "IBE", "Iberdrola", "ES" )
    , ( "BAX", "Baxter International", "US" )
    , ( "BDX", "Becton Dickinson", "US" )
    , ( "ITX", "Inditex", "ES" )
    , ( "BRK.B", "Berkshire Hathaway", "US" )
    , ( "BBY", "Best Buy", "US" )
    , ( "BBVA", "BBVA", "ES" )
    , ( "TECH", "Bio-Techne", "US" )
    , ( "BIIB", "Biogen", "US" )
    , ( "NESN", "Nestlé", "CH" )
    , ( "BLK", "BlackRock", "US" )
    , ( "ROG", "Roche Holding", "CH" )
    ]
