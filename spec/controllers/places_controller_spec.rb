require File.dirname(__FILE__) + '/../spec_helper'

describe PlacesController do
  let(:user) { UserPrivilege.make!( privilege: UserPrivilege::ORGANIZER ).user }
  describe "create" do
    it "should make a place with no default type" do
      sign_in user
      expect {
        post(:create, params: {
          place: {
            name: "Pine Island Ridge Natural Area"
          },
          file: test_place_kml
        })
      }.to change(Place, :count).by(1)
      expect( Place.last.place_type ).to be_blank
    end

    it "creates places with kml" do
      sign_in user
      post :create, params: { place: {
        name: "Test kml",
        latitude: 30,
        longitude: 30
      }, file: test_place_kml }
      p = Place.last
      expect( p.name ).to eq "Test kml"
      expect( p.place_geometry ).to_not be_nil
    end

    it "fails with invalid kml" do
      sign_in user
      expect {
        post :create, params: {
          place: {
            name: "Test kml",
            latitude: 30,
            longitude: 30
          },
          file: test_place_kml(:invalid)
        }
      }.not_to change( Place, :count )
    end

    it "does not allow non admins to create huge places" do
      sign_in user
      place_count = Place.count
      post :create, params: { place: {
        name: "Test non-admin kml",
        latitude: 30,
        longitude: 30
      }, file: test_place_kml(:huge) }
      expect( response ).not_to be_redirect
      expect( Place.count ).to eq place_count
    end

    it "allows admins to create huge places" do
      user = make_admin
      sign_in user
      post :create, params: { place: {
        name: "Test admin kml",
        latitude: 30,
        longitude: 30
      }, file: test_place_kml(:huge) }
      p = Place.last
      expect( p.name ).to eq "Test admin kml"
      expect( p.place_geometry ).to_not be_nil
    end

    it "limits place create to a daily quota" do
      sign_in user
      PlacesController::QUOTA.times do
        expect {
          post :create, params: { place: {
            name: Faker::Name.name,
            latitude: 0.5,
            longitude: 0.5
          }, file: test_place_kml }
        }.to change( Place, :count ).by( 1 )
      end
      expect {
        post :create, params: { place: {
          name: Faker::Name.name,
          latitude: 0.5,
          longitude: 0.5
        }, file: test_place_kml }
      }.to change( Place, :count ).by( 0 )
    end
  end

  describe "show" do
    render_views
    let(:place) { make_place_with_geom( user: user ) }
    it "renders a self-referential canonical tag" do
      get :show, params: { id: place.id }
      expect( response.body ).to have_tag(
        "link[rel=canonical][href='#{place_url( place, host: Site.default.url )}']" )
    end

    it "renders a canonical tag from other sites to default site" do
      different_site = Site.make!
      get :show, params: { id: place.id, inat_site_id: different_site.id }
      expect( response.body ).to have_tag(
        "link[rel=canonical][href='#{place_url( place, host: Site.default.url )}']" )
    end
  end

  describe "update" do
    it "updates places with kml" do
      p = make_place_with_geom(user: user)
      sign_in user
      put :update, params: { id: p.id, place: {
        name: "Test kml",
        latitude: 30,
        longitude: 30
      }, file: test_place_kml }
      p = Place.last
      expect( p.name ).to eq "Test kml"
      expect( p.place_geometry ).to_not be_nil
    end

    it "does not allow non-admins to update places to make them huge" do
      p = make_place_with_geom(user: user)
      sign_in user
      put :update, params: { id: p.id, place: {
        name: "Test non-admin kml",
        latitude: 30,
        longitude: 30
      }, file: test_place_kml(:huge) }
      expect( response ).not_to be_redirect
    end

    it "does not allow non-admins to update places that are already huge" do
      p = make_place_with_geom( user: user, wkt: "MULTIPOLYGON(((0 0,0 10,10 10,10 0,0 0)))" )
      sign_in user
      put :update, params: { id: p.id, place: {
        name: "Test non-admin kml",
        latitude: 30,
        longitude: 30
      }, file: test_place_kml }
      expect( response ).not_to be_redirect
    end

    it "allows admins to create huge places" do
      user = make_admin
      p = make_place_with_geom(user: user)
      sign_in user
      put :update, params: { id: p.id, place: {
        name: "Test admin kml",
        latitude: 30,
        longitude: 30
      }, file: test_place_kml(:huge) }
      p = Place.last
      expect( p.name ).to eq "Test admin kml"
      expect( p.place_geometry ).to_not be_nil
    end

    it "should allow users without the organizaer privilege to update places they created" do
      p = make_place_with_geom( user: user )
      user.user_privileges.destroy_all
      sign_in user
      put :update, params: { id: p.id, place: { name: "the new name" } }
      p.reload
      expect( p.name ).to eq "the new name"
    end
    it "does not allow removal of the geometry with old remove_geom" do
      p = make_place_with_geom( user: user )
      put :update, params: { id: p.id,
        place: {
          name: "something else"
        },
        remove_geom: true
      }
      expect( response ).to be_redirect
      p.reload
      expect( p.place_geometry ).not_to be_blank
    end
  end

  describe "destroy" do
    let(:place) { make_place_with_geom( user: user ) }
    before do
      sign_in user
    end
    it "should delete the place" do
      expect(place).not_to be_blank
      expect {
        delete :destroy, params: { id: place.id }
      }.to change(Place, :count).by(-1)
    end
    it "should fail if projects are using the place" do
      p = Project.make!(place: place)
      delete :destroy, params: { id: place.id }
      expect( Place.find_by_id(place.id) ).not_to be_blank
    end
    it "should fail if projects are using the place in rules" do
      p = Project.make!
      p.project_observation_rules.create(operand: place, operator: 'observed_in_place?')
      delete :destroy, params: { id: place.id }
      expect( Place.find_by_id(place.id) ).not_to be_blank
    end
  end

  describe "search" do
    let(:place) { make_place_with_geom(name: 'Panama') }
    let(:another_place) { make_place_with_geom(name: 'Norway') }
    it "should return results in HTML" do
      expect( place ).not_to be_blank
      response_json = <<-JSON
        {
          "results": [
            {
              "record": {
                "id": #{place.id}
              }
            }
          ]
        }
      JSON
      stub_request(:get, /#{INatAPIService::ENDPOINT}/).to_return(
        status: 200,
        body: response_json,
        headers: { "Content-Type" => "application/json" }
      )
      get :search, params: { q: place.name }
      expect( response.content_type ).to include "text/html"
    end
  end

  describe "merge" do
    let(:keeper) { make_place_with_geom(place_type: Place::STATE) }
    let(:reject) { make_place_with_geom(place_type: Place::COUNTRY) }
    before do
      sign_in make_curator
    end
    it "should delete the reject" do
      reject_id = reject.id
      post :merge, params: { id: reject.slug, with: keeper.id }
      log_timer do
        expect(Place.find_by_id(reject_id)).to be_blank
      end
    end
    it "should allow you to keep the reject name" do
      reject_name = reject.name
      post :merge, params: { id: reject.slug, with: keeper.id, keep_name: 'left' }
      keeper.reload
      expect(keeper.name).to eq reject_name
    end
    it "should allow you to keep the reject place type" do
      reject_place_type = reject.place_type
      post :merge, params: { id: reject.slug, with: keeper.id, keep_place_type_name: 'left' }
      keeper.reload
      expect(keeper.place_type).to eq reject_place_type
    end
    it "should be impossible if the keeper is a standard place" do
      keeper.update( admin_level: Place::STATE_LEVEL )
      post :merge, params: { id: reject.slug, with: keeper.id }
      expect( Place.find_by_id( keeper.id ) ).not_to be_blank
      expect( Place.find_by_id( reject.id ) ).not_to be_blank
    end
    it "should be impossible if the reject is a standard place" do
      reject.update( admin_level: Place::STATE_LEVEL )
      post :merge, params: { id: reject.slug, with: keeper.id }
      expect( Place.find_by_id( keeper.id ) ).not_to be_blank
      expect( Place.find_by_id( reject.id ) ).not_to be_blank
    end
    it "should be possible if the keeper is a standard place and the user is on staff" do
      sign_in make_admin
      keeper.update( admin_level: Place::STATE_LEVEL )
      post :merge, params: { id: reject.slug, with: keeper.id }
      expect( Place.find_by_id( keeper.id ) ).not_to be_blank
      expect( Place.find_by_id( reject.id ) ).to be_blank
    end
  end
end

describe PlacesController, "geometry" do
  before do
    @place = make_place_with_geom(user: @user)
    @place_without_geom = make_place_with_geom
    @place_without_geom.place_geometry.destroy
  end

  it "should return geojson when places have a geometry" do
    get :geometry, format: :geojson, params: { id: @place.id }
    expect( response.body ).to include "MultiPolygon"
  end

  it "should not fail when places have no geometry" do
    expect {
      get :geometry, format: :geojson, params: { id: @place_without_geom.id }
    }.to_not raise_error
    expect( response.body ).to eq("{}")
  end
end

def test_place_kml(size = :default)
  coords = if size == :default
    [[0,0], [0,1], [1,1], [1,0], [0,0]]
  elsif size == :huge
    [[0,0], [0,60], [60,60], [60,0], [0,0]]
  elsif size == :invalid
    [[0,0], [0,1]]
  end
  path = File.join(Dir::tmpdir, "test-place-kml-#{size}.kml")
  if File.exists?( path )
    Rack::Test::UploadedFile.new( path, "application/vnd.google-earth.kml+xml", false )
  end
  kml = <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://earth.google.com/kml/2.1">
  <Document>
    <Placemark>
      <MultiGeometry>
        <Polygon>
          <outerBoundaryIs>
            <LinearRing>
              <coordinates>#{coords.map{|c| c.join( "," )}.join( " " )}</coordinates>
            </LinearRing>
          </outerBoundaryIs>
        </Polygon>
      </MultiGeometry>
    </Placemark>
  </Document>
</kml>
  XML
  File.open( path, "w" ) do |f|
    f << kml
  end
  Rack::Test::UploadedFile.new( path, "application/vnd.google-earth.kml+xml", false )
end
