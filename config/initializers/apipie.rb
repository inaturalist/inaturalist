# TODO Rails 5: Remove apipie, it's only documenting trips, which are in the shed
# Apipie.configure do |config|
#   config.app_name                = "iNaturalist"
#   config.doc_base_url            = "/apipie"
#   config.api_base_url = ""
#   config.validate = false
#   config.api_controllers_matcher = "#{Rails.root}/app/controllers/*.rb"
#   config.copyright = "&copy; #{Time.now.year} iNaturalist, LLC"
#   config.app_info = "
#     The iNat API is a set of REST endpoints that can be used to read data from
#     iNat and write data back on the behalf of users. Data can be retrieved in
#     different formats by appending  <code>.[format]</code> to the endpoint, e.g.
#     <code>/observations.json</code> to retrieve observations as JSON. Read-only endpoints
#     generally do not require authentication, but if you want to access data
#     like unobscured coordinates on behalf of users or write data to iNat, you
#     will need to make authenticated requests (see http://www.inaturalist.org/pages/api+reference#auth).
#   "
# end
