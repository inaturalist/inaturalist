if CONFIG.rakismet
  Inaturalist::Application.config.rakismet.key = CONFIG.rakismet.key
  Inaturalist::Application.config.rakismet.url = CONFIG.rakismet.site_url
else
  Rakismet.disabled = true
end
