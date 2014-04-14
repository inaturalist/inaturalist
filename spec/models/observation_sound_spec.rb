# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ObservationSound, "creation" do
  it "should increment the counter cache on observations" do
    o = Observation.make!
    lambda {
      without_delay { ObservationSound.make!(:observation => o) }
      o.reload
    }.should change(o, :observation_sounds_count).by(1)
  end
end

describe ObservationSound, "deletion" do
  it "should decrement the counter cache on observations" do
    o = Observation.make!
    os = ObservationSound.make!(:observation => o)
    o.reload
    lambda {
      os.destroy
      o.reload
    }.should change(o, :observation_sounds_count).by(-1)
  end
end
