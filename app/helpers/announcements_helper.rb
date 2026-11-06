# frozen_string_literal: true

module AnnouncementsHelper
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

  # [label, locale] for each supported locale, sorted by localized name
  def donation_preview_locale_options
    options = I18N_SUPPORTED_LOCALES.map {| locale | [t( "locales.#{locale}", default: locale ), locale] }
    options.sort_by {| label, _locale | label.downcase }
  end
end
