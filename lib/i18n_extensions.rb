# frozen_string_literal: true

module I18nExtensions
  # Detect if the current locale has translation _without_ falling back to the default locale
  # Helpful to introduce new translations while maintaining backward compatibility
  def has_t?( key, options = {} )
    current_locale = options[:locale] || I18n.locale
    fallbacks = I18n.fallbacks[current_locale.to_sym]
    base_default_locale = I18n.default_locale.to_s.split( "-" ).first

    unless current_locale.to_s.start_with?( base_default_locale )
      fallbacks -= [I18n.default_locale]
    end

    fallbacks.any? {| locale | I18n.backend.exists?( locale, key, fallback: false ) }
  end
end
