# frozen_string_literal: true

require "qdrant"
# load our own Qdrant logic
require "qdrant_model/acts_as_qdrant_model"

if CONFIG.qdrant&.url.present?
  qdrant_config = {
    url: CONFIG.qdrant.url,
    api_key: CONFIG.qdrant&.api_key,
    raise_error: true,
    logger: Rails.logger
  }

  ActsAsQdrantModel.client = Qdrant::Client.new( **qdrant_config )

  # override the Faraday logger used by qdrant-ruby to suppress logging request bodies
  conn = ActsAsQdrantModel.client.connection
  conn.builder.delete( Faraday::Response::Logger )
  conn.builder.insert_after(
    Faraday::Request::Json,
    Faraday::Response::Logger,
    Rails.logger,
    headers: false, bodies: false, errors: true
  )
end

ActiveRecord::Base.include( ActsAsQdrantModel )
