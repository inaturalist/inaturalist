# frozen_string_literal: true

module FeatureFlagging
  # Outermost layer of the storage stack built by FeatureFlagging.build_adapter.
  #
  # A read that raises ( flipper tables not migrated yet, Postgres down, the
  # cache layer misbehaving ) logs and returns the empty result flipper treats
  # as "no gates", so every flag reports off. That is the same contract as
  # FeatureFlagging.evaluate, extended to the one read that rescue cannot
  # reach: the preload Flipper::Middleware::Memoizer runs before any controller
  # code. Without this a missing table would 500 every page.
  #
  # Writes are deliberately not rescued. An admin toggling a flag while storage
  # is broken should see the error, not a success page for a change that never
  # happened ( flipper's own Failsafe adapter rescues everything, silently ).
  class FailClosedAdapter < Flipper::Adapters::Wrapper
    READ_DEFAULTS = {
      features: -> { Set.new },
      get: -> { {} },
      get_multi: -> { {} },
      get_all: -> { {} }
    }.freeze

    def wrap( method, *_args, **_kwargs )
      yield
    rescue StandardError => e
      raise unless READ_DEFAULTS.key?( method )

      Rails.logger.error "[FeatureFlagging] adapter #{method} failed, treating all flags as off: " \
        "#{e.class}: #{e.message}"
      READ_DEFAULTS[method].call
    end
  end
end
