# frozen_string_literal: true

module AnnouncementsHelper
  # Menu of countries to preview donation amounts as, with the default
  # country first
  def donation_preview_country_select( selected )
    options = [[donation_preview_default_country_label, ""]] + donation_preview_country_options
    select_tag :preview_country,
      options_for_select( options, selected ),
      class: "form-control",
      data: { autosubmit: true }
  end

  # Menu of locales to preview donation labels and checkout in, with the
  # viewer's own locale first
  def donation_preview_locale_select( selected )
    options = [[t( "views.announcements.preview_your_locale" ), ""]] + donation_preview_locale_options
    select_tag :preview_locale,
      options_for_select( options, selected ),
      class: "form-control",
      data: { autosubmit: true }
  end

  # [label, code] for each country in config/donation_currencies.yml, e.g.
  # ["Mexico (MXN)", "MX"], sorted by localized name
  def donation_preview_country_options
    options = DonationCurrency.config["countries"].map do | code, country |
      name = Place.localized_name( country["name"], admin_level: Place::COUNTRY_LEVEL )
      ["#{name} (#{country['currency']})", code]
    end
    options.sort_by {| label, _code | label.downcase }
  end

  # Label for the blank country option, which previews the default country
  def donation_preview_default_country_label
    code = DonationCurrency.default_country_code
    country = DonationCurrency.config["countries"][code]
    t( "views.announcements.preview_default_country",
      country: Place.localized_name( country["name"], admin_level: Place::COUNTRY_LEVEL ),
      currency: country["currency"] )
  end

  # Tiers with amounts for each frequency, e.g. "once: min; monthly: min"
  def donation_priced_tiers_text
    priced = DonationShortcodes.priced_tiers.reject {| _frequency, tiers | tiers.empty? }
    priced.map {| frequency, tiers | "#{frequency}: #{tiers.join( ', ' )}" }.join( "; " )
  end

  # The [donation-url] attributes copied into the link, each in a <code>
  def donation_shortcode_query_params_html
    safe_join( DonationShortcodes::QUERY_PARAMS.map {| param | content_tag( :code, param ) }, " " )
  end

  # Example announcement markup for the donation shortcode help, each in a <pre>
  def donation_shortcode_examples_html
    alternate_url = "https://giving.inaturalist.org/login?form=donations"
    examples = [
      %(<a href="[donation-url utm_source='announcement']">[donation-label]</a>),
      %(<a href="[donation-url url='#{alternate_url}' utm_campaign='year-end']">) \
        "[donation-label tier=\"#{DonationShortcodes::DEFAULT_TIER}\"]</a>"
    ]
    safe_join( examples.map {| example | content_tag( :pre, example ) } )
  end

  # [label, locale] for each supported locale, sorted by localized name
  def donation_preview_locale_options
    options = I18N_SUPPORTED_LOCALES.map {| locale | [t( "locales.#{locale}", default: locale ), locale] }
    options.sort_by {| label, _locale | label.downcase }
  end
end
