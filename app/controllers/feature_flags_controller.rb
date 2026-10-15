# frozen_string_literal: true

# Unauthenticated so clients can fetch flags before a session exists.
class FeatureFlagsController < ApplicationController
  def index
    # Per-actor payload: private cache only; short max-age lets mobile refresh without a fetch per screen.
    response.headers["Cache-Control"] = "private, max-age=60"
    render json: {
      flags: FeatureFlagging.flags_for( current_user ),
      experiments: FeatureFlagging.experiments_for( current_user )
    }
  end
end
