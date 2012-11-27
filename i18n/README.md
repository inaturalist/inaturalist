iNaturalist I18n Guidelines
===========================

1. As much as possible, employ reusable strings and keep them in the default translation files.
2. For strings specific to individual views, place them in the i18n/views directory using the same structure as app/views.
3. For views that are primarily static AND don't involve a lot of markup, make a locale-specific view, e.g. index.es.html.erb.
4. [I18n fallbacks](https://github.com/svenfuchs/i18n/wiki/Fallbacks) are active, so if, for example, you want to add es-MX.yml files for Mexican Spanish, 
   they will overide the es.yml files when available, but es values will be used when there is no 
   es-MX translation.
