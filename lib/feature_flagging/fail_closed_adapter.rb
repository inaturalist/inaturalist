# frozen_string_literal: true

module FeatureFlagging
  # Reads fail-closed; preload runs before controller rescue. Writes re-raise so admins see failures.
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
