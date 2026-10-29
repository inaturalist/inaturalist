// Starter countries and CLDR (Node Intl) format lookups used to pre-fill and
// check the donation workbook.

const { normalize } = require( "./parse" );

// [ISO2, name, currency, iNat languages (first = main)]. A starting point for
// engagement to edit, not data about where iNat's users are.
const STARTER = [
  ["US", "United States", "USD", ["en", "es"]],
  ["CA", "Canada", "CAD", ["en", "fr"]],
  ["MX", "Mexico", "MXN", ["es"]],
  ["GB", "United Kingdom", "GBP", ["en"]],
  ["IE", "Ireland", "EUR", ["en"]],
  ["AU", "Australia", "AUD", ["en"]],
  ["NZ", "New Zealand", "NZD", ["en", "mi"]],
  ["ZA", "South Africa", "ZAR", ["en", "af"]],
  ["IN", "India", "INR", ["en", "hi"]],
  ["DE", "Germany", "EUR", ["de"]],
  ["AT", "Austria", "EUR", ["de"]],
  ["CH", "Switzerland", "CHF", ["de", "fr", "it"]],
  ["FR", "France", "EUR", ["fr"]],
  ["BE", "Belgium", "EUR", ["nl", "fr"]],
  ["NL", "Netherlands", "EUR", ["nl"]],
  ["LU", "Luxembourg", "EUR", ["fr", "de", "lb"]],
  ["ES", "Spain", "EUR", ["es", "ca"]],
  ["PT", "Portugal", "EUR", ["pt"]],
  ["IT", "Italy", "EUR", ["it"]],
  ["GR", "Greece", "EUR", ["el"]],
  ["FI", "Finland", "EUR", ["fi", "sv"]],
  ["SE", "Sweden", "SEK", ["sv"]],
  ["NO", "Norway", "NOK", ["nb"]],
  ["DK", "Denmark", "DKK", ["da"]],
  ["PL", "Poland", "PLN", ["pl"]],
  ["CZ", "Czechia", "CZK", ["cs"]],
  ["UA", "Ukraine", "UAH", ["uk"]],
  ["TR", "Türkiye", "TRY", ["tr"]],
  ["IL", "Israel", "ILS", ["he"]],
  ["BR", "Brazil", "BRL", ["pt"]],
  ["AR", "Argentina", "ARS", ["es"]],
  ["CL", "Chile", "CLP", ["es"]],
  ["CO", "Colombia", "COP", ["es"]],
  ["CR", "Costa Rica", "CRC", ["es"]],
  ["PE", "Peru", "PEN", ["es"]],
  ["JP", "Japan", "JPY", ["ja"]],
  ["KR", "South Korea", "KRW", ["ko"]],
  ["TW", "Taiwan", "TWD", ["zh-TW"]],
  ["HK", "Hong Kong", "HKD", ["zh-HK", "en"]],
  ["SG", "Singapore", "SGD", ["en"]],
  ["MY", "Malaysia", "MYR", ["ms", "en"]],
  ["ID", "Indonesia", "IDR", ["id"]]
];

// Currencies FundraiseUp can charge for a US-registered nonprofit. FundraiseUp's
// supported-currencies page defers to Stripe, so this is Stripe's list of
// presentment currencies for US accounts (docs.stripe.com/currencies, 2026-10-29).
const FRU_CURRENCIES = [
  "AED", "AFN", "ALL", "AMD", "ANG", "AOA", "ARS", "AUD", "AWG", "AZN", "BAM", "BBD",
  "BDT", "BIF", "BMD", "BND", "BOB", "BRL", "BSD", "BWP", "BYN", "BZD", "CAD", "CDF",
  "CHF", "CLP", "CNY", "COP", "CRC", "CVE", "CZK", "DJF", "DKK", "DOP", "DZD", "EGP",
  "ETB", "EUR", "FJD", "FKP", "GBP", "GEL", "GIP", "GMD", "GNF", "GTQ", "GYD", "HKD",
  "HNL", "HTG", "HUF", "IDR", "ILS", "INR", "ISK", "JMD", "JPY", "KES", "KGS", "KHR",
  "KMF", "KRW", "KYD", "KZT", "LAK", "LBP", "LKR", "LRD", "LSL", "MAD", "MDL", "MGA",
  "MKD", "MMK", "MNT", "MOP", "MUR", "MVR", "MWK", "MXN", "MYR", "MZN", "NAD", "NGN",
  "NIO", "NOK", "NPR", "NZD", "PAB", "PEN", "PGK", "PHP", "PKR", "PLN", "PYG", "QAR",
  "RON", "RSD", "RUB", "RWF", "SAR", "SBD", "SCR", "SEK", "SGD", "SHP", "SLE", "SOS",
  "SRD", "STD", "SZL", "THB", "TJS", "TOP", "TRY", "TTD", "TWD", "TZS", "UAH", "UGX",
  "USD", "UYU", "UZS", "VND", "VUV", "WST", "XAF", "XCD", "XCG", "XOF", "XPF", "YER",
  "ZAR", "ZMW"
];

// The lowest amount on iNat's FundraiseUp donation form in each currency
// (frb.amounts.options7, from Casey 2026-10-29). Only the ratios to USD are
// used: they set each currency's suggested tiers.
const LOWEST_FORM_AMOUNTS = {
  USD: 2.75,
  CAD: 2.75,
  AUD: 2.75,
  NZD: 2.75,
  GBP: 2.75,
  EUR: 2.75,
  DKK: 20,
  HUF: 500,
  ILS: 10,
  INR: 25,
  JPY: 300,
  MYR: 10,
  NOK: 30,
  PLN: 10,
  CZK: 50,
  RON: 10,
  SEK: 30,
  UAH: 50,
  ZAR: 30,
  BRL: 15,
  CLP: 2000,
  COP: 10500,
  MXN: 50,
  PEN: 10,
  UYU: 100,
  CHF: 5
};

// One-time tiers suggested in USD, converted at the form amounts' ratio
const SUGGESTED_USD_TIERS = { min: 5, mid: 20, max: 100 };

// The whole number nearest x (by ratio) in a 1, 1.5, 2, 2.5, 3, 4, 5, 7.5
// series, e.g. 36 → 40, 545 → 500, 76364 → 75000
function niceRound( x ) {
  const base = 10 ** Math.floor( Math.log10( x ) );
  const distance = n => Math.abs( Math.log( n / x ) );
  return [1, 1.5, 2, 2.5, 3, 4, 5, 7.5, 10]
    .map( m => m * base )
    .filter( Number.isInteger )
    .reduce( ( best, n ) => ( distance( n ) < distance( best ) ? n : best ) );
}

// No amount may be worth less than this many USD at market rates
const MIN_USD = 3;

// Market units of each currency per USD (usd_rates.json; refresh with
// update_rates.js)
const USD_RATES = require( "./usd_rates.json" );

// The smallest amount in a currency worth at least MIN_USD, or undefined
// without a market rate
const floorAmount = currency => ( USD_RATES.rates[currency] ? MIN_USD * USD_RATES.rates[currency] : undefined );

// Round numbers near x: whole numbers below 10, and the 1, 1.5, 2, 2.5, 3,
// 4, 5, 7.5 series at x's order of magnitude
function niceCandidates( x ) {
  const base = 10 ** Math.floor( Math.log10( x ) );
  return [1, 2, 3, 4, 5, 6, 7, 8, 9, ...[1, 1.5, 2, 2.5, 3, 4, 5, 7.5, 10].map( m => m * base )]
    .filter( Number.isInteger );
}

// The smallest round number at or above x, e.g. 5.3 → 6, 137 → 150, 286 → 300
const niceCeil = x => Math.min( ...niceCandidates( x ).filter( n => n >= x ) );

// The largest round number at or below x, e.g. 18.4 → 15, 795 → 750
const niceFloor = x => Math.max( ...niceCandidates( x ).filter( n => n <= x ) );

// Whether a currency's suggested amounts are adjusted for purchasing power
// (it's on the donation form) rather than converted at market rates
const purchasingPowerAdjusted = currency => Boolean( LOWEST_FORM_AMOUNTS[currency] );

// Suggested one-time tiers for a currency. On the donation form: { min, mid,
// max }, each SUGGESTED_USD_TIERS at the form's ratio to USD (purchasing
// power), raised to MIN_USD at market rates if lower. Otherwise just { min }:
// the USD min at market rates, rounded down (never below $3.33, since the
// candidates are at most 1.5x apart). Undefined without a market rate.
function suggestedTiers( currency ) {
  if ( !purchasingPowerAdjusted( currency ) ) {
    const market = USD_RATES.rates[currency];
    return market ? { min: niceFloor( SUGGESTED_USD_TIERS.min * market ) } : undefined;
  }
  const rate = LOWEST_FORM_AMOUNTS[currency] / LOWEST_FORM_AMOUNTS.USD;
  const floor = floorAmount( currency );
  const tiers = {};
  Object.entries( SUGGESTED_USD_TIERS ).forEach( ( [tier, usd] ) => {
    const amount = niceRound( usd * rate );
    tiers[tier] = floor && amount < floor ? niceCeil( floor ) : amount;
  } );
  return tiers;
}

// [ISO2, language] whose formatting a currency's defaults come from, where the
// default is wrong: the first starter country using the currency, otherwise
// the country in the code's first two letters and CLDR's likeliest language
// there. Shared currencies get a representative country, and countries whose
// likeliest language has no CLDR number formats get another official one.
const CURRENCY_HOME = {
  EUR: ["DE"],
  XAF: ["CM"],
  XOF: ["SN", "fr"],
  XPF: ["PF"],
  XCD: ["AG"],
  XCG: ["CW", "nl"],
  // pt-CV's symbol is an invisible zero-width space, with $ as the decimal mark
  CVE: ["CV", "en"],
  ANG: ["SX"],
  HTG: ["HT", "fr"],
  MVR: ["MV", "en"],
  PGK: ["PG", "en"],
  PYG: ["PY", "es"],
  VUV: ["VU", "en"],
  WST: ["WS", "en"]
};

// iNat locale codes whose CLDR locale needs a script, not just a region
const INTL_LOCALE = { "zh-TW": "zh-Hant-TW", "zh-HK": "zh-Hant-HK", "zh-CN": "zh-Hans-CN" };

function intlLocale( lang, country ) {
  if ( INTL_LOCALE[lang] ) return INTL_LOCALE[lang];
  return `${lang.split( "-" )[0]}-${country}`;
}

function formatter( lang, country, currency, decimals ) {
  return new Intl.NumberFormat( `${intlLocale( lang, country )}-u-nu-latn`, {
    style: "currency",
    currency,
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals
  } );
}

// What CLDR says an amount looks like for a language in a country:
// the symbol and the two written examples the workbook asks for
function suggest( lang, country, currency ) {
  const withCents = formatter( lang, country, currency, 2 );
  const symbolPart = withCents.formatToParts( 1000 ).find( p => p.type === "currency" );
  return {
    symbol: normalize( symbolPart.value ),
    thousand: normalize( withCents.format( 1000 ) ),
    million: normalize( withCents.format( 1000000 ) )
  };
}

// CLDR rendering of a whole amount, for comparing against what the app renders
function cldrWhole( lang, country, currency, amount ) {
  return normalize( formatter( lang, country, currency, 0 ).format( amount ) );
}

const currencyNames = new Intl.DisplayNames( ["en"], { type: "currency" } );
const currencyName = code => currencyNames.of( code );
const regionNames = new Intl.DisplayNames( ["en"], { type: "region" } );

// [ISO2, country name, currency, [language]] for the country and language a
// currency's default format comes from, or undefined for a currency that is
// neither a starter country's nor one FundraiseUp supports
function currencyHome( currency ) {
  const [country, lang] = CURRENCY_HOME[currency] || [];
  const starter = STARTER.find( s => ( country ? s[0] === country : s[2] === currency ) );
  if ( starter ) return starter;
  if ( !FRU_CURRENCIES.includes( currency ) ) return undefined;
  const cc = country || currency.slice( 0, 2 );
  return [cc, regionNames.of( cc ), currency, [lang || new Intl.Locale( `und-${cc}` ).maximize( ).language]];
}

// Language whose CLDR format a country's examples come from: its first listed
// language when CLDR's likeliest language there is listed, else the first
// listed language that's official there. Failing both, CLDR's likeliest
// language if Node has data for it, so local conventions apply even where no
// iNat locale is spoken (৳ in Bangladesh rather than BDT).
function formatLanguage( country, langs ) {
  const base = lang => lang.split( "-" )[0];
  const likely = new Intl.Locale( `und-${country}` ).maximize( ).language;
  if ( langs.some( lang => base( lang ) === likely ) ) return langs[0];
  const { territoryInfo } = require( "cldr-core/supplemental/territoryInfo.json" ).supplemental;
  const population = territoryInfo[country]?.languagePopulation || {};
  const official = lang => Object.entries( population ).some( ( [code, p] ) => (
    code.split( "_" )[0] === base( lang ) && ["official", "de_facto_official"].includes( p._officialStatus )
  ) );
  const supported = new Intl.NumberFormat( likely ).resolvedOptions( ).locale.split( "-" )[0] === likely;
  return langs.find( official ) || ( supported ? likely : langs[0] ) || likely;
}

// CLDR region codes that aren't ISO 3166-1 countries, so geoip never returns them
const NOT_COUNTRIES = ["AC", "CP", "DG", "EA", "EU", "EZ", "IC", "QO", "TA", "UN", "ZZ"];

// Stripe still lists the dobra under its pre-2018 code
const CURRENCY_ALIASES = { STN: "STD" };

// CLDR language codes as iNat locale codes
function inatLocale( lang, country ) {
  if ( !lang.startsWith( "zh" ) ) return lang.split( "_" )[0];
  if ( !lang.includes( "Hant" ) ) return "zh-CN";
  return ["HK", "MO"].includes( country ) ? "zh-HK" : "zh-TW";
}

// Every country whose current currency FundraiseUp supports, as
// [ISO2, name, currency, iNat languages, notes], from CLDR's
// supplemental data. Starter countries come first with their curated values,
// then the rest by name. Languages are the iNat locales that are official or
// spoken by at least a quarter of people, most spoken first, or en if none are.
function allCountries( localeCodes ) {
  const { region } = require( "cldr-core/supplemental/currencyData.json" ).supplemental.currencyData;
  const { territoryInfo } = require( "cldr-core/supplemental/territoryInfo.json" ).supplemental;
  const others = Object.keys( region )
    .filter( cc => /^[A-Z]{2}$/.test( cc ) && !NOT_COUNTRIES.includes( cc ) )
    .filter( cc => !STARTER.some( s => s[0] === cc ) )
    .map( cc => {
      const cldrCurrent = region[cc]
        .map( entry => Object.entries( entry )[0] )
        .filter( ( [, dates] ) => !dates._to && dates._tender !== "false" )
        .map( ( [code] ) => code );
      const current = cldrCurrent.map( code => CURRENCY_ALIASES[code] || code );
      const supported = current.filter( code => FRU_CURRENCIES.includes( code ) );
      if ( supported.length === 0 ) return null;
      const spoken = Object.entries( territoryInfo[cc]?.languagePopulation || {} )
        .filter( ( [, p] ) => ["official", "de_facto_official"].includes( p._officialStatus )
          || p._populationPercent >= 25 )
        .sort( ( a, b ) => b[1]._populationPercent - a[1]._populationPercent )
        .map( ( [lang] ) => inatLocale( lang, cc ) )
        .filter( lang => localeCodes.has( lang ) );
      const langs = spoken.length > 0 ? [...new Set( spoken )] : ["en"];
      const notes = [];
      cldrCurrent.filter( code => CURRENCY_ALIASES[code] ).forEach( code => {
        notes.push( `CLDR has ${code}; Stripe lists it as ${CURRENCY_ALIASES[code]}.` );
      } );
      const alsoUses = current.filter( code => code !== supported[0] );
      if ( alsoUses.length > 0 ) notes.push( `Also uses ${alsoUses.join( ", " )}.` );
      if ( spoken.length === 0 ) notes.push( "No iNaturalist locale for its languages." );
      return [cc, regionNames.of( cc ), supported[0], langs, notes.join( " " )];
    } )
    .filter( Boolean )
    .sort( ( a, b ) => a[1].localeCompare( b[1] ) );
  return [...STARTER.map( s => [...s, null] ), ...others];
}

// Symbols CLDR gives to more than one currency across the workbook's
// countries and their languages, such as $ and kr. Mirrors check.js's
// bare-symbol warning.
let ambiguous;
function ambiguousSymbols( ) {
  if ( ambiguous ) return ambiguous;
  const { loadLocales } = require( "./locales" );
  const currenciesBySymbol = {};
  allCountries( new Set( loadLocales( ).map( l => l.code ) ) ).forEach( ( [cc, , currency, langs] ) => {
    new Set( [formatLanguage( cc, langs ), ...langs] ).forEach( lang => {
      const { symbol } = suggest( lang, cc, currency );
      currenciesBySymbol[symbol] = currenciesBySymbol[symbol] || new Set( );
      currenciesBySymbol[symbol].add( currency );
    } );
  } );
  ambiguous = new Set( Object.keys( currenciesBySymbol ).filter( sym => currenciesBySymbol[sym].size > 1 ) );
  return ambiguous;
}

// The format the workbook suggests: CLDR's, with the ISO code appended where
// the symbol is shared by several currencies, as in $1,000.00 (CAD)
function suggestion( lang, country, currency ) {
  const s = suggest( lang, country, currency );
  if ( !ambiguousSymbols( ).has( s.symbol ) ) return s;
  return { ...s, thousand: `${s.thousand} (${currency})`, million: `${s.million} (${currency})` };
}

module.exports = {
  STARTER,
  FRU_CURRENCIES,
  suggest,
  suggestion,
  ambiguousSymbols,
  cldrWhole,
  currencyHome,
  currencyName,
  intlLocale,
  formatLanguage,
  allCountries,
  niceRound,
  niceCeil,
  niceFloor,
  purchasingPowerAdjusted,
  suggestedTiers,
  floorAmount,
  MIN_USD,
  USD_RATES
};
