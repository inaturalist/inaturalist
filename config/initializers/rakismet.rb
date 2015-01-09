if CONFIG.rakismet_key
  Inaturalist::Application.config.rakismet.key = CONFIG.rakismet_key
  Inaturalist::Application.config.rakismet.url = CONFIG.site_url
else
  Rakismet.disabled = true
end
