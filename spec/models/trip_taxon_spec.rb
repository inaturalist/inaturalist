require "spec_helper.rb"

describe TripTaxon do
  it { is_expected.to belong_to :taxon }
  it { is_expected.to belong_to(:trip).inverse_of :trip_taxa }

  it { is_expected.to validate_presence_of :taxon }
  it { is_expected.to validate_uniqueness_of(:taxon_id).scoped_to :trip_id }
end
