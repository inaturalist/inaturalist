# frozen_string_literal: true

# Resolved feature flags for the caller. This is the endpoint non-web clients
# read, and the Rails half of the GET /v2/feature_flags contract in
# doc/feature_flags_ab_options.md: the Node API proxies here with
# InaturalistAPI.iNatJSWrap, the same way /v2/app_build_info proxies
# /build_info ( WEB-1167 ).
#
# Web pages do not need this. They get the same map inlined into the CONFIG
# payload by ApplicationHelper#feature_flags_json, with no extra request.
#
# Deliberately unauthenticated. Anonymous callers get the map with everything
# off rather than a 401, which is what lets a client fetch flags before it knows
# whether it has a session. A user JWT is resolved by
# Devise::Strategies::JsonWebToken, so a mobile bearer token needs no special
# handling here; see FeatureFlagging.resolve_actor for why the application-level
# token's shared anonymous user is deliberately not treated as an actor.
class FeatureFlagsController < ApplicationController
  def index
    # Per-actor payload, so it must never reach a shared or CDN cache. The short
    # max-age is what keeps a foregrounding mobile app from re-fetching on every
    # navigation while still picking a toggle up within about a minute.
    response.headers["Cache-Control"] = "private, max-age=60"
    render json: {
      flags: FeatureFlagging.flags_for( current_user ),
      experiments: FeatureFlagging.experiments_for( current_user )
    }
  end
end
