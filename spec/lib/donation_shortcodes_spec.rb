# frozen_string_literal: true

require "spec_helper"

describe DonationShortcodes do
  nbsp = DonationCurrency::NBSP

  let( :config ) do
    {
      "default_country" => "US",
      "tier_names" => %w(min mid max),
      "frequencies" => { "once" => "once", "monthly" => "monthly" },
      "currencies" => {
        "USD" => {
          "symbol" => "$", "format" => "%u%n (%c)", "delimiter" => ",", "separator" => ".",
          "tiers" => { "once" => { "min" => 5, "mid" => 20 }, "monthly" => { "min" => 3 } }
        },
        "MXN" => {
          "symbol" => "$", "format" => "%u%n (%c)", "delimiter" => ",", "separator" => ".",
          "tiers" => { "once" => { "min" => 100 }, "monthly" => { "min" => 60 } }
        },
        "EUR" => {
          "symbol" => "€", "format" => "%n %u", "delimiter" => ".", "separator" => ",",
          "tiers" => { "once" => { "min" => 5 } }
        }
      },
      "countries" => {
        "US" => { "currency" => "USD" },
        "MX" => { "currency" => "MXN" },
        "DE" => { "currency" => "EUR" }
      }
    }
  end

  before { DonationCurrency.config = config }
  after { DonationCurrency.config = nil }

  # Sets a translation for the example and puts the old value back afterwards.
  # A nil value makes the key count as untranslated in that locale.
  def with_translation( locale, key, value )
    original = I18n.t( key, locale: locale, fallback: false, default: nil )
    I18n.backend.store_translations( locale, key => value )
    yield
  ensure
    I18n.backend.store_translations( locale, key => original )
  end

  def query_params( url )
    Rack::Utils.parse_query( URI.parse( url ).query )
  end

  describe "#label" do
    it "uses donate_amount in the viewer's locale" do
      expect( DonationShortcodes.new( "US", locale: :en ).label( tier: "min" ) ).to eq "Donate $5#{nbsp}(USD)"
    end

    it "formats the amount for the viewer's country" do
      with_translation( :es, :donate_amount, "Dona %{amount}" ) do
        expect( DonationShortcodes.new( "MX", locale: :es ).label( tier: "min" ) ).to eq "Dona $100#{nbsp}(MXN)"
      end
    end

    it "uses the default country when the country is unknown" do
      expect( DonationShortcodes.new( nil, locale: :en ).label( tier: "min" ) ).to eq "Donate $5#{nbsp}(USD)"
    end

    it "uses the frequency's amount" do
      expect(
        DonationShortcodes.new( "US", locale: :en ).label( tier: "min", frequency: "monthly" )
      ).to eq "Donate $3#{nbsp}(USD)"
    end

    it "falls back to the translated donate_ string when donate_amount is not translated" do
      with_translation( :de, :donate_amount, nil ) do
        expect(
          DonationShortcodes.new( "DE", locale: :de ).label( tier: "min" )
        ).to eq "#{I18n.t( :donate_, locale: :de )} 5#{nbsp}€"
      end
    end

    it "does not use the English donate_amount for another locale" do
      with_translation( :de, :donate_amount, nil ) do
        expect( DonationShortcodes.new( "DE", locale: :de ).label( tier: "min" ) ).not_to start_with "Donate "
      end
    end

    it "returns nil for a tier no one prices" do
      expect( DonationShortcodes.new( "US", locale: :en ).label( tier: "max" ) ).to be_nil
    end
  end

  describe "#url" do
    it "defaults to DEFAULT_DONATION_URL" do
      url = DonationShortcodes.new( "US", locale: :en ).url( tier: "min" )
      expect( url ).to start_with DonationShortcodes::DEFAULT_DONATION_URL.split( "?" ).first
      expect( query_params( url ) ).to include( "form" => "supportinaturalist" )
    end

    it "presets the amount, currency, frequency and language" do
      url = DonationShortcodes.new( "MX", locale: :"es-MX" ).url( tier: "min", frequency: "monthly" )
      expect( query_params( url ) ).to include(
        "amount" => "60", "currency" => "MXN", "recurring" => "monthly", "_lang" => "es-MX"
      )
    end

    it "uses the default country's currency for a tier the country doesn't price" do
      url = DonationShortcodes.new( "MX", locale: :es ).url( tier: "mid" )
      expect( query_params( url ) ).to include( "amount" => "20", "currency" => "USD" )
    end

    it "keeps the query of a custom base url" do
      url = DonationShortcodes.new( "US", locale: :en ).url(
        tier: "min", url: "https://giving.inaturalist.org/page/other?designation=abc"
      )
      expect( url ).to start_with "https://giving.inaturalist.org/page/other?"
      expect( query_params( url ) ).to include( "designation" => "abc", "amount" => "5" )
      expect( query_params( url ) ).not_to include( "form" )
    end

    it "appends several utm params" do
      url = DonationShortcodes.new( "US", locale: :en ).url(
        tier: "min", utm_source: "announcement", utm_medium: "web", utm_campaign: "eoy 26"
      )
      expect( query_params( url ) ).to include(
        "utm_source" => "announcement", "utm_medium" => "web", "utm_campaign" => "eoy 26"
      )
    end

    it "returns nil for a tier no one prices" do
      expect( DonationShortcodes.new( "US", locale: :en ).url( tier: "max" ) ).to be_nil
    end
  end

  describe "#render" do
    let( :shortcodes ) { DonationShortcodes.new( "MX", locale: :en ) }

    it "returns a body without shortcodes unchanged" do
      body = "<p>Hello [world]</p>"
      expect( shortcodes.render( body ) ).to eq body
    end

    it "replaces a label shortcode" do
      expect( shortcodes.render( '<p>[donation-label tier="min"]</p>' ) ).to eq "<p>Donate $100#{nbsp}(MXN)</p>"
    end

    it "replaces a url shortcode inside an href and escapes it" do
      html = shortcodes.render(
        "<a href=\"[donation-url tier='min' utm_source='announcement' utm_campaign='eoy']\">Give</a>"
      )
      href = Nokogiri::HTML.fragment( html ).at( "a" )["href"]
      expect( query_params( href ) ).to include(
        "amount" => "100", "currency" => "MXN", "utm_source" => "announcement", "utm_campaign" => "eoy"
      )
      expect( html ).to include "&amp;amount=100"
      expect( html ).not_to include "&amount="
    end

    it "HTML-escapes label text" do
      with_translation( :en, :donate_amount, "<b>Give</b> %{amount}" ) do
        expect( shortcodes.render( '[donation-label tier="min"]' ) ).to eq "&lt;b&gt;Give&lt;/b&gt; $100#{nbsp}(MXN)"
      end
    end

    it "decodes HTML entities in attribute values" do
      html = shortcodes.render( "[donation-url tier='min' utm_campaign='a&amp;b']" )
      expect( query_params( CGI.unescapeHTML( html ) ) ).to include( "utm_campaign" => "a&b" )
    end

    it "replaces several shortcodes" do
      html = shortcodes.render( '[donation-label tier="min"] or [donation-label tier="min" frequency="monthly"]' )
      expect( html ).to eq "Donate $100#{nbsp}(MXN) or Donate $60#{nbsp}(MXN)"
    end

    it "uses DEFAULT_TIER when a shortcode has no tier" do
      expect( shortcodes.render( "[donation-label]" ) ).to eq shortcodes.render( '[donation-label tier="min"]' )
      expect( shortcodes.render( "[donation-url]" ) ).to eq shortcodes.render( '[donation-url tier="min"]' )
      url = CGI.unescapeHTML( shortcodes.render( "[donation-url]" ) )
      expect( query_params( url ) ).to include( "amount" => "100" )
    end

    it "removes invalid shortcodes instead of raising" do
      expect( shortcodes.render( 'a[donation-label tier="huge"]b[donation-nope]c' ) ).to eq "abc"
    end
  end

  describe ".validation_errors" do
    def error_keys( body )
      DonationShortcodes.validation_errors( body ).map( &:first )
    end

    it "accepts valid shortcodes" do
      body = <<~HTML
        [donation-label tier="min"] [donation-label tier='min' frequency='monthly']
        <a href="[donation-url tier='mid' url='https://example.org/give?x=1' utm_source='a' utm_content='b']">x</a>
      HTML
      expect( DonationShortcodes.validation_errors( body ) ).to eq []
    end

    it "accepts a body without shortcodes" do
      expect( DonationShortcodes.validation_errors( "<p>Hello</p>" ) ).to eq []
    end

    it "rejects an unknown shortcode" do
      expect( error_keys( '[donation-amount tier="min"]' ) ).to eq [:unknown_donation_shortcode]
    end

    it "rejects an unreadable attribute" do
      expect( error_keys( "[donation-label tier=min]" ) ).to eq [:malformed_donation_shortcode]
    end

    it "rejects an unknown attribute" do
      expect( error_keys( '[donation-label tier="min" color="red"]' ) ).to eq [:unknown_donation_shortcode_attribute]
    end

    it "rejects url and utm attributes on a label" do
      expect(
        error_keys( '[donation-label tier="min" url="https://example.org" utm_source="a"]' )
      ).to eq [:unknown_donation_shortcode_attribute, :unknown_donation_shortcode_attribute]
    end

    it "rejects a non-standard utm param" do
      expect( error_keys( '[donation-url tier="min" utm_foo="a"]' ) ).to eq [:unknown_donation_shortcode_attribute]
    end

    it "accepts a missing tier, which defaults to DEFAULT_TIER" do
      expect( DonationShortcodes.validation_errors( "[donation-label] [donation-url]" ) ).to eq []
    end

    it "rejects a missing tier when DEFAULT_TIER isn't priced for the frequency" do
      expect( error_keys( '[donation-label frequency="monthly"]' ) ).to eq []
      stub_const( "DonationShortcodes::DEFAULT_TIER", "max" )
      expect( error_keys( "[donation-label]" ) ).to eq [:unpriced_donation_tier]
    end

    it "rejects an unknown tier" do
      expect( error_keys( '[donation-label tier="huge"]' ) ).to eq [:invalid_donation_tier]
    end

    it "rejects an unknown frequency" do
      expect( error_keys( '[donation-label tier="min" frequency="weekly"]' ) ).to eq [:invalid_donation_frequency]
    end

    it "rejects a tier the default country doesn't price" do
      expect( error_keys( '[donation-label tier="max"]' ) ).to eq [:unpriced_donation_tier]
    end

    it "rejects a url that isn't http or https" do
      expect( error_keys( "[donation-url tier='min' url='javascript:alert(1)']" ) ).to eq [:invalid_donation_url]
      expect( error_keys( "[donation-url tier='min' url='http://exa mple.org']" ) ).to eq [:invalid_donation_url]
    end

    it "includes the shortcode in the error options" do
      _key, options = DonationShortcodes.validation_errors( '[donation-label tier="huge"]' ).first
      expect( options[:shortcode] ).to eq '[donation-label tier="huge"]'
    end
  end
end
