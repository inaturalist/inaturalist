require "json_web_token"

module Devise
  module Strategies
    class JsonWebToken < Base
      def valid?
        !request.headers["Authorization"].nil?
      end

      def authenticate!
        if claims and user = User.find_by_id(claims.fetch("user_id"))
          success! user
        else
          fail!
        end
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
