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

module.exports = {
  STARTER, FRU_CURRENCIES, suggest, cldrWhole, currencyHome, currencyName, intlLocale
};
