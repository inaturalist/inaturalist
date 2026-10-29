# Donation config tools

Tools for the workbook that engagement fills in with donation amounts, currency formats and button text for announcements (WEB-1399). The workbook's contents become `config/donation_currencies.yml` and `config/locales/donation_labels/*.yml`. [FIELDS.md](FIELDS.md) describes that format and how each field is derived.

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
- 42 starter countries
- every currency FundraiseUp supports (`FRU_CURRENCIES` in `seed.js`)
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
- missing, non-whole or out-of-order tier amounts
- unknown countries, currencies or languages, and currencies FundraiseUp doesn't support
- button text without `{amount}`
- overrides that don't match their tier amount
- currencies not confirmed as enabled in FundraiseUp

It warns, without failing, about:
- formats that differ from CLDR
- a symbol such as `$` shown without a code for several currencies

`--fill` writes a copy with blank format cells filled from CLDR, each with a cell note. It never changes a cell that has a value.

## Tests

```sh
node --test
```

The round-trip test runs `render_check.rb` with `bundle exec ruby` from the repo root. It checks that the parsed fields, rendered through ActiveSupport as the app will, reproduce CLDR for every starter country and language and every currency's default format.

## Updating the currency list

FundraiseUp's [supported currencies](https://fundraiseup.com/support/supported-currencies/) page defers to Stripe, so `FRU_CURRENCIES` is Stripe's list of [presentment currencies](https://docs.stripe.com/currencies#presentment-currencies) for US accounts. To refresh it, copy the US list from that page. A currency's default format comes from the country in its code's first two letters and CLDR's likeliest language there; add an entry to `CURRENCY_HOME` where that's wrong, such as a currency shared by several countries.
