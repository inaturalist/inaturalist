// Turns written examples of an amount ("1 000,00 €" and "1 000 000,00 €")
// into the formatting fields stored in config/donation_currencies.yml:
// format, delimiter, separator, group_min_digits and grouping.

// Any kind of space reads as a plain space (the app renders spaces as
// non-breaking); bidi marks are invisible and dropped
function normalize( text ) {
  return String( text ?? "" )
    .replace( /[    ]/g, " " )
    .replace( /[‎‏؜]/g, "" )
    .replace( /\s+/g, " " )
    .trim( );
}

// Splits an example into the text before the number, the number, and the
// text after it. The number runs from the first digit to the last digit.
function splitNumber( example ) {
  const match = example.match( /^(\D*)(\d[\s\S]*\d|\d)(\D*)$/ );
  if ( !match ) return null;
  return { before: match[1], number: match[2], after: match[3] };
}

// Replaces the symbol and the ISO code in the text around the number with
// %u and %c, so "$" + " (CAD)" becomes "%u" + " (%c)"
function affixPattern( text, { symbol, code } ) {
  let out = text;
  let found = false;
  if ( symbol && out.includes( symbol ) ) {
    out = out.replace( symbol, "%u" );
    found = true;
  }
  if ( code && code !== symbol && out.includes( code ) ) {
    out = out.replace( code, "%c" );
    found = true;
  }
  return { pattern: out, found };
}

function parseThousand( number ) {
  // 1,000.00 / 1 000,00 / 1000,00 / 1.000 (no cents)
  const match = number.match( /^1(\D?)000(?:(\D)00)?$/ );
  if ( !match ) return null;
  return { delimiter: match[1], separator: match[2] };
}

function parseMillion( number ) {
  const standard = number.match( /^1(\D)000\1(?:000)(?:(\D)00)?$/ );
  if ( standard ) {
    return { delimiter: standard[1], separator: standard[2], grouping: "standard" };
  }
  const indian = number.match( /^10(\D)00\1(?:000)(?:(\D)00)?$/ );
  if ( indian ) {
    return { delimiter: indian[1], separator: indian[2], grouping: "indian" };
  }
  return null;
}

// examples: { thousand, million, symbol, code }
// Returns { fields, errors, warnings }. fields is null when there are errors.
function parseExamples( { thousand, million, symbol, code } ) {
  const errors = [];
  const warnings = [];
  const sym = normalize( symbol );
  const iso = normalize( code );
  const parts = {};

  [["thousand", "1,000.00"], ["million", "1,000,000.00"]].forEach( ( [key, label] ) => {
    const example = normalize( key === "thousand" ? thousand : million );
    if ( !example ) {
      errors.push( `The ${label} example is blank` );
      return;
    }
    const split = splitNumber( example );
    if ( !split ) {
      errors.push( `Couldn't find a number in the ${label} example "${example}"` );
      return;
    }
    const before = affixPattern( split.before, { symbol: sym, code: iso } );
    const after = affixPattern( split.after, { symbol: sym, code: iso } );
    if ( !before.found && !after.found ) {
      errors.push( `The ${label} example "${example}" doesn't contain the symbol "${sym}"`
        + `${iso ? ` or the code ${iso}` : ""}` );
    }
    const number = key === "thousand" ? parseThousand( split.number ) : parseMillion( split.number );
    if ( !number ) {
      errors.push( `The ${label} example "${example}" doesn't read as ${label}` );
      return;
    }
    parts[key] = { ...number, format: `${before.pattern}%n${after.pattern}` };
  } );

  if ( errors.length > 0 ) return { fields: null, errors, warnings };

  const { thousand: t, million: m } = parts;
  if ( t.format !== m.format ) {
    errors.push( `The examples put the symbol in different places ("${t.format}" vs "${m.format}")` );
  }
  if ( t.separator !== m.separator ) {
    errors.push( `The examples use different decimal separators ("${t.separator ?? "none"}" vs "${m.separator ?? "none"}")` );
  }
  if ( t.delimiter !== "" && t.delimiter !== m.delimiter ) {
    errors.push( `The examples use different thousands separators ("${t.delimiter}" vs "${m.delimiter}")` );
  }
  if ( m.separator && m.separator === m.delimiter ) {
    errors.push( `The thousands and decimal separators are both "${m.delimiter}"` );
  }
  if ( !m.separator ) {
    warnings.push( "No cents in the examples, so the decimal separator is unknown" );
  }
  if ( errors.length > 0 ) return { fields: null, errors, warnings };

  const fields = {
    format: m.format,
    delimiter: m.delimiter,
    group_min_digits: t.delimiter === "" ? 2 : 1,
    grouping: m.grouping
  };
  if ( sym ) fields.symbol = sym;
  if ( m.separator ) fields.separator = m.separator;
  return { fields, errors, warnings };
}

module.exports = { normalize, parseExamples };
