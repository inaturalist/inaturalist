if CONFIG.rakismet
  Inaturalist::Application.config.rakismet.key = CONFIG.rakismet.key
  Inaturalist::Application.config.rakismet.url = CONFIG.rakismet.site_url
  Inaturalist::Application.config.rakismet.use_middleware = false
else
  Rakismet.disabled = true
end
