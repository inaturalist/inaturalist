require "spec_helper.rb"

describe ProviderAuthorization do
  it { is_expected.to belong_to :user }
  it { is_expected.to validate_presence_of :user_id }
  it { is_expected.to validate_presence_of :provider_uid }
  it { is_expected.to validate_presence_of :provider_name }
end
