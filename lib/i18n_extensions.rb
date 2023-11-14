# frozen_string_literal: true

# rubocop:disable Naming/PredicateName
module I18nExtensions
  # Detect if the current locale has translation _without_ falling back to the default locale
  # Helpful to introduce new translations while maintaining backward compatibility
  def has_t?( key, options = {} )
    fallbacks = I18n.fallbacks[I18n.locale.to_sym]
    base_default_locale = I18n.default_locale.to_s.split( "-" ).first
    current_locale = ( options[:locale] || I18n.locale ).to_s

    unless current_locale.start_with?( base_default_locale )
      fallbacks -= [I18n.default_locale]
    end

    fallbacks.any? {| locale | I18n.backend.exists?( locale, key, fallback: false ) }
  end
end
# rubocop:enable Naming/PredicateName
