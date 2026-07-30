# frozen_string_literal: true

require "digest"

# Thin wrapper over the flipper gem. Every feature-flag read in app code goes
# through here rather than calling Flipper directly, so the engine underneath
# can be replaced without touching call sites. See WEB-1074 and
# doc/feature_flags_ab_options.md.
#
# Reads are fail-closed on purpose: if the flipper tables are missing or a DB
# read fails, every flag reports off rather than raising. That is what keeps
# pages rendering in the window between a deploy and its migration.
#
#   FeatureFlagging.enabled?( :some_flag, current_user )
#   FeatureFlagging.flags_for( current_user )       # => { some_flag: false }
#   FeatureFlagging.variant( :some_experiment, current_user )  # => "treatment"
#
# Flags are managed by admins at /admin/feature_flags. Nothing here reads
# targeting rules from the client, and only CLIENT_FLAGS are sent to browsers.
module FeatureFlagging
  # Every flag the app is allowed to read, with a one-line description of what
  # it gates. Listing a key here does not enable it anywhere. Reading a key that
  # is not listed raises, so typos and flags deleted from the admin UI surface
  # immediately instead of silently evaluating false forever.
  KNOWN_FLAGS = {
    flipper_smoke_test: "WEB-1074 pilot flag. Gates nothing; proves the flag pipeline end to end.",
    exp_hello_world: "WEB-1074 pilot experiment. Gates eligibility for the hello_world variant split."
  }.freeze

  # The subset of KNOWN_FLAGS whose resolved values are sent to clients, in the
  # inline JS payload today and via GET /v2/feature_flags later. Server-only
  # flags stay out of this list so unannounced feature names do not appear in
  # page source.
  CLIENT_FLAGS = [
    :flipper_smoke_test
  ].freeze

  # A/B experiments, as experiment key => ordered list of variant names. Each
  # experiment needs a matching `exp_<name>` flag in KNOWN_FLAGS, which controls
  # who is eligible; the variant split then applies only to eligible actors.
  # Assignment is a deterministic hash, so a variant can be re-derived for any
  # actor after the fact and no assignment table is needed.
  KNOWN_EXPERIMENTS = {
    hello_world: %w(control treatment)
  }.freeze

  class UnknownFlagError < StandardError; end
  class UnknownExperimentError < StandardError; end

  class << self
    # actor: a User, nil, or anything else responding to #flipper_id
    def enabled?( key, actor = nil )
      key = key.to_sym
      raise UnknownFlagError, "unknown feature flag: #{key}" unless KNOWN_FLAGS.key?( key )

      evaluate( key, resolve_actor( actor ) )
    end

    # Resolved flag map for the inline JS payload and, later, for
    # GET /v2/feature_flags. Values are always booleans.
    def flags_for( actor = nil )
      resolved = resolve_actor( actor )
      CLIENT_FLAGS.index_with {| key | evaluate( key, resolved ) }
    end

    # The variant this actor is assigned in an experiment, or nil if they are
    # not eligible. Hashing the experiment name in with the actor id means
    # assignment is independent between experiments -- unlike
    # Announcement::TARGET_GROUPS, where the same users land in the same
    # bucket in every test.
    #
    # MD5 rather than the CRC32 flipper uses internally, and not for security.
    # CRC32 is linear, so two keys differing only by a fixed substring produce
    # outputs differing by a constant XOR. Taking that modulo a small variant
    # count exposes the low bits directly, which made two 2-variant experiments
    # perfectly anti-correlated: every actor in "control" for one was in
    # "treatment" for the other. ( Flipper's own percentage gate is not affected
    # in practice -- its threshold test is modulo 100_000, which masks the
    # structure; measured cross-flag overlap is within ~10% of independent. )
    def variant( experiment, actor = nil )
      experiment = experiment.to_sym
      variants = KNOWN_EXPERIMENTS[experiment]
      raise UnknownExperimentError, "unknown experiment: #{experiment}" if variants.blank?

      resolved = resolve_actor( actor )
      return nil if resolved.nil?
      return nil unless evaluate( experiment_flag( experiment ), resolved )

      variants[bucket( "#{experiment}:#{resolved.flipper_id}" ) % variants.size]
    end

    # Resolved variant map, the documented extension of the flag payload.
    def experiments_for( actor = nil )
      KNOWN_EXPERIMENTS.keys.index_with {| experiment | variant( experiment, actor ) }
    end

    # The flag that gates eligibility for an experiment.
    def experiment_flag( experiment )
      :"exp_#{experiment}"
    end

    private

    # Deterministic 32-bit bucket for a key. Stable across processes, releases,
    # and Ruby versions, so a variant can be re-derived later for analysis.
    def bucket( key )
      Digest::MD5.hexdigest( key )[0, 8].to_i( 16 )
    end

    def evaluate( key, resolved_actor )
      if resolved_actor
        Flipper.enabled?( key, resolved_actor )
      else
        Flipper.enabled?( key )
      end
    rescue StandardError => e
      Rails.logger.error "[FeatureFlagging] #{key} evaluation failed, treating as off: #{e.message}"
      false
    end

    # With no actor, actor and percentage-of-actors gates evaluate false and
    # only a boolean ( fully enabled ) gate applies, so anonymous visitors see
    # flags off. Giving logged-out traffic a stable actor is a follow-up.
    def resolve_actor( actor )
      return nil if actor.blank?
      return actor if actor.respond_to?( :flipper_id )

      raise ArgumentError, "feature flag actor must respond to #flipper_id, got #{actor.class}"
    end
  end
end
