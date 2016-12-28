# configure the Rails gem
es_config = { transport_options: { request: { timeout: 60 } } }
if CONFIG.elasticsearch_hosts
  es_config[:hosts] = CONFIG.elasticsearch_hosts
  es_config[:retry_on_failure] = true
else
  es_config[:host] = CONFIG.elasticsearch_host
end
Elasticsearch::Model.client = Elasticsearch::Client.new(es_config)
# load our own Elasticsearch logic
require 'elastic_model'
