# tell the I18n library where to find your translations
I18n.load_path += Dir[Rails.root.join('i18n', '*.{rb,yml}')]
 
# set default locale to something other than :en
I18n.default_locale = :es

