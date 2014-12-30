require File.dirname(__FILE__) + '/../spec_helper'

describe IdentificationsController, "agree" do
  it "should not result in two current identifications" do
    i1 = Identification.make!
    o = i1.observation
    u = User.make!
    sign_in u
    post :agree, :observation_id => o.id, :taxon_id => i1.taxon_id
    post :agree, :observation_id => o.id, :taxon_id => i1.taxon_id
    o.identifications.by(u).current.size.should eq 1
  end

  it "should not raise an error when you agree with yourself" do
    i1 = Identification.make!
    i2 = Identification.make!(:observation => i1.observation)
    o = i1.observation
    sign_in i1.user
    lambda {
      post :agree, :observation_id => o.id, :taxon_id => i1.taxon_id
    }.should_not raise_error
  end

  it "should not raise an error if the observation does not exist" do
    o = Observation.make!
    u = User.make!
    t = Taxon.make!
    sign_in u
    lambda {
      post :agree, :observation_id => o.id+1, :taxon_id => t.id
    }.should_not raise_error
  end
end

describe IdentificationsController, "destroy" do
  it "should work" do
    i = Identification.make!
    sign_in i.user
    delete :destroy, :id => i.id
    Identification.find_by_id(i.id).should be_blank
  end
end
