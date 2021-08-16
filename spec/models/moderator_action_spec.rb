require "spec_helper.rb"

describe ModeratorAction do
  it { is_expected.to belong_to(:user).inverse_of :moderator_actions }
  it { is_expected.to belong_to(:resource).inverse_of :moderator_actions }

  it { is_expected.to validate_inclusion_of(:action).in_array ModeratorAction::ACTIONS }
  it { is_expected.to validate_length_of(:reason).is_at_least 10 }
end
