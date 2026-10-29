# frozen_string_literal: true

# Picks a viewer's donation currency and amounts by country, and formats
# amounts the way people there write them. Reads
# config/donation_currencies.yml, which is generated from the engagement
# workbook by tools/donation_config/export_yaml.js; FIELDS.md in that directory
# describes every field.
#
#   donation = DonationCurrency.for_country( "FR" )
#   donation.currency                                   # => "EUR"
#   donation.amount( tier: :min )                       # => Price( 5, "EUR", "FR" )
#   donation.formatted_amount( tier: :min, locale: :fr ) # => "5 €" (non-breaking space)
class DonationCurrency
  CONFIG_PATH = Rails.root.join( "config", "donation_currencies.yml" )

  # Formatting fields, each resolved on its own: country × language, then
  # country, then currency
  FORMAT_FIELDS = %w(symbol format delimiter separator group_min_digits grouping).freeze

  # Lakh/crore grouping: 10,00,000
  INDIAN_DELIMITER_PATTERN = /(\d+?)(?=(\d\d)+(\d)(?!\d))/

  NBSP = " "

  Price = Struct.new( :amount, :currency, :country_code, keyword_init: true )

  class << self
    attr_writer :config

    def config
      @config ||= YAML.load_file( CONFIG_PATH ).freeze
    end

    def for_country( code )
      new( code )
    end

    def default_country_code
      config["default_country"]
    end
  end

  attr_reader :country_code

  # Unknown and disabled countries, and a blank code (geoip failed), get the
  # default country
  def initialize( code )
    requested = code.to_s.strip.upcase
    @country_code = enabled_country?( requested ) ? requested : self.class.default_country_code
  end

  def currency
    country["currency"]
  end

  def default_country?
    country_code == self.class.default_country_code
  end

  # The amount for a tier, as a Price. A tier the country and its currency
  # don't set comes from the default country, in its currency, so the amount
  # and currency always match. Returns nil if the default country doesn't set
  # it either.
  def amount( tier:, frequency: :once )
    tier = check_name( tier, config["tier_names"], "tier" )
    frequency = check_name( frequency, config["frequencies"].keys, "frequency" )
    value = country.dig( "tiers", frequency, tier ) || currency_config.dig( "tiers", frequency, tier )
    return Price.new( amount: value, currency: currency, country_code: country_code ) if value
    return if default_country?

    self.class.new( self.class.default_country_code ).amount( tier: tier, frequency: frequency )
  end

  # A whole-number amount in this country's currency, as people here write it
  # in the given locale
  def format( amount, locale: I18n.locale )
    fields = format_fields( locale )
    options = {
      unit: fields["symbol"],
      format: fields["format"].gsub( "%c", currency ),
      precision: 0,
      delimiter: fields["delimiter"],
      separator: fields["separator"],
      locale: locale
    }
    if fields["group_min_digits"].to_i == 2 && amount.to_i.abs.to_s.length < 5
      options[:delimiter] = ""
    end
    options[:delimiter_pattern] = INDIAN_DELIMITER_PATTERN if fields["grouping"] == "indian"
    ActiveSupport::NumberHelper.number_to_currency( amount, options.compact ).tr( " ", NBSP )
  end

  # The formatted amount for a tier, or nil if no amount is set
  def formatted_amount( tier:, frequency: :once, locale: I18n.locale )
    price = amount( tier: tier, frequency: frequency )
    return unless price

    self.class.new( price.country_code ).format( price.amount, locale: locale )
  end

  # Each formatting field from the first level that sets it, falling back to
  # the locale's number format for the separators
  def format_fields( locale )
    locale = locale.to_s
    levels = [
      country.dig( "formats", locale ),
      country.dig( "formats", locale.split( "-" ).first ),
      country,
      currency_config
    ].compact
    number_format = I18n.t( "number.format", locale: locale, default: {} )
    FORMAT_FIELDS.to_h do | field |
      found = levels.find {| level | level.key?( field ) }
      value = found ? found[field] : nil
      value = number_format[field.to_sym] if value.nil? && %w(delimiter separator).include?( field )
      [field, value]
    end
  end

  private

  def config
    self.class.config
  end

  def country
    config["countries"][country_code]
  end

  def currency_config
    config["currencies"][currency] || {}
  end

  def enabled_country?( code )
    settings = config["countries"][code]
    settings && settings["enabled"] != false
  end

  def check_name( value, allowed, kind )
    name = value.to_s
    return name if allowed.include?( name )

    raise ArgumentError, "Unknown donation #{kind} #{value.inspect}; expected one of #{allowed.join( ', ' )}"
  end
end
