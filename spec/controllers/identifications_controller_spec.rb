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
end
