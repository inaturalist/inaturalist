const test = require( "node:test" );
const assert = require( "node:assert" );
const {
  FRU_CURRENCIES, niceRound, niceCeil, niceFloor, suggestedTiers, floorAmount, purchasingPowerAdjusted
} = require( "../seed" );

test( "amounts round to the nearest number in a 1, 1.5, 2, 2.5, 3, 4, 5, 7.5 series", ( ) => {
  assert.deepStrictEqual( [9.09, 36.4, 545, 727, 3636, 76364].map( niceRound ), [10, 40, 500, 750, 4000, 75000] );
} );

test( "suggested tiers are $5, $20 and $100 at the donation form's ratio to USD", ( ) => {
  assert.deepStrictEqual( suggestedTiers( "USD" ), { min: 5, mid: 20, max: 100 } );
  assert.deepStrictEqual( suggestedTiers( "EUR" ), { min: 5, mid: 20, max: 100 } );
  // DKK 20 : USD 2.75
  assert.deepStrictEqual( suggestedTiers( "DKK" ), { min: 40, mid: 150, max: 750 } );
  assert.deepStrictEqual( suggestedTiers( "COP" ), { min: 20000, mid: 75000, max: 400000 } );
  assert.ok( purchasingPowerAdjusted( "COP" ) );
} );

test( "currencies not on the form get only a min: $5 at market rates, rounded down", ( ) => {
  // usd_rates.json, 2026-10-29: 5 USD is about 168.9 THB and 18.4 AED
  assert.deepStrictEqual( suggestedTiers( "THB" ), { min: 150 } );
  assert.deepStrictEqual( suggestedTiers( "AED" ), { min: 15 } );
  assert.ok( !purchasingPowerAdjusted( "THB" ) );
  assert.deepStrictEqual( [18.4, 795, 5.5].map( niceFloor ), [15, 750, 5] );
} );

test( "suggested tiers are raised to at least $3 at market rates", ( ) => {
  // usd_rates.json, 2026-10-29: ₹50 is about $0.52, ₴100 about $2.19, NZ$5 about $2.81
  assert.deepStrictEqual( suggestedTiers( "INR" ), { min: 300, mid: 300, max: 1000 } );
  assert.deepStrictEqual( suggestedTiers( "UAH" ), { min: 150, mid: 400, max: 2000 } );
  assert.deepStrictEqual( suggestedTiers( "NZD" ), { min: 6, mid: 20, max: 100 } );
  assert.deepStrictEqual( [5.34, 136.8, 285.9, 9.5].map( niceCeil ), [6, 150, 300, 10] );
} );

test( "every currency gets a suggested min, and every suggested amount is worth at least $3", ( ) => {
  FRU_CURRENCIES.forEach( code => {
    assert.ok( suggestedTiers( code )?.min, code );
    Object.values( suggestedTiers( code ) || {} ).forEach( amount => {
      assert.ok( amount >= floorAmount( code ), `${code} ${amount}` );
    } );
  } );
} );
