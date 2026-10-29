// Tab names, header text and row positions shared by build.js and check.js.
// check.js finds columns by header text, so renaming a header here is enough.

const TABS = {
  how: "How to fill",
  settings: "Settings",
  currencies: "Currencies",
  countries: "Countries",
  countryLanguages: "Country by language",
  buttons: "Button text",
  overrides: "Exact text overrides",
  reference: "Field reference",
  lists: "Lists"
};

const H = {
  currencyCode: "Currency code (ISO 4217)",
  currencyName: "Currency name",
  symbol: "Symbol",
  currencyThousand: "How 1,000.00 should look (default)",
  currencyMillion: "How 1,000,000.00 should look (default)",
  formatChecked: "Format checked?",
  fruEnabled: "Enabled in FundraiseUp campaign?",
  fruMinOnce: "FundraiseUp minimum, one-time",
  fruMinMonthly: "FundraiseUp minimum, monthly",
  notes: "Notes",

  countryCode: "Country code (ISO 2-letter)",
  countryName: "Country name",
  currency: "Currency code",
  onceMin: "One-time min",
  onceMid: "One-time mid",
  onceMax: "One-time max",
  monthlyMin: "Monthly min",
  monthlyMid: "Monthly mid",
  monthlyMax: "Monthly max",
  languages: "Languages viewers here use (main first)",
  countrySymbol: "Symbol here",
  countryThousand: "How 1,000.00 looks here",
  countryMillion: "How 1,000,000.00 looks here",
  enabled: "Enabled?",
  source: "Source / notes",

  country: "Country code",
  language: "Language",
  langSymbol: "Symbol, if different",
  langThousand: "How 1,000.00 looks",
  langMillion: "How 1,000,000.00 looks",

  languageName: "Language name",
  donateReference: "Existing translation of \"Donate\"",
  onceText: "One-time button text",
  monthlyText: "Monthly button text",
  textSource: "Where the text came from",

  frequency: "Frequency",
  tier: "Tier",
  exactText: "Exact button text",
  tierAmount: "Tier amount"
};

// Row 1 is an intro line, row 2 the headers, row 3 Required/Optional
const HEADER_ROW = 2;
const FIRST_ROW = 4;
const LAST_ROW = 150;

const TIERS = ["min", "mid", "max"];
const FREQUENCIES = ["One-time", "Monthly"];
const TIER_COLUMNS = {
  "One-time": { min: H.onceMin, mid: H.onceMid, max: H.onceMax },
  Monthly: { min: H.monthlyMin, mid: H.monthlyMid, max: H.monthlyMax }
};

module.exports = {
  TABS, H, HEADER_ROW, FIRST_ROW, LAST_ROW, TIERS, FREQUENCIES, TIER_COLUMNS
};
