# After upgrading to Ruby 2.6.0, google-api-client (v0.8.6) complained
# about newlines in user-agents it sent with requests. This is meant
# to remove these newlines.
# An attempt was made to upgrade google-api-client (on v0.28.0 at the time
# of writing), but I was having issues with authentication.

Google::APIClient::ENV::OS_VERSION.gsub!( "\n", "" )

# Really crude monkey patch b/c I think Google stopped returning responses to
# https://www.googleapis.com/discovery/v1/apis/oauth2/v1/rest with a
# Content-Type of application/json... or something. Regardless the old version
# of google-api-client we're using was not acknowledging that it was JSON and
# was thus bailing, even though the response *was* JSON. ~~kueda 2020-03-24
module Google
  class APIClient
    class Result
      def media_type
        "application/json"
      end
    end
  end
end
