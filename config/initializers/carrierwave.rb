if CONFIG.azure
  CarrierWave.configure do |config|
    config.azure_storage_account_name = CONFIG.azure.account_name
    config.azure_storage_access_key = CONFIG.azure.access_key
    config.azure_container = CONFIG.azure.container
  end
end
