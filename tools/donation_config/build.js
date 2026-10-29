// Builds the donation amounts and formats workbook that engagement fills in.
//
//   node build.js donation-config.xlsx

const fs = require( "node:fs" );
const ExcelJS = require( "exceljs" );
const {
  TABS, H, FIRST_ROW, LAST_ROW, TIERS, FREQUENCIES
} = require( "./layout" );
const {
  STARTER, FRU_CURRENCIES, suggest, currencyHome, currencyName
} = require( "./seed" );
const { loadLocales } = require( "./locales" );
const { writeValidations } = require( "./xlsx_validations" );

const FONT = "Arial";
const C = {
  header: "FF1F3864",
  headerText: "FFFFFFFF",
  req: "FFD9D9D9",
  input: "FFFFF2CC",
  reference: "FFF2F2F2",
  example: "FF7F7F7F",
  bad: "FFF4CCCC"
};

const fill = argb => ( { type: "pattern", pattern: "solid", fgColor: { argb } } );
const font = ( extra = {} ) => ( { name: FONT, size: 10, ...extra } );

function colLetter( n ) {
  let s = "";
  let rest = n;
  while ( rest > 0 ) {
    const m = ( rest - 1 ) % 26;
    s = String.fromCharCode( 65 + m ) + s;
    rest = Math.floor( ( rest - 1 ) / 26 );
  }
  return s;
}

const list = ( ref, error ) => ( {
  type: "list", formula: ref, errorTitle: "Pick from the list", error
} );
const yesNo = list( `${TABS.lists}!$C$2:$C$3`, "Choose Yes or No." );
const wholeNumber = {
  type: "whole",
  operator: "greaterThan",
  formula: "0",
  errorTitle: "Whole number",
  error: "FundraiseUp only accepts whole-number amounts greater than 0."
};
const amountPlaceholder = col => ( {
  type: "custom",
  formula: `ISNUMBER(SEARCH("{amount}",${col}${FIRST_ROW}))`,
  errorTitle: "Missing {amount}",
  error: "Include {amount} where the amount goes."
} );
const text = { numFmt: "@" };

function buildWorkbook( ) {
  const wb = new ExcelJS.Workbook( );
  wb.creator = "iNaturalist Web team";
  const validations = {};
  const locales = loadLocales( );

  // cols: [{ header, req, width, validation, formula, reference }]
  function tableSheet( name, intro, cols, rows = [], { exampleRows = [] } = {} ) {
    const ws = wb.addWorksheet( name );
    ws.getCell( "A1" ).value = intro;
    ws.getCell( "A1" ).font = font( { italic: true } );
    ws.getCell( "A1" ).alignment = { wrapText: true, vertical: "top" };
    ws.mergeCells( 1, 1, 1, cols.length );
    ws.getRow( 1 ).height = 42;

    cols.forEach( ( c, i ) => {
      ws.getColumn( i + 1 ).width = c.width || 18;
      const h = ws.getCell( 2, i + 1 );
      h.value = c.header;
      h.font = font( { bold: true, color: { argb: C.headerText } } );
      h.fill = fill( C.header );
      h.alignment = { wrapText: true, vertical: "middle" };
      const r = ws.getCell( 3, i + 1 );
      r.value = c.req;
      r.font = font( { italic: true, bold: c.req.startsWith( "Required" ) } );
      r.fill = fill( C.req );
    } );
    ws.getRow( 2 ).height = 44;

    let row = FIRST_ROW;
    exampleRows.forEach( values => {
      values.forEach( ( v, i ) => {
        const cell = ws.getCell( row, i + 1 );
        cell.value = v;
        cell.font = font( { italic: true, color: { argb: C.example } } );
      } );
      row += 1;
    } );
    rows.forEach( values => {
      values.forEach( ( v, i ) => {
        if ( v !== null && v !== undefined ) ws.getCell( row, i + 1 ).value = v;
      } );
      row += 1;
    } );

    const inputFrom = FIRST_ROW + exampleRows.length;
    cols.forEach( ( c, i ) => {
      for ( let r = FIRST_ROW; r <= LAST_ROW; r += 1 ) {
        const cell = ws.getCell( r, i + 1 );
        if ( !cell.font || !cell.font.italic ) cell.font = font( );
        if ( c.numFmt ) cell.numFmt = c.numFmt;
        if ( c.formula ) {
          cell.value = { formula: c.formula( r ) };
        } else if ( c.reference ) {
          cell.fill = fill( C.reference );
        } else if ( r >= inputFrom ) {
          cell.fill = fill( C.input );
        }
      }
      if ( c.validation ) {
        const L = colLetter( i + 1 );
        validations[name] = validations[name] || [];
        validations[name].push( { ...c.validation, sqref: `${L}${FIRST_ROW}:${L}${LAST_ROW}` } );
      }
    } );
    ws.views = [{ state: "frozen", ySplit: 3, xSplit: 1 }];
    return ws;
  }

  // ---------- How to fill ----------
  const how = wb.addWorksheet( TABS.how );
  how.getColumn( 1 ).width = 26;
  how.getColumn( 2 ).width = 100;
  const howRows = [
    ["Donation amounts and button text", null],
    ["What this is", "The amounts and button text that iNaturalist announcements show donors in their own currency and language. Engineering turns this into config/donation_currencies.yml and the donation_labels locale files."],
    [null, null],
    ["Legend", null],
    ["Light yellow cells", "Fill these in."],
    ["Light gray cells", "Reference only. Filled from data we already have."],
    ["Gray italic row", "Example row showing the expected format. Replace it or leave it; it is not imported."],
    ["Required / Optional", "Row 3 of each tab says whether a column is required for launch. Optional columns help us get formatting right, so fill them where you can."],
    ["Pre-filled formats", "Symbols and the 1,000.00 and 1,000,000.00 examples are pre-filled from the Unicode CLDR standard (what browsers use). Correct anything that's wrong and set \"Format checked?\" to Yes. Many currencies use a bare $; add the code, e.g. $1,000.00 (CAD), wherever that could be ambiguous."],
    ["Writing the examples", "Write one thousand and one million, with cents, exactly as people in that country and language would see them, including the currency symbol: 1 000,00 € or ₹10,00,000.00. Buttons use whole amounts, but the cents tell us the decimal separator, and the two examples tell us the thousands separator and how digits are grouped."],
    [null, null],
    ["Tabs, in order", null],
    [TABS.settings, "Overall settings: fallback country, tier names, FundraiseUp campaign details."],
    [TABS.currencies, "Every currency FundraiseUp supports, with its symbol, default format, and whether it is enabled in the FundraiseUp campaign. The format here is only used when a country leaves its own blank. Only currencies with a count in \"Countries using it\" need checking."],
    [TABS.countries, "One row per country: its currency, the amount for each tier (one-time and monthly), and how amounts look there. Starts with a starter list; delete rows that are out of scope."],
    [TABS.countryLanguages, "Only where a country's amounts should look different in one of its other languages, e.g. Switzerland: CHF 1'000.00 in German, 1'000.00 CHF in French."],
    ["How formats are chosen", "For a viewer in a country using a language: Country by language first, then the country's own format on Countries, then the currency default on Currencies."],
    [TABS.buttons, "The button text for each language, with {amount} where the amount goes. Each language is listed with our existing translation of \"Donate\" for reference; leave a row blank to fall back to English."],
    [TABS.overrides, "Only where the generated button text isn't right for a specific country, language and tier. Write the exact text."],
    [TABS.reference, "Every config field, whether it is required, and which column it comes from."],
    [TABS.lists, "Values for the dropdowns. Do not edit."],
    [null, null],
    ["Codes", "Countries use 2-letter ISO codes (US, MX, FR). Currencies use 3-letter ISO codes (USD, MXN, EUR). Languages use the iNaturalist locale codes on the Lists tab (es, es-MX, pt-BR)."],
    ["Placeholders", "Write {amount} in button text where the formatted amount goes. Example: Donnez {amount} becomes Donnez 5 €."]
  ];
  howRows.forEach( ( r, i ) => {
    const row = how.getRow( i + 1 );
    row.values = r;
    row.font = font( );
    row.getCell( 1 ).alignment = { vertical: "top" };
    row.getCell( 2 ).alignment = { wrapText: true, vertical: "top" };
    if ( r[0] && r[1] ) row.getCell( 1 ).font = font( { bold: true } );
  } );
  how.getCell( "A1" ).font = font( { bold: true, size: 14 } );
  how.getCell( "A4" ).font = font( { bold: true } );
  how.getCell( "A12" ).font = font( { bold: true } );
  how.getCell( "A5" ).fill = fill( C.input );
  how.getCell( "A6" ).fill = fill( C.reference );
  how.getCell( "A7" ).font = font( { italic: true, color: { argb: C.example } } );

  // ---------- Settings ----------
  const settings = wb.addWorksheet( TABS.settings );
  settings.columns = [
    { header: "Setting", width: 30 },
    { header: "Required?", width: 12 },
    { header: "Value", width: 36 },
    { header: "Example", width: 36 },
    { header: "What it's for", width: 70 }
  ];
  const settingRows = [
    ["Fallback country", "Required", null, "US", "Shown when we can't tell the viewer's country, or the country isn't on the Countries tab. Must be on the Countries tab."],
    ["Tier names", "Required", "min, mid, max", "min, mid, max", "The tiers every country must have. Announcements refer to these names."],
    ["FundraiseUp campaign page", "Required", null, "https://giving.inaturalist.org/page/supportinaturalist", "Where donation buttons send people. The amount and currency are added to this link."],
    ["FundraiseUp languages", "Required", null, "en, es, fr, de, it, pt, nl, ja", "Languages the FundraiseUp campaign page supports. Other languages open the page in its default language."],
    ["FundraiseUp designation ID", "Optional", null, "E12345", "Only if announcement gifts should go to a specific designation."],
    ["FundraiseUp custom fields", "Optional", null, "source=announcement", "Fields to attach to every announcement donation, for attribution. They must exist in the campaign first."],
    ["Default UTM source", "Optional", null, "inaturalist", "Added to donation links so FundraiseUp reports show where gifts came from."],
    ["Default UTM medium", "Optional", null, "announcement", "As above."],
    ["Last reviewed (date)", "Optional", null, "2026-11-01", "When these amounts were last checked."],
    ["Reviewed by", "Optional", null, "Engagement team", "Who to ask about these amounts."]
  ];
  settingRows.forEach( r => settings.addRow( r ) );
  settings.getRow( 1 ).eachCell( c => {
    c.font = font( { bold: true, color: { argb: C.headerText } } );
    c.fill = fill( C.header );
  } );
  for ( let r = 2; r <= settingRows.length + 1; r += 1 ) {
    const row = settings.getRow( r );
    row.eachCell( { includeEmpty: true }, c => {
      c.font = font( );
      c.alignment = { wrapText: true, vertical: "top" };
    } );
    row.getCell( 2 ).font = font( { bold: row.getCell( 2 ).value === "Required" } );
    row.getCell( 3 ).fill = fill( C.input );
    row.getCell( 3 ).numFmt = "@";
    row.getCell( 4 ).font = font( { italic: true, color: { argb: C.example } } );
  }
  settings.views = [{ state: "frozen", ySplit: 1 }];

  // ---------- Currencies ----------
  const currencyRows = FRU_CURRENCIES.map( currency => {
    const [homeCountry, homeName, , homeLangs] = currencyHome( currency );
    const s = suggest( homeLangs[0], homeCountry, currency );
    return [currency, currencyName( currency ), null, s.symbol, s.thousand, s.million,
      null, null, null, null, `Default from ${homeName} formatting`];
  } );
  tableSheet( TABS.currencies,
    "Every currency FundraiseUp supports. Only those used on the Countries tab need checking. These are fallbacks: a country's own format on the Countries tab wins. Symbol and examples are pre-filled from the Unicode CLDR standard.",
    [
      { header: H.currencyCode, req: "Required", width: 14, ...text },
      { header: H.currencyName, req: "Optional", width: 22 },
      {
        header: H.currencyUsedBy,
        req: "Formula",
        width: 11,
        formula: r => `IF(A${r}="","",COUNTIF(${TABS.countries}!$C$${FIRST_ROW}:$C$${LAST_ROW},A${r}))`
      },
      { header: H.symbol, req: "Required", width: 9, ...text },
      { header: H.currencyThousand, req: "Required", width: 18, ...text },
      { header: H.currencyMillion, req: "Required", width: 20, ...text },
      { header: H.formatChecked, req: "Optional", width: 10, validation: yesNo },
      {
        header: H.fruEnabled,
        req: "Required if used",
        width: 16,
        validation: list( `${TABS.lists}!$C$2:$C$4`, "Choose Yes, No or Not sure." )
      },
      { header: H.fruMinOnce, req: "Optional", width: 14, validation: wholeNumber },
      { header: H.fruMinMonthly, req: "Optional", width: 14, validation: wholeNumber },
      { header: H.notes, req: "Optional", width: 30 }
    ],
    currencyRows );

  // ---------- Countries ----------
  const countryRows = STARTER.map( ( [cc, name, currency, langs] ) => {
    const s = suggest( langs[0], cc, currency );
    return [cc, name, currency, null, null, null, null, null, null, langs.join( ", " ),
      s.symbol, s.thousand, s.million, null, null, "Starter row; delete if out of scope"];
  } );
  const countries = tableSheet( TABS.countries,
    "Starter list of countries; delete rows that are out of scope and add any that are missing. Every country needs all six amounts, as whole numbers in its currency. Format columns are pre-filled from the Unicode CLDR standard for the country's main language: correct anything that's wrong, then set \"Format checked?\" to Yes.",
    [
      {
        header: H.countryCode,
        req: "Required",
        width: 11,
        ...text,
        validation: {
          type: "custom",
          formula: `AND(LEN(A${FIRST_ROW})=2,EXACT(A${FIRST_ROW},UPPER(A${FIRST_ROW})))`,
          errorTitle: "Country code",
          error: "Use a 2-letter uppercase ISO code, e.g. MX."
        }
      },
      { header: H.countryName, req: "Optional", width: 16 },
      {
        header: H.currency,
        req: "Required",
        width: 10,
        ...text,
        validation: list( `${TABS.currencies}!$A$${FIRST_ROW}:$A$${LAST_ROW}`, "Add the currency on the Currencies tab first." )
      },
      { header: H.onceMin, req: "Required", width: 10, validation: wholeNumber },
      { header: H.onceMid, req: "Required", width: 10, validation: wholeNumber },
      { header: H.onceMax, req: "Required", width: 10, validation: wholeNumber },
      { header: H.monthlyMin, req: "Required", width: 10, validation: wholeNumber },
      { header: H.monthlyMid, req: "Required", width: 10, validation: wholeNumber },
      { header: H.monthlyMax, req: "Required", width: 10, validation: wholeNumber },
      { header: H.languages, req: "Optional", width: 16 },
      { header: H.countrySymbol, req: "Optional", width: 9, ...text },
      { header: H.countryThousand, req: "Optional", width: 16, ...text },
      { header: H.countryMillion, req: "Optional", width: 19, ...text },
      { header: H.formatChecked, req: "Optional", width: 10, validation: yesNo },
      { header: H.enabled, req: "Optional", width: 9, validation: yesNo },
      { header: H.source, req: "Optional", width: 30 }
    ],
    countryRows );
  // Duplicate country codes and tiers out of order get a red fill
  countries.addConditionalFormatting( {
    ref: `A${FIRST_ROW}:A${LAST_ROW}`,
    rules: [{
      type: "expression",
      formulae: [`AND(A${FIRST_ROW}<>"",COUNTIF($A$${FIRST_ROW}:$A$${LAST_ROW},A${FIRST_ROW})>1)`],
      style: { fill: fill( C.bad ) }
    }]
  } );
  [["D", "E", "F"], ["G", "H", "I"]].forEach( ( [lo, mid, hi] ) => {
    countries.addConditionalFormatting( {
      ref: `${lo}${FIRST_ROW}:${hi}${LAST_ROW}`,
      rules: [{
        type: "expression",
        formulae: [`AND(COUNT($${lo}${FIRST_ROW}:$${hi}${FIRST_ROW})=3,NOT(AND($${lo}${FIRST_ROW}<=$${mid}${FIRST_ROW},$${mid}${FIRST_ROW}<=$${hi}${FIRST_ROW})))`],
        style: { fill: fill( C.bad ) }
      }]
    } );
  } );

  // ---------- Country by language ----------
  // Rows only for a country's other languages; its main language is on Countries
  const countryLanguageRows = [];
  STARTER.forEach( ( [cc, , currency, langs] ) => {
    const main = suggest( langs[0], cc, currency );
    langs.slice( 1 ).forEach( lang => {
      const s = suggest( lang, cc, currency );
      const same = s.thousand === main.thousand && s.million === main.million;
      countryLanguageRows.push( [cc, lang, s.symbol === main.symbol ? null : s.symbol, s.thousand, s.million,
        null, same ? "Same as the country's main language; delete unless it needs to differ" : null] );
    } );
  } );
  tableSheet( TABS.countryLanguages,
    "Only where a country's amounts should look different in one of its other languages, e.g. Switzerland: CHF 1'000.00 in German, 1'000.00 CHF in French. Pre-filled from the Unicode CLDR standard for the starter countries.",
    [
      {
        header: H.country,
        req: "Required",
        width: 10,
        ...text,
        validation: list( `${TABS.countries}!$A$${FIRST_ROW}:$A$${LAST_ROW}`, "Add the country on the Countries tab first." )
      },
      {
        header: H.language,
        req: "Required",
        width: 10,
        ...text,
        validation: list( `${TABS.lists}!$A$2:$A$100`, "Pick a language code from the Lists tab." )
      },
      { header: H.langSymbol, req: "Optional", width: 12, ...text },
      { header: H.langThousand, req: "Required", width: 16, ...text },
      { header: H.langMillion, req: "Required", width: 19, ...text },
      { header: H.formatChecked, req: "Optional", width: 10, validation: yesNo },
      { header: H.notes, req: "Optional", width: 40 }
    ],
    countryLanguageRows );

  // ---------- Button text ----------
  tableSheet( TABS.buttons,
    "Button text for each language. Put {amount} where the amount goes. Leave a row blank to fall back to English. English is required. The gray column shows our existing translation of \"Donate\" for reference.",
    [
      { header: H.language, req: "Required", width: 10, ...text },
      { header: H.languageName, req: "Optional", width: 24 },
      { header: H.donateReference, req: "Reference", width: 22, reference: true },
      {
        header: H.onceText, req: "Required (en)", width: 30, validation: amountPlaceholder( "D" )
      },
      {
        header: H.monthlyText, req: "Required (en)", width: 30, validation: amountPlaceholder( "E" )
      },
      {
        header: H.textSource,
        req: "Optional",
        width: 20,
        validation: list( `${TABS.lists}!$G$2:$G$5`, "Pick a source from the list." )
      },
      { header: H.notes, req: "Optional", width: 36 }
    ],
    locales.map( l => {
      const reference = l.donate && l.donateFrom !== l.code ? `${l.donate} (from ${l.donateFrom})` : l.donate;
      return l.code === "en"
        ? [l.code, l.name, reference, "Donate {amount}", "Donate {amount}/month", "Engagement", null]
        : [l.code, l.name, reference, null, null, null, null];
    } ) );

  // ---------- Exact text overrides ----------
  tableSheet( TABS.overrides,
    "Only where the generated button text isn't right. Write the exact text, including the amount. \"Tier amount\" shows the amount from the Countries tab so you can check it matches.",
    [
      {
        header: H.country,
        req: "Required",
        width: 10,
        ...text,
        validation: list( `${TABS.countries}!$A$${FIRST_ROW}:$A$${LAST_ROW}`, "Add the country on the Countries tab first." )
      },
      {
        header: H.language,
        req: "Required",
        width: 10,
        ...text,
        validation: list( `${TABS.lists}!$A$2:$A$100`, "Pick a language code from the Lists tab." )
      },
      {
        header: H.frequency,
        req: "Required",
        width: 12,
        validation: list( `${TABS.lists}!$I$2:$I$3`, "Choose One-time or Monthly." )
      },
      {
        header: H.tier,
        req: "Required",
        width: 8,
        validation: list( `${TABS.lists}!$K$2:$K$4`, "Choose min, mid or max." )
      },
      { header: H.exactText, req: "Required", width: 30 },
      { header: H.notes, req: "Optional", width: 30 },
      {
        header: H.tierAmount,
        req: "Formula",
        width: 12,
        formula: r => `IF(OR(A${r}="",C${r}="",D${r}=""),"",IFERROR(INDEX(${TABS.countries}!$D$${FIRST_ROW}:$I$${LAST_ROW},MATCH(A${r},${TABS.countries}!$A$${FIRST_ROW}:$A$${LAST_ROW},0),IF(C${r}="Monthly",3,0)+MATCH(D${r},${TABS.lists}!$K$2:$K$4,0)),"Country not found"))`
      }
    ],
    [],
    { exampleRows: [["FR", "fr", "One-time", "min", "Donnez 5 €", "Example row"]] } );

  // ---------- Field reference ----------
  const ref = wb.addWorksheet( TABS.reference );
  ref.columns = [
    { header: "File", width: 30 },
    { header: "Field", width: 44 },
    { header: "Required?", width: 11 },
    { header: "Comes from", width: 40 },
    { header: "Example", width: 30 },
    { header: "Purpose", width: 70 }
  ];
  const Y = "config/donation_currencies.yml";
  const L = "config/locales/donation_labels/<locale>.yml";
  const LEVELS = "currencies.<ISO> / countries.\"<ISO2>\" / countries.\"<ISO2>\".formats.<locale>";
  const EXAMPLES = "the 1,000.00 and 1,000,000.00 examples on Currencies, Countries or Country by language";
  [
    [Y, "default_country", "Required", "Settings", "\"US\"", "Fallback when geolocation fails or the country isn't listed."],
    [Y, "tier_names", "Required", "Settings", "[min, mid, max]", "Fixed tier set. Every country must define every tier."],
    [Y, "frequencies", "Required", "(fixed)", "{ once: once, monthly: monthly }", "Our frequency name and FundraiseUp's recurring value."],
    [Y, "last_reviewed", "Optional", "Settings", "2026-11-01", "When amounts were last checked."],
    [Y, "fru.campaign_page_url", "Required", "Settings", "https://giving.inaturalist.org/page/supportinaturalist", "Base URL for [donation-url]."],
    [Y, "fru.languages", "Required", "Settings", "[en, es, fr, ...]", "Languages FundraiseUp supports for _lang. Omitted if the viewer's language isn't listed."],
    [Y, "fru.designation_id", "Optional", "Settings", "E12345", "FundraiseUp designation for announcement gifts."],
    [Y, "fru.custom_fields", "Optional", "Settings", "{ source: announcement }", "Attribution fields; must exist in the campaign."],
    [Y, "fru.utm_defaults", "Optional", "Settings", "{ utm_source: inaturalist }", "Shared with WEB-1389."],
    [Y, "currencies.<ISO>.name", "Optional", "Currencies", "Euro", "Admin preview and docs."],
    [Y, "currencies.<ISO>.fru_enabled", "Required if used", "Currencies", "true", "Confirms the currency is enabled in the campaign. Only currencies a country uses need it."],
    [Y, "currencies.<ISO>.fru_minimum", "Optional", "Currencies", "{ once: 1, monthly: 1 }", "Tiers are checked against it."],
    [Y, "countries.\"<ISO2>\".currency", "Required", "Countries", "EUR", "Must exist under currencies."],
    [Y, "countries.\"<ISO2>\".tiers.<frequency>.<tier>", "Required", "Countries", "once: { min: 5, mid: 10, max: 25 }", "Whole-number amounts; all frequencies and tiers required."],
    [Y, "countries.\"<ISO2>\".label_overrides", "Optional", TABS.overrides, "fr: { once: { min: \"Donnez 5 €\" } }", "Exact button text; digits must match the amount."],
    [Y, "countries.\"<ISO2>\".locales", "Optional", "Countries (languages)", "[fr, en]", "Admin preview options and test coverage."],
    [Y, "countries.\"<ISO2>\".enabled", "Optional", "Countries", "true", "Stage a country without turning it on."],
    [Y, `${LEVELS} .symbol`, "Required on currencies", "Symbol columns", "€, kr., CHF", "The symbol. Also used to find the symbol in the examples."],
    [Y, `${LEVELS} .format`, "Required on currencies", EXAMPLES, "\"%n %u\"", "Where the symbol and code go. %n = number, %u = symbol, %c = ISO code."],
    [Y, `${LEVELS} .delimiter`, "Optional", EXAMPLES, "\" \", \".\", \",\", \"'\"", "Thousands separator. Falls back to the language default from rails-i18n."],
    [Y, `${LEVELS} .separator`, "Optional", EXAMPLES, "\",\"", "Decimal separator. Stored now; v1 amounts are whole numbers."],
    [Y, `${LEVELS} .group_min_digits`, "Optional", "the 1,000.00 example", "2", "2 = 1000 is written ungrouped (Spain, Portugal); default 1."],
    [Y, `${LEVELS} .grouping`, "Optional", "the 1,000,000.00 example", "indian", "standard (default) or indian (10,00,000)."],
    [L, "donation_labels.once", "Required (en)", TABS.buttons, "Donnez %{amount}", "One-time button text. Other languages fall back to English."],
    [L, "donation_labels.monthly", "Required (en)", TABS.buttons, "Donnez %{amount}/mois", "Monthly button text."]
  ].forEach( r => ref.addRow( r ) );
  ref.getRow( 1 ).eachCell( c => {
    c.font = font( { bold: true, color: { argb: C.headerText } } );
    c.fill = fill( C.header );
  } );
  ref.eachRow( ( row, n ) => {
    if ( n === 1 ) return;
    row.eachCell( { includeEmpty: true }, c => {
      c.font = font( { bold: c.col === 3 && String( c.value ).startsWith( "Required" ) } );
      c.alignment = { wrapText: true, vertical: "top" };
    } );
  } );
  ref.views = [{ state: "frozen", ySplit: 1 }];

  // ---------- Lists ----------
  const lists = wb.addWorksheet( TABS.lists );
  lists.getRow( 1 ).values = ["Language code", "Language name", "Yes / No", null, null, null,
    "Text source", null, "Frequency", null, "Tier"];
  lists.getRow( 1 ).font = font( { bold: true } );
  locales.forEach( ( l, i ) => {
    lists.getCell( i + 2, 1 ).value = l.code;
    lists.getCell( i + 2, 2 ).value = l.name;
  } );
  ["Yes", "No", "Not sure"].forEach( ( v, i ) => { lists.getCell( i + 2, 3 ).value = v; } );
  ["Crowdin", "Engagement", "Machine translation", "Other"].forEach( ( v, i ) => { lists.getCell( i + 2, 7 ).value = v; } );
  FREQUENCIES.forEach( ( v, i ) => { lists.getCell( i + 2, 9 ).value = v; } );
  TIERS.forEach( ( v, i ) => { lists.getCell( i + 2, 11 ).value = v; } );
  lists.getColumn( 1 ).numFmt = "@";
  [1, 2, 3, 7, 9, 11].forEach( c => { lists.getColumn( c ).width = c === 2 ? 24 : 14; } );
  lists.eachRow( row => row.eachCell( c => { if ( !c.font?.bold ) c.font = font( ); } ) );

  return { wb, validations };
}

async function writeWorkbook( out ) {
  const { wb, validations } = buildWorkbook( );
  const buffer = await writeValidations( await wb.xlsx.writeBuffer( ), validations );
  fs.writeFileSync( out, buffer );
  return buffer.length;
}

if ( require.main === module ) {
  const out = process.argv[2] || "donation-config.xlsx";
  writeWorkbook( out ).then( size => console.log( `wrote ${out} (${size} bytes)` ) );
}

module.exports = { writeWorkbook };
