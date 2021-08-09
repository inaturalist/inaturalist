# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe GuideUser do
  it { is_expected.to belong_to(:guide).inverse_of :guide_users }
  it { is_expected.to belong_to(:user).inverse_of :guide_users }

  it { is_expected.to validate_presence_of :guide }
  it { is_expected.to validate_presence_of :user }
  it { is_expected.to validate_uniqueness_of(:user_id).scoped_to :guide_id }
end
