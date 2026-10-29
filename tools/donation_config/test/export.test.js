const test = require( "node:test" );
const assert = require( "node:assert" );
const fs = require( "node:fs" );
const os = require( "node:os" );
const path = require( "node:path" );
const { execFileSync } = require( "node:child_process" );
const { writeWorkbook } = require( "../build" );
const { readWorkbook } = require( "../check" );
const { exportYaml } = require( "../export_yaml" );
const { TABS, DEFAULT_DONATION_URL } = require( "../layout" );

const REPO_ROOT = path.resolve( __dirname, "../../.." );
const tmp = fs.mkdtempSync( path.join( os.tmpdir( ), "donation-export-" ) );
const built = path.join( tmp, "built.xlsx" );

// Loads YAML the way the app will: Ruby's Psych, which reads YAML 1.1
function loadWithRuby( text ) {
  const file = path.join( tmp, "out.yml" );
  fs.writeFileSync( file, text );
  const json = execFileSync( "bundle", ["exec", "ruby", "-ryaml", "-rjson", "-e", "puts JSON.generate( YAML.load_file( ARGV[0] ) )", file], {
    cwd: REPO_ROOT, encoding: "utf8"
  } );
  return JSON.parse( json );
}

let config;

test.before( async ( ) => {
  await writeWorkbook( built );
  const { yaml } = await exportYaml( built );
  config = loadWithRuby( yaml );
} );
test.after( ( ) => fs.rmSync( tmp, { recursive: true, force: true } ) );

test( "country codes load as strings in Ruby, including NO", ( ) => {
  const keys = Object.keys( config.countries );
  assert.ok( keys.includes( "NO" ) );
  keys.forEach( k => assert.match( k, /^[A-Z]{2}$/ ) );
  Object.values( config.countries ).forEach( c => assert.ok( config.currencies[c.currency], c.currency ) );
} );

test( "settings become the top-level keys", ( ) => {
  assert.strictEqual( config.default_country, "US" );
  assert.deepStrictEqual( config.tier_names, ["min", "mid", "max"] );
  assert.deepStrictEqual( config.frequencies, { once: "once", monthly: "monthly" } );
  assert.deepStrictEqual( config.fru, { default_url: DEFAULT_DONATION_URL } );
} );

test( "currencies carry their amounts and full format", ( ) => {
  assert.deepStrictEqual( config.currencies.DKK.tiers, { once: { min: 40, mid: 150, max: 750 } } );
  assert.strictEqual( config.currencies.DKK.purchasing_power_adjusted, true );
  assert.deepStrictEqual( config.currencies.THB.tiers, { once: { min: 150 } } );
  assert.strictEqual( config.currencies.THB.purchasing_power_adjusted, false );
  assert.strictEqual( config.currencies.USD.format, "%u%n (%c)" );
  assert.strictEqual( config.currencies.INR.grouping, "indian" );
  // Defaults are left out
  assert.strictEqual( config.currencies.USD.grouping, undefined );
  assert.strictEqual( config.currencies.USD.group_min_digits, undefined );
} );

test( "countries only keep what differs from their currency", ( ) => {
  const formatKeys = c => Object.keys( c ).filter( k => ["symbol", "format", "delimiter", "separator", "group_min_digits", "grouping"].includes( k ) );
  assert.deepStrictEqual( formatKeys( config.countries.US ), [] );
  assert.strictEqual( config.countries.US.tiers, undefined );
  // France groups with a space, the EUR default (from Germany) with a dot
  assert.strictEqual( config.countries.FR.delimiter, " " );
  assert.strictEqual( config.countries.ES.group_min_digits, 2 );
  // Catalan in Spain groups 1.000, unlike Spanish
  assert.strictEqual( config.countries.ES.formats.ca.group_min_digits, 1 );
  assert.deepStrictEqual( config.countries.CA.locales, ["en", "fr"] );
  assert.strictEqual( config.countries.CA.formats.fr.format, "%n %u (%c)" );
} );

test( "edits in the workbook reach the YAML", async ( ) => {
  const wb = await readWorkbook( built );
  const countries = wb.getWorksheet( TABS.countries );
  const row = countries.getColumn( 1 ).values.indexOf( "FR" );
  countries.getRow( row ).getCell( 4 ).value = 6;
  const kenya = countries.getColumn( 1 ).values.indexOf( "KE" );
  countries.getRow( kenya ).getCell( 15 ).value = "No";
  const currencies = wb.getWorksheet( TABS.currencies );
  const eur = currencies.getColumn( 1 ).values.indexOf( "EUR" );
  currencies.getRow( eur ).getCell( currencies.getRow( 2 ).values.indexOf( "Enabled in FundraiseUp campaign?" ) ).value = "Yes";
  const settings = wb.getWorksheet( TABS.settings );
  settings.getRow( 6 ).getCell( 3 ).value = "source=announcement, campaign=fall";
  settings.getRow( 7 ).getCell( 3 ).value = "inaturalist";

  const { yaml } = await exportYaml( Buffer.from( await wb.xlsx.writeBuffer( ) ) );
  const edited = loadWithRuby( yaml );
  assert.deepStrictEqual( edited.countries.FR.tiers, { once: { min: 6 } } );
  assert.strictEqual( edited.countries.KE.enabled, false );
  assert.strictEqual( edited.currencies.EUR.fru_enabled, true );
  assert.deepStrictEqual( edited.fru.custom_fields, { source: "announcement", campaign: "fall" } );
  assert.deepStrictEqual( edited.fru.utm_defaults, { utm_source: "inaturalist" } );
} );

test( "a workbook with errors isn't exported", async ( ) => {
  const wb = await readWorkbook( built );
  const currencies = wb.getWorksheet( TABS.currencies );
  const row = currencies.getColumn( 1 ).values.indexOf( "ZMW" );
  currencies.getRow( row ).getCell( 1 ).value = "ZZZ";
  const { result, yaml } = await exportYaml( Buffer.from( await wb.xlsx.writeBuffer( ) ) );
  assert.strictEqual( yaml, null );
  assert.ok( result.errors.some( e => /ZZZ isn't a currency FundraiseUp supports/.test( e.message ) ) );
} );

test( "the output is the same each time", async ( ) => {
  const a = ( await exportYaml( built ) ).yaml;
  const b = ( await exportYaml( built ) ).yaml;
  assert.strictEqual( a, b );
} );
