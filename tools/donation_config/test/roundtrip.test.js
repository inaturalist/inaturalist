// Parses the CLDR examples for every starter country and language, and every
// FundraiseUp currency's default format, renders
// whole amounts from the parsed fields with ActiveSupport (as the app will),
// and checks the result matches CLDR. This shows the stored fields are enough
// to reproduce each format.

const test = require( "node:test" );
const assert = require( "node:assert" );
const path = require( "node:path" );
const { execFileSync } = require( "node:child_process" );
const { parseExamples, normalize } = require( "../parse" );
const {
  STARTER, FRU_CURRENCIES, suggest, cldrWhole, currencyHome
} = require( "../seed" );

const REPO_ROOT = path.resolve( __dirname, "../../.." );
const AMOUNTS = [5, 1000, 25000, 1000000];

test( "parsed CLDR formats render the same through ActiveSupport", ( ) => {
  const cases = [];
  const addCase = ( label, lang, country, currency ) => {
    const s = suggest( lang, country, currency );
    const { fields, errors } = parseExamples( { ...s, code: currency } );
    assert.deepStrictEqual( errors, [], `${label}: ${errors.join( "; " )}` );
    cases.push( {
      label, fields, code: currency, amounts: AMOUNTS,
      expected: AMOUNTS.map( a => cldrWhole( lang, country, currency, a ) )
    } );
  };
  STARTER.forEach( ( [country, , currency, langs] ) => {
    langs.forEach( lang => addCase( `${country}/${lang}`, lang, country, currency ) );
  } );
  FRU_CURRENCIES.forEach( currency => {
    const [country, , , [lang]] = currencyHome( currency );
    addCase( `${currency} (${country}/${lang})`, lang, country, currency );
  } );

  const output = execFileSync( "bundle", ["exec", "ruby", path.join( __dirname, "../render_check.rb" )], {
    cwd: REPO_ROOT,
    input: JSON.stringify( cases )
  } );
  const rendered = JSON.parse( output.toString( ) );

  const mismatches = [];
  cases.forEach( ( c, i ) => {
    c.amounts.forEach( ( amount, j ) => {
      const got = normalize( rendered[i][j] );
      if ( got !== c.expected[j] ) {
        mismatches.push( `${c.label} ${amount}: rendered "${got}", CLDR "${c.expected[j]}"` );
      }
    } );
  } );
  assert.deepStrictEqual( mismatches, [] );
} );
