class SoundcloudIdentity < ApplicationRecord
  belongs_to :user

  def token
    if sc = user.provider_authorizations.where(:provider_name => 'soundcloud').first
      sc.token
    end
  end
end