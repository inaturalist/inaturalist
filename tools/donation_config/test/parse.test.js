const test = require( "node:test" );
const assert = require( "node:assert" );
const { parseExamples } = require( "../parse" );

const parse = ( thousand, million, symbol, code ) => parseExamples( {
  thousand, million, symbol, code
} );

test( "France: space thousands separator, comma decimal, symbol after", ( ) => {
  const { fields, errors } = parse( "1 000,00 €", "1 000 000,00 €", "€", "EUR" );
  assert.deepStrictEqual( errors, [] );
  assert.deepStrictEqual( fields, {
    format: "%n %u",
    symbol: "€",
    delimiter: " ",
    separator: ",",
    group_min_digits: 1,
    grouping: "standard"
  } );
} );

test( "French in Switzerland uses an apostrophe and a decimal point", ( ) => {
  const { fields } = parse( "1'000.00 CHF", "1'000'000.00 CHF", "CHF", "CHF" );
  assert.strictEqual( fields.delimiter, "'" );
  assert.strictEqual( fields.separator, "." );
  assert.strictEqual( fields.format, "%n %u" );
} );

test( "Spain doesn't group four-digit numbers", ( ) => {
  const { fields } = parse( "1000,00 €", "1.000.000,00 €", "€", "EUR" );
  assert.strictEqual( fields.group_min_digits, 2 );
  assert.strictEqual( fields.delimiter, "." );
  assert.strictEqual( fields.separator, "," );
} );

test( "India uses lakh grouping", ( ) => {
  const { fields } = parse( "₹1,000.00", "₹10,00,000.00", "₹", "INR" );
  assert.strictEqual( fields.grouping, "indian" );
  assert.strictEqual( fields.delimiter, "," );
  assert.strictEqual( fields.format, "%u%n" );
} );

test( "a symbol containing a period (Danish kr.) isn't read as a separator", ( ) => {
  const { fields, errors } = parse( "1.000,00 kr.", "1.000.000,00 kr.", "kr.", "DKK" );
  assert.deepStrictEqual( errors, [] );
  assert.strictEqual( fields.format, "%n %u" );
  assert.strictEqual( fields.separator, "," );
} );

test( "an ISO code next to the symbol becomes %c", ( ) => {
  const { fields } = parse( "$1,000.00 (CAD)", "$1,000,000.00 (CAD)", "$", "CAD" );
  assert.strictEqual( fields.format, "%u%n (%c)" );
} );

test( "non-breaking and narrow spaces read as plain spaces", ( ) => {
  const { fields } = parse( "1 000,00 €", "1 000 000,00 €", "€", "EUR" );
  assert.strictEqual( fields.delimiter, " " );
  assert.strictEqual( fields.format, "%n %u" );
} );

test( "examples without cents warn that the decimal separator is unknown", ( ) => {
  const { fields, warnings } = parse( "$1,000", "$1,000,000", "$", "USD" );
  assert.strictEqual( fields.separator, undefined );
  assert.match( warnings[0], /decimal separator is unknown/ );
} );

test( "an example that isn't the right number is an error", ( ) => {
  const { fields, errors } = parse( "one thousand", "$1,000,000.00", "$", "USD" );
  assert.strictEqual( fields, null );
  assert.match( errors[0], /Couldn't find a number/ );
  assert.match( parse( "$1,500.00", "$1,000,000.00", "$", "USD" ).errors[0], /doesn't read as 1,000.00/ );
} );

test( "a missing symbol is an error", ( ) => {
  const { errors } = parse( "1,000.00", "1,000,000.00", "$", "USD" );
  assert.match( errors[0], /doesn't contain the symbol/ );
} );

test( "examples that disagree are an error", ( ) => {
  assert.match( parse( "1.000,00 €", "1,000,000.00 €", "€", "EUR" ).errors.join( " " ), /different decimal separators/ );
  assert.match( parse( "€1.000,00", "1.000.000,00 €", "€", "EUR" ).errors.join( " " ), /different places/ );
  assert.match( parse( "1.000,00 €", "1 000 000,00 €", "€", "EUR" ).errors.join( " " ), /different thousands separators/ );
} );

test( "a blank example is an error", ( ) => {
  assert.match( parse( "", "1 000 000,00 €", "€", "EUR" ).errors[0], /blank/ );
} );
