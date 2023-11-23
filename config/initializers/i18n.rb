# frozen_string_literal: true

# tell the I18n library where to find your translations
I18N_LOCALES = Dir[Rails.root.join( "config", "locales", "*.{rb,yml}" )].map do | p |
  p[%r{/([\w\-]+?)\.yml}, 1]
end.compact.uniq
I18N_SUPPORTED_LOCALES = I18N_LOCALES.reject {| l | l == "qqq" || l =~ /-phonetic/ }

Rails.application.config.i18n.available_locales = I18N_SUPPORTED_LOCALES

# set up fallbacks
require "i18n/backend/fallbacks"
I18n::Backend::Simple.include I18n::Backend::Fallbacks
fallback_maps = I18N_SUPPORTED_LOCALES.map {| locale | [locale.to_sym, :en] }.to_h
fallback_maps[:iw] = [:he, :en]
fallback_maps[:"zh-HK"] = [:"zh-TW", :en]
I18n.fallbacks.map( fallback_maps )

# from and to locales for the translate gem (translation ui)
Rails.application.config.from_locales = [:en, :es]
Rails.application.config.to_locales = [:es, :"es-MX"]

# Extend I18n module and the simple backend
I18n.extend( I18nExtensions )
I18n::Backend::Simple.include I18nCustomBackend

I18n::JS.export_i18n_js_dir_path = "app/assets/javascripts"

def without_english_fallback
  old_fallbacks = I18n.fallbacks.clone
  new_fallbacks = old_fallbacks.each_with_object( {} ) do | pair, memo |
    locale, fallbacks = pair
    memo[locale] = if fallbacks.include?( :en ) && locale.to_s !~ /^en/
      fallbacks.without( :en )
    else
      fallbacks
    end
  end
  I18n.fallbacks = I18n::Locale::Fallbacks.new( new_fallbacks )
  yield
  I18n.fallbacks = I18n::Locale::Fallbacks.new( old_fallbacks )
end
