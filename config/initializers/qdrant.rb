# frozen_string_literal: true

# load our own Qdrant logic
require "qdrant"
require "qdrant_model"

qdrant_config = {
  url: CONFIG.qdrant.url,
  api_key: CONFIG.qdrant.api_key,
  raise_error: true,
  logger: Rails.logger
}

ActsAsQdrantModel.client = Qdrant::Client.new( **qdrant_config )

ActiveRecord::Base.include( ActsAsQdrantModel )
