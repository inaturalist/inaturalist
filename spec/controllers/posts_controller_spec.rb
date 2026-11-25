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

describe PostsController, "site blog index" do
  render_views
  let( :site ) { Site.default }

  it "links site admins to the blog category management page" do
    sign_in SiteAdmin.make!( site: site ).user
    get :index, params: { inat_site_id: site.id }
    expect( Nokogiri::HTML( response.body ).at_css( "a[href='#{blog_categories_path}']" ) ).not_to be_nil
  end

  it "doesn't link admins of other sites to the blog category management page" do
    other_site = Site.make!
    sign_in SiteAdmin.make!( site: other_site ).user
    get :index, params: { inat_site_id: other_site.id }
    expect( Nokogiri::HTML( response.body ).at_css( "a[href='#{blog_categories_path}']" ) ).to be_nil
  end

  it "doesn't link normal users to the blog category management page" do
    sign_in User.make!
    get :index, params: { inat_site_id: site.id }
    expect( Nokogiri::HTML( response.body ).at_css( "a[href='#{blog_categories_path}']" ) ).to be_nil
  end
end

describe PostsController, "create" do
  let( :site_only_values ) do
    { featured_at: Time.now, mobile_featured_at: Time.now, blog_category_id: BlogCategory.make!.id }
  end
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
    %i[featured_at mobile_featured_at blog_category_id].each do | field |
      it "should not save #{field}" do
        expect do
          post :create, params: {
            post: {
              title: "Foo",
              body: "Bar",
              parent_type: "User",
              parent_id: user.id,
              field => site_only_values[field]
            }
          }
        end.not_to change( Post, :count )
      end
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
    %i[featured_at mobile_featured_at blog_category_id].each do | field |
      it "should not save #{field}" do
        project = Project.make!( user: user )
        expect do
          post :create, params: {
            post: {
              title: "Foo",
              body: "Bar",
              parent_type: "Project",
              parent_id: project.id,
              field => site_only_values[field]
            }
          }
        end.not_to change( Post, :count )
      end
    end
  end
  describe "for sites" do
    let( :site ) { Site.default }
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
    it "should let a site admin set the blog fields" do
      sign_in SiteAdmin.make!( site: site ).user
      category = BlogCategory.make!( site: site )
      post :create, params: {
        post: {
          title: "Foo",
          body: "Bar",
          parent_type: "Site",
          parent_id: site.id,
          featured_at: Time.now,
          mobile_featured_at: Time.now,
          blog_category_id: category.id,
          locale: "fr"
        }
      }
      created = Post.last
      expect( created.featured_at ).not_to be_nil
      expect( created.mobile_featured_at ).not_to be_nil
      expect( created.blog_category ).to eq category
      expect( created.locale ).to eq "fr"
    end
    it "should set the featured timestamps from the form checkboxes" do
      sign_in SiteAdmin.make!( site: site ).user
      post :create, params: {
        post: {
          title: "Foo",
          body: "Bar",
          parent_type: "Site",
          parent_id: site.id,
          featured: "1",
          mobile_featured: "1"
        }
      }
      created = Post.last
      expect( created.featured_at ).not_to be_nil
      expect( created.mobile_featured_at ).not_to be_nil
    end
    it "should save the category and tags from the form" do
      sign_in SiteAdmin.make!( site: site ).user
      category = BlogCategory.make!( site: site )
      post :create, params: {
        post: {
          title: "Foo",
          body: "Bar",
          parent_type: "Site",
          parent_id: site.id,
          blog_category_id: category.id,
          tag_list: "herons, birds"
        }
      }
      created = Post.last
      expect( created.blog_category ).to eq category
      expect( created.tag_list ).to match_array %w(herons birds)
    end
    it "should not save featured flags on a site other than the default" do
      other_site = Site.make!
      sign_in SiteAdmin.make!( site: other_site ).user
      expect do
        post :create, params: {
          post: { title: "Foo", body: "Bar", parent_type: "Site", parent_id: other_site.id, featured: "1" }
        }
      end.not_to change( Post, :count )
    end
  end
end

describe PostsController, "update" do
  let( :site_only_values ) do
    { featured_at: Time.now, mobile_featured_at: Time.now, blog_category_id: BlogCategory.make!.id }
  end
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
    %i[featured_at mobile_featured_at blog_category_id].each do | field |
      it "should not save #{field}" do
        p = Post.make!( user: user, parent: user )
        put :update, params: { id: p.id, post: { body: "New body", field => site_only_values[field] } }
        p.reload
        expect( p.body ).not_to eq "New body"
        expect( p[field] ).to be_nil
      end
    end
    it "should set the locale" do
      p = Post.make!( user: user, parent: user )
      put :update, params: { id: p.id, post: { locale: "fr" } }
      expect( p.reload.locale ).to eq "fr"
    end
    %i[featured_at mobile_featured_at blog_category_id].each do | field |
      it "should not save #{field} on a trip" do
        trip = Trip.make!( user: user )
        put :update, params: {
          id: trip.id,
          observations: [Observation.make!( user: user ).id],
          trip: { body: "New body", field => site_only_values[field] }
        }
        trip.reload
        expect( trip.body ).not_to eq "New body"
        expect( trip[field] ).to be_nil
      end
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
    %i[featured_at mobile_featured_at blog_category_id].each do | field |
      it "should not save #{field}" do
        p = Post.make!( user: user, parent: Project.make!( user: user ) )
        put :update, params: { id: p.id, post: { body: "New body", field => site_only_values[field] } }
        p.reload
        expect( p.body ).not_to eq "New body"
        expect( p[field] ).to be_nil
      end
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
    it "should let a site admin feature the post and set its cover" do
      site = Site.default
      sign_in SiteAdmin.make!( site: site ).user
      p = Post.make!( parent: site )
      cover = PostImage.make!( post: p, alt: "A heron" )
      put :update, params: {
        id: p.id,
        post: { featured_at: Time.now, mobile_featured_at: Time.now, cover_image_id: cover.id }
      }
      p.reload
      expect( p.featured_at ).not_to be_nil
      expect( p.mobile_featured_at ).not_to be_nil
      expect( p.cover_image ).to eq cover
    end
    it "should let the post's author set featured flags without being a site editor" do
      site = Site.default
      author = User.make!
      sign_in author
      p = Post.make!( parent: site, user: author )
      put :update, params: { id: p.id, post: { featured_at: Time.now, mobile_featured_at: Time.now } }
      p.reload
      expect( p.featured_at ).not_to be_nil
      expect( p.mobile_featured_at ).not_to be_nil
    end
    describe "blog form fields" do
      render_views
      let( :site ) { Site.default }
      let( :legacy_body ) { "<p>Legacy <b>HTML</b> body\nwith a line break</p>" }
      let( :p ) { Post.make!( parent: site, body: legacy_body ) }
      before { sign_in SiteAdmin.make!( site: site ).user }

      it "saves category, tags and featured flags without changing the body" do
        category = BlogCategory.make!( site: site )
        put :update, params: {
          id: p.id,
          post: { blog_category_id: category.id, tag_list: "herons, birds", featured: "1", mobile_featured: "1" }
        }
        p.reload
        expect( p.blog_category ).to eq category
        expect( p.tag_list ).to match_array %w(herons birds)
        expect( p.featured_at ).not_to be_nil
        expect( p.mobile_featured_at ).not_to be_nil
        expect( p.body ).to eq legacy_body
      end

      it "clears the featured timestamps when unchecked" do
        p.update!( featured_at: Time.now, mobile_featured_at: Time.now )
        put :update, params: { id: p.id, post: { featured: "0", mobile_featured: "0" } }
        p.reload
        expect( p.featured_at ).to be_nil
        expect( p.mobile_featured_at ).to be_nil
      end

      def page_text
        Nokogiri::HTML( response.body ).text
      end

      it "re-renders the form with an error for another site's category" do
        put :update, params: { id: p.id, post: { blog_category_id: BlogCategory.make!( site: Site.make! ).id } }
        expect( response ).to be_successful
        expect( page_text ).to include p.errors.generate_message( :blog_category, :must_belong_to_post_site )
        expect( p.reload.blog_category ).to be_nil
      end

      it "re-renders the form with an error for an over-long tag list" do
        put :update, params: { id: p.id, post: { tag_list: Array.new( 100 ) {| i | "heron#{i}" }.join( ", " ) } }
        expect( response ).to be_successful
        expect( page_text ).to include p.errors.generate_message( :tag_list, :too_long )
        expect( p.reload.tag_list ).to be_empty
      end

      it "keeps the original featured timestamp when left checked" do
        featured_at = 3.days.ago.change( usec: 0 )
        p.update!( featured_at: featured_at )
        put :update, params: { id: p.id, post: { title: "New title", featured: "1" } }
        expect( p.reload.featured_at ).to eq featured_at
      end
    end
  end
end

describe PostsController, "post form blog fields" do
  render_views
  let( :blog_field_names ) { %w(post[blog_category_id] post[tag_list] post[featured] post[mobile_featured]) }

  def form_field_names
    Nokogiri::HTML( response.body ).css( "form.post_form [name]" ).map {| el | el["name"] }
  end

  it "shows the blog fields on a default site post with only that site's categories" do
    site = Site.default
    category = BlogCategory.make!( site: site )
    other_category = BlogCategory.make!( site: Site.make! )
    p = Post.make!( parent: site )
    sign_in SiteAdmin.make!( site: site ).user
    get :edit, params: { id: p.id }
    expect( form_field_names ).to include( *blog_field_names )
    options = Nokogiri::HTML( response.body ).css( "select[name='post[blog_category_id]'] option" ).map { _1["value"] }
    expect( options ).to include category.id.to_s
    expect( options ).not_to include other_category.id.to_s
  end

  it "shows the blog fields on a new default site post" do
    site = Site.default
    sign_in SiteAdmin.make!( site: site ).user
    get :new, params: { inat_site_id: site.id }
    expect( form_field_names ).to include( *blog_field_names )
  end

  it "doesn't show the blog fields on a post for a site other than the default" do
    site = Site.make!
    p = Post.make!( parent: site )
    sign_in SiteAdmin.make!( site: site ).user
    get :edit, params: { id: p.id }
    expect( response ).to be_successful
    expect( form_field_names & blog_field_names ).to be_empty
  end

  it "doesn't show the blog fields on a journal post" do
    user = User.make!
    p = Post.make!( parent: user, user: user )
    sign_in user
    get :edit, params: { id: p.id, login: user.login }
    expect( response ).to be_successful
    expect( form_field_names & blog_field_names ).to be_empty
  end

  it "doesn't show the blog fields on a project post" do
    user = make_user_with_privilege( UserPrivilege::ORGANIZER )
    project = Project.make!( user: user )
    p = Post.make!( parent: project, user: user )
    sign_in user
    get :edit, params: { id: p.id, project_id: project.id }
    expect( response ).to be_successful
    expect( form_field_names & blog_field_names ).to be_empty
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

  describe "side navigation" do
    render_views

    let( :journal_post ) { Post.make!( parent: user ) }

    it "drops the summary and description links" do
      get :show, params: { id: journal_post.id }
      expect( response.body ).not_to include "href=\"#summary\""
      expect( response.body ).not_to include "href=\"#description\""
    end

    it "renders the comments link with its count in both the side and inline navs" do
      2.times { Comment.make!( parent: journal_post ) }
      get :show, params: { id: journal_post.id }
      html = Nokogiri::HTML( response.body )
      %w(.post-nav-side .post-nav-inline).each do | nav |
        expect( html.css( "#{nav} a[href='#comments']" ).text ).to eq "2 comments"
      end
    end

    it "omits the navs when there is nothing to link to" do
      get :show, params: { id: journal_post.id }
      html = Nokogiri::HTML( response.body )
      expect( html.css( "a[href='#comments']" ) ).to be_empty
      expect( html.css( ".post-nav" ) ).to be_empty
    end

    it "links to observations when the post has some" do
      journal_post.observations << Observation.make!( user: user )
      get :show, params: { id: journal_post.id }
      html = Nokogiri::HTML( response.body )
      expect( html.css( ".post-nav-inline a[href='#observations']" ) ).not_to be_empty
    end
  end

  describe "templates" do
    it "renders the blog page for a Site post when blog_v2 is on" do
      Flipper.enable( :blog_v2 )
      get :show, params: { id: Post.make!( parent: Site.make!, user: user ).id }
      expect( response ).to render_template( :show_blog )
    end

    it "keeps the shared page for a Site post when blog_v2 is off" do
      get :show, params: { id: Post.make!( parent: Site.make!, user: user, published_at: 1.hour.ago ).id }
      expect( response ).to render_template( :show )
      expect( response ).not_to render_template( :show_blog )
    end

    it "renders the blog page only for users blog_v2 is enabled for" do
      staff = User.make!
      Flipper.enable_actor( :blog_v2, staff )
      blog_post = Post.make!( parent: Site.make!, user: user, published_at: 1.hour.ago )
      sign_in staff
      get :show, params: { id: blog_post.id }
      expect( response ).to render_template( :show_blog )
      sign_out staff
      sign_in User.make!
      get :show, params: { id: blog_post.id }
      expect( response ).not_to render_template( :show_blog )
    end

    it "keeps the shared page for a journal post" do
      get :show, params: { id: Post.make!( parent: user, user: user ).id, login: user.login }
      expect( response ).to render_template( :show )
      expect( response ).not_to render_template( :show_blog )
    end

    it "keeps the shared page for a project post" do
      project = Project.make!
      get :show, params: { id: Post.make!( parent: project, user: project.user ).id, project_id: project.id }
      expect( response ).to render_template( :show )
      expect( response ).not_to render_template( :show_blog )
    end
  end
end

describe PostsController, "show for a blog post" do
  render_views
  let( :site ) { Site.make! }
  let( :author ) { User.make! }
  let( :blog_post ) { Post.make!( parent: site, user: author, published_at: 1.hour.ago ) }

  before do
    Flipper.enable( :blog_v2 )
    controller.request.host = URI.parse( site.url ).host
  end

  def html
    Nokogiri::HTML( response.body )
  end

  def show( post = blog_post )
    get :show, params: { id: post.id }
  end

  def add_cover( post, attrs = {} )
    cover = PostImage.make!( { post: post, user: post.user, alt: "A heron on a rock" }.merge( attrs ) )
    post.update!( cover_image: cover )
    cover
  end

  describe "other posts" do
    it "lists the 3 newest other published posts from the same site" do
      newest = [1, 2, 3].map {| d | Post.make!( parent: site, user: author, published_at: d.days.ago ) }
      older = Post.make!( parent: site, user: author, published_at: 10.days.ago )
      draft = Post.make!( parent: site, user: author, published_at: nil )
      other_site = Post.make!( parent: Site.make!, user: author, published_at: 1.minute.ago )
      show
      expect( assigns( :other_posts ) ).to eq newest
      expect( assigns( :other_posts ) ).not_to include( blog_post, older, draft, other_site )
      expect( html.css( ".post-card" ).size ).to eq 3
    end

    it "skips the journal prev/next lookups" do
      Post.make!( parent: site, user: author, published_at: 1.day.ago )
      Post.make!( parent: site, user: author, published_at: 1.minute.ago )
      show
      expect( assigns( :prev ) ).to be_nil
      expect( assigns( :next ) ).to be_nil
    end

    it "links to the blog archive" do
      Post.make!( parent: site, user: author, published_at: 1.day.ago )
      show
      expect( html.at_css( "a[href='#{archives_site_posts_path}']" ) ).not_to be_nil
    end
  end

  describe "deleted author" do
    it "renders with a deleted user byline" do
      blog_post
      User.where( id: author.id ).delete_all
      show
      expect( response ).to be_successful
      expect( html.at_css( ".post-article__byline" ).text ).to include I18n.t( :deleted_user )
    end
  end

  describe "a post from another site" do
    let( :other_site ) { Site.make! }
    let( :other_post ) { Post.make!( parent: other_site, user: author, published_at: 1.hour.ago ) }

    before { Post.make!( parent: other_site, user: author, published_at: 1.day.ago ) }

    it "links back to that site's blog" do
      show( other_post )
      expect( html.at_css( ".post-article__back" )["href"] ).to eq "#{other_site.url}#{site_posts_path}"
    end

    it "links to that site's archive" do
      show( other_post )
      expect( html.at_css( ".post-other-posts__archive" )["href"] ).to eq "#{other_site.url}#{archives_site_posts_path}"
    end

    it "keeps relative links for the current site's posts" do
      show
      expect( html.at_css( ".post-article__back" )["href"] ).to eq site_posts_path
    end
  end

  describe "link previews" do
    it "uses the cover image for og:image" do
      cover = add_cover( blog_post )
      show
      expect( assigns( :shareable_image_url ) ).to include cover.file.url( :original ).split( "?" ).first
    end

    it "falls back to the first body image without a cover" do
      post = Post.make!( parent: site, user: author, body: "<img src='https://example.org/a.png'>" )
      show( post )
      expect( assigns( :shareable_image_url ) ).to eq "https://example.org/a.png"
    end
  end

  describe "cover" do
    it "shows the hero with its alt text and a caption of caption and attribution" do
      add_cover( blog_post, caption: "Riverweed on a rock", attribution: "Photo © seastarya, CC BY-NC" )
      show
      expect( html.at_css( ".post-article__hero img" )["alt"] ).to eq "A heron on a rock"
      expect( html.at_css( ".post-article__hero figcaption" ).text.squish ).to eq(
        "Riverweed on a rock. Photo © seastarya, CC BY-NC"
      )
    end

    it "shows either caption part alone" do
      add_cover( blog_post, attribution: "Photo © seastarya" )
      show
      expect( html.at_css( ".post-article__hero figcaption" ).text.squish ).to eq "Photo © seastarya"
    end

    it "has no caption when caption and attribution are empty" do
      add_cover( blog_post )
      show
      expect( html.at_css( ".post-article__hero figcaption" ) ).to be_nil
    end

    it "has no hero without a cover" do
      show
      expect( html.at_css( ".post-article__hero" ) ).to be_nil
    end
  end

  describe "category and tags" do
    it "shows the category label and tags as plain text" do
      blog_post.update!(
        blog_category: BlogCategory.make!( site: site, label: "Behind the Observation" ),
        tag_list: "herons, rivers"
      )
      show
      expect( html.at_css( ".post-article__category" ).text.squish ).to eq "Behind the Observation"
      expect( html.css( ".post-article__tags li" ).map {| li | li.text.squish } ).to match_array %w(#herons #rivers)
      expect( html.css( ".post-article__tags a, .post-article__category a" ) ).to be_empty
    end

    it "has no tags row without tags" do
      show
      expect( html.at_css( ".post-article__tags" ) ).to be_nil
    end
  end

  describe "body" do
    it "renders inside the post content" do
      show
      content = html.at_css( ".post-article__content" )
      expect( content["tabindex"] ).to be_nil
      expect( content.text ).to include blog_post.body
    end

    it "wraps each table in its own scroller" do
      blog_post.update!( body: "<table><tr><td>a</td></tr></table><p>between</p><table><tr><td>b</td></tr></table>" )
      show
      scrollers = html.css( ".post-article__content > .post-article__table-scroll" )
      expect( scrollers.size ).to eq 2
      expect( scrollers.map {| s | s.at_css( "> table" ).text } ).to eq %w(a b)
    end

    it "leaves tables nested in a table unwrapped" do
      blog_post.update!( body: "<table><tr><td><table><tr><td>inner</td></tr></table></td></tr></table>" )
      show
      expect( html.css( ".post-article__table-scroll" ).size ).to eq 1
    end
  end

  describe "comments" do
    it "offers to read all comments when there are some" do
      2.times { Comment.make!( parent: blog_post ) }
      show
      expect( html.at_css( ".post-comments summary" ).text.squish ).to include "Read all 2 comments"
    end

    it "says there are no comments yet" do
      show
      expect( html.at_css( ".post-comments summary" ) ).to be_nil
      expect( html.at_css( ".post-comments" ).text ).to include "No comments yet"
    end

    it "asks logged-out readers to sign in" do
      show
      expect( html.at_css( ".post-comments a[href='#{login_path}']" ).text.squish ).to eq "Sign in to comment"
      expect( html.at_css( ".post-comments form" ) ).to be_nil
    end

    it "gives signed-in readers the comment form" do
      sign_in make_user_with_privilege( UserPrivilege::INTERACTION )
      Comment.make!( parent: blog_post )
      show
      form = html.at_css( ".post-comments form" )
      expect( form.at_css( "input[type=submit]" )["value"] ).to eq "Post comment"
      expect( form.text ).not_to include "Preview"
    end

    it "says comments are disabled instead of inviting readers to comment" do
      blog_post.update!( prefers_no_comments: true )
      show
      expect( html.at_css( ".post-comments" ).text ).to include "Comments have been disabled"
      expect( html.at_css( ".post-comments" ).text ).not_to include "No comments yet"
      expect( html.at_css( ".post-comments a[href='#{login_path}']" ) ).to be_nil
    end

    it "says comments are disabled under existing comments" do
      Comment.make!( parent: blog_post )
      blog_post.update!( prefers_no_comments: true )
      show
      expect( html.at_css( ".post-comments summary" ) ).not_to be_nil
      expect( html.at_css( ".post-comments" ).text ).to include "Comments have been disabled"
    end

    it "hides flagged comments" do
      c = Comment.make!( parent: blog_post )
      Flag.make!( flaggable: c, flag: Flag::INAPPROPRIATE )
      show
      expect( response.body ).not_to include c.body
    end
  end

  describe "without Bootstrap" do
    it "renders the page outside Bootstrap's scope" do
      show
      expect( html.at_css( ".post-page" ).ancestors( ".bootstrap" ) ).to be_empty
    end

    it "keeps Bootstrap's scope for journal posts" do
      get :show, params: { id: Post.make!( parent: author, user: author, published_at: 1.hour.ago ).id }
      expect( html.at_css( "#wrapper.bootstrap" ) ).not_to be_nil
    end

    it "uses no Bootstrap component classes" do
      commenter = make_user_with_privilege( UserPrivilege::INTERACTION )
      Comment.make!( parent: blog_post, user: commenter )
      sign_in author
      show
      page = html.at_css( ".post-page" )
      expect( page.css( ".btn, .alert, .form-control, [data-toggle]" ) ).to be_empty
    end

    it "marks an unpublished post as a preview with a notice" do
      sign_in author
      show( Post.make!( parent: site, user: author, published_at: nil ) )
      expect( html.at_css( ".post-page > .inat-notice" )&.text&.squish ).to eq "Preview"
    end

    it "gives the comment form a labeled textarea and shared buttons" do
      sign_in make_user_with_privilege( UserPrivilege::INTERACTION )
      show
      form = html.at_css( ".post-comments form" )
      textarea = form.at_css( "textarea.inat-input" )
      expect( form.at_css( "label[for='#{textarea['id']}']" ).text.squish ).to eq "Add a comment"
      expect( form.at_css( "input[type=submit].inat-button--primary" )["value"] ).to eq "Post comment"
      expect( form.at_css( ".commentpreviewbutton" ) ).to be_nil
    end

    it "asks readers who can't interact yet to confirm their email instead of showing the form" do
      sign_in User.make!
      show
      comments = html.at_css( ".post-comments" )
      expect( comments.at_css( "form textarea" ) ).to be_nil
      expect( comments.at_css( "a.inat-button.emailConfirmationModalTrigger" ) ).not_to be_nil
    end

    describe "a comment" do
      let( :commenter ) { User.make! }
      let!( :comment ) { Comment.make!( parent: blog_post, user: commenter, body: "What a cool plant!" ) }

      def comment_item
        html.at_css( "#activity_comment_#{comment.uuid}.post-comment" )
      end

      it "shows the commenter, when they commented and what they said" do
        show
        expect( comment_item.at_css( ".post-comment__who" )["href"] ).to eq person_path( commenter )
        expect( comment_item.at_css( ".post-comment__who" ).text.squish ).to eq commenter.login
        expect( comment_item.at_css( "time" )["datetime"] ).to eq comment.created_at.iso8601
        expect( comment_item.at_css( ".post-comment__body" ).text ).to include "What a cool plant!"
      end

      it "lets the commenter edit and delete it" do
        sign_in commenter
        show
        links = comment_item.css( ".post-comment__actions a" ).map {| a | a.text.squish }
        expect( links ).to include( "Edit", "Delete" )
      end

      it "lets other signed-in readers flag it but not edit it" do
        sign_in User.make!
        show
        links = comment_item.css( ".post-comment__actions a" ).map {| a | a.text.squish }
        expect( links ).to include "Flag"
        expect( links ).not_to include "Edit"
      end

      it "shows no actions to logged-out readers" do
        show
        expect( comment_item.at_css( ".post-comment__actions" ) ).to be_nil
      end

      it "hides the text of a hidden comment from other readers" do
        ModeratorAction.make!( resource: comment, action: ModeratorAction::HIDE )
        show
        expect( comment_item.text ).not_to include "What a cool plant!"
        expect( comment_item.text ).to include "Content Hidden"
      end
    end
  end

  describe "kept features" do
    it "shows the edit button to its author" do
      sign_in author
      show
      expect( html.at_css( ".post-article__title-row a.inat-button" )&.text ).to eq "Edit"
    end

    it "hides the edit button from other users" do
      sign_in User.make!
      show
      expect( html.at_css( ".post-article__title-row a" ) ).to be_nil
    end

    it "shows linked observations" do
      blog_post.observations << Observation.make!
      show
      expect( html.at_css( "#observations" ) ).not_to be_nil
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

describe PostsController, "search" do
  let!( :site_post ) { Post.make!( body: "this is the post body", parent: Site.default ) }
  let( :user ) { User.make! }
  let!( :user_post ) { Post.make!( body: "this is the post body", parent: user ) }

  it "returns matching site posts" do
    get :search, params: { q: "post body" }
    expect( assigns( :posts ).size ).to eq 1
    expect( assigns( :posts ) ).to include( site_post )
  end

  it "returns nothing on non-matching posts" do
    get :search, params: { q: "nonsense" }
    expect( assigns( :posts ) ).to eq []
  end

  it "returns matching user posts" do
    get :search, params: { q: "post body", post: { parent_type: "User", parent_id: user.id } }
    expect( assigns( :posts ).size ).to eq 1
    expect( assigns( :posts ) ).to include( user_post )
  end

  it "returns nothing on non-matching user posts" do
    get :search, params: { q: "nonsense", post: { parent_type: "User", parent_id: user.id } }
    expect( assigns( :posts ) ).to eq []
  end
end
