require "spec_helper.rb"

describe Password do
  it { is_expected.to belong_to :user }

  it { is_expected.to validate_presence_of(:email).with_message "with this email address doesn't exist" }
  it { is_expected.to validate_presence_of(:user).with_message "with this email address doesn't exist" }
end
