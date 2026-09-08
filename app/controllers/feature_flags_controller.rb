# frozen_string_literal: true

# Unauthenticated endpoint for non-web clients to fetch flags; allows fetching before session is known.
class FeatureFlagsController < ApplicationController
  def index
    # Per-actor payload requires private cache; short max-age lets mobile refresh without reloading every nav.
    response.headers["Cache-Control"] = "private, max-age=60"
    render json: {
      flags: FeatureFlagging.flags_for( current_user ),
      experiments: FeatureFlagging.experiments_for( current_user )
    }
  end
end
