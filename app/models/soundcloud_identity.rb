class SoundcloudIdentity < ActiveRecord::Base
	belongs_to :user

	def token
    user.provider_authorizations.where(:provider_name => 'soundcloud').first.token
	end
end