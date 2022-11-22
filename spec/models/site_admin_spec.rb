require "spec_helper.rb"

describe SiteAdmin do
  it { is_expected.to belong_to(:site).inverse_of :site_admins }
  # TODO app/models/site_admin.rb:4-5
  xit { is_expected.to belong_to(:user).inverse_of :site_admins }
  xit { is_expected.to belong_to :user }

  it { is_expected.to validate_presence_of :site }
  it { is_expected.to validate_presence_of :user }
  it { is_expected.to validate_uniqueness_of(:user_id).scoped_to :site_id }
end
