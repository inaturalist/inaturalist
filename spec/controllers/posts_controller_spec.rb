# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

describe PostsController, "spam" do
  let( :spammer_content ) do
    p = Post.make!( parent: User.make! )
    p.user.update( spammer: true )
    p
  end
  let( :flagged_content ) do
    p = Post.make!( parent: User.make! )
    Flag.make!( flaggable: p, flag: Flag::SPAM )
    p
  end

  describe "show" do
    it "should render 403 when the owner is a spammer" do
      get :show, params: { id: spammer_content.id }
      expect( response.response_code ).to eq 403
    end

    it "should render 403 when content is flagged as spam" do
      get :show, params: { id: spammer_content.id }
      expect( response.response_code ).to eq 403
    end
  end

  describe "index" do
    it "should render atom" do
      expect do
        get :index, format: :atom, params: { login: spammer_content.user.login }
      end.not_to raise_error
    end

    it "returns posts new_than other posts" do
      p1 = Post.make!( parent: Site.default )
      p2 = Post.make!( parent: Site.default )
      p1.update( published_at: Time.now )
      p2.update( published_at: 1.minute.ago )
      get :index, format: :json
      expect( JSON.parse( response.body ).length ).to eq( 2 )
      get :index, format: :json, params: { newer_than: p2.id }
      body = JSON.parse( response.body )
      expect( JSON.parse( response.body ).length ).to eq( 1 )
      expect( body[0]["id"] ).to eq( p1.id )
      get :index, format: :json, params: { newer_than: p1.id }
      expect( JSON.parse( response.body ).length ).to eq( 0 )
    end

    it "returns posts older_than other posts" do
      p1 = Post.make!( parent: Site.default )
      p2 = Post.make!( parent: Site.default )
      p1.update( published_at: Time.now )
      p2.update( published_at: 1.minute.ago )
      get :index, format: :json
      expect( JSON.parse( response.body ).length ).to eq( 2 )
      get :index, format: :json, params: { older_than: p1.id }
      body = JSON.parse( response.body )
      expect( JSON.parse( response.body ).length ).to eq( 1 )
      expect( body[0]["id"] ).to eq( p2.id )
      get :index, format: :json, params: { older_than: p2.id }
      expect( JSON.parse( response.body ).length ).to eq( 0 )
    end
  end
end

describe PostsController, "create" do
  describe "for user journal" do
    let( :user ) { User.make! }
    before do
      sign_in user
    end
    it "should work for user" do
      expect do
        post :create, params: { post: { title: "Foo", body: "Bar", parent_type: "User", parent_id: user.id } }
      end.to change( Post, :count ).by( 1 )
    end
    it "should not allow a user to post to another user's journal" do
      expect do
        post :create, params: { post: { title: "Foo", body: "Bar", parent_type: "User", parent_id: User.make!.id } }
      end.not_to change( Post, :count )
    end
  end
  describe "for projects" do
    let( :user ) { make_user_with_privilege( UserPrivilege::ORGANIZER ) }
    before do
      sign_in user
    end
    it "should work for a curator" do
      project = Project.make!( user: user )
      expect( project ).to be_curated_by user
      expect do
        post :create, params: { post: { title: "Foo", body: "Bar", parent_type: "Project", parent_id: project.id } }
      end.to change( Post, :count ).by( 1 )
    end
    it "should not work for a non-curator" do
      project = Project.make!
      expect( project ).not_to be_curated_by user
      expect do
        post :create, params: { post: { title: "Foo", body: "Bar", parent_type: "Project", parent_id: project.id } }
      end.not_to change( Post, :count )
    end
  end
  describe "for sites" do
    let( :site ) { Site.make! }
    it "should work for a site admin" do
      user = SiteAdmin.make!( site: site ).user
      sign_in user
      expect do
        post :create, params: { post: { title: "Foo", body: "Bar", parent_type: "Site", parent_id: site.id } }
      end.to change( Post, :count ).by( 1 )
    end
    it "should not work for a normal user" do
      user = User.make!
      sign_in user
      expect do
        post :create, params: { post: { title: "Foo", body: "Bar", parent_type: "Site", parent_id: site.id } }
      end.not_to change( Post, :count )
    end
  end
end

describe PostsController, "update" do
  describe "for user" do
    let( :user ) { User.make! }
    before { sign_in user }
    it "should work for owner" do
      p = Post.make!( user: user, parent: user )
      new_body = "This is a new body"
      put :update, params: { id: p.id, post: { body: new_body } }
      p.reload
      expect( p.body ).to eq new_body
    end
    it "should not work for non-owner" do
      other_user = User.make!
      p = Post.make!( parent: other_user, user: other_user )
      new_body = "This is a new body"
      put :update, params: { id: p.id, post: { body: new_body } }
      p.reload
      expect( p.body ).not_to eq new_body
    end
  end
  describe "for project" do
    let( :user ) { make_user_with_privilege( UserPrivilege::ORGANIZER ) }
    before { sign_in user }
    it "should work or a project curator" do
      project = Project.make!( user: user )
      p = Post.make!( user: user, parent: project )
      new_body = "This is a new body"
      put :update, params: { id: p.id, post: { body: new_body } }
      p.reload
      expect( p.body ).to eq new_body
    end
    it "should not work for a normal user" do
      project = Project.make!
      p = Post.make!( user: project.user, parent: project )
      new_body = "This is a new body"
      put :update, params: { id: p.id, post: { body: new_body } }
      p.reload
      expect( p.body ).not_to eq new_body
    end
  end
  describe "for site" do
    it "should work or a site admin" do
      site = Site.make!
      user = make_admin
      sign_in user
      p = Post.make!( parent: site )
      new_body = "This is a new body"
      put :update, params: { id: p.id, post: { body: new_body } }
      p.reload
      expect( p.body ).to eq new_body
    end
    it "should not work for a normal user" do
      site = Site.make!
      user = User.make!
      sign_in user
      p = Post.make!( parent: site )
      new_body = "This is a new body"
      put :update, params: { id: p.id, post: { body: new_body } }
      p.reload
      expect( p.body ).not_to eq new_body
    end
  end
end

describe PostsController, "for projects" do
  let( :project ) { Project.make! }
  describe "edit" do
    let( :post ) { Post.make!( parent: project, user: project.user ) }
    def expect_post_to_be_editable_by( user )
      sign_in user
      get :edit, params: { id: post.id }
      expect( response.response_code ).to eq 200
    end
    it "should work for post author" do
      expect_post_to_be_editable_by post.user
    end
    it "should work for project managers" do
      pu = ProjectUser.make!( project: project, role: ProjectUser::MANAGER )
      expect_post_to_be_editable_by pu.user
    end
    it "should work for project curators" do
      pu = ProjectUser.make!( project: project, role: ProjectUser::CURATOR )
      expect_post_to_be_editable_by pu.user
    end
  end
end

describe PostsController, "show" do
  let( :user ) { User.make! }
  it "should use the first image as the shareable_image_url regardless of quote style" do
    single_quote_url = "https://www.inaturalist.org/img/single_quote.png"
    double_quote_url = "https://www.inaturalist.org/img/double_quote.png"
    body = <<-HTML
      This is some text
      <img src='#{single_quote_url}' />
      <img src="#{double_quote_url}" />
    HTML
    post = Post.make!( parent: user, body: body )
    get :show, params: { id: post.id }
    expect( assigns( :shareable_image_url ) ).to eq single_quote_url
  end

  describe "spam comments" do
    render_views
    it "should not render" do
      post = Post.make!( parent: user )
      c = Comment.make!( parent: post )
      Flag.make!( flaggable: c, flag: Flag::SPAM )
      get :show, params: { id: post.id }
      expect( response.body ).not_to include c.body
    end
  end
end

describe PostsController, "edit" do
  let( :user ) { create :user }
  let( :user_post ) { create :post, user: user, parent: user }
  before { sign_in( user ) }

  it "should allow a post author to preview their own post" do
    get :edit, params: { login: user.login, id: user_post.id, preview: true }
    expect( response.response_code ).to eq 200
  end
  it "should not allow a user to preview another user's post" do
    other_user = create :user
    other_user_post = create :post, user: other_user, parent: other_user
    get :edit, params: { login: user.login, id: other_user_post.id, preview: true }
    expect( response.response_code ).to be >= 300
  end
end
