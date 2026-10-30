# frozen_string_literal: true

require "spec_helper"

describe DonationCurrency do
  nbsp = DonationCurrency::NBSP

  let( :config ) do
    {
      "default_country" => "US",
      "tier_names" => %w(min mid max),
      "frequencies" => { "once" => "once", "monthly" => "monthly" },
      "currencies" => {
        "USD" => {
          "symbol" => "$", "format" => "%u%n (%c)", "delimiter" => ",", "separator" => ".",
          "tiers" => { "once" => { "min" => 5, "mid" => 20, "max" => 100 }, "monthly" => { "min" => 3 } }
        },
        "MXN" => {
          "symbol" => "$", "format" => "%u%n (%c)", "delimiter" => ",", "separator" => ".",
          "tiers" => { "once" => { "min" => 100 } }
        },
        "EUR" => {
          "symbol" => "€", "format" => "%n %u", "delimiter" => ".", "separator" => ",",
          "tiers" => { "once" => { "min" => 5, "mid" => 20 } }
        },
        "CHF" => {
          "symbol" => "CHF", "format" => "%u %n", "delimiter" => "'", "separator" => ".",
          "tiers" => { "once" => { "min" => 5 } }
        },
        "INR" => {
          "symbol" => "₹", "format" => "%u%n", "delimiter" => ",", "separator" => ".", "grouping" => "indian",
          "tiers" => { "once" => { "min" => 300 } }
        },
        "XYZ" => { "symbol" => "X", "format" => "%n %u", "tiers" => { "once" => { "min" => 1000 } } }
      },
      "countries" => {
        "US" => { "currency" => "USD" },
        "MX" => { "currency" => "MXN", "tiers" => { "once" => { "mid" => 400 } } },
        "FR" => { "currency" => "EUR", "delimiter" => " " },
        "ES" => { "currency" => "EUR", "group_min_digits" => 2 },
        "CH" => { "currency" => "CHF", "formats" => { "fr" => { "format" => "%n %u" } } },
        "IN" => { "currency" => "INR" },
        "XX" => { "currency" => "XYZ" },
        "KE" => { "currency" => "EUR", "enabled" => false }
      }
    }
  end

  before { DonationCurrency.config = config }
  after { DonationCurrency.config = nil }

  describe ".for_country" do
    it "picks the country's currency" do
      expect( DonationCurrency.for_country( "MX" ).currency ).to eq "MXN"
    end

    it "ignores case and whitespace" do
      expect( DonationCurrency.for_country( " mx " ).country_code ).to eq "MX"
    end

    it "uses the default country when there is no country" do
      expect( DonationCurrency.for_country( nil ).country_code ).to eq "US"
    end

    it "uses the default country for an unlisted country" do
      expect( DonationCurrency.for_country( "ZZ" ).currency ).to eq "USD"
    end

    it "uses the default country for a disabled country" do
      expect( DonationCurrency.for_country( "KE" ).currency ).to eq "USD"
    end
  end

  describe "#amount" do
    it "uses the currency's amount" do
      price = DonationCurrency.for_country( "MX" ).amount( tier: :min )
      expect( price.to_h ).to eq( amount: 100, currency: "MXN", country_code: "MX" )
    end

    it "uses the country's own amount first" do
      expect( DonationCurrency.for_country( "MX" ).amount( tier: :mid ).amount ).to eq 400
    end

    it "uses the default country's amount and currency for a tier nobody sets" do
      price = DonationCurrency.for_country( "MX" ).amount( tier: :max )
      expect( price.to_h ).to eq( amount: 100, currency: "USD", country_code: "US" )
    end

    it "reads monthly amounts" do
      expect( DonationCurrency.for_country( "US" ).amount( tier: "min", frequency: "monthly" ).amount ).to eq 3
    end

    it "is nil when the default country doesn't set the tier either" do
      expect( DonationCurrency.for_country( "FR" ).amount( tier: :mid, frequency: :monthly ) ).to be_nil
    end

    it "rejects an unknown tier" do
      expect { DonationCurrency.for_country( "FR" ).amount( tier: :huge ) }.to raise_error( ArgumentError, /tier/ )
    end

    it "rejects an unknown frequency" do
      expect do
        DonationCurrency.for_country( "FR" ).amount( tier: :min, frequency: :weekly )
      end.to raise_error( ArgumentError, /frequency/ )
    end
  end

  describe "#format" do
    it "adds the code where the format asks for it" do
      expect( DonationCurrency.for_country( "US" ).format( 5, locale: :en ) ).to eq "$5#{nbsp}(USD)"
      expect( DonationCurrency.for_country( "MX" ).format( 1000, locale: :es ) ).to eq "$1,000#{nbsp}(MXN)"
    end

    it "uses the country's fields over the currency's" do
      expect( DonationCurrency.for_country( "FR" ).format( 1000, locale: :fr ) ).to eq "1#{nbsp}000#{nbsp}€"
    end

    it "uses the country's format for the locale, then for its language" do
      ch = DonationCurrency.for_country( "CH" )
      expect( ch.format( 1000, locale: :de ) ).to eq "CHF#{nbsp}1'000"
      expect( ch.format( 1000, locale: :fr ) ).to eq "1'000#{nbsp}CHF"
      expect( ch.format( 1000, locale: :"fr-CA" ) ).to eq "1'000#{nbsp}CHF"
    end

    it "leaves 4-digit amounts ungrouped where group_min_digits is 2" do
      es = DonationCurrency.for_country( "ES" )
      expect( es.format( 1000, locale: :es ) ).to eq "1000#{nbsp}€"
      expect( es.format( 10_000, locale: :es ) ).to eq "10.000#{nbsp}€"
    end

    it "groups lakhs and crores for Indian grouping" do
      expect( DonationCurrency.for_country( "IN" ).format( 10_000_000, locale: :hi ) ).to eq "₹1,00,00,000"
    end

    it "falls back to the locale's delimiter when no level sets one" do
      xx = DonationCurrency.for_country( "XX" )
      delimiter = I18n.t( "number.format.delimiter", locale: :de )
      expect( xx.format( 1000, locale: :de ) ).to eq "1#{delimiter}000#{nbsp}X".tr( " ", nbsp )
    end
  end

  describe "#formatted_amount" do
    it "formats the tier amount for the viewer's locale" do
      expect( DonationCurrency.for_country( "FR" ).formatted_amount( tier: :min, locale: :fr ) ).to eq "5#{nbsp}€"
    end

    it "formats a fallback amount in the default country's currency" do
      text = DonationCurrency.for_country( "MX" ).formatted_amount( tier: :max, locale: :es )
      expect( text ).to eq "$100#{nbsp}(USD)"
    end

    it "is nil when there is no amount" do
      expect( DonationCurrency.for_country( "FR" ).formatted_amount( tier: :max, frequency: :monthly ) ).to be_nil
    end
  end
end
