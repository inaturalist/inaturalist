require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a PostsController" do
  let(:user) { User.make! }
  
  describe "routes" do
    it "should accept GET requests" do
      project = Project.make!
      expect(get: "/projects/#{project.id}/journal.json").to be_routable
    end
  end
  
  describe "index" do
    it "should list journal posts for a project" do
      project = Project.make!
      post = Post.make!(parent: project, user: project.user)
      get :index, format: :json, project_id: project.id
      json = JSON.parse(response.body)
      json_post = json.detect{ |p| p['id'] == post.id }
      expect( json_post ).not_to be_blank
    end
  end
  
  describe "for_user" do
    it "should include posts by projects the user belongs to" do
      pu = ProjectUser.make!(user: user)
      post = Post.make!(parent: pu.project, user: pu.project.user)
      get :for_user, format: :json
      json = JSON.parse(response.body)
      expect( json.detect{|p|  p['id'] == post.id } ).not_to be_blank
    end
    it "should not include posts by projects the user doesn't belongs to" do
      pu = ProjectUser.make!
      post = Post.make!(parent: pu.project, user: pu.project.user)
      get :for_user, format: :json
      json = JSON.parse(response.body)
      expect( json.detect{|p|  p['id'] == post.id } ).to be_blank
    end
    it "should not include user posts" do
      friendship = Friendship.make!(user: user)
      post = Post.make!(parent: friendship.friend, user: friendship.friend)
      get :for_user, format: :json
      json = JSON.parse(response.body)
      expect( json.detect{|p|  p['id'] == post.id } ).to be_blank
    end
    it "should include project title" do
      pu = ProjectUser.make!(user: user)
      post = Post.make!(parent: pu.project, user: pu.project.user)
      get :for_user, format: :json
      json = JSON.parse(response.body)
      post = json.detect{|p| p['id'] == post.id }
      expect( post['parent']['title'] ).to eq pu.project.title
    end
    it "should include project icon_url" do
      pu = ProjectUser.make!(user: user)
      post = Post.make!(parent: pu.project, user: pu.project.user)
      get :for_user, format: :json
      json = JSON.parse(response.body)
      expect( json.detect{|p| p['id'] == post.id }['parent']['icon_url'] ).to eq pu.project.icon_url
    end
    it "should include site name" do
      site = Site.make!
      user.update_attributes( site: site )
      post = Post.make!( parent: site )
      get :for_user, format: :json
      json = JSON.parse(response.body)
      json_post = json.detect{|p| p['id'] == post.id }
      expect( json_post['parent']['name'] ).to eq site.name
    end
    it "should include site icon_url" do
      site = Site.make!
      user.update_attributes( site: site )
      post = Post.make!( parent: site )
      get :for_user, format: :json
      json = JSON.parse(response.body)
      json_post = json.detect{|p| p['id'] == post.id }
      expect( json_post['parent']['icon_url'] ).to eq site.icon_url
    end
    it "should not include disallowed tags like figure" do
      pu = ProjectUser.make!(user: user)
      post = Post.make!(parent: pu.project, user: pu.project.user, body: "<figure>foo</figure>")
      get :for_user, format: :json
      json = JSON.parse(response.body)
      expect( json.detect{|p| p['id'] == post.id }['body'] ).not_to match /<figure>/
    end
    it "should include site posts for the user's site" do
      s = Site.make!
      user.update_attributes( site: s )
      expect( user.site_id ).to eq s.id
      post = Post.make!( parent: s )
      get :for_user, format: :json
      json = JSON.parse(response.body)
      expect( json.detect{|p|  p['id'] == post.id } ).not_to be_blank
    end
    it "should not include duplicate site posts if the user has joined several projects" do
      s = Site.make!
      3.times { ProjectUser.make!( user: user ) }
      user.update_attributes( site: s )
      expect( user.site_id ).to eq s.id
      post = Post.make!( parent: s )
      get :for_user, format: :json
      json = JSON.parse(response.body)
      expect( json.select{|p|  p['id'] == post.id }.size ).to eq 1
    end
    it "should not include site posts from other sites" do
      s1 = Site.make!
      s2 = Site.make!
      user.update_attributes( site: s1 )
      post = Post.make!( parent: s2 )
      get :for_user, format: :json
      json = JSON.parse(response.body)
      expect( json.detect{|p|  p['id'] == post.id } ).to be_blank
    end
    describe "older_than" do
      let( :pu ) { ProjectUser.make!( user: user ) }
      let( :p1 ) { Post.make!( parent: pu.project, user: pu.project.user ) }
      let( :p2 ) { Post.make!( parent: pu.project, user: pu.project.user ) }
      let( :p3 ) { Post.make!( parent: pu.project, user: pu.project.user ) }
      before do
        expect( p1.published_at ).to be < p2.published_at
        expect( p2.published_at ).to be < p3.published_at
      end
      it "should show posts older than the selected post" do
        get :for_user, format: :json, older_than: p2.id
        json = JSON.parse( response.body )
        expect( json.detect{|p|  p[ 'id' ] == p1.id } ).not_to be_blank
      end
      it "should not show posts newer than the selected post" do
        get :for_user, format: :json, older_than: p2.id
        json = JSON.parse( response.body )
        expect( json.detect{|p|  p[ 'id' ] == p3.id } ).to be_blank
      end
    end
    describe "newer_than" do
      let( :pu ) { ProjectUser.make!( user: user ) }
      let( :p1 ) { Post.make!( parent: pu.project, user: pu.project.user ) }
      let( :p2 ) { Post.make!( parent: pu.project, user: pu.project.user ) }
      let( :p3 ) { Post.make!( parent: pu.project, user: pu.project.user ) }
      before do
        expect( p1.published_at ).to be < p2.published_at
        expect( p2.published_at ).to be < p3.published_at
      end
      it "should show posts newer than the selected post" do
        get :for_user, format: :json, newer_than: p2.id
        json = JSON.parse( response.body )
        expect( json.detect{|p|  p[ 'id' ] == p3.id } ).not_to be_blank
      end
      it "should not show posts older than the selected post" do
        get :for_user, format: :json, newer_than: p2.id
        json = JSON.parse( response.body )
        expect( json.detect{|p|  p[ 'id' ] == p1.id } ).to be_blank
      end
    end
  end
end

describe PostsController, "oauth authentication" do
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id, :application => OauthApplication.make! }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  it_behaves_like "a PostsController"
end

describe PostsController, "devise authentication" do
  before { http_login(user) }
  it_behaves_like "a PostsController"
end

describe PostsController, "without authentication" do
  describe "for_user" do
    it "should return site posts" do
      post = Post.make!( parent: Site.default )
      get :for_user, format: :json
      json = JSON.parse(response.body)
      json_post = json.detect{ |p| p['id'] == post.id }
      expect( json_post ).not_to be_blank
    end
  end
end
