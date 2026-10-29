# Donation config tools

Tools for the workbook that engagement fills in with donation amounts, currency formats and button text for announcements (WEB-1399). The workbook's contents become `config/donation_currencies.yml` (WEB-1360) and, later, `config/locales/donation_labels/*.yml` (WEB-1362). [FIELDS.md](FIELDS.md) describes that format and how each field is derived.

The tools use Node because its `Intl` API includes the Unicode CLDR locale data, which is used to pre-fill and check formats. They're a self-contained package: the app's `package.json` doesn't depend on them.

## Setup

```sh
cd tools/donation_config
npm ci
```

## Build a fresh workbook

```sh
node build.js donation-config.xlsx
```

This pre-fills:
- every currency FundraiseUp supports (`FRU_CURRENCIES` in `seed.js`), with one-time amounts for the 26 on our donation form: $5, $20 and $100 at the ratio of each currency's lowest form amount to USD's (`LOWEST_FORM_AMOUNTS`), rounded by `niceRound`, and raised where needed so none is worth less than $3 at market rates. Every other currency gets only a one-time min, $5 at market rates rounded down, marked "No" in the "Purchasing power adjusted?" column
- every country whose current currency is one of those, from CLDR's currency and language data (`cldr-core`, pinned to the CLDR version Node uses). The 42 starter countries come first. All are enabled; a country without amounts of its own uses its currency's.
- every currency's and country's symbol and its 1,000.00 and 1,000,000.00 examples, from CLDR
- each locale's existing translation of "Donate", read from `config/locales`

To update the shared sheet without changing its link, upload the file in Google Drive with "Manage versions → Upload new version".

## Check a filled-in workbook

Download the sheet as .xlsx, then:

```sh
node check.js donation-config.xlsx
node check.js donation-config.xlsx --fill donation-config-filled.xlsx
```

`check.js` prints a Markdown report and exits with status 1 if there are errors. It reports:
- examples that don't parse or disagree with each other
- currencies with no one-time min that enabled countries need, and non-whole or out-of-order amounts
- any amount worth less than $3 at market rates
- unknown countries, currencies or languages, and currencies FundraiseUp doesn't support
- button text without `{amount}`
- overrides that don't match their tier amount
- currencies not confirmed as enabled in FundraiseUp
- tiers under a currency's FundraiseUp minimum, a missing or disabled fallback country, and custom fields that aren't `name=value`

It warns, without failing, about:
- a fallback country without every tier
- formats that differ from CLDR
- a symbol such as `$` shown without a code for several currencies

`--fill` writes a copy with blank format cells filled from CLDR, each with a cell note. It never changes a cell that has a value.

## Export to YAML

```sh
node export_yaml.js donation-config.xlsx
node export_yaml.js donation-config.xlsx --out some/other.yml
```

This runs the same checks as `check.js` and writes nothing if there are errors. Otherwise it overwrites `config/donation_currencies.yml` (the default `--out`). The workbook stays the source of truth: change it, check it, and re-export rather than editing the YAML by hand. The output is sorted and has no timestamp, so re-exports diff cleanly.

What it writes:
- every country on the Countries tab, including disabled ones (`enabled: false`), with only the amounts and formatting it sets itself
- country formatting fields only where they differ from the currency's, and `formats.<locale>` from Country by language only where they differ from the country's
- every currency a country uses, with its full format (defaults such as `grouping: standard` left out), amounts and FundraiseUp details
- the settings as top-level keys. `fru.default_url` falls back to the default donation page.

Button text and exact text overrides aren't exported yet (WEB-1362).

## Tests

```sh
node --test
```

The round-trip test runs `render_check.rb` with `bundle exec ruby` from the repo root. It checks that the parsed fields, rendered through ActiveSupport as the app will, reproduce CLDR for every country and language on the workbook and every currency's default format.

## Updating exchange rates

The $3 minimum uses market rates from `usd_rates.json`, a snapshot of [Exchange Rate API](https://www.exchangerate-api.com)'s free USD rates. Refresh it with `npm run rates`, then rebuild the workbook and rerun the tests: the suggestion tests pin a few amounts that depend on the rates.

## Updating the currency list

FundraiseUp's [supported currencies](https://fundraiseup.com/support/supported-currencies/) page defers to Stripe, so `FRU_CURRENCIES` is Stripe's list of [presentment currencies](https://docs.stripe.com/currencies#presentment-currencies) for US accounts. To refresh it, copy the US list from that page. A currency's default format comes from the country in its code's first two letters and CLDR's likeliest language there; add an entry to `CURRENCY_HOME` where that's wrong, such as a currency shared by several countries.
