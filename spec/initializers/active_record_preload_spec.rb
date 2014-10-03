require File.expand_path("../../spec_helper", __FILE__)

describe 'ActiveRecord::Base' do

  it "should have a preload_associations method" do
    Observation.respond_to?(:preload_associations).should be_true
  end

  it "perform preloading" do
    o = Observation.make!
    o.association(:taxon).loaded?.should be_false
    Observation.preload_associations(o, :taxon)
    o.association(:taxon).loaded?.should be_true
  end

end
