# configure the Rails gem
Elasticsearch::Model.client = Elasticsearch::Client.new(
  host: CONFIG.elasticsearch_host,
  transport_options: { request: { timeout: 5 } }
)
# load our own Elasticsearch logic
require 'elastic_model'
