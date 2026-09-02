# frozen_string_literal: true

require "spec_helper"

describe "Taxon Index" do
  it "as_indexed_json should return a hash" do
    t = Taxon.make!
    json = t.as_indexed_json
    expect( json ).to be_a Hash
  end

  it "does not include flagged taxon photos" do
    taxon = Taxon.make!
    taxon_photo = TaxonPhoto.make!( taxon: taxon )
    taxon.reload
    expect( taxon.as_indexed_json[:default_photo][:id] ).to eq taxon_photo.photo.id
    expect( taxon.as_indexed_json[:taxon_photos].first[:photo][:id] ).to eq taxon_photo.photo.id

    # skip callback that would delete the TaxonPhoto after flagging,
    # simulating taxon photos flagged before that callback was created
    allow( taxon_photo.photo ).to receive( :flagged_with ).and_return( true )
    Flag.make!( flaggable: taxon_photo.photo )
    taxon.reload
    expect( taxon.taxon_photos ).not_to be_empty
    expect( taxon.as_indexed_json[:default_photo] ).to be_nil
    expect( taxon.as_indexed_json[:taxon_photos] ).to be_empty
  end

  it "includes photo attribution names" do
    taxon = Taxon.make!
    user = User.make!( name: "photographer" )
    photo = LocalPhoto.make!( user: user )
    TaxonPhoto.make!( taxon: taxon, photo: photo )
    taxon.reload
    expect( taxon.as_indexed_json[:default_photo][:id] ).to eq photo.id
    expect( taxon.as_indexed_json[:default_photo][:attribution_name] ).to eq user.name

    expect( taxon.as_indexed_json[:taxon_photos].first[:photo][:id] ).to eq photo.id
    expect( taxon.as_indexed_json[:taxon_photos].first[:photo][:attribution_name] ).to eq user.name
  end

  it "allows photo attribution names to be nil" do
    taxon = Taxon.make!
    photo = FlickrPhoto.make!(
      user: nil,
      native_realname: nil,
      native_username: nil,
      license: Photo::CC0
    )
    TaxonPhoto.make!( taxon: taxon, photo: photo )
    taxon.reload
    expect( taxon.as_indexed_json[:default_photo][:id] ).to eq photo.id
    expect( taxon.as_indexed_json[:default_photo][:attribution_name] ).to be_nil

    expect( taxon.as_indexed_json[:taxon_photos].first[:photo][:id] ).to eq photo.id
    expect( taxon.as_indexed_json[:taxon_photos].first[:photo][:attribution_name] ).to be_nil
  end

  describe "prepare_batch_for_index" do
    it "caches project_ids" do
      t = Taxon.make!
      lt = ListedTaxon.make!( taxon: t, list: CheckList.make!, place: make_place_with_geom )
      expect( t.indexed_place_ids ).to eq nil
      Taxon.prepare_batch_for_index( [t] )
      expect( t.indexed_place_ids ).to eq [lt.place_id]
    end

    it "sets project_ids to an empty array by default" do
      t = Taxon.make!
      expect( t.indexed_place_ids ).to eq nil
      Taxon.prepare_batch_for_index( [t] )
      expect( t.indexed_place_ids ).to eq []
    end
  end

  describe "embeddings_for_taxon_photos" do
    let( :taxon_photo ) { TaxonPhoto.make! }
    let( :response_object ) { { "success" => true } }

    it "uses SSL when connecting to HTTPS endpoints" do
      expect( CONFIG ).to receive( :vision_api_url ).and_return( "https://vision.api" )
      stub_request( :post, "https://vision.api/embeddings_for_photos" ).to_return(
        status: 200,
        body: response_object.to_json,
        headers: { "Content-Type" => "application/json" }
      )
      expect_any_instance_of( Net::HTTP ).to receive( "use_ssl=" ).
        at_least( :once ).and_call_original
      expect( TaxonPhoto.embeddings_for_taxon_photos( [taxon_photo], enable_in_test_env: true ) ).
        to eq response_object
    end

    it "does not use SSL when connecting to HTTP endpoints" do
      expect( CONFIG ).to receive( :vision_api_url ).and_return( "http://vision.api" )
      stub_request( :post, "http://vision.api/embeddings_for_photos" ).to_return(
        status: 200,
        body: response_object.to_json,
        headers: { "Content-Type" => "application/json" }
      )
      expect_any_instance_of( Net::HTTP ).not_to receive( "use_ssl=" )
      expect( TaxonPhoto.embeddings_for_taxon_photos( [taxon_photo], enable_in_test_env: true ) ).
        to eq response_object
    end
  end
end
