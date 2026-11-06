# frozen_string_literal: true

module Admin
  # Read-only view of every flag as the current admin sees it; edits happen in Flipper::UI.
  class FeatureFlagsController < ApplicationController
    before_action :authenticate_user!
    before_action :admin_required

    layout "admin"

    def index
      @feature_keys = FeatureFlagging.feature_keys
      # Previews what a logged-out app with this X-Installation-ID would get.
      @installation_id = params[:installation_id].to_s.strip.presence
      @installation_id_valid = FeatureFlagging.valid_installation_id?( @installation_id )
    end
  end
end
