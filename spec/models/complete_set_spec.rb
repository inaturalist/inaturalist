require "spec_helper.rb"

describe CompleteSet do
  it { is_expected.to belong_to :taxon }
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :place }
  it { is_expected.to belong_to :source }
  it { is_expected.to have_many(:comments).dependent :destroy }

  it do
    is_expected.to validate_uniqueness_of(:taxon_id).scoped_to(:place_id)
                                                    .with_message "already has complete set for this place"
  end
  it { is_expected.to validate_presence_of :taxon }
  it { is_expected.to validate_presence_of :place }
end
