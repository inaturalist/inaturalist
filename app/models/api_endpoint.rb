class ApiEndpoint < ApplicationRecord

  has_many :api_endpoint_caches

  def to_s
    "<ApiEndpoint #{id} #{base_url}>"
  end

end
