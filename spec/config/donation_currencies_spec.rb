# frozen_string_literal: true

require "spec_helper"

# Checks config/donation_currencies.yml, which is generated from the
# engagement workbook by tools/donation_config/export_yaml.js. That script's
# checker covers the same rules and more (e.g. the $3 minimum at market rates);
# these catch hand edits and a stale export.
describe "config/donation_currencies.yml" do
  config = YAML.load_file( DonationCurrency::CONFIG_PATH )
  tiers = config["tier_names"]
  frequencies = config["frequencies"].keys
  currencies = config["currencies"]
  countries = config["countries"]
  enabled = countries.reject {| _, c | c["enabled"] == false }

  levels = currencies.map {| code, c | ["currency #{code}", c] } +
    countries.map {| code, c | ["country #{code}", c] } +
    countries.flat_map do | code, c |
      ( c["formats"] || {} ).map {| locale, f | ["country #{code} locale #{locale}", f] }
    end

  it "uses the fixed tier names and frequencies" do
    expect( tiers ).to eq %w(min mid max)
    expect( config["frequencies"] ).to eq( "once" => "once", "monthly" => "monthly" )
  end

  it "has 2-letter uppercase string country codes with a listed currency" do
    countries.each do | code, country |
      expect( code ).to be_a( String ).and match( /\A[A-Z]{2}\z/ )
      expect( currencies ).to have_key( country["currency"] ), "#{code} uses #{country['currency']}"
    end
  end

  it "has 3-letter uppercase currency codes with a symbol and format" do
    currencies.each do | code, currency |
      expect( code ).to match( /\A[A-Z]{3}\z/ )
      expect( currency["symbol"] ).to be_present, code
      expect( currency["format"] ).to be_present, code
    end
  end

  it "has an enabled default country" do
    expect( enabled ).to have_key( config["default_country"] )
  end

  it "gives every enabled country a one-time min" do
    missing = enabled.keys.reject do | code |
      countries[code].dig( "tiers", "once", "min" ) ||
        currencies[countries[code]["currency"]].dig( "tiers", "once", "min" )
    end
    expect( missing ).to be_empty
  end

  it "has positive whole amounts, in min ≤ mid ≤ max order, at least FundraiseUp's minimum" do
    problems = []
    check = lambda do | label, amounts, minimum |
      frequencies.each do | freq |
        set = tiers.map {| t | amounts.dig( freq, t ) }.compact
        problems << "#{label} #{freq}: #{set}" unless set.all? {| n | n.is_a?( Integer ) && n.positive? }
        problems << "#{label} #{freq} out of order: #{set}" unless set == set.sort
        next unless minimum&.dig( freq )

        problems << "#{label} #{freq} under the FundraiseUp minimum" if set.any? {| n | n < minimum[freq] }
      end
    end
    currencies.each do | code, c |
      check.call( "currency #{code}", c["tiers"] || {}, c["fru_minimum"] )
    end
    countries.each do | code, c |
      currency = currencies[c["currency"]]
      combined = frequencies.to_h do | freq |
        [freq, ( currency.dig( "tiers", freq ) || {} ).merge( c.dig( "tiers", freq ) || {} )]
      end
      check.call( "country #{code}", combined, currency["fru_minimum"] )
    end
    expect( problems ).to be_empty
  end

  it "has no currency in use that isn't enabled in FundraiseUp" do
    used = enabled.values.map {| c | c["currency"] }.uniq
    expect( used.select {| code | currencies[code]["fru_enabled"] == false } ).to be_empty
  end

  it "has formats with %n and only %n, %u and %c" do
    levels.each do | label, fields |
      next unless fields["format"]

      expect( fields["format"] ).to include( "%n" ), label
      expect( fields["format"].scan( /%./ ) - %w(%n %u %c) ).to be_empty, label
    end
  end

  it "has known grouping values and different delimiters and separators" do
    levels.each do | label, fields |
      expect( [nil, "standard", "indian"] ).to include( fields["grouping"] ), label
      expect( [nil, 1, 2] ).to include( fields["group_min_digits"] ), label
      next unless fields["delimiter"] && fields["separator"]

      expect( fields["delimiter"] ).not_to eq( fields["separator"] ), label
    end
  end

  it "formats every enabled country's one-time min in each of its locales" do
    enabled.each do | code, country |
      donation = DonationCurrency.for_country( code )
      ( country["locales"] || ["en"] ).each do | locale |
        text = donation.formatted_amount( tier: :min, locale: locale )
        expect( text ).to match( /\d/ ), "#{code} #{locale}: #{text.inspect}"
      end
    end
  end
end
