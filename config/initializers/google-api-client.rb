# After upgrading to Ruby 2.6.0, google-api-client (v0.8.6) complained
# about newlines in user-agents it sent with requests. This is meant
# to remove these newlines.
# An attempt was made to upgrade google-api-client (on v0.28.0 at the time
# of writing), but I was having issues with authentication.

Google::APIClient::ENV::OS_VERSION.gsub!( "\n", "" )
