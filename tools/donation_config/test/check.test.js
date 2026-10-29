const test = require( "node:test" );
const assert = require( "node:assert" );
const fs = require( "node:fs" );
const os = require( "node:os" );
const path = require( "node:path" );
const JSZip = require( "jszip" );
const { writeWorkbook } = require( "../build" );
const { checkWorkbook, fillWorkbook, readWorkbook } = require( "../check" );
const { sheetPaths } = require( "../xlsx_validations" );
const { TABS, LAST_ROW } = require( "../layout" );
const { FRU_CURRENCIES, STARTER } = require( "../seed" );

const tmp = fs.mkdtempSync( path.join( os.tmpdir( ), "donation-config-" ) );
const built = path.join( tmp, "built.xlsx" );

// Row numbers of starter countries on the Countries tab
const US = 4;
const FR = 16;
const ES = 20;

const hasXml = ( xml, fragment ) => assert.ok( xml.includes( fragment ), `expected ${fragment}` );

test.before( async ( ) => { await writeWorkbook( built ); } );
test.after( ( ) => fs.rmSync( tmp, { recursive: true, force: true } ) );

test( "a freshly built workbook only lacks currency amounts and settings", async ( ) => {
  const { errors } = await checkWorkbook( built );
  const unexpected = errors.filter( e => !/^One-time min missing, | is blank$/.test( e.message ) );
  assert.deepStrictEqual( unexpected, [] );
  const wb = await readWorkbook( built );
  const used = new Set( wb.getWorksheet( TABS.countries ).getColumn( 3 ).values.slice( 4 ).filter( Boolean ) );
  assert.strictEqual( errors.filter( e => /^One-time min missing/.test( e.message ) ).length, used.size );
} );

test( "the Countries tab lists every enabled country using a FundraiseUp currency, starters first", async ( ) => {
  const wb = await readWorkbook( built );
  const rows = {};
  wb.getWorksheet( TABS.countries ).eachRow( ( row, n ) => {
    if ( n >= 4 ) rows[row.getCell( 1 ).value] = { row: n, currency: row.getCell( 3 ).value, enabled: row.getCell( 15 ).value };
  } );
  assert.deepStrictEqual( rows.US, { row: US, currency: "USD", enabled: "Yes" } );
  assert.deepStrictEqual( rows.TH, { row: rows.TH.row, currency: "THB", enabled: "Yes" } );
  assert.ok( rows.TH.row > 4 + STARTER.length - 1, "new countries come after the starters" );
  assert.strictEqual( rows.SN.currency, "XOF" );
  assert.strictEqual( rows.ST.currency, "STD" );
  // Currencies Stripe can't take (KWD), and CLDR codes that aren't countries
  ["KW", "EU", "IC", "ZZ"].forEach( cc => assert.strictEqual( rows[cc], undefined, cc ) );
  Object.values( rows ).forEach( r => assert.ok( FRU_CURRENCIES.includes( r.currency ), r.currency ) );
} );

test( "countries use their currency's amounts unless they set their own", async ( ) => {
  const wb = await readWorkbook( built );
  const currencies = wb.getWorksheet( TABS.currencies );
  const currencyRow = code => currencies.getRow( currencies.getColumn( 1 ).values.indexOf( code ) );
  currencies.getColumn( 1 ).values.forEach( ( code, n ) => {
    if ( n >= 4 && code ) currencies.getRow( n ).getCell( 4 ).value = 1;
  } );
  // EUR: one-time min 3, mid 2 is out of order
  currencyRow( "EUR" ).getCell( 4 ).value = 3;
  currencyRow( "EUR" ).getCell( 5 ).value = 2;
  // France sets its own mid, which fixes the order there
  wb.getWorksheet( TABS.countries ).getRow( FR ).getCell( 5 ).value = 10;
  // Spain sets only a monthly min, so still has EUR's bad one-time order
  wb.getWorksheet( TABS.countries ).getRow( ES ).getCell( 7 ).value = 5;
  const overrides = wb.getWorksheet( TABS.overrides );
  overrides.getRow( 5 ).values = ["DE", "de", "One-time", "min", "Spende 3 €"];
  overrides.getRow( 6 ).values = ["AT", "de", "One-time", "min", "Spende 4 €"];
  overrides.getRow( 7 ).values = ["FR", "fr", "One-time", "mid", "Donnez 10 €"];
  wb.getWorksheet( TABS.settings ).getRow( 2 ).getCell( 3 ).value = "US";

  const { errors, warnings } = await checkWorkbook( await wb.xlsx.writeBuffer( ) );
  const messages = errors.map( e => `${e.tab} ${e.row}: ${e.message}` );
  assert.ok( !messages.some( m => /One-time min missing/.test( m ) ), messages.join( "\n" ) );
  assert.ok( messages.some( m => /^Currencies \d+: One-time amounts aren't in min ≤ mid ≤ max order \(3, 2, -\)/.test( m ) ), messages.join( "\n" ) );
  assert.ok( messages.some( m => m.startsWith( `Countries ${ES}: One-time amounts aren't in min` ) ), messages.join( "\n" ) );
  assert.ok( !messages.some( m => m.startsWith( `Countries ${FR}:` ) ), messages.join( "\n" ) );
  assert.deepStrictEqual( messages.filter( m => m.startsWith( "Exact text overrides" ) ), [
    "Exact text overrides 6: \"Spende 4 €\" doesn't show the tier amount 3"
  ] );
  assert.ok( warnings.some( w => /Fallback country US has no One-time mid, One-time max, Monthly min/.test( w.message ) ) );
} );

test( "the Currencies tab lists every FundraiseUp currency once", async ( ) => {
  const wb = await readWorkbook( built );
  const codes = wb.getWorksheet( TABS.currencies ).getColumn( 1 ).values
    .slice( 4 ).filter( Boolean );
  assert.deepStrictEqual( codes, [...FRU_CURRENCIES].sort( ) );
} );

test( "the built workbook keeps its dropdowns and checks on the right columns", async ( ) => {
  const zip = await JSZip.loadAsync( fs.readFileSync( built ) );
  const paths = await sheetPaths( zip );
  const countries = await zip.file( paths[TABS.countries] ).async( "string" );
  hasXml( countries, `sqref="A4:A${LAST_ROW}"><formula1>AND(LEN(A4)=2` );
  hasXml( countries, `sqref="C4:C${LAST_ROW}"><formula1>Currencies!$A$4:$A$${LAST_ROW}` );
  hasXml( countries, `sqref="N4:N${LAST_ROW}"><formula1>Lists!$C$2:$C$3` );
  const buttons = await zip.file( paths[TABS.buttons] ).async( "string" );
  hasXml( buttons, `sqref="D4:D${LAST_ROW}"><formula1>ISNUMBER(SEARCH(&quot;{amount}&quot;,D4))` );
} );

test( "mistakes are reported and --fill only fills blank cells", async ( ) => {
  const wb = await readWorkbook( built );
  const countries = wb.getWorksheet( TABS.countries );
  [5, 3, 25, 3, 5, 10].forEach( ( n, i ) => { countries.getRow( US ).getCell( 4 + i ).value = n; } );
  [5, 10, 25, 3, 5, 10].forEach( ( n, i ) => { countries.getRow( FR ).getCell( 4 + i ).value = n; } );
  countries.getRow( FR ).getCell( 12 ).value = "one thousand";
  countries.getRow( ES ).getCell( 12 ).value = null;
  const buttons = wb.getWorksheet( TABS.buttons );
  const enRow = buttons.getColumn( 1 ).values.indexOf( "en" );
  buttons.getRow( enRow ).getCell( 4 ).value = "Donate now";
  wb.getWorksheet( TABS.overrides ).getRow( 5 ).values = ["FR", "fr", "One-time", "min", "Donnez 6 €"];
  const currencies = wb.getWorksheet( TABS.currencies );
  const zmwRow = currencies.getColumn( 1 ).values.indexOf( "ZMW" );
  currencies.getRow( zmwRow ).getCell( 1 ).value = "ZZZ";
  const mistakes = await wb.xlsx.writeBuffer( );

  const { errors, fills } = await checkWorkbook( mistakes );
  const messages = errors.map( e => `${e.tab} ${e.row}: ${e.message}` );
  const has = pattern => assert.ok( messages.some( m => pattern.test( m ) ), `expected ${pattern} in\n${messages.join( "\n" )}` );
  has( /Countries 4: One-time amounts aren't in min/ );
  has( /Countries 16: Couldn't find a number in the 1,000.00 example "one thousand"/ );
  has( /Button text \d+: One-time button text "Donate now" doesn't contain \{amount\}/ );
  has( /Exact text overrides 5: "Donnez 6 €" doesn't show the tier amount 5/ );
  has( /Currencies \d+: ZZZ isn't a currency FundraiseUp supports/ );
  assert.deepStrictEqual( fills.map( f => `${f.tab} ${f.row} ${f.value}` ), ["Countries 20 1000,00 €"] );

  const filledPath = path.join( tmp, "filled.xlsx" );
  await fillWorkbook( Buffer.from( mistakes ), filledPath );
  const filled = await readWorkbook( filledPath );
  const filledCountries = filled.getWorksheet( TABS.countries );
  assert.strictEqual( filledCountries.getRow( ES ).getCell( 12 ).value, "1000,00 €" );
  assert.match( String( filledCountries.getRow( ES ).getCell( 12 ).note ), /Filled from CLDR/ );
  assert.strictEqual( filledCountries.getRow( FR ).getCell( 12 ).value, "one thousand" );

  // exceljs re-writes validations onto the wrong rows; the originals are restored
  const zip = await JSZip.loadAsync( fs.readFileSync( filledPath ) );
  const xml = await zip.file( ( await sheetPaths( zip ) )[TABS.countries] ).async( "string" );
  assert.strictEqual( ( xml.match( /<dataValidations\b/g ) || [] ).length, 1 );
  hasXml( xml, `sqref="A4:A${LAST_ROW}"><formula1>AND(LEN(A4)=2` );
} );
