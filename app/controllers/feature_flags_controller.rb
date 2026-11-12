# frozen_string_literal: true

# Unauthenticated so clients can fetch flags before a session exists.
class FeatureFlagsController < ApplicationController
  def index
    # Per-actor payload: private cache only; short max-age lets mobile refresh without a fetch per screen.
    response.headers["Cache-Control"] = "private, max-age=60"
    # Apps send this logged in or out; install_ flags bucket on it.
    installation_id = request.headers["X-Installation-ID"]
    render json: {
      flags: FeatureFlagging.flags_for( current_user, installation_id: installation_id ),
      experiments: FeatureFlagging.experiments_for( current_user, installation_id: installation_id )
    }
  end
end
