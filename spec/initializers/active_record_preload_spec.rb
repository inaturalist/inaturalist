require File.expand_path("../../spec_helper", __FILE__)

describe 'ActiveRecord::Base' do

  it "should have a preload_associations method" do
    expect(Observation.respond_to?(:preload_associations)).to be true
  end

  it "perform preloading" do
    o = Observation.make!
    expect(o.association(:taxon).loaded?).to be false
    Observation.preload_associations(o, :taxon)
    expect(o.association(:taxon).loaded?).to be true
  end

end
