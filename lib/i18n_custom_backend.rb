# frozen_string_literal: true

# Customizations to the I18n backend
module I18nCustomBackend
  # Port of the same function in the original Simple backend, except it adds
  # support for lowercase month codes %=b and %=B
  def translate_localization_format( locale, object, format, _options )
    format.to_s.gsub( /%[=\^]?[aAbBpP]/ ) do | match |
      case match
      when "%a"
        I18n.t!( :"date.abbr_day_names", locale: locale, format: format )[object.wday]
      when "%^a"
        I18n.t!( :"date.abbr_day_names", locale: locale, format: format )[object.wday].upcase
      when "%A"
        I18n.t!( :"date.day_names", locale: locale, format: format )[object.wday]
      when "%^A"
        I18n.t!( :"date.day_names", locale: locale, format: format )[object.wday].upcase
      when "%b"
        I18n.t!( :"date.abbr_month_names", locale: locale, format: format )[object.mon]
      when "%^b"
        I18n.t!( :"date.abbr_month_names", locale: locale, format: format )[object.mon].upcase
      when "%=b"
        I18n.t!( :"date.abbr_month_names", locale: locale, format: format )[object.mon].downcase
      when "%B"
        I18n.t!( :"date.month_names", locale: locale, format: format )[object.mon]
      when "%^B"
        I18n.t!( :"date.month_names", locale: locale, format: format )[object.mon].upcase
      when "%=B"
        I18n.t!( :"date.month_names", locale: locale, format: format )[object.mon].downcase
      when "%p"
        hour = object.respond_to?( :hour ) ? object.hour : 0
        time_key = hour < 12 ? :am : :pm
        I18n.t!( :"time.#{time_key}", locale: locale, format: format ).upcase
      when "%P"
        hour = object.respond_to?( :hour ) ? object.hour : 0
        time_key = hour < 12 ? :am : :pm
        I18n.t!( :"time.#{time_key}", locale: locale, format: format ).downcase
      end
    end
  rescue MissingTranslationData => e
    e.message
  end
end
