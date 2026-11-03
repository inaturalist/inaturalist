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

      # A website call forwarded by the Node API: a user JWT without an
      # oauth_application_id, and no session cookie (the Node API doesn't
      # forward the browser's cookies)
      def self.node_api_website_request?( request )
        return false unless request.headers["X-Via"] == "node-api"
        return false if request.session.exists?

        jwt_claims = claims_from( request )
        jwt_claims.present? && jwt_claims["user_id"].present? && jwt_claims["oauth_application_id"].blank?
      end

      # The Node API sends the JWT on every call it forwards, so there's no
      # need to store the user in the session. Storing also makes Warden renew
      # the session, which inserts a new sessions row on every call.
      def store?
        return false if self.class.node_api_website_request?( request )

        super
      end

      private

      def claims
        self.class.claims_from( request )
      end

      def self.claims_from( request )
        auth_header = request.headers["Authorization"] and
          token = auth_header.split(" ").last and
          ::JsonWebToken.decode(token)
      rescue
        nil
      end
    end
  end
end
