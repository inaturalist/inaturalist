# frozen_string_literal: true

# Replaces donation shortcodes in announcement bodies with the viewer's local
# amount, using DonationCurrency for the amounts and formats.
#
#   [donation-label tier="min"]                  → Donate $100 (MXN)
#   [donation-label tier="min" frequency="monthly"]
#   <a href="[donation-url tier='min' utm_source='announcement']">…</a>
#   <a href="[donation-url tier='min' url='https://giving.inaturalist.org/page/other']">…</a>
#
# Attribute values can use double or single quotes, so a shortcode fits inside
# a double-quoted href.
class DonationShortcodes
  # Where [donation-url] points when it has no url attribute
  DEFAULT_DONATION_URL = "https://giving.inaturalist.org/login?form=supportinaturalist"

  UTM_PARAMS = %w(utm_source utm_medium utm_campaign utm_term utm_content).freeze

  # Shortcode name → the attributes it accepts
  SHORTCODES = {
    "label" => %w(tier frequency),
    "url" => %w(tier frequency url) + UTM_PARAMS
  }.freeze

  # Matches anything that looks like a donation shortcode, valid or not, so
  # validation can report the invalid ones
  PATTERN = /\[donation-([^\s\]]*)([^\]]*)\]/

  ATTRIBUTE_PATTERN = /([\w-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/

  DEFAULT_FREQUENCY = "once"

  Shortcode = Struct.new( :text, :name, :attributes, :malformed, keyword_init: true )

  class << self
    # Each shortcode in the body, in order
    def parse( body )
      body.to_s.to_enum( :scan, PATTERN ).map do
        match = Regexp.last_match
        attribute_text = match[2]
        attributes = attribute_text.scan( ATTRIBUTE_PATTERN ).map do | name, double_quoted, single_quoted |
          [name, CGI.unescapeHTML( double_quoted || single_quoted )]
        end
        Shortcode.new(
          text: match[0],
          name: match[1],
          attributes: attributes,
          malformed: attribute_text.gsub( ATTRIBUTE_PATTERN, "" ).strip.present?
        )
      end
    end

    # [error_key, options] pairs for Announcement to add to its body errors.
    # Every option hash includes the offending :shortcode text.
    def validation_errors( body )
      parse( body ).flat_map {| shortcode | shortcode_errors( shortcode ) }
    end

    private

    def shortcode_errors( shortcode )
      error = ->( key, **options ) { [key, options.merge( shortcode: shortcode.text )] }
      allowed_attributes = SHORTCODES[shortcode.name]
      return [error.call( :unknown_donation_shortcode )] unless allowed_attributes
      return [error.call( :malformed_donation_shortcode )] if shortcode.malformed

      attributes = shortcode.attributes.to_h
      unknown_attributes = shortcode.attributes.map( &:first ) - allowed_attributes
      errors = unknown_attributes.map do | name |
        error.call( :unknown_donation_shortcode_attribute, attribute: name )
      end

      config = DonationCurrency.config
      tier = attributes["tier"]
      frequency = attributes["frequency"] || DEFAULT_FREQUENCY
      tier_names = config["tier_names"]
      frequencies = config["frequencies"].keys
      if tier.blank?
        errors << error.call( :missing_donation_tier, allowed: tier_names.join( ", " ) )
      elsif !tier_names.include?( tier )
        errors << error.call( :invalid_donation_tier, value: tier, allowed: tier_names.join( ", " ) )
      end
      unless frequencies.include?( frequency )
        errors << error.call( :invalid_donation_frequency, value: frequency, allowed: frequencies.join( ", " ) )
      end
      if tier_names.include?( tier ) && frequencies.include?( frequency ) && !default_priced?( tier, frequency )
        errors << error.call( :unpriced_donation_tier, tier: tier, frequency: frequency )
      end
      if attributes.key?( "url" ) && !valid_url?( attributes["url"] )
        errors << error.call( :invalid_donation_url )
      end
      errors
    end

    def default_priced?( tier, frequency )
      DonationCurrency.for_country( DonationCurrency.default_country_code ).
        amount( tier: tier, frequency: frequency ).present?
    end

    def valid_url?( url )
      uri = URI.parse( url.to_s )
      uri.is_a?( URI::HTTP ) && uri.host.present?
    rescue URI::InvalidURIError
      false
    end
  end

  attr_reader :locale

  # A blank or unknown country code (geoip failed or found nothing) gets the
  # default country
  def initialize( country_code, locale: I18n.locale )
    @currency = DonationCurrency.for_country( country_code )
    @locale = locale.to_sym
  end

  # The body with every shortcode replaced by HTML-escaped text. Shortcodes
  # that are invalid, or whose tier has no amount, are removed: validation
  # stops them being saved, and a page must never fail to render because of one.
  def render( body )
    body.to_s.gsub( PATTERN ) do
      shortcode = self.class.parse( Regexp.last_match( 0 ) ).first
      ERB::Util.html_escape( replacement( shortcode ).to_s )
    end
  end

  # Button text such as "Donate $100 (MXN)" in the viewer's locale, or nil if
  # no amount is set for the tier
  def label( tier:, frequency: DEFAULT_FREQUENCY )
    amount = @currency.formatted_amount( tier: tier, frequency: frequency, locale: locale )
    return unless amount

    template_locale = donate_amount_locale
    return I18n.t( :donate_amount, amount: amount, locale: template_locale ) if template_locale

    "#{I18n.t( :donate_, locale: locale )} #{amount}"
  end

  # A FundraiseUp checkout URL with the amount, currency, frequency and
  # language preset, or nil if no amount is set for the tier
  def url( tier:, frequency: DEFAULT_FREQUENCY, url: nil, **utm )
    price = @currency.amount( tier: tier, frequency: frequency )
    return unless price

    uri = URI.parse( url.presence || DEFAULT_DONATION_URL )
    params = Rack::Utils.parse_query( uri.query.to_s )
    params.merge!(
      "amount" => price.amount.to_s,
      "currency" => price.currency,
      "recurring" => DonationCurrency.config["frequencies"][frequency.to_s],
      "_lang" => locale.to_s
    )
    utm.each do | name, value |
      params[name.to_s] = value if UTM_PARAMS.include?( name.to_s ) && value.present?
    end
    uri.query = Rack::Utils.build_query( params )
    uri.to_s
  end

  private

  def replacement( shortcode )
    return if shortcode.nil? || shortcode.malformed

    attributes = shortcode.attributes.to_h.transform_keys( &:to_sym )
    case shortcode.name
    when "label" then label( **attributes.slice( :tier, :frequency ) )
    when "url" then url( **attributes.slice( :tier, :frequency, :url, *UTM_PARAMS.map( &:to_sym ) ) )
    end
  rescue ArgumentError, URI::InvalidURIError
    nil
  end

  # The first locale in the viewer's fallback chain that translates
  # donate_amount. English only counts for English locales, so a missing
  # translation uses the translated donate_ string instead of English text.
  # Checks each locale without fallbacks rather than swapping I18n.fallbacks,
  # which is process-wide.
  def donate_amount_locale
    chain = I18n.fallbacks[locale]
    chain -= [:en] unless locale.to_s.split( "-" ).first == "en"
    chain.find {| candidate | I18n.exists?( :donate_amount, locale: candidate, fallback: false ) }
  end
end
