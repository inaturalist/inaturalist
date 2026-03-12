# frozen_string_literal: true

require "spec_helper"

describe "User Index" do
  before do
    allow( CONFIG ).to receive( :content_creation_restriction_days ).and_return( 1 )
  end
  let( :user ) do
    user = User.make!( created_at: 2.days.ago )
    UserPrivilege.make!( privilege: UserPrivilege::ORGANIZER, user: user )
    user
  end
  let( :identification ) do
    Identification.make!( body: "thebody" )
  end
  let( :exemplar_identification ) do
    identification.exemplar_identification
  end

  it "as_indexed_json should return a hash" do
    expect( exemplar_identification.as_indexed_json ).to be_a Hash
  end

  it "includes vote counts" do
    doc = exemplar_identification.as_indexed_json
    expect( doc[:votes] ).to be_empty
    expect( doc[:cached_votes_total] ).to eq 0

    exemplar_identification.vote_up( User.make! )
    exemplar_identification.reload
    doc = exemplar_identification.as_indexed_json
    expect( doc[:votes].length ).to eq 1
    expect( doc[:cached_votes_total] ).to eq 1

    exemplar_identification.vote_down( User.make! )
    exemplar_identification.reload
    doc = exemplar_identification.as_indexed_json
    expect( doc[:votes].length ).to eq 2
    expect( doc[:cached_votes_total] ).to eq 0

    exemplar_identification.vote_down( User.make! )
    exemplar_identification.reload
    doc = exemplar_identification.as_indexed_json
    expect( doc[:votes].length ).to eq 3
    expect( doc[:cached_votes_total] ).to eq( -1 )
  end

  it "includes non-downvoted observation annotations" do
    life_stage_attribute = make_controlled_term_with_label( "Life Stage" )
    larva = make_controlled_value_with_label( "Larva", life_stage_attribute )

    doc = exemplar_identification.as_indexed_json
    expect( doc[:identification] ).not_to be_empty
    expect( doc[:identification][:observation] ).not_to be_empty
    expect( doc[:identification][:observation][:annotations] ).to be_empty

    annotation = Annotation.make!(
      resource: identification.observation,
      controlled_attribute: life_stage_attribute,
      controlled_value: larva
    )
    exemplar_identification.reload
    doc = exemplar_identification.as_indexed_json
    expect( doc[:identification][:observation][:annotations] ).not_to be_empty

    annotation.vote_up( User.make! )
    exemplar_identification.reload
    doc = exemplar_identification.as_indexed_json
    expect( doc[:identification][:observation][:annotations] ).not_to be_empty

    annotation.vote_down( User.make! )
    annotation.vote_down( User.make! )
    exemplar_identification.reload
    doc = exemplar_identification.as_indexed_json
    expect( doc[:identification][:observation][:annotations] ).to be_empty
  end
end
