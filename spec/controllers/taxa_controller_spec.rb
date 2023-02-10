# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

describe TaxaController do
  describe "new" do
    render_views
    it "should work for a curator" do
      sign_in create( :user, :as_curator )
      get :new
      expect( response ).to be_successful
    end
    it "should not work for a non-curator" do
      sign_in create( :user )
      get :new
      expect( response ).to be_redirect
    end
  end
  describe "show" do
    render_views
    let( :taxon ) { Taxon.make! }
    elastic_models( Observation )
    it "should 404 for absurdly large ids" do
      get :show, params: { id: 123_123_123_123_123_123 }
      expect( response ).to be_not_found
    end

    it "renders a self-referential canonical tag" do
      expect( INatAPIService ).to receive( "get_json" ) { {}.to_json }
      get :show, params: { id: taxon.id }
      expect( response.body ).to have_tag(
        "link[rel=canonical][href='#{taxon_url( taxon, host: Site.default.url )}']"
      )
    end

    it "renders a canonical tag from other sites to default site" do
      expect( INatAPIService ).to receive( "get_json" ) { {}.to_json }
      different_site = Site.make!
      get :show, params: { id: taxon.id, inat_site_id: different_site.id }
      expect( response.body ).to have_tag(
        "link[rel=canonical][href='#{taxon_url( taxon, host: Site.default.url )}']"
      )
    end
  end

  describe "merge" do
    it "should redirect on succesfully merging" do
      user = make_curator
      keeper = Taxon.make!( rank: Taxon::SPECIES )
      reject = Taxon.make!( rank: Taxon::SPECIES )
      sign_in user
      post :merge, params: { id: reject.id, taxon_id: keeper.id, commit: "Merge" }
      expect( response ).to be_redirect
    end

    it "should allow curators to merge taxa they created" do
      curator = make_curator
      sign_in curator
      keeper = Taxon.make!( creator: curator, rank: Taxon::SPECIES )
      reject = Taxon.make!( creator: curator, rank: Taxon::SPECIES )
      post :merge, params: { id: reject.id, taxon_id: keeper.id, commit: "Merge" }
      expect( Taxon.find_by_id( reject.id ) ).to be_blank
    end

    it "should not allow curators to merge taxa they didn't create" do
      curator = make_curator
      sign_in curator
      keeper = Taxon.make!( creator: curator, rank: Taxon::SPECIES )
      reject = Taxon.make!
      Observation.make!( taxon: reject )
      post :merge, params: { id: reject.id, taxon_id: keeper.id, commit: "Merge" }
      expect( Taxon.find_by_id( reject.id ) ).not_to be_blank
    end

    it "should allow curators to merge synonyms" do
      curator = make_curator
      sign_in curator
      keeper = Taxon.make!( name: "Foo", rank: Taxon::SPECIES )
      reject = Taxon.make!( name: "Foo", rank: Taxon::SPECIES )
      post :merge, params: { id: reject.id, taxon_id: keeper.id, commit: "Merge" }
      expect( Taxon.find_by_id( reject.id ) ).to be_blank
    end

    it "should not allow curators to merge unsynonymous taxa" do
      curator = make_curator
      sign_in curator
      keeper = Taxon.make!( rank: Taxon::SPECIES )
      reject = Taxon.make!( rank: Taxon::SPECIES )
      Observation.make!( taxon: reject )
      post :merge, params: { id: reject.id, taxon_id: keeper.id, commit: "Merge" }
      expect( Taxon.find_by_id( reject.id ) ).not_to be_blank
    end

    it "should allow curators to merge taxa without observations" do
      curator = make_curator
      sign_in curator
      keeper = Taxon.make!( rank: Taxon::SPECIES )
      reject = Taxon.make!( rank: Taxon::SPECIES )
      post :merge, params: { id: reject.id, taxon_id: keeper.id, commit: "Merge" }
      expect( Taxon.find_by_id( reject.id ) ).to be_blank
    end

    it "should allow admins to merge anything" do
      curator = make_admin
      sign_in curator
      keeper = Taxon.make!( rank: Taxon::SPECIES )
      reject = Taxon.make!( rank: Taxon::SPECIES )
      post :merge, params: { id: reject.id, taxon_id: keeper.id, commit: "Merge" }
      expect( Taxon.find_by_id( reject.id ) ).to be_blank
    end

    describe "routes" do
      let( :taxon ) { Taxon.make! }
      before do
        sign_in make_curator
      end
      it "should accept GET requests" do
        expect( get: "/taxa/#{taxon.to_param}/merge" ).to be_routable
      end
      it "should accept POST requests" do
        expect( post: "/taxa/#{taxon.to_param}/merge" ).to be_routable
      end
    end
  end

  describe "destroy" do
    let( :curator ) { make_curator }
    let( :admin ) { make_admin }
    it "should be possible if user did create the record" do
      sign_in curator
      t = Taxon.make!( creator: curator, rank: Taxon::FAMILY )
      delete :destroy, params: { id: t.id }
      expect( Taxon.find_by_id( t.id ) ).to be_blank
    end

    it "should not be possible if user did not create the record" do
      sign_in curator
      t = Taxon.make!( rank: Taxon::FAMILY )
      delete :destroy, params: { id: t.id }
      expect( Taxon.find_by_id( t.id ) ).not_to be_blank
    end

    it "should always be possible for admins" do
      sign_in admin
      t = Taxon.make!( rank: Taxon::FAMILY )
      delete :destroy, params: { id: t.id }
      expect( Taxon.find_by_id( t.id ) ).to be_blank
    end

    it "should not be possible for taxa inolved in taxon changes" do
      t = Taxon.make!( creator: curator, rank: Taxon::FAMILY )
      make_taxon_swap( input_taxon: t )
      sign_in curator
      delete :destroy, params: { id: t.id }
      expect( Taxon.find_by_id( t.id ) ).not_to be_blank
    end

    it "should not be possible if descendants are associated with taxon changes" do
      fam = Taxon.make!( creator: curator, rank: Taxon::FAMILY )
      gen = Taxon.make!( creator: curator, rank: Taxon::GENUS, parent: fam )
      make_taxon_swap( input_taxon: gen )
      sign_in curator
      delete :destroy, params: { id: fam.id }
      expect( Taxon.find_by_id( fam.id ) ).not_to be_blank
    end
    it "should not be possible if descendants are associated with taxon change taxa" do
      fam = Taxon.make!( creator: curator, rank: Taxon::FAMILY )
      gen = Taxon.make!( creator: curator, rank: Taxon::GENUS, parent: fam )
      make_taxon_split( input_taxon: gen )
      sign_in curator
      delete :destroy, params: { id: fam.id }
      expect( Taxon.find_by_id( fam.id ) ).not_to be_blank
    end
    it "should not be possible if the taxon has children" do
      fam = Taxon.make!( creator: curator, rank: Taxon::FAMILY )
      Taxon.make!( creator: curator, rank: Taxon::GENUS, parent: fam )
      sign_in curator
      delete :destroy, params: { id: fam.id }
      expect( Taxon.find_by_id( fam.id ) ).not_to be_blank
    end
    it "should not be possible if the taxon is used in identifications" do
      t = Taxon.make!( :species, creator: curator )
      Identification.make!( taxon: t )
      sign_in curator
      delete :destroy, params: { id: t.id }
      expect( Taxon.find_by_id( t.id ) ).not_to be_blank
    end
    it "should not be possible if the taxon is used in project observation rules" do
      t = Taxon.make!( :species, creator: curator )
      ProjectObservationRule.make!( operator: "in_taxon?", operand: t )
      sign_in curator
      delete :destroy, params: { id: t.id }
      expect( Taxon.find_by_id( t.id ) ).not_to be_blank
    end
    it "should not be possible if the taxon is used in observation field values" do
      t = Taxon.make!( :species, creator: curator )
      of = ObservationField.make!( datatype: "taxon" )
      ObservationFieldValue.make!( observation_field: of, value: t.id )
      sign_in curator
      delete :destroy, params: { id: t.id }
      expect( Taxon.find_by_id( t.id ) ).not_to be_blank
    end
    it "should not be possible if the taxon is used in controlled term taxa" do
      t = Taxon.make!( :species, creator: curator )
      ControlledTermTaxon.make!( taxon: t )
      sign_in curator
      delete :destroy, params: { id: t.id }
      expect( Taxon.find_by_id( t.id ) ).not_to be_blank
    end
  end

  describe "update" do
    it "should allow curators to supercede locking" do
      user = make_curator
      sign_in user
      locked_parent = Taxon.make!( locked: true, rank: Taxon::ORDER )
      taxon = Taxon.make!( rank: Taxon::FAMILY )
      put :update, params: { id: taxon.id, taxon: { parent_id: locked_parent.id } }
      taxon.reload
      expect( taxon.parent_id ).to eq locked_parent.id
    end

    describe "photos_locked" do
      it "should not be updateable by curators" do
        t = Taxon.make!
        curator = make_curator
        sign_in curator
        expect( t ).not_to be_photos_locked
        put :update, params: { id: t.id, taxon: { photos_locked: true } }
        t.reload
        expect( t ).not_to be_photos_locked
      end
      it "should do be updateable by staff" do
        t = Taxon.make!
        curator = make_admin
        sign_in curator
        expect( t ).not_to be_photos_locked
        put :update, params: { id: t.id, taxon: { photos_locked: true } }
        t.reload
        expect( t ).to be_photos_locked
      end
    end

    describe "with audits" do
      let( :current_user ) { make_curator }
      let( :taxon ) { create :taxon, rank: Taxon::SPECIES }
      before { sign_in( current_user ) }
      it "should create an audit belonging to the current_user" do
        put :update, params: { id: taxon.id, taxon: { rank: "genus" } }
        taxon.reload
        expect( taxon.audits.last.user ).to eq current_user
      end
      it "should create an audit with a user_id that survives user deletion" do
        put :update, params: { id: taxon.id, taxon: { rank: "genus" } }
        taxon.reload
        audit = taxon.audits.last
        expect( taxon.audits.last.user ).to eq current_user
        current_user.destroy
        audit.reload
        expect( audit.user_id ).to be > 0
      end
    end
  end

  describe "autocomplete" do
    elastic_models( Taxon )
    it "should choose exact matches" do
      t = Taxon.make!
      get :autocomplete, format: :json, params: { q: t.name }
      expect( assigns( :taxa ) ).to include t
    end
  end

  describe "search" do
    elastic_models( Taxon )
    render_views
    it "should find a taxon by name" do
      t = Taxon.make!( name: "Predictable species", rank: Taxon::SPECIES )
      get :search, params: { q: t.name }
      expect( response.body ).to be =~ %r{<span class="sciname">.*?#{t.name}.*?</span>}m
    end
    it "should not raise an exception with an invalid per page value" do
      t = Taxon.make!
      get :search, params: { q: t.name, per_page: "foo" }
      expect( response ).to be_successful
    end
  end

  describe "observation_photos" do
    elastic_models( Observation, Taxon )

    let( :o ) { make_research_grade_observation }
    let( :p ) { o.photos.first }
    it "should include photos from observations" do
      get :observation_photos, params: { id: o.taxon_id }
      expect( assigns( :photos ) ).to include p
    end

    it "should return photos of an exact taxon match even if there are lots of text matches" do
      t = o.taxon
      other_obs = []
      10.times { other_obs << make_research_grade_observation( description: t.name ) }
      Delayed::Worker.new.work_off
      expect( Taxon.where( name: t.name ).count ).to eq 1
      expect( o.photos.size ).to eq 1
      get :observation_photos, params: { q: t.name }
      expect( assigns( :photos ).size ).to eq 1
      expect( assigns( :photos ) ).to include p
    end

    it "should return photos from Research Grade obs even if there are multiple synonymous taxa" do
      o.taxon.update( rank: Taxon::SPECIES, parent: Taxon.make!( rank: Taxon::GENUS ) )
      t2 = Taxon.make!( name: o.taxon.name, rank: Taxon::SPECIES, parent: Taxon.make!( rank: Taxon::GENUS ) )
      o2 = make_research_grade_observation( taxon: t2 )
      Delayed::Worker.new.work_off
      expect( Taxon.single_taxon_for_name( o.taxon.name ) ).to be_nil
      get :observation_photos, params: { q: o.taxon.name, quality_grade: Observation::RESEARCH_GRADE }
      expect( assigns( :photos ) ).to include p
      expect( assigns( :photos ) ).to include o2.photos.first
    end
  end

  describe "graft" do
    it "should graft a taxon" do
      genus = Taxon.make!( name: "Bartleby", rank: Taxon::GENUS )
      species = Taxon.make!( name: "Bartleby thescrivener", rank: Taxon::SPECIES )
      expect( species.parent ).to be_blank
      u = make_curator
      sign_in u
      expect( patch: "/taxa/#{species.to_param}/graft.json" ).to be_routable
      patch :graft, format: "json", params: { id: species.id }
      expect( response ).to be_successful
      species.reload
      expect( species.parent ).to eq genus
    end
  end

  describe "set_photos" do
    elastic_models( Observation, Taxon )
    it "should reindex the taxon new photos even if there are existing photos" do
      sign_in User.make!
      taxon = Taxon.make!
      existing_tp = TaxonPhoto.make!( taxon: taxon )
      photo = LocalPhoto.make!
      es_taxon = Taxon.elastic_search( where: { id: taxon.id } ).results.results[0]
      expect( es_taxon.default_photo.id ).to eq existing_tp.photo.id
      post :set_photos, format: :json, params: { id: taxon.id, photos: [
        { id: photo.id, type: "LocalPhoto", native_photo_id: photo.id },
        { id: existing_tp.photo.id, type: "LocalPhoto", native_photo_id: existing_tp.photo.id }
      ] }
      expect( response ).to be_ok
      es_taxon = Taxon.elastic_search( where: { id: taxon.id } ).results.results[0]
      expect( es_taxon.default_photo.id ).to eq photo.id
    end
    it "should not change anything if photos_locked and user is not an admin" do
      taxon = Taxon.make!( photos_locked: true )
      sign_in make_curator
      photo = LocalPhoto.make!
      es_taxon = Taxon.elastic_search( where: { id: taxon.id } ).results.results[0]
      expect( es_taxon.default_photo ).to be_blank
      post :set_photos, format: :json, params: { id: taxon.id, photos: [
        { id: photo.id, type: "LocalPhoto", native_photo_id: photo.id }
      ] }
      expect( response ).not_to be_ok
      es_taxon = Taxon.elastic_search( where: { id: taxon.id } ).results.results[0]
      expect( es_taxon.default_photo ).to be_blank
    end
    it "should change photos if photos_locked and user is an admin" do
      taxon = Taxon.make!( photos_locked: true )
      sign_in make_admin
      photo = LocalPhoto.make!
      es_taxon = Taxon.elastic_search( where: { id: taxon.id } ).results.results[0]
      expect( es_taxon.default_photo ).to be_blank
      post :set_photos, format: :json, params: { id: taxon.id, photos: [
        { id: photo.id, type: "LocalPhoto", native_photo_id: photo.id }
      ] }
      expect( response ).to be_ok
      es_taxon = Taxon.elastic_search( where: { id: taxon.id } ).results.results[0]
      expect( es_taxon.default_photo.id ).to eq photo.id
    end
  end
end
