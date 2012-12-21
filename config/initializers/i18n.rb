# tell the I18n library where to find your translations
# I18n.load_path += Dir[Rails.root.join('i18n', '*.{rb,yml}')]
I18n.load_path += Dir[Rails.root.join('i18n', '**', '*.{rb,yml}')]
I18N_SUPPORTED_LOCALES = I18n.load_path.map{|p| p[/defaults\/(.*?)\.yml/, 1]}.compact
 
# set default locale to something other than :en
I18n.default_locale = INAT_CONFIG['default_locale'].to_sym if INAT_CONFIG['default_locale']

# set up fallbacks
require "i18n/backend/fallbacks"
I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
