# frozen_string_literal: true

module FeatureFlagging
  # Everything a request is known by. Flipper sees one id per key (see bucketed_by) so logging in
  # can't move a percentage result, but group blocks see the whole request on every key.
  class RequestActor
    attr_reader :user, :installation_id, :bucket_by

    def initialize( user, installation_id, bucket_by = nil )
      @user = user
      @installation_id = installation_id
      @bucket_by = bucket_by
    end

    def bucketed_by( identity )
      return nil if id_for( identity ).nil?

      self.class.new( user, installation_id, identity )
    end

    def flipper_id
      id_for( bucket_by )
    end

    # This request as each actor an actor or group gate could name.
    def identities
      [bucketed_by( :user ), bucketed_by( :installation )].compact
    end

    def is_admin?
      user.respond_to?( :is_admin? ) && user.is_admin?
    end

    private

    def id_for( identity )
      case identity
      when :user then user&.flipper_id
      when :installation then installation_id && "Installation;#{installation_id}"
      end
    end
  end
end
