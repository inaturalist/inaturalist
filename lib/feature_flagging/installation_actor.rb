# frozen_string_literal: true

module FeatureFlagging
  # Buckets install_ flags by the app's X-Installation-ID so logging in keeps the assignment.
  class InstallationActor
    attr_reader :installation_id, :user

    # user: the signed-in User, or nil when logged out
    def initialize( installation_id, user = nil )
      @installation_id = installation_id
      @user = user
    end

    # Pinned format: it feeds variant hashes and stored actor gates.
    def flipper_id
      "Installation;#{installation_id}"
    end

    # Group blocks are duck-typed against User, so answer for the signed-in user.
    def is_admin?
      user.respond_to?( :is_admin? ) && user.is_admin?
    end
  end
end
