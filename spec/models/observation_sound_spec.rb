# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ObservationSound do
  elastic_models( Observation )

  describe "creation" do
    it "should increment the counter cache on observations" do
      o = Observation.make!
      expect {
        without_delay { ObservationSound.make!(:observation => o) }
        o.reload
      }.to change(o, :observation_sounds_count).by(1)
    end
  end

  describe "deletion" do
    it "should decrement the counter cache on observations" do
      o = Observation.make!
      os = ObservationSound.make!(:observation => o)
      o.reload
      expect {
        os.destroy
        o.reload
      }.to change(o, :observation_sounds_count).by(-1)
    end
  end
end
