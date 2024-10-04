# frozen_string_literal: true

require "spec_helper"

describe ObservationSound do
  it { is_expected.to belong_to( :observation ).inverse_of( :observation_sounds ).counter_cache false }
  it { is_expected.to belong_to :sound }
  it { is_expected.to validate_presence_of :sound }
  it { is_expected.to validate_presence_of :observation }
  it { is_expected.to validate_uniqueness_of( :sound_id ).scoped_to :observation_id }

  elastic_models( Observation )

  describe "creation" do
    it "should increment the counter cache on observations" do
      o = Observation.make!
      expect do
        without_delay { ObservationSound.make!( observation: o ) }
        o.reload
      end.to change( o, :observation_sounds_count ).by( 1 )
    end
  end

  describe "deletion" do
    it "should decrement the counter cache on observations" do
      o = Observation.make!
      os = ObservationSound.make!( observation: o )
      o.reload
      expect do
        os.destroy
        o.reload
      end.to change( o, :observation_sounds_count ).by( -1 )
    end
  end
end
