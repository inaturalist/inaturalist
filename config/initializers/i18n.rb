# tell the I18n library where to find your translations
I18n.load_path += Dir[Rails.root.join('config', 'locales', '*.{rb,yml}')].sort
I18n.load_path += Dir[Rails.root.join('config', 'locales', 'extra', '*.{rb,yml}')].sort
I18N_LOCALES = Dir[Rails.root.join('config', 'locales', '*.{rb,yml}')].sort.map{|p| 
  p[/\/([\w\-]+?)\.yml/, 1]
}.compact.uniq
I18N_SUPPORTED_LOCALES = I18N_LOCALES.reject{|l| l == 'qqq' || l =~ /\-phonetic/}

# set default locale to something other than :en
I18n.default_locale = CONFIG.default_locale.to_sym if CONFIG.default_locale

# set up fallbacks
require "i18n/backend/fallbacks"
I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
Rails.application.config.i18n.fallbacks = [ :en ]

# from and to locales for the translate gem (translation ui)
Rails.application.config.from_locales = [:en, :es]
Rails.application.config.to_locales = [:es, "es-MX".to_sym]
