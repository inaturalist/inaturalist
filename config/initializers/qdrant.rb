# frozen_string_literal: true

require "qdrant"
# load our own Qdrant logic
require "qdrant_model/acts_as_qdrant_model"

qdrant_config = {
  url: CONFIG.qdrant.url,
  api_key: CONFIG.qdrant.api_key,
  raise_error: true,
  logger: Rails.logger
}

ActsAsQdrantModel.client = Qdrant::Client.new( **qdrant_config )

ActiveRecord::Base.include( ActsAsQdrantModel )
