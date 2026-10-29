// Checks a filled-in donation workbook and reports problems as Markdown.
// With --fill, also writes a copy with blank format cells filled from CLDR.
//
//   node check.js donation-config.xlsx
//   node check.js donation-config.xlsx --fill donation-config-filled.xlsx

const fs = require( "node:fs" );
const ExcelJS = require( "exceljs" );
const {
  TABS, H, HEADER_ROW, FIRST_ROW, TIERS, FREQUENCIES, TIER_COLUMNS
} = require( "./layout" );
const { parseExamples, normalize } = require( "./parse" );
const {
  FRU_CURRENCIES, suggestion, currencyHome, currencyName, formatLanguage, floorAmount, MIN_USD, USD_RATES
} = require( "./seed" );
const { loadLocales } = require( "./locales" );

// The only tier every enabled country needs, for now
const REQUIRED_TIER = { freq: "One-time", tier: "min" };
const REQUIRED_HEADER = TIER_COLUMNS[REQUIRED_TIER.freq][REQUIRED_TIER.tier];
const { restoreValidations } = require( "./xlsx_validations" );

function cellText( cell ) {
  const { value } = cell;
  if ( value === null || value === undefined ) return "";
  if ( typeof value === "object" ) {
    if ( value.richText ) return value.richText.map( r => r.text ).join( "" ).trim( );
    if ( "result" in value ) return String( value.result ?? "" ).trim( );
    if ( value.text ) return String( value.text ).trim( );
  }
  return String( value ).trim( );
}

// Rows of a table tab as { row, get(header), cell(header) }, skipping blank
// rows and example rows
function readTable( ws ) {
  const columns = {};
  ws.getRow( HEADER_ROW ).eachCell( ( cell, col ) => { columns[cellText( cell )] = col; } );
  const rows = [];
  for ( let r = FIRST_ROW; r <= ws.rowCount; r += 1 ) {
    const row = ws.getRow( r );
    const cell = header => ( columns[header] ? row.getCell( columns[header] ) : null );
    const get = header => ( cell( header ) ? cellText( cell( header ) ) : "" );
    // Formula columns (tier amount, countries using a currency) don't count
    const isBlank = Object.values( columns ).every( col => (
      row.getCell( col ).formula || cellText( row.getCell( col ) ) === ""
    ) );
    if ( !isBlank && !/^Example row/.test( get( H.notes ) ) ) {
      rows.push( { row: r, get, cell } );
    }
  }
  return { columns, rows };
}

const languagesOf = value => value.split( /[,\s]+/ ).filter( Boolean );

function checkWorkbookObject( wb ) {
  const errors = [];
  const warnings = [];
  const fills = [];
  const error = ( tab, row, message ) => errors.push( { tab, row, message } );
  const warn = ( tab, row, message ) => warnings.push( { tab, row, message } );
  const localeCodes = new Set( loadLocales( ).map( l => l.code ) );

  const tab = name => {
    const ws = wb.getWorksheet( name );
    if ( !ws ) error( name, null, "Tab is missing" );
    return ws;
  };

  // Value of a format cell, or what CLDR would fill it with when it's blank
  const formatValue = ( tabName, r, header, cldr ) => {
    const value = r.get( header );
    if ( value || !cldr || !r.cell( header ) ) return value;
    fills.push( {
      tab: tabName, row: r.row, header, value: cldr
    } );
    return cldr;
  };

  // Parses a row's two examples, reporting errors, and comparing with CLDR
  const checkExamples = ( tabName, r, { thousand, million }, symbol, code, cldr ) => {
    const { fields, errors: problems, warnings: notes } = parseExamples( {
      thousand, million, symbol, code
    } );
    problems.forEach( p => error( tabName, r.row, p ) );
    notes.forEach( n => warn( tabName, r.row, n ) );
    if ( fields && cldr && ( normalize( thousand ) !== cldr.thousand || normalize( million ) !== cldr.million ) ) {
      warn( tabName, r.row, `Differs from the suggested format (CLDR, with the code added where the symbol is shared): "${cldr.thousand}" and "${cldr.million}". Fine if intended.` );
    }
    return fields;
  };

  const safeSuggest = ( lang, country, currency ) => {
    if ( !lang || !country || !currency ) return null;
    try {
      return suggestion( lang, country, currency );
    } catch ( e ) {
      return null;
    }
  };

  // Formats shown without an ISO code, by symbol, to spot a bare $ shared
  // by several currencies
  const bareSymbols = {};
  const noteBareSymbol = ( fields, currency ) => {
    if ( !fields || fields.format.includes( "%c" ) ) return;
    bareSymbols[fields.symbol] = bareSymbols[fields.symbol] || new Set( );
    bareSymbols[fields.symbol].add( currency );
  };

  // A row's tier amounts as { "One-time": { min: 5, ... }, ... }, reporting
  // any that aren't whole numbers or are worth less than MIN_USD. Blank tiers
  // are left out.
  const readAmounts = ( tabName, r, currency ) => {
    const amounts = {};
    FREQUENCIES.forEach( freq => {
      amounts[freq] = {};
      TIERS.forEach( tier => {
        const header = TIER_COLUMNS[freq][tier];
        const raw = r.get( header );
        if ( raw === "" ) return;
        const n = Number( raw );
        if ( !Number.isInteger( n ) || n <= 0 ) {
          error( tabName, r.row, `${header} "${raw}" isn't a whole number above 0` );
          return;
        }
        amounts[freq][tier] = n;
        const floor = floorAmount( currency );
        if ( floor && n < floor ) {
          const usd = ( n / USD_RATES.rates[currency] ).toFixed( 2 );
          error( tabName, r.row, `${header} ${n} ${currency} is about $${usd}, under the $${MIN_USD} minimum (at least ${Math.ceil( floor )}; rates from ${USD_RATES.updated})` );
        }
      } );
    } );
    return amounts;
  };
  const checkOrder = ( tabName, r, amounts ) => {
    FREQUENCIES.forEach( freq => {
      const { min, mid, max } = amounts[freq];
      const present = [min, mid, max].filter( Boolean );
      if ( present.some( ( n, i ) => i > 0 && n < present[i - 1] ) ) {
        error( tabName, r.row, `${freq} amounts aren't in min ≤ mid ≤ max order (${min ?? "-"}, ${mid ?? "-"}, ${max ?? "-"})` );
      }
    } );
  };
  const hasAny = amounts => FREQUENCIES.some( freq => Object.keys( amounts[freq] ).length > 0 );

  // ---------- Currencies ----------
  const currencies = {};
  const currenciesWs = tab( TABS.currencies );
  if ( currenciesWs ) {
    readTable( currenciesWs ).rows.forEach( r => {
      const code = r.get( H.currencyCode );
      if ( !/^[A-Z]{3}$/.test( code ) ) {
        error( TABS.currencies, r.row, `Currency code "${code}" isn't a 3-letter uppercase ISO code` );
        return;
      }
      if ( currencies[code] ) error( TABS.currencies, r.row, `${code} is listed more than once` );
      if ( !FRU_CURRENCIES.includes( code ) ) {
        error( TABS.currencies, r.row, `${code} isn't a currency FundraiseUp supports` );
      }
      const home = currencyHome( code );
      const cldr = home ? safeSuggest( home[3][0], home[0], code ) : null;
      if ( !r.get( H.currencyName ) ) {
        try {
          fills.push( {
            tab: TABS.currencies, row: r.row, header: H.currencyName, value: currencyName( code )
          } );
        } catch ( e ) { /* unknown code: nothing to fill */ }
      }
      const symbol = formatValue( TABS.currencies, r, H.symbol, cldr?.symbol );
      const thousand = formatValue( TABS.currencies, r, H.currencyThousand, cldr?.thousand );
      const million = formatValue( TABS.currencies, r, H.currencyMillion, cldr?.million );
      if ( !symbol ) error( TABS.currencies, r.row, "Symbol is blank" );
      const fields = checkExamples( TABS.currencies, r, { thousand, million }, symbol, code, cldr );
      const amounts = readAmounts( TABS.currencies, r, code );
      checkOrder( TABS.currencies, r, amounts );
      currencies[code] = {
        row: r.row, symbol, fields, amounts, fruEnabled: r.get( H.fruEnabled )
      };
    } );
  }

  // ---------- Countries ----------
  const countries = {};
  const countriesWs = tab( TABS.countries );
  if ( countriesWs ) {
    readTable( countriesWs ).rows.forEach( r => {
      const code = r.get( H.countryCode );
      if ( !/^[A-Z]{2}$/.test( code ) ) {
        error( TABS.countries, r.row, `Country code "${code}" isn't a 2-letter uppercase ISO code` );
        return;
      }
      if ( countries[code] ) error( TABS.countries, r.row, `${code} is listed more than once` );
      const currency = r.get( H.currency );
      if ( !currencies[currency] ) {
        error( TABS.countries, r.row, `Currency "${currency}" isn't on the Currencies tab` );
      }
      const langs = languagesOf( r.get( H.languages ) );
      langs.filter( l => !localeCodes.has( l ) ).forEach( l => {
        error( TABS.countries, r.row, `Language "${l}" isn't an iNaturalist locale (see Lists)` );
      } );

      // Tier amounts: the country's own, else its currency's. Order is checked
      // on the combination when the country sets any of its own.
      const own = readAmounts( TABS.countries, r, currency );
      const amounts = {};
      FREQUENCIES.forEach( freq => {
        amounts[freq] = { ...currencies[currency]?.amounts[freq], ...own[freq] };
      } );
      if ( hasAny( own ) ) checkOrder( TABS.countries, r, amounts );
      // Disabled countries fall back to the default country, so need no amounts
      const enabled = r.get( H.enabled ) !== "No";
      if ( enabled && !amounts[REQUIRED_TIER.freq][REQUIRED_TIER.tier] && currencies[currency] ) {
        currencies[currency].unpriced = [...( currencies[currency].unpriced || [] ), code];
      }

      // Format: blank examples fall back to the currency, but CLDR can fill them
      const cldr = safeSuggest( formatLanguage( code, langs ), code, currency );
      const symbol = formatValue( TABS.countries, r, H.countrySymbol, cldr?.symbol )
        || currencies[currency]?.symbol;
      const thousand = formatValue( TABS.countries, r, H.countryThousand, cldr?.thousand );
      const million = formatValue( TABS.countries, r, H.countryMillion, cldr?.million );
      let fields = currencies[currency]?.fields;
      if ( thousand || million ) {
        fields = checkExamples( TABS.countries, r, { thousand, million }, symbol, currency, cldr );
      }
      if ( enabled ) noteBareSymbol( fields, currency );

      countries[code] = {
        currency, amounts, symbol, enabled
      };
    } );
  }

  // An enabled country needs a one-time min, from itself or its currency.
  // Reported once per currency rather than on every country using it.
  Object.entries( currencies ).forEach( ( [code, currency] ) => {
    if ( !currency.unpriced ) return;
    const list = currency.unpriced.length > 8
      ? `${currency.unpriced.slice( 0, 8 ).join( ", " )} and ${currency.unpriced.length - 8} more`
      : currency.unpriced.join( ", " );
    error( TABS.currencies, currency.row, `${REQUIRED_HEADER} missing, and enabled countries using ${code} don't set their own (${list}). Set it here, set it on those countries, or disable them.` );
  } );

  // ---------- Settings ----------
  const settingsWs = tab( TABS.settings );
  if ( settingsWs ) {
    for ( let r = 2; r <= settingsWs.rowCount; r += 1 ) {
      const row = settingsWs.getRow( r );
      const setting = cellText( row.getCell( 1 ) );
      const value = cellText( row.getCell( 3 ) );
      if ( cellText( row.getCell( 2 ) ) === "Required" && !value ) {
        error( TABS.settings, r, `${setting} is blank` );
      }
      if ( setting === "Fallback country" && value && !countries[value] ) {
        error( TABS.settings, r, `Fallback country "${value}" isn't on the Countries tab` );
      } else if ( setting === "Fallback country" && value ) {
        const gaps = FREQUENCIES.flatMap( freq => TIERS
          .filter( tier => !countries[value].amounts[freq][tier] )
          .map( tier => TIER_COLUMNS[freq][tier] ) );
        if ( gaps.length > 0 ) {
          warn( TABS.settings, r, `Fallback country ${value} has no ${gaps.join( ", " )}. Buttons for those tiers show nothing wherever a country has no amount of its own.` );
        }
      }
    }
  }

  // ---------- Currencies in use must be enabled in FundraiseUp ----------
  const used = new Set( Object.values( countries ).filter( c => c.enabled ).map( c => c.currency ) );
  used.forEach( code => {
    const currency = currencies[code];
    // Unpriced currencies are already errors; confirming FundraiseUp can wait
    if ( !currency || currency.unpriced ) return;
    if ( currency.fruEnabled === "No" ) {
      error( TABS.currencies, currency.row, `${code} is used by a country but isn't enabled in the FundraiseUp campaign` );
    } else if ( currency.fruEnabled !== "Yes" ) {
      warn( TABS.currencies, currency.row, `${code} is used by a country; confirm it's enabled in the FundraiseUp campaign` );
    }
  } );

  // ---------- Country by language ----------
  const langWs = tab( TABS.countryLanguages );
  if ( langWs ) {
    const seen = new Set( );
    readTable( langWs ).rows.forEach( r => {
      const country = r.get( H.country );
      const lang = r.get( H.language );
      const countryInfo = countries[country];
      if ( !countryInfo ) {
        error( TABS.countryLanguages, r.row, `Country "${country}" isn't on the Countries tab` );
        return;
      }
      if ( !localeCodes.has( lang ) ) {
        error( TABS.countryLanguages, r.row, `Language "${lang}" isn't an iNaturalist locale (see Lists)` );
        return;
      }
      if ( seen.has( `${country}/${lang}` ) ) {
        error( TABS.countryLanguages, r.row, `${country}/${lang} is listed more than once` );
      }
      seen.add( `${country}/${lang}` );
      const cldr = safeSuggest( lang, country, countryInfo.currency );
      const symbol = r.get( H.langSymbol ) || countryInfo.symbol;
      const thousand = formatValue( TABS.countryLanguages, r, H.langThousand, cldr?.thousand );
      const million = formatValue( TABS.countryLanguages, r, H.langMillion, cldr?.million );
      const fields = checkExamples( TABS.countryLanguages, r, { thousand, million }, symbol, countryInfo.currency, cldr );
      if ( countryInfo.enabled ) noteBareSymbol( fields, countryInfo.currency );
    } );
  }

  Object.entries( bareSymbols ).forEach( ( [symbol, codes] ) => {
    if ( codes.size > 1 ) {
      warn( "All format tabs", null, `"${symbol}" is shown without a currency code for ${[...codes].sort( ).join( ", " )}. Viewers may not know which currency it is; consider adding the code to the examples, as in $1,000.00 (CAD).` );
    }
  } );

  // ---------- Button text ----------
  const buttonsWs = tab( TABS.buttons );
  if ( buttonsWs ) {
    let hasEnglish = false;
    readTable( buttonsWs ).rows.forEach( r => {
      const lang = r.get( H.language );
      if ( !localeCodes.has( lang ) ) {
        error( TABS.buttons, r.row, `Language "${lang}" isn't an iNaturalist locale` );
      }
      [H.onceText, H.monthlyText].forEach( header => {
        const value = r.get( header );
        if ( lang === "en" && !value ) error( TABS.buttons, r.row, `English ${header.toLowerCase( )} is required` );
        if ( value && !value.includes( "{amount}" ) ) {
          error( TABS.buttons, r.row, `${header} "${value}" doesn't contain {amount}` );
        }
      } );
      if ( lang === "en" ) hasEnglish = true;
    } );
    if ( !hasEnglish ) error( TABS.buttons, null, "There's no English row" );
  }

  // ---------- Exact text overrides ----------
  const overridesWs = tab( TABS.overrides );
  if ( overridesWs ) {
    readTable( overridesWs ).rows.forEach( r => {
      const country = r.get( H.country );
      const lang = r.get( H.language );
      const freq = r.get( H.frequency );
      const tier = r.get( H.tier );
      const exact = r.get( H.exactText );
      if ( !countries[country] ) error( TABS.overrides, r.row, `Country "${country}" isn't on the Countries tab` );
      if ( !localeCodes.has( lang ) ) error( TABS.overrides, r.row, `Language "${lang}" isn't an iNaturalist locale` );
      if ( !FREQUENCIES.includes( freq ) ) error( TABS.overrides, r.row, `Frequency "${freq}" should be One-time or Monthly` );
      if ( !TIERS.includes( tier ) ) error( TABS.overrides, r.row, `Tier "${tier}" should be one of ${TIERS.join( ", " )}` );
      if ( !exact ) error( TABS.overrides, r.row, "Exact button text is blank" );
      const amount = countries[country]?.amounts?.[freq]?.[tier];
      if ( exact && amount ) {
        const digits = exact.replace( /\D/g, "" );
        if ( digits !== String( amount ) ) {
          error( TABS.overrides, r.row, `"${exact}" doesn't show the tier amount ${amount}` );
        }
      } else if ( exact && countries[country] ) {
        warn( TABS.overrides, r.row, "Can't check the text until the tier amount is filled in" );
      }
    } );
  }

  return { errors, warnings, fills };
}

async function readWorkbook( input ) {
  const wb = new ExcelJS.Workbook( );
  await wb.xlsx.load( Buffer.isBuffer( input ) ? input : fs.readFileSync( input ) );
  return wb;
}

async function checkWorkbook( input ) {
  return checkWorkbookObject( await readWorkbook( input ) );
}

// Writes a copy with blank format cells filled from CLDR. Never changes a
// cell that has a value.
async function fillWorkbook( input, out ) {
  const original = Buffer.isBuffer( input ) ? input : fs.readFileSync( input );
  const wb = await readWorkbook( original );
  const result = checkWorkbookObject( wb );
  const today = new Date( ).toISOString( ).slice( 0, 10 );
  result.fills.forEach( f => {
    const ws = wb.getWorksheet( f.tab );
    const { columns } = readTable( ws );
    const cell = ws.getRow( f.row ).getCell( columns[f.header] );
    if ( cellText( cell ) !== "" ) return;
    cell.value = f.value;
    cell.note = `Filled from CLDR (Unicode) on ${today}. Check it and set "Format checked?" to Yes.`;
  } );
  const buffer = await restoreValidations( original, await wb.xlsx.writeBuffer( ) );
  fs.writeFileSync( out, buffer );
  return result;
}

function report( { errors, warnings, fills }, { filledTo } = {} ) {
  const lines = ["# Donation workbook check", ""];
  lines.push( `${errors.length} errors, ${warnings.length} warnings, ${fills.length} blank cells CLDR can fill`, "" );
  const section = ( title, items ) => {
    if ( items.length === 0 ) return;
    lines.push( `## ${title}`, "" );
    const byTab = {};
    items.forEach( i => { ( byTab[i.tab] = byTab[i.tab] || [] ).push( i ); } );
    Object.entries( byTab ).forEach( ( [tabName, list] ) => {
      lines.push( `### ${tabName}`, "" );
      list.forEach( i => lines.push( `- ${i.row ? `Row ${i.row}: ` : ""}${i.message}` ) );
      lines.push( "" );
    } );
  };
  section( "Errors", errors );
  section( "Warnings", warnings );
  if ( fills.length > 0 ) {
    section( filledTo ? `Filled from CLDR into ${filledTo}` : "Blank cells CLDR can fill (run with --fill)", fills.map( f => ( {
      tab: f.tab, row: f.row, message: `${f.header}: ${f.value}`
    } ) ) );
  }
  return lines.join( "\n" );
}

if ( require.main === module ) {
  const [input, flag, out] = process.argv.slice( 2 );
  if ( !input || ( flag && ( flag !== "--fill" || !out ) ) ) {
    console.error( "Usage: node check.js <workbook.xlsx> [--fill <out.xlsx>]" );
    process.exit( 2 );
  }
  const run = flag ? fillWorkbook( input, out ) : checkWorkbook( input );
  run.then( result => {
    console.log( report( result, { filledTo: out } ) );
    process.exitCode = result.errors.length > 0 ? 1 : 0;
  } );
}

module.exports = {
  checkWorkbook, fillWorkbook, report, readWorkbook
};
