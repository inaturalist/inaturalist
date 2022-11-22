# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

describe IdentificationsController, "agree" do
  it "should not result in two current identifications" do
    i1 = Identification.make!
    o = i1.observation
    u = User.make!
    sign_in u
    post :agree, params: { observation_id: o.id, taxon_id: i1.taxon_id }
    post :agree, params: { observation_id: o.id, taxon_id: i1.taxon_id }
    expect( o.identifications.by( u ).current.size ).to eq 1
  end

  it "should not raise an error when you agree with yourself" do
    i1 = Identification.make!
    Identification.make!( observation: i1.observation )
    o = i1.observation
    sign_in i1.user
    expect do
      post :agree, params: { observation_id: o.id, taxon_id: i1.taxon_id }
    end.not_to raise_error
  end

  it "should not raise an error if the observation does not exist" do
    o = Observation.make!
    u = User.make!
    t = Taxon.make!
    sign_in u
    expect do
      post :agree, params: { observation_id: o.id + 1, taxon_id: t.id }
    end.not_to raise_error
  end
end
