# tell the I18n library where to find your translations
I18n.load_path += Dir[Rails.root.join('config', 'locales', '*.{rb,yml}')].sort
I18n.load_path += Dir[Rails.root.join('config', 'locales', 'extra', '*.{rb,yml}')].sort
I18N_LOCALES = Dir[Rails.root.join('config', 'locales', '*.{rb,yml}')].sort.map{|p| 
  p[/\/([\w\-]+?)\.yml/, 1]
}.compact.uniq
I18N_SUPPORTED_LOCALES = I18N_LOCALES.reject{|l| l == 'qqq' || l =~ /\-phonetic/}

Rails.application.config.i18n.available_locales = I18N_SUPPORTED_LOCALES

# set up fallbacks
require "i18n/backend/fallbacks"
I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
I18n.fallbacks.map( iw: :he )

# from and to locales for the translate gem (translation ui)
Rails.application.config.from_locales = [:en, :es]
Rails.application.config.to_locales = [:es, "es-MX".to_sym]
I18n.extend(I18nExtensions)
