# would've liked to call this simply Authorization, but that model name clashes with restful_authentication
class ProviderAuthorization < ActiveRecord::Base
  belongs_to  :user
  validates_presence_of :user_id, :provider_uid, :provider_name
  validates_uniqueness_of :provider_uid, :scope => :provider_name

  def self.find_from_omniauth(auth_info)
    return self.find_by_provider_name_and_provider_uid(auth_info['provider'], auth_info['uid'])
  end

end
