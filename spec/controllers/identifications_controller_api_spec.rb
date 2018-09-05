require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "an IdentificationsController" do
  let(:user) { User.make! }
  let(:observation) { Observation.make! }

  describe "create" do
    it "should work" do
      expect(observation.identifications.count).to eq 0
      t = Taxon.make!
      post :create, :format => :json, :identification => {
        :observation_id => observation.id,
        :taxon_id => t.id,
        :body => "i must eat them all"
      }
      expect(response).to be_success
      observation.reload
      expect(observation.identifications.count).to eq 1
    end

    it "should mark the observation as captive if requested" do
      expect( observation ).not_to be_captive_cultivated
      post :create, format: :json, identification: {
        observation_id: observation.id, 
        taxon_id: Taxon.make!.id,
        captive_flag: '1'
      }
      observation.reload
      expect( observation ).to be_captive_cultivated
    end

    it "should not mark the observation as wild if there's an existing contradictory quality metric" do
      QualityMetric.make!(metric: QualityMetric::WILD, observation: observation, user: user, agree: false)
      observation.reload
      expect( observation ).to be_captive_cultivated
      post :create, format: :json, identification: {
        observation_id: observation.id, 
        taxon_id: Taxon.make!.id,
        captive_flag: '0'
      }
      expect( response ).to be_success
      observation.reload
      expect( observation ).to be_captive_cultivated
    end

    it "should include the observation in the response" do
      t = Taxon.make!
      post :create, :format => :json, :identification => {
        :observation_id => observation.id,
        :taxon_id => t.id,
        :body => "i must eat them all"
      }
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json['observation']['id']).to eq observation.id
    end

    it "should not include observation private coordinates" do
      t = Taxon.make!
      o = make_private_observation
      expect(user).not_to eq o.user
      post :create, :format => :json, :identification => {
        :observation_id => o.id,
        :taxon_id => t.id,
        :body => "i must eat them all"
      }
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json['observation']['private_latitude']).to be_blank
    end

    it "should include the observation iconic_taxon_name" do
      load_test_taxa
      t = Taxon.make!
      expect(@Pseudacris_regilla.iconic_taxon).to eq @Amphibia
      o = Observation.make!(:taxon => @Pseudacris_regilla)
      expect(o.iconic_taxon_name).to eq @Amphibia.name
      post :create, :format => :json, :identification => {
        :observation_id => o.id,
        :taxon_id => t.id,
        :body => "i must eat them all"
      }
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json['observation']['iconic_taxon_name']).to eq o.iconic_taxon_name
    end

    it "should set vision attribute" do
      post :create, format: :json, identification: {
        observation_id: observation.id,
        taxon_id: Taxon.make!.id,
        vision: true
      }
      expect( response ).to be_success
      json = JSON.parse(response.body)
      expect( json["vision"] ).to be true
      ident = Identification.find( json["id"] )
      expect( ident.vision ).to be true
    end
  end

  describe "update" do
    let(:identification) { Identification.make!( user: user ) }
    it "should work" do
      expect {
        put :update, :format => :json, :id => identification.id, :identification => {:body => "i must eat them all"}
        identification.reload
      }.to change(identification, :body)
    end
    
    it "should return json" do
      put :update, :format => :json, :id => identification.id, :identification => {:body => "i must eat them all"}
      json = JSON.parse(response.body)
      expect(json['taxon_id']).to eq identification.taxon_id
    end

    it "should mark other identifications as not current if restoring" do
      # puts "creating new ident"
      i2 = Identification.make!( user: user, observation: identification.observation )
      # puts "done creating new ident"
      identification.reload
      expect( i2 ).to be_current
      expect( identification ).not_to be_current
      # puts "updating"
      put :update, format: :json, id: identification.id, identification: { current: true }
      # puts "response.body: #{response.body}"
      # puts "done updating"
      identification.reload
      i2.reload
      expect( i2 ).not_to be_current
      expect( identification ).to be_current
    end
  end

  describe "destroy" do
    before(:all) do
      # some identification deletion callbacks need to happen after the transaction is complete
      DatabaseCleaner.strategy = :truncation
    end

    after(:all) do
      DatabaseCleaner.strategy = :transaction
    end

    before(:each) { enable_elastic_indexing( Observation ) }
    after(:each) { disable_elastic_indexing( Observation ) }

    let(:identification) { Identification.make!(:user => user) }

    # it "should work" do
    #   delete :destroy, :format => :json, :id => identification.id
    #   expect(Identification.find_by_id(identification.id)).to be_blank
    # end

    it "should not destroy the identification" do
      delete :destroy, format: :json, id: identification.id
      expect( Identification.find_by_id( identification.id ) ).not_to be_blank
    end
    
    it "should mark the identification as not current" do
      expect( identification ).to be_current
      delete :destroy, format: :json, id: identification.id
      identification.reload
      expect( identification ).not_to be_current
    end

    it "should remove the observation taxon if there are no current identifications" do
      expect( identification.observation.taxon ).to eq identification.taxon
      delete :destroy, format: :json, id: identification.id
      identification.reload
      expect( identification.observation.taxon ).to be_blank
    end

    # it "should work if there's a pre-existing ident" do
    #   i = Identification.make!( user: user, observation: identification.observation )
    #   expect( i ).to be_current
    #   identification.reload
    #   expect( identification ).not_to be_current
    #   delete :destroy, id: i.id
    #   i.reload
    #   expect( i ).not_to be_current
    #   identification.reload
    #   expect( identification ).to be_current
    # end

    it "should not leave multiple current IDs when deleting a middle ID" do
      o = Observation.make!
      i1 = Identification.make!( user: user, observation: o )
      i2 = Identification.make!( user: user, observation: o )
      i3 = Identification.make!( user: user, observation: o )
      delete :destroy, id: i2.id
      i1.reload
      i3.reload
      expect( i3 ).to be_current
      expect( i1 ).not_to be_current
    end
  end

  describe "by_login" do
    before(:all) { load_test_taxa }
    before(:each) { enable_elastic_indexing( Observation ) }
    after(:each) { disable_elastic_indexing( Observation ) }
    it "should return identifications by the selected user" do
      ident = Identification.make!( user: user )
      get :by_login, format: :json, login: user.login
      json = JSON.parse( response.body )
      expect( json.detect{|i| i["id"] == ident.id } ).not_to be_blank
    end
    it "should not return identifications not by the selected user" do
      ident = Identification.make!
      get :by_login, format: :json, login: user.login
      json = JSON.parse( response.body )
      expect( json.detect{|i| i["id"] == ident.id } ).to be_blank
    end
    describe "response should include the" do
      let(:ident) { Identification.make!( user: user, observation: make_research_grade_observation( taxon: @Calypte_anna ) ) }
      let(:json_ident) do
        expect( ident ).not_to be_blank
        get :by_login, format: :json, login: user.login
        json = JSON.parse( response.body )
        json.detect{|i| i["id"] == ident.id }
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
      user.update_attributes( locale: "es" )
      get :by_login, format: :json, login: user.login
      json = JSON.parse( response.body )
      json_ident = json.detect{|i| i["id"] == ident.id }
      expect( json_ident["taxon"]["default_name"]["name"] ).to eq tn.name
    end
    it "should include place-specific taxon name" do
      ident = Identification.make!( user: user, observation: make_research_grade_observation( taxon: @Calypte_anna ) )
      place = Place.make!
      tn = TaxonName.make!( taxon: ident.taxon, lexicon: TaxonName::LEXICONS[:ENGLISH] )
      ptn = PlaceTaxonName.make!( taxon_name: tn, place: place )
      user.update_attributes( place: place, locale: "en" )
      get :by_login, format: :json, login: user.login
      json = JSON.parse( response.body )
      json_ident = json.detect{|i| i["id"] == ident.id }
      expect( json_ident["taxon"]["default_name"]["name"] ).to eq tn.name
    end
    it "should include locale-specific observation taxon name" do
      ident = Identification.make!( user: user, observation: make_research_grade_observation( taxon: @Calypte_anna ) )
      tn = TaxonName.make!( taxon: ident.observation.taxon, lexicon: TaxonName::LEXICONS[:SPANISH] )
      user.update_attributes( locale: "es" )
      get :by_login, format: :json, login: user.login
      json = JSON.parse( response.body )
      json_ident = json.detect{|i| i["id"] == ident.id }
      expect( json_ident["observation"]["taxon"]["default_name"]["name"] ).to eq tn.name
    end
  end
end

describe IdentificationsController, "oauth authentication" do
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id, :application => OauthApplication.make! }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  it_behaves_like "an IdentificationsController"
end

describe IdentificationsController, "devise authentication" do
  before { http_login(user) }
  it_behaves_like "an IdentificationsController"
end
