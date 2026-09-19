# frozen_string_literal: true

module Admin
  # Read-only view of every flag as the current admin sees it; edits happen in Flipper::UI.
  class FeatureFlagsController < ApplicationController
    before_action :authenticate_user!
    before_action :admin_required

    layout "admin"

    def index
      @feature_keys = FeatureFlagging.feature_keys
    end
  end
end
