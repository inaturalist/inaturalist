require File.dirname(__FILE__) + '/../spec_helper'

describe IdentificationsController, "agree" do
  it "should not result in two current identifications" do
    i1 = Identification.make!
    o = i1.observation
    u = User.make!
    sign_in u
    post :agree, :observation_id => o.id, :taxon_id => i1.taxon_id
    post :agree, :observation_id => o.id, :taxon_id => i1.taxon_id
    expect(o.identifications.by(u).current.size).to eq 1
  end

  it "should not raise an error when you agree with yourself" do
    i1 = Identification.make!
    i2 = Identification.make!(:observation => i1.observation)
    o = i1.observation
    sign_in i1.user
    expect {
      post :agree, :observation_id => o.id, :taxon_id => i1.taxon_id
    }.not_to raise_error
  end

  it "should not raise an error if the observation does not exist" do
    o = Observation.make!
    u = User.make!
    t = Taxon.make!
    sign_in u
    expect {
      post :agree, :observation_id => o.id+1, :taxon_id => t.id
    }.not_to raise_error
  end
end
