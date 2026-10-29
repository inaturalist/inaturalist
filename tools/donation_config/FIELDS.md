# Donation config fields

Draft for WEB-1399 (parent WEB-1398; spike WEB-1247), last updated 2026-10-29. This is the shape of `config/donation_currencies.yml` and the donation button label locale files, and where each field comes from in the engagement workbook. `export_yaml.js` writes the YAML (WEB-1360); the label files and `label_overrides` come with the shortcodes (WEB-1362).

Decisions so far:
- Tiers are per currency, with optional per-country overrides, for one-time and monthly giving (2026-10-29). Tier names are a fixed set. Only the one-time `min` is required for now: every enabled country must get one from itself or its currency.
- The button label is a per-language template plus optional exact-text overrides. Templates live in app-owned locale files.
- Formatting is resolved country-first: country × language, then country, then currency, then the language's defaults.
- Separators are collected as written examples (1,000.00 and 1,000,000.00) and parsed into fields. `separator` is stored even though v1 amounts are whole numbers.

**E** = essential for v1. **O** = optional; collected now because it's cheap. Fields marked O can be left out and fall back to the default.

## File 1: `config/donation_currencies.yml`

### Top level

| Field | E/O | Example | Purpose |
|---|---|---|---|
| `default_country` | E | `"US"` | Used when geoip fails, the country isn't listed or is disabled, or a tier has no amount. Its tiers and currency apply. Should have every tier; the checker warns if not. |
| `tier_names` | E | `[min, mid, max]` | Fixed tier set. Shortcodes can only use these names. |
| `frequencies` | E | `{ once: once, monthly: monthly }` | Our key → FundraiseUp `recurring` value. |
| `last_reviewed` | O | `2026-11-01` | When engagement last checked the amounts. |
| `reviewed_by` | O | `Engagement team` | Who to ask about the amounts. |
| `rates_updated` | O | `2026-10-29` | Date of the exchange rates the $3 minimum was checked against. |
| `fru.default_url` | O | `https://giving.inaturalist.org/login?form=supportinaturalist` | Base URL for `[donation-url]` when the shortcode doesn't pass its own. Defaults to this value. |
| `fru.lang_map` | O | `{ zh-TW: zh, pt-BR: pt }` | Explicit locale → `_lang` mappings, where the language-prefix rule is wrong. `_lang` is always the viewer's iNaturalist locale, even when FundraiseUp doesn't support it, so the language matches the announcement. |
| `fru.designation_id` | O | `"E1234"` | FundraiseUp designation for announcement gifts. |
| `fru.custom_fields` | O | `{ source: announcement }` | Static custom fields for attribution. They must exist in FundraiseUp first. |
| `fru.utm_defaults` | O | `{ utm_source: inaturalist, utm_medium: announcement }` | Shared with WEB-1389. |

### `currencies.<ISO4217>`

The workbook lists every currency FundraiseUp supports (Stripe's presentment currencies for US accounts, 134 as of 2026-10-29). The YAML only needs the currencies that countries use, plus any staged for later.

| Field | E/O | Example | Purpose |
|---|---|---|---|
| `tiers.<frequency>.<tier>` | E: `once.min` if used | `once: { min: 5, mid: 10, max: 25 }` | Default whole-number amounts for every country using the currency. `once.min` is required unless every enabled country using the currency sets its own. Other tiers are optional. The workbook pre-fills one-time tiers for the 26 currencies on our donation form: $5, $20 and $100 at the ratio of the form's lowest amount in that currency to USD's 2.75, rounded to a 1/1.5/2/2.5/3/4/5/7.5 series, and raised to the next round number where that's worth less than $3 at market rates. The other currencies get only `once.min`: $5 at market rates, rounded down. |
| `purchasing_power_adjusted` | O | `false` | Whether the default amounts were adjusted for purchasing power (from the donation form) or converted at market rates. Lets reviewers find the market-rate ones to revisit. |
| formatting fields | E: `symbol`, `format` | see below | Defaults, used when a country sets nothing. |
| `fru_enabled` | E if used | `true` | Engagement confirms the currency is enabled in the FundraiseUp campaign. A spec fails if a currency in use is `false`. |
| `fru_minimum` | O | `{ once: 1, monthly: 1 }` | FundraiseUp's minimum in this currency. A spec checks every tier is at least this. |
| `name` | O | `Euro` | Admin preview country picker and docs. |

### `countries."<ISO2>"` (keys **must be quoted**; `NO:` loads as `false`)

| Field | E/O | Example | Purpose |
|---|---|---|---|
| `currency` | E | `EUR` | Must be a key under `currencies`. |
| `tiers.<frequency>.<tier>` | O | `once: { min: 5 }` | Whole-number amounts that override the currency's, tier by tier. |
| formatting fields | O | see below | Override the currency's. |
| `formats.<locale>` | O | `fr: { format: "%n %u", separator: "," }` | Formatting fields for one language within the country. |
| `label_overrides.<locale>.<frequency>.<tier>` (WEB-1362) | O | `fr: { once: { min: "Donnez 5 €" } }` | Exact button text; wins over the template. Its digits must match the tier amount. |
| `locales` | O | `[fr, en]` | Languages viewers here use. Drives admin preview options and test coverage. |
| `enabled` | O | `true` | `false` gives viewers there `default_country`'s amounts and currency. The workbook lists every country using a FundraiseUp currency, all enabled. |
| `notes` | O | `"Seeded from Wikipedia 2025 asks"` | Where the numbers came from. |

### Formatting fields

These can appear on `currencies.<ISO>`, `countries."<ISO2>"` and `countries."<ISO2>".formats.<locale>`.

| Field | Example | Notes |
|---|---|---|
| `format` | `"%n %u"` | `%n` number, `%u` symbol, `%c` ISO code: `"%u%n (%c)"` shows `$5 (CAD)`. |
| `symbol` | `"kr."` | Also used to find the symbol in the examples, since a symbol can contain `.`. |
| `delimiter` | `"'"`, `" "`, `"."`, `","` | Thousands separator. Always quoted. A space is stored as `" "` and rendered non-breaking. |
| `separator` | `","` | Decimal separator. Stored now; unused while amounts are whole numbers. |
| `group_min_digits` | `2` | `2` = `1000` is written ungrouped (Spain, Portugal, Italy, Poland). Default `1`. |
| `grouping` | `indian` | `standard` (default) or `indian` (`10,00,000`). An enum, never a regex. |

The same language formats differently by country, which is why country comes first:

| Country / language | 1,000.00 | 1,000,000.00 |
|---|---|---|
| FR / fr | `1 000,00 €` | `1 000 000,00 €` |
| CH / fr | `1'000.00 CHF` | `1'000'000.00 CHF` |
| ES / es | `1000,00 €` | `1.000.000,00 €` |
| MX / es | `$1,000.00` | `$1,000,000.00` |
| IN / hi | `₹1,000.00` | `₹10,00,000.00` |
| DK / da | `1.000,00 kr.` | `1.000.000,00 kr.` |

## File 2: `config/locales/donation_labels/<locale>.yml` (WEB-1362)

Loaded by the existing `config/locales/**/*.yml` glob, and not part of Crowdin's source file. `I18n.t` handles fallbacks (`es-MX` → `es` → `en`) and interpolation.

```yaml
fr:
  donation_labels:
    once: "Donnez %{amount}"          # E for en; other locales fall back to en
    monthly: "Donnez %{amount}/mois"
```

The `en.yml` copies need translator comments as usual.

## Parsing the examples (`parse.js`)

The workbook collects the symbol plus two written examples. `parse.js` turns them into the formatting fields, and the WEB-1360 YAML import should reuse it.

1. Find the symbol (or the ISO code) in the text around the number and replace it with `%u` (or `%c`). That text plus `%n` becomes `format`.
2. `1,000.00` must match `/^1(\D?)000(?:(\D)00)?$/`. An empty first group means `group_min_digits: 2`; the second group is `separator`.
3. `1,000,000.00` must match either:
   - `/^1(\D)000\1(?:000)(?:(\D)00)?$/` → `delimiter`, `grouping: standard`
   - `/^10(\D)00\1(?:000)(?:(\D)00)?$/` → `delimiter`, `grouping: indian`
4. It's an error if the two examples disagree on the symbol position, decimal separator or thousands separator, or if either doesn't parse. Examples without cents only warn, since the decimal separator is then unknown.

## Rendering an amount

1. Look up the country (geoip), falling back to `default_country` when the lookup fails, the country isn't listed, or it's disabled. That gives the currency.
2. Resolve the tier amount: `country.tiers[freq][tier]`, then `currency.tiers[freq][tier]`. If neither is set, the whole button uses `default_country`'s amount and currency for that tier instead, so the amount and currency always match. If that's missing too, the shortcode renders nothing and logs a warning. (Only `once.min` is required for now; revisit this when all tiers are.)
3. Resolve each formatting field on its own; the first match wins:
   1. `country.formats[locale]`, then `country.formats[language]`
   2. `country`
   3. `currency`
   4. rails-i18n `number.format` (`delimiter` and `separator` only); `group_min_digits` defaults to 1, `grouping` to `standard`
4. Call ActiveSupport's `number_to_currency( amount, unit:, format:, precision: 0, delimiter:, separator:, delimiter_pattern: )`, with `%c` replaced by the ISO code first:
   - `grouping: indian` passes `delimiter_pattern: /(\d+?)(?=(\d\d)+(\d)(?!\d))/`.
   - `group_min_digits: 2` passes `delimiter: ""` when the integer part has fewer than 5 digits.

   `render_check.rb` is the reference implementation, and `test/roundtrip.test.js` checks it against CLDR for every country and language on the workbook.
5. Turn spaces into non-breaking spaces, so `5` and `€` never wrap apart. Digits are always Latin; the FundraiseUp URL uses plain ASCII digits.
6. Label: `country.label_overrides[locale][freq][tier]`, otherwise `I18n.t( "donation_labels.#{freq}", amount: )`.

## Validations (spec on the YAML, run in CI)

- Country keys are 2-letter uppercase strings, and each `currency` exists under `currencies`.
- `default_country` exists and is enabled. The export always lists every country's `currency` under `currencies`.
- Every enabled country resolves a `once.min`, from itself or its currency. Every tier that is set is a positive integer.
- Set tiers are in min ≤ mid ≤ max order, on each currency and on each country combined with its currency's.
- Every amount is worth at least $3 at market rates. The workbook checker uses a dated snapshot (`usd_rates.json`); the app spec should too, rather than calling a rates API.
- Tiers are ≥ `fru_minimum` when set, and every currency in use has `fru_enabled: true`.
- Every currency is one FundraiseUp supports.
- Patterns contain `%n` and use only `%n`, `%u` and `%c`. `delimiter` and `separator` differ.
- Every override locale is supported and every override tier/frequency is known. The digits in each literal override match the amount.
- `en` donation labels exist for every frequency and contain `%{amount}`.

`check.js` runs the same checks on the workbook before anything reaches YAML.

## Shortcodes (affects WEB-1362)

| Shortcode | FR viewer, `fr` locale |
|---|---|
| `[donation-label tier="min" frequency="once"]` | `Donnez 5 €` |
| `[donation-url tier="min" frequency="once"]` | `…?amount=5&currency=EUR&recurring=once&_lang=fr` |

- `frequency` defaults to `once`.
- `[donation-amount]` was dropped (2026-10-21); authors insert the full button text.
- The label language is always the viewer's locale, even when the announcement variant is in another language. Authors who want matching text create locale-scoped variants.
