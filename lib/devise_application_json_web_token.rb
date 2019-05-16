require "json_web_token"

module Devise
  module Strategies
    class ApplicationJsonWebToken < Base
      ANONYMOUS_USER_ID = -1
      def valid?
        claims
      end

      def authenticate!
        if claims
          anon_user = User.new( id: ANONYMOUS_USER_ID, login: "anonymous" )
          success! anon_user
        else
          fail!
        end
      end

      private

      def claims
        auth_header = request.headers["Authorization"] and
          token = auth_header.split(" ").last and
          ::JsonWebToken.decodeApplication( token )
      rescue
        nil
      end
    end
  end
end
