# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

shared_examples_for "an IdentificationsController basics" do
  let( :user ) { User.make! }
  let( :observation ) { Observation.make! }

  describe "create" do
    it "should work" do
      expect( observation.identifications.count ).to eq 0
      t = Taxon.make!
      post :create, format: :json, params: { identification: {
        observation_id: observation.id,
        taxon_id: t.id,
        body: "i must eat them all"
      } }
      expect( response ).to be_successful
      observation.reload
      expect( observation.identifications.count ).to eq 1
    end
  end

  describe "update" do
    let( :identification ) { Identification.make!( user: user ) }
    it "should work" do
      expect do
        put :update, format: :json, params: {
          id: identification.id, identification: { body: "i must eat them all" }
        }
        identification.reload
      end.to change( identification, :body )
    end
  end
end

shared_examples_for "an IdentificationsController" do
  let( :user ) { User.make! }
  let( :observation ) { Observation.make! }

  describe "create" do
    it "should mark the observation as captive if requested" do
      expect( observation ).not_to be_captive_cultivated
      post :create, format: :json, params: { identification: {
        observation_id: observation.id,
        taxon_id: Taxon.make!.id,
        captive_flag: "1"
      } }
      observation.reload
      expect( observation ).to be_captive_cultivated
    end

    it "should not mark the observation as wild if there's an existing contradictory quality metric" do
      QualityMetric.make!( metric: QualityMetric::WILD, observation: observation, user: user, agree: false )
      observation.reload
      expect( observation ).to be_captive_cultivated
      post :create, format: :json, params: { identification: {
        observation_id: observation.id,
        taxon_id: Taxon.make!.id,
        captive_flag: "0"
      } }
      expect( response ).to be_successful
      observation.reload
      expect( observation ).to be_captive_cultivated
    end

    it "should include the observation in the response" do
      t = Taxon.make!
      post :create, format: :json, params: { identification: {
        observation_id: observation.id,
        taxon_id: t.id,
        body: "i must eat them all"
      } }
      expect( response ).to be_successful
      json = JSON.parse( response.body )
      expect( json["observation"]["id"] ).to eq observation.id
    end

    it "should not include observation private coordinates" do
      t = Taxon.make!
      o = make_private_observation
      expect( user ).not_to eq o.user
      post :create, format: :json, params: { identification: {
        observation_id: o.id,
        taxon_id: t.id,
        body: "i must eat them all"
      } }
      expect( response ).to be_successful
      json = JSON.parse( response.body )
      expect( json["observation"]["private_latitude"] ).to be_blank
    end

    it "should include the observation iconic_taxon_name" do
      load_test_taxa
      t = Taxon.make!
      expect( @Pseudacris_regilla.iconic_taxon ).to eq @Amphibia
      o = Observation.make!( taxon: @Pseudacris_regilla )
      expect( o.iconic_taxon_name ).to eq @Amphibia.name
      post :create, format: :json, params: { identification: {
        observation_id: o.id,
        taxon_id: t.id,
        body: "i must eat them all"
      } }
      expect( response ).to be_successful
      json = JSON.parse( response.body )
      expect( json["observation"]["iconic_taxon_name"] ).to eq o.iconic_taxon_name
    end

    it "should set vision attribute" do
      post :create, format: :json, params: { identification: {
        observation_id: observation.id,
        taxon_id: Taxon.make!.id,
        vision: true
      } }
      expect( response ).to be_successful
      json = JSON.parse( response.body )
      expect( json["vision"] ).to be true
      ident = Identification.find( json["id"] )
      expect( ident.vision ).to be true
    end

    it "should assign a taxon by UUID" do
      t = Taxon.make!
      post :create, format: :json, params: { identification: {
        taxon_id: t.uuid,
        observation_id: observation.id
      } }
      expect( response ).to be_successful
      expect( user.identifications.last.taxon ).to eq t
    end

    it "should assign an observation by UUID" do
      t = Taxon.make!
      post :create, format: :json, params: { identification: {
        taxon_id: t.id,
        observation_id: observation.uuid
      } }
      expect( response ).to be_successful
      expect( user.identifications.last.observation ).to eq observation
    end
  end

  describe "update" do
    let( :identification ) { Identification.make!( user: user ) }

    it "should return json" do
      put :update, format: :json, params: {
        id: identification.id, identification: { body: "i must eat them all" }
      }
      json = JSON.parse( response.body )
      expect( json["taxon_id"] ).to eq identification.taxon_id
    end

    it "should work with a UUID" do
      expect do
        put :update, format: :json, params: {
          id: identification.uuid, identification: { body: "i must eat them all" }
        }
        identification.reload
      end.to change( identification, :body )
    end

    it "should mark other identifications as not current if restoring" do
      i2 = Identification.make!( user: user, observation: identification.observation )
      identification.reload
      expect( i2 ).to be_current
      expect( identification ).not_to be_current
      put :update, format: :json, params: {
        id: identification.id, identification: { current: true }
      }
      identification.reload
      i2.reload
      expect( i2 ).not_to be_current
      expect( identification ).to be_current
    end

    describe "with hidden content" do
      let( :hidden_ident ) { ModeratorAction.make!( resource: Identification.make!( user: user ) ).resource }
      it "should allow the identifier to withdraw" do
        expect( hidden_ident ).to be_current
        put :update, format: :json, params: { id: hidden_ident.id, identification: { current: false } }
        hidden_ident.reload
        expect( hidden_ident ).not_to be_current
      end
      it "should allow the identifier to restore" do
        hidden_ident.update( current: false )
        expect( hidden_ident ).not_to be_current
        put :update, format: :json, params: { id: hidden_ident.id, identification: { current: true } }
        hidden_ident.reload
        expect( hidden_ident ).to be_current
      end
      it "should not allow the identifier to change the body" do
        body = "ermgrd its er mirirge"
        hidden_ident.update( body: body )
        expect( hidden_ident.body ).to eq body
        put :update, format: :json, params: {
          id: hidden_ident.id,
          identification: { body: "this is totally less offensive" }
        }
        hidden_ident.reload
        expect( hidden_ident.body ).to eq body
      end
    end
  end

  describe "destroy" do
    elastic_models( Observation, Identification )

    let( :identification ) { Identification.make!( user: user ) }

    it "should not destroy the identification by default" do
      delete :destroy, format: :json, params: { id: identification.id }
      expect( Identification.find_by_id( identification.id ) ).not_to be_blank
    end

    it "should destroy the identification with the delete parameter" do
      delete :destroy, format: :json, params: { id: identification.id, delete: true }
      expect( Identification.find_by_id( identification.id ) ).to be_blank
    end

    it "should not destroy the identification with the delete param if the content was hidden" do
      ModeratorAction.make!( resource: identification )
      identification.reload
      expect( identification ).to be_hidden
      delete :destroy, format: :json, params: { id: identification.id, delete: true }
      expect( Identification.find_by_id( identification.id ) ).not_to be_blank
    end

    it "should mark the identification as not current" do
      expect( identification ).to be_current
      delete :destroy, format: :json, params: { id: identification.id }
      identification.reload
      expect( identification ).not_to be_current
    end

    it "should remove the observation taxon if there are no current identifications" do
      expect( identification.observation.taxon ).to eq identification.taxon
      delete :destroy, format: :json, params: { id: identification.id }
      identification.reload
      expect( identification.observation.taxon ).to be_blank
    end

    it "should not leave multiple current IDs when deleting a middle ID" do
      o = Observation.make!
      i1 = Identification.make!( user: user, observation: o )
      i2 = Identification.make!( user: user, observation: o )
      i3 = Identification.make!( user: user, observation: o )
      delete :destroy, params: { id: i2.id }
      i1.reload
      i3.reload
      expect( i3 ).to be_current
      expect( i1 ).not_to be_current
    end
  end

  describe "by_login" do
    before( :all ) { load_test_taxa }
    elastic_models( Observation, Identification )
    it "should return identifications by the selected user" do
      ident = Identification.make!( user: user )
      get :by_login, format: :json, params: { login: user.login }
      json = JSON.parse( response.body )
      expect( json.detect {| i | i["id"] == ident.id } ).not_to be_blank
    end
    it "should not return identifications not by the selected user" do
      ident = Identification.make!
      get :by_login, format: :json, params: { login: user.login }
      json = JSON.parse( response.body )
      expect( json.detect {| i | i["id"] == ident.id } ).to be_blank
    end
    describe "response should include the" do
      let( :ident ) do
        Identification.make!( user: user, observation: make_research_grade_observation( taxon: @Calypte_anna ) )
      end
      let( :json_ident ) do
        expect( ident ).not_to be_blank
        get :by_login, format: :json, params: { login: user.login }
        json = JSON.parse( response.body )
        json.detect {| i | i["id"] == ident.id }
      end
      it "taxon" do
        expect( json_ident["taxon"]["id"] ).to eq ident.taxon_id
      end
      it "observation" do
        expect( json_ident["observation"]["id"] ).to eq ident.observation_id
      end
      it "observation's taxon" do
        expect( json_ident["observation"]["taxon"]["id"] ).to eq ident.observation.taxon_id
      end
      it "observation photo URL" do
        expect( json_ident["observation"]["photos"][0]["medium_url"] ).to eq ident.observation.photos.first.medium_url
      end
      it "observation iconic_taxon_name" do
        expect( ident.observation.iconic_taxon_name ).not_to be_blank
        expect( json_ident["observation"]["iconic_taxon_name"] ).to eq ident.observation.iconic_taxon_name
      end
    end
    it "should include locale-specific taxon name" do
      ident = Identification.make!( user: user, observation: make_research_grade_observation( taxon: @Calypte_anna ) )
      tn = TaxonName.make!( taxon: ident.taxon, lexicon: TaxonName::LEXICONS[:SPANISH] )
      user.update( locale: "es" )
      get :by_login, format: :json, params: { login: user.login }
      json = JSON.parse( response.body )
      json_ident = json.detect {| i | i["id"] == ident.id }
      expect( json_ident["taxon"]["default_name"]["name"] ).to eq tn.name
    end
    it "should include place-specific taxon name" do
      ident = Identification.make!( user: user, observation: make_research_grade_observation( taxon: @Calypte_anna ) )
      place = make_place_with_geom
      tn = TaxonName.make!( taxon: ident.taxon, lexicon: TaxonName::LEXICONS[:ENGLISH] )
      PlaceTaxonName.make!( taxon_name: tn, place: place )
      user.update( place: place, locale: "en" )
      get :by_login, format: :json, params: { login: user.login }
      json = JSON.parse( response.body )
      json_ident = json.detect {| i | i["id"] == ident.id }
      expect( json_ident["taxon"]["default_name"]["name"] ).to eq tn.name
    end
    it "should include locale-specific observation taxon name" do
      ident = Identification.make!( user: user, observation: make_research_grade_observation( taxon: @Calypte_anna ) )
      tn = TaxonName.make!( taxon: ident.observation.taxon, lexicon: TaxonName::LEXICONS[:SPANISH] )
      user.update( locale: "es" )
      get :by_login, format: :json, params: { login: user.login }
      json = JSON.parse( response.body )
      json_ident = json.detect {| i | i["id"] == ident.id }
      expect( json_ident["observation"]["taxon"]["default_name"]["name"] ).to eq tn.name
    end
  end
end

describe IdentificationsController, "oauth authentication" do
  let( :token ) do
    double acceptable?: true, accessible?: true, resource_owner_id: user.id, application: OauthApplication.make!
  end
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow( controller ).to receive( :doorkeeper_token ) { token }
  end
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
  it_behaves_like "an IdentificationsController basics"
  it_behaves_like "an IdentificationsController"
end

describe IdentificationsController, "with authentication" do
  before { sign_in( user ) }
  it_behaves_like "an IdentificationsController basics"
end

describe IdentificationsController, "with an invalid JWT" do
  before do
    request.env["HTTP_AUTHORIZATION"] = "not-a-valid-jwt"
  end
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
  describe "create" do
    it "should response with a 401" do
      o = create :observation
      post :create, format: :json, params: {
        identification: {
          observation_id: o.id,
          taxon_id: create(:taxon).id
        }
      }
      expect( response.response_code ).to eq 401
    end
  end
end
