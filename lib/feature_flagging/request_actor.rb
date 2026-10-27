# frozen_string_literal: true

module FeatureFlagging
  # Everything a request is known by. Flipper sees one id per key (see bucketed_by) so logging in
  # can't move a percentage result, but group blocks see the whole request on every key.
  class RequestActor
    attr_reader :user, :installation_id, :bucket_by

    # user: the signed-in User, or nil when logged out
    # installation_id: the app's validated X-Installation-ID as sent, or nil
    # bucket_by: :user or :installation once bucketed_by picks one
    def initialize( user, installation_id, bucket_by = nil )
      @user = user
      @installation_id = installation_id
      @bucket_by = bucket_by
    end

    # This request as the actor for one key, or nil when it lacks that key's identity:
    # an actor without an id would put every such request in the same percentage bucket.
    def bucketed_by( identity )
      return nil if id_for( identity ).nil?

      self.class.new( user, installation_id, identity )
    end

    # The id Flipper's actor and percentage gates check; nil until bucketed_by.
    def flipper_id
      id_for( bucket_by )
    end

    # Every id an actor gate could name for this request.
    def flipper_ids
      [id_for( :user ), id_for( :installation )].compact
    end

    # Group blocks are duck-typed against User, so answer for the signed-in user.
    def is_admin?
      user.respond_to?( :is_admin? ) && user.is_admin?
    end

    private

    # Pinned formats: they feed variant hashes and stored actor gates.
    def id_for( identity )
      case identity
      when :user then user&.flipper_id
      when :installation then installation_id && "Installation;#{installation_id}"
      end
    end
  end
end
