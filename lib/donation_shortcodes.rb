# frozen_string_literal: true

# Replaces donation shortcodes in announcement bodies with the viewer's local
# amount, using DonationCurrency for the amounts and formats.
#
#   [donation-label tier="min"]                  → Donate $100 (MXN)
#   [donation-label tier="min" frequency="monthly"]
#   <a href="[donation-url tier='min' utm_source='announcement']">…</a>
#   <a href="[donation-url tier='min' url='https://giving.inaturalist.org/page/other']">…</a>
#   <a href="[donation-url form='donations' segment='acqmobile26' redirectTo='/' utm_medium='mobile']">…</a>
#
# Every [donation-url] link gets utm_term set to the announcement id unless the
# author sets utm_term, either as an attribute or in the url's query.
#
# tier defaults to DEFAULT_TIER and frequency to DEFAULT_FREQUENCY. Attribute
# values can use double or single quotes, so a shortcode fits inside a
# double-quoted href.
class DonationShortcodes
  UTM_PARAMS = %w(utm_source utm_medium utm_campaign utm_term utm_content).freeze

  # FundraiseUp URL params [donation-url] passes through: the form to open, the
  # donor segment, and the page to show after the login step
  FRU_PARAMS = %w(form segment redirectTo).freeze

  # Attributes of [donation-url] copied into the link's query as written
  QUERY_PARAMS = ( FRU_PARAMS + UTM_PARAMS ).freeze

  # Codes FundraiseUp accepts for _lang (https://fundraiseup.com/docs/languages/).
  FUNDRAISEUP_LANGUAGES = %w(
    ar da de en-CA en-GB en-US es es-US fi fr-CA fr-FR he hu it ja ko nl no pl
    pt-BR pt-PT ru sv zh-CN zh-TW
  ).freeze

  # locales where FundraiseUp language code differs from inat
  FUNDRAISEUP_LANGUAGE_ALIASES = {
    "en" => "en-US",
    "fr" => "fr-FR",
    "pt" => "pt-PT",
    "nb" => "no",
    "nn" => "no",
    "zh-HK" => "zh-TW",
    "iw" => "he"
  }.freeze

  # Shortcode name → the attributes it accepts
  SHORTCODES = {
    "label" => %w(tier frequency),
    "url" => %w(tier frequency url) + QUERY_PARAMS
  }.freeze

  # Matches anything that looks like a donation shortcode, valid or not, so
  # validation can report the invalid ones
  PATTERN = /\[donation-([^\s\]]*)([^\]]*)\]/

  ATTRIBUTE_PATTERN = /([\w-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/

  DEFAULT_TIER = "min"

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

    def fundraiseup_language( locale )
      locale = locale.to_s
      language = locale.split( "-" ).first
      candidates = [
        locale,
        FUNDRAISEUP_LANGUAGE_ALIASES[locale],
        language,
        FUNDRAISEUP_LANGUAGE_ALIASES[language]
      ]
      candidates.find {| code | FUNDRAISEUP_LANGUAGES.include?( code ) }
    end

    # Frequency → the tiers the default country has an amount for, e.g.
    # { "once" => ["min"], "monthly" => [] }. Shortcodes may only use these.
    def priced_tiers
      config = DonationCurrency.config
      config["frequencies"].keys.index_with do | frequency |
        config["tier_names"].select {| tier | default_priced?( tier, frequency ) }
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
      tier = attributes["tier"] || DEFAULT_TIER
      frequency = attributes["frequency"] || DEFAULT_FREQUENCY
      tier_names = config["tier_names"]
      frequencies = config["frequencies"].keys
      unless tier_names.include?( tier )
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
  # default country. utm_term is the default for [donation-url] links,
  # normally the announcement id.
  def initialize( country_code, locale: I18n.locale, utm_term: nil )
    @currency = DonationCurrency.for_country( country_code )
    @locale = locale.to_sym
    @utm_term = utm_term.presence&.to_s
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
  def label( tier: DEFAULT_TIER, frequency: DEFAULT_FREQUENCY )
    amount = @currency.formatted_amount( tier: tier, frequency: frequency, locale: locale )
    return unless amount

    template_locale = donate_amount_locale
    return I18n.t( :donate_amount, amount: amount, locale: template_locale ) if template_locale

    "#{I18n.t( :donate_, locale: locale )} #{amount}"
  end

  # A FundraiseUp checkout URL with the amount, currency, frequency and
  # language preset, or nil if no amount is set for the tier. The base url's
  # query is kept; QUERY_PARAMS given here replace params of the same name,
  # and the amount, currency, frequency and language always come from the
  # viewer. _lang is left out when FundraiseUp has no language for the
  # viewer's locale, so FundraiseUp picks one itself.
  def url( tier: DEFAULT_TIER, frequency: DEFAULT_FREQUENCY, url: nil, **query )
    price = @currency.amount( tier: tier, frequency: frequency )
    return unless price

    uri = URI.parse( url.presence || DonationCurrency.config["fru"]["default_url"] )
    params = Rack::Utils.parse_query( uri.query.to_s )
    params["utm_term"] ||= @utm_term if @utm_term
    query.each do | name, value |
      params[name.to_s] = value if QUERY_PARAMS.include?( name.to_s ) && value.present?
    end
    params.merge!(
      "amount" => price.amount.to_s,
      "currency" => price.currency,
      "recurring" => DonationCurrency.config["frequencies"][frequency.to_s]
    )
    language = self.class.fundraiseup_language( locale )
    if language
      params["_lang"] = language
    else
      params.delete( "_lang" )
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
    when "url" then url( **attributes.slice( :tier, :frequency, :url, *QUERY_PARAMS.map( &:to_sym ) ) )
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
