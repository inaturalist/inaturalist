require "json_web_token"

module Devise
  module Strategies
    class JsonWebToken < Base
      def valid?
        claims
      end

      def authenticate!
        user_id = begin
          claims.fetch("user_id")
        rescue KeyError
          nil
        end
        if claims && user_id && user = User.find_by_id( user_id )
          success! user
        else
          fail!
        end
      end

      # Our mobile apps send the JWT on every request, so there's no need to
      # store the user in the session. Storing also makes Warden renew the
      # session, which inserts a new sessions row on every request.
      def store?
        return false if OauthApplication.skips_session_storage?( claims.to_h["oauth_application_id"] )

        super
      end

      private

      def claims
        auth_header = request.headers["Authorization"] and
          token = auth_header.split(" ").last and
          ::JsonWebToken.decode(token)
      rescue
        nil
      end
    end
  end
end
