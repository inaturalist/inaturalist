const test = require( "node:test" );
const assert = require( "node:assert" );
const fs = require( "node:fs" );
const os = require( "node:os" );
const path = require( "node:path" );
const JSZip = require( "jszip" );
const { writeWorkbook } = require( "../build" );
const { checkWorkbook, fillWorkbook, readWorkbook } = require( "../check" );
const { sheetPaths } = require( "../xlsx_validations" );
const { TABS } = require( "../layout" );

const tmp = fs.mkdtempSync( path.join( os.tmpdir( ), "donation-config-" ) );
const built = path.join( tmp, "built.xlsx" );

// Row numbers of starter countries on the Countries tab
const US = 4;
const FR = 16;
const ES = 20;

test.before( async ( ) => { await writeWorkbook( built ); } );
test.after( ( ) => fs.rmSync( tmp, { recursive: true, force: true } ) );

test( "a freshly built workbook only lacks amounts and settings", async ( ) => {
  const { errors } = await checkWorkbook( built );
  const unexpected = errors.filter( e => !/^Amounts missing$| is blank$/.test( e.message ) );
  assert.deepStrictEqual( unexpected, [] );
  assert.strictEqual( errors.filter( e => e.message === "Amounts missing" ).length, 42 );
} );

test( "the built workbook keeps its dropdowns and checks on the right columns", async ( ) => {
  const zip = await JSZip.loadAsync( fs.readFileSync( built ) );
  const paths = await sheetPaths( zip );
  const countries = await zip.file( paths[TABS.countries] ).async( "string" );
  assert.match( countries, /sqref="A4:A150"><formula1>AND\(LEN\(A4\)=2/ );
  assert.match( countries, /sqref="C4:C150"><formula1>Currencies!\$A\$4:\$A\$150/ );
  assert.match( countries, /sqref="N4:N150"><formula1>Lists!\$C\$2:\$C\$3/ );
  const buttons = await zip.file( paths[TABS.buttons] ).async( "string" );
  assert.match( buttons, /sqref="D4:D150"><formula1>ISNUMBER\(SEARCH\(&quot;\{amount\}&quot;,D4\)\)/ );
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
  const mistakes = await wb.xlsx.writeBuffer( );

  const { errors, fills } = await checkWorkbook( mistakes );
  const messages = errors.map( e => `${e.tab} ${e.row}: ${e.message}` );
  const has = pattern => assert.ok( messages.some( m => pattern.test( m ) ), `expected ${pattern} in\n${messages.join( "\n" )}` );
  has( /Countries 4: One-time amounts aren't in min/ );
  has( /Countries 16: Couldn't find a number in the 1,000.00 example "one thousand"/ );
  has( /Button text \d+: One-time button text "Donate now" doesn't contain \{amount\}/ );
  has( /Exact text overrides 5: "Donnez 6 €" doesn't show the tier amount 5/ );
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
  assert.match( xml, /sqref="A4:A150"><formula1>AND\(LEN\(A4\)=2/ );
} );
