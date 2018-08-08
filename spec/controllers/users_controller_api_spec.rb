require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a signed in UsersController" do
  before(:all) { User.destroy_all }
  before(:each) do
    enable_elastic_indexing( Observation )
    enable_has_subscribers
  end
  after(:each) do
    disable_elastic_indexing( Observation )
    disable_has_subscribers
  end
  let(:user) { User.make! }
  it "should show email for edit" do
    get :edit, :format => :json
    expect(response).to be_success
    expect(response.body).to be =~ /#{user.email}/
  end

  it "should show the dashboard" do
    get :dashboard
    expect(response).to be_success
  end

  describe "update" do
    it "should remove the user icon with icon_delete param" do
      user.icon = File.open( File.join( Rails.root, "spec", "fixtures", "files", "cuthona_abronia-tagged.jpg" ) )
      user.save!
      expect( user.icon_file_name ).not_to be_blank
      put :update, id: user.id, format: :json, icon_delete: true
      expect( response ).to be_success
      user.reload
      expect( user.icon_file_name ).to be_blank
    end
    it "should not remove the user icon with no user[icon] param" do
      user.icon = File.open( File.join( Rails.root, "spec", "fixtures", "files", "cuthona_abronia-tagged.jpg" ) )
      user.save!
      expect( user.icon_file_name ).not_to be_blank
      new_desc = "show me the tarweeds"
      put :update, id: user.id, format: :json, user: { description: new_desc }
      expect( response ).to be_success
      user.reload
      expect( user.description ).to eq new_desc
      expect( user.icon_file_name ).not_to be_blank
    end
    describe "observation license preference" do
      it "should update past observations if requested" do
        user.update_attributes( preferred_observation_license: Observation::CC_BY )
        o = Observation.make!( user: user )
        expect( o.license ).to eq Observation::CC_BY
        put :update, id: user.id, format: :json, user: { preferred_observation_license: Observation::CC0, make_observation_licenses_same: "1" }
        o.reload
        expect( o.license ).to eq Observation::CC0
      end
      it "should update re-index past observations" do
        user.update_attributes( preferred_observation_license: Observation::CC_BY )
        o = Observation.make!( user: user )
        es_response = Observation.elastic_search( where: { id: o.id } ).results.results.first
        expect( es_response.license_code ).to eq Observation::CC_BY.downcase
        put :update, id: user.id, format: :json, user: {
          preferred_observation_license: "",
          make_observation_licenses_same: "1"
        }
        Delayed::Worker.new.work_off
        es_response = Observation.elastic_search( where: { id: o.id } ).results.results.first
        expect( es_response.license_code ).to be_blank
      end
    end
    describe "photo license preference" do
      it "should update past observations if requested" do
        user.update_attributes( preferred_photo_license: Observation::CC_BY )
        p = LocalPhoto.make!( user: user )
        expect( p.license_code ).to eq Observation::CC_BY
        put :update, id: user.id, format: :json, user: {
          preferred_photo_license: Observation::CC0,
          make_photo_licenses_same: "1"
        }
        p.reload
        expect( p.license_code ).to eq Observation::CC0
      end
      # Honestly not sure why this passes
      it "should update re-index past observations" do
        user.update_attributes( preferred_photo_license: Observation::CC_BY )
        o = make_research_grade_observation( user: user )
        es_response = Observation.elastic_search( where: { id: o.id } ).results.results.first
        expect( es_response.photos.first.license_code ).to eq Observation::CC_BY.downcase
        put :update, id: user.id, format: :json, user: {
          preferred_photo_license: "",
          make_photo_licenses_same: "1"
        }
        Delayed::Worker.new.work_off
        es_response = Observation.elastic_search( where: { id: o.id } ).results.results.first
        expect( es_response.photos.first.license_code ).to be_blank
      end
    end
  end

  describe "new_updates" do
    before { CONFIG.has_subscribers = :enabled }
    after { CONFIG.has_subscribers = :disabled }
    it "should show recent updates" do
      o = Observation.make!(:user => user)
      without_delay { Comment.make!(:parent => o) }
      get :new_updates, :format => :json
      json = JSON.parse(response.body)
      expect(json.size).to be > 0
    end

    it "return mentions" do
      without_delay { Comment.make!(body: "hey @#{ user.login }") }
      get :new_updates, format: :json, notification: "mention"
      json = JSON.parse(response.body)
      expect(json.size).to be > 0
      expect(json.first["notification"]).to eq "mention"
    end

    it "should filter by resource_type" do
      p = Post.make!(:parent => user, :user => user)
      without_delay { Comment.make!(:parent => p) }
      get :new_updates, :format => :json, :resource_type => "Post"
      json = JSON.parse(response.body)
      expect(json.size).to be > 0

      get :new_updates, :format => :json, :resource_type => "Observation"
      json = JSON.parse(response.body)
      expect(json).to be_blank
      expect(json.size).to eq 0
    end

    it "should filter by notifier_type" do
      o = Observation.make!(:user => user)
      without_delay { Comment.make!(:parent => o) }
      get :new_updates, :format => :json, :notifier_type => "Comment"
      json = JSON.parse(response.body)
      expect(json.size).to be > 0

      get :new_updates, :format => :json, :notifier_type => "Identification"
      json = JSON.parse(response.body)
      expect(json).to be_blank
      expect(json.size).to eq 0
    end

    it "should allow user to skip marking the updates as viewed" do
      o = Observation.make!(:user => user)
      without_delay { Comment.make!(:parent => o) }
      expect( UpdateAction.unviewed_by_user_from_query(user.id, resource: o) ).to eq true
      get :new_updates, :format => :json, :skip_view => true
      Delayed::Worker.new(:quiet => true).work_off
      expect( UpdateAction.unviewed_by_user_from_query(user.id, resource: o) ).to eq true
    end
  end

  describe "search" do
    it "should search by username" do
      u = User.make!
      get :search, :q => u.login, :format => :json
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json.detect{|ju| ju['id'] == u.id}).not_to be_blank
    end

    it "should allow email searches" do
      u = User.make!
      get :search, :q => u.email, :format => :json
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json.detect{|ju| ju['id'] == u.id}).not_to be_blank
    end
  end

  describe "test_groups" do
    it "should be set with update" do
      test_groups = "foo"
      expect( user.test_groups ).to be_blank
      put :update, id: user.id, user: { test_groups: test_groups }
      user.reload
      expect( user.test_groups ).to eq test_groups
    end
  end

end

describe UsersController, "oauth authentication" do
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  it_behaves_like "a signed in UsersController"
end

describe UsersController, "devise authentication" do
  before do
    http_login user
  end
  it_behaves_like "a signed in UsersController"
end

describe UsersController, "without authentication" do
  it "should not show email for edit" do
    user = User.make!
    get :edit, :format => :json, :id => user.id
    expect(response).not_to be_success
    expect(response.body).not_to be =~ /#{user.email}/
  end

  describe "show" do
    let( :user ) { User.make! }
    it "should show observations_count" do
      get :show, format: :json, id: user.id
      expect( response ).to be_success
      expect( JSON.parse( response.body )["observations_count"] ).to eq 0
    end
    it "should show identifications_count" do
      get :show, format: :json, id: user.id
      expect( response ).to be_success
      expect( JSON.parse( response.body )["identifications_count"] ).to eq 0
    end
  end

  describe "search" do
    it "should search by username" do
      u1 = User.make!(:login => "foo")
      u2 = User.make!(:login => "bar")
      get :search, :q => u1.login, :format => :json
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json.detect{|ju| ju['id'] == u1.id}).not_to be_blank
      expect(json.detect{|ju| ju['id'] == u2.id}).to be_blank
    end
    
    it "should not allow email searches" do
      u = User.make!
      get :search, :q => u.email, :format => :json
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json).to be_blank
    end

    it "can order by activity" do
      u1 = User.make!(login: "aaa", observations_count: 2)
      u2 = User.make!(login: "abb", observations_count: 1)
      u3 = User.make!(login: "acc", observations_count: 3)
      get :search, q: "a", format: :json
      expect(JSON.parse(response.body).map{ |r| r["login"] }).to eq [ "aaa", "abb", "acc" ]
      get :search, q: "a", format: :json, order: "activity"
      expect(JSON.parse(response.body).map{ |r| r["login"] }).to eq [ "acc", "aaa", "abb" ]
    end
  end
end
