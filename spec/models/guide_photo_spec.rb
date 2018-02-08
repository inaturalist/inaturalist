# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe GuidePhoto, "creation" do
  before(:all) { enable_elastic_indexing( Observation ) }
  after(:all) { disable_elastic_indexing( Observation ) }
  it "should validate the length of a description" do
    gs = GuidePhoto.make(:description => "foo")
    expect(gs).to be_valid
    gs = GuidePhoto.make(:description => "foo"*256)
    expect(gs).not_to be_valid
    expect(gs.errors[:description]).not_to be_blank
  end
end
