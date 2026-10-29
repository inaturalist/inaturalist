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

// Country whose formatting a currency's defaults come from, when it isn't the
// first starter country using that currency
const CURRENCY_HOME = { EUR: "DE" };

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

function currencyHome( currency ) {
  const home = CURRENCY_HOME[currency];
  return STARTER.find( s => ( home ? s[0] === home : s[2] === currency ) );
}

const currencyNames = new Intl.DisplayNames( ["en"], { type: "currency" } );
const currencyName = code => currencyNames.of( code );

module.exports = {
  STARTER, suggest, cldrWhole, currencyHome, currencyName, intlLocale
};
