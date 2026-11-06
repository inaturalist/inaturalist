// Refreshes usd_rates.json: market units of each FundraiseUp currency per USD,
// used to keep every amount at or above the USD floor. Run when the snapshot
// gets stale, then rebuild the workbook.
//
//   node update_rates.js

const fs = require( "node:fs" );
const path = require( "node:path" );
const { FRU_CURRENCIES } = require( "./seed" );

const SOURCE = "https://open.er-api.com/v6/latest/USD";

// Stripe uses the pre-2018 dobra (STD), worth 1000 of today's STN
const DERIVED = { STD: rates => rates.STN * 1000 };

( async ( ) => {
  const response = await fetch( SOURCE );
  const data = await response.json( );
  if ( data.result !== "success" ) throw new Error( `Rates request failed: ${JSON.stringify( data )}` );
  const rates = {};
  const missing = [];
  FRU_CURRENCIES.forEach( code => {
    const rate = DERIVED[code] ? DERIVED[code]( data.rates ) : data.rates[code];
    if ( rate ) rates[code] = rate;
    else missing.push( code );
  } );
  const out = {
    source: SOURCE,
    attribution: "Rates By Exchange Rate API (https://www.exchangerate-api.com)",
    updated: new Date( data.time_last_update_unix * 1000 ).toISOString( ).slice( 0, 10 ),
    rates
  };
  fs.writeFileSync( path.join( __dirname, "usd_rates.json" ), `${JSON.stringify( out, null, 2 )}\n` );
  console.log( `wrote usd_rates.json (${out.updated}, ${Object.keys( rates ).length} currencies)` );
  if ( missing.length > 0 ) console.log( `no rate for ${missing.join( ", " )}` );
} )( );
