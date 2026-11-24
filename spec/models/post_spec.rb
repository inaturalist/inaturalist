# frozen_string_literal: true

require "spec_helper"

describe Post do
  it { is_expected.to belong_to :parent }
  it { is_expected.to belong_to :user }
  it { is_expected.to have_many( :comments ).dependent :destroy }
  it { is_expected.to have_many( :post_images ).dependent :destroy }
  it { is_expected.to belong_to( :cover_image ).class_name( "PostImage" ).optional }
  it { is_expected.to belong_to( :blog_category ).optional }

  it { is_expected.to validate_length_of( :title ).is_at_least( 1 ).is_at_most 2000 }
  it { is_expected.to validate_presence_of :parent }

  before { enable_has_subscribers }
  after { disable_has_subscribers }

  describe "creation" do
    it "should not generate jobs if it's a draft" do
      friendship = Friendship.make
      expect do
        Post.make( :draft, user: friendship.friend )
      end.to_not change( Delayed::Job, :count )
    end

    it "should not generate an update for the owner" do
      u = User.make!
      post = without_delay { Post.make!( user: u, parent: u ) }
      expect( UpdateAction.where( notifier_type: "Post", notifier_id: post.id ).first ).to be_blank
    end

    it "should not be published if user created in the last 24 hours" do
      u = User.make!( created_at: Time.now )
      p = Post.make( published_at: Time.now, user: u )
      expect( p ).not_to be_valid
      expect( p.errors[:user] ).not_to be_blank
    end
  end

  describe "update" do
    it "should generate an update if the post was just published" do
      f = Friendship.make!
      post = without_delay { Post.make!( :draft, parent: f.friend ) }
      expect( post ).not_to be_published
      UpdateAction.destroy_all
      expect( UpdateAction.unviewed_by_user_from_query( f.user_id, notifier: post ) ).to eq false
      without_delay { post.update( body: "#{post.body} something else", published_at: Time.now ) }
      expect( UpdateAction.unviewed_by_user_from_query( f.user_id, notifier: post ) ).to eq true
    end
    it "should not generate updates if body changed by published_at didn't" do
      f = Friendship.make!
      post = without_delay { Post.make!( parent: f.friend, published_at: Time.now ) }
      UpdateAction.destroy_all
      expect( UpdateAction.unviewed_by_user_from_query( f.user_id, notifier: post ) ).to eq false
      without_delay { post.update( body: "#{post.body} something else" ) }
      expect( UpdateAction.unviewed_by_user_from_query( f.user_id, notifier: post ) ).to eq false
    end
  end

  describe "publish" do
    describe "for a project" do
      let( :project ) { Project.make! }
      let( :post ) { Post.make!( :draft, parent: project, user: project.user ) }

      it "should generate an update for a project user" do
        pu = ProjectUser.make!( project: project )
        expect( UpdateAction.unviewed_by_user_from_query( pu.user_id, notifier: post ) ).to eq false
        without_delay do
          post.update( published_at: Time.now )
        end
        expect( UpdateAction.unviewed_by_user_from_query( pu.user_id, notifier: post ) ).to eq true
      end

      it "should not generate an update for a project user if they don't prefer it" do
        pu = ProjectUser.make!( project: project, prefers_updates: false )
        expect( UpdateAction.unviewed_by_user_from_query( pu.user_id, notifier: post ) ).to eq false
        without_delay do
          post.update( published_at: Time.now )
        end
        expect( UpdateAction.unviewed_by_user_from_query( pu.user_id, notifier: post ) ).to eq false
      end

      it "should notify subscribers of collection projects" do
        u = User.make!
        Subscription.make!( user: u, resource: project )
        without_delay do
          post.update( published_at: Time.now )
        end
        expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: post ) ).to eq true
      end
    end

    describe "for a user" do
      it "should increment the user's counter cache" do
        u = User.make!
        expect( u.journal_posts_count ).to eq 0
        p = Post.make!( :draft, parent: u, user: u )
        u.reload
        expect( p ).not_to be_published
        expect( u.journal_posts_count ).to eq 0
        p.update( published_at: Time.now )
        expect( p ).to be_published
        u.reload
        expect( u.journal_posts_count ).to eq 1
      end
    end
  end

  describe "unpublish" do
    describe "for a user" do
      it "should decrement the user's counter cache" do
        u = User.make!
        expect( u.journal_posts_count ).to eq 0
        p = Post.make!( parent: u, user: u )
        u.reload
        expect( u.journal_posts_count ).to eq 1
        p.update( published_at: nil )
        u.reload
        expect( u.journal_posts_count ).to eq 0
      end
    end
  end

  describe "destroy" do
    describe "for a user" do
      it "should decrement the user's counter cache" do
        u = User.make!
        expect( u.journal_posts_count ).to eq 0
        p = Post.make!( parent: u, user: u )
        u.reload
        expect( u.journal_posts_count ).to eq 1
        p.destroy
        u.reload
        expect( u.journal_posts_count ).to eq 0
      end
    end
  end

  describe "creation for project" do
    it "should generate an update for the owner" do
      p = Project.make!
      u = p.user
      expect( UpdateAction.unviewed_by_user_from_query( u.id, {} ) ).to eq false
      post = without_delay { Post.make!( user: u, parent: p ) }
      expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: post ) ).to eq true
    end
  end

  describe "creation for user" do
    it "should generate updates for followers" do
      f = Friendship.make!
      expect( UpdateAction.unviewed_by_user_from_query( f.user_id, {} ) ).to eq false
      post = without_delay { Post.make!( parent: f.friend ) }
      expect( UpdateAction.unviewed_by_user_from_query( f.user_id, notifier: post ) ).to eq true
    end
  end

  describe "mentions" do
    it "knows what users have been mentioned" do
      u = User.make!
      project = Project.make!
      p = Post.make!( body: "hey @#{u.login}", parent: project )
      expect( p.mentioned_users ).to eq [u]
    end

    describe "mention updates" do
      it "generate for published posts" do
        u = User.make!
        project = Project.make!
        expect( UpdateAction.unviewed_by_user_from_query( u.id, {} ) ).to eq false
        p = Post.make!( body: "hey @#{u.login}", parent: project )
        expect( p ).to be_published
        expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: p ) ).to eq true
      end

      it "generates updates for subscribers and mentioned users" do
        mentioned_user = User.make!
        subscribed_user = UserPrivilege.make!( privilege: UserPrivilege::INTERACTION ).user
        posting_user = User.make!
        Subscription.make!( user: subscribed_user, resource: posting_user )
        expect( UpdateAction.unviewed_by_user_from_query( mentioned_user.id, {} ) ).to eq false
        expect( UpdateAction.unviewed_by_user_from_query( subscribed_user.id, {} ) ).to eq false
        p = Post.make!(
          body: "hey @#{mentioned_user.login}",
          user: posting_user,
          parent: posting_user,
          published_at: nil
        )

        # the post is not published so no one will be mentioned yet
        expect( p ).not_to be_published
        expect( UpdateAction.unviewed_by_user_from_query( mentioned_user.id, {} ) ).to eq false
        expect( UpdateAction.unviewed_by_user_from_query( subscribed_user.id, {} ) ).to eq false
        p.update( published_at: Time.now )
        Delayed::Job.all.each {| j | Delayed::Worker.new.run( j ) }

        # now that the post is published and delayed jobs have run, both the mentioned
        # user and the subscribed user should have notifications
        expect( UpdateAction.unviewed_by_user_from_query(
          mentioned_user.id, notifier: p
        ) ).to eq true
        expect( UpdateAction.unviewed_by_user_from_query(
          subscribed_user.id, notifier: p
        ) ).to eq true
      end

      it "do not generate for drafts" do
        u = User.make!
        project = Project.make!
        expect( UpdateAction.unviewed_by_user_from_query( u.id, {} ) ).to eq false
        p = Post.make!( :draft, body: "hey @#{u.login}", parent: project )
        expect( p ).not_to be_published
        expect( UpdateAction.unviewed_by_user_from_query( u.id, {} ) ).to eq false
      end

      it "generate for drafts when they're published" do
        u = User.make!
        project = Project.make!
        expect( UpdateAction.unviewed_by_user_from_query( u.id, {} ) ).to eq false
        p = Post.make!( :draft, body: "hey @#{u.login}", parent: project )
        expect( p ).not_to be_published
        expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: p ) ).to eq false
        p.update( published_at: Time.now )
        expect( p ).to be_published
        expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: p ) ).to eq true
      end
    end
  end

  describe "search" do
    it "returns search results" do
      user = User.make!
      post1 = Post.make!( title: "nonsense title", body: "this is a test", parent: user )
      post2 = Post.make!( title: "this is a test", body: "nonsense body", parent: user )
      expect( Post.dbsearch( user, "test" ).size ).to eq 2
      expect( Post.dbsearch( user, "test" ) ).to include( post1 )
      expect( Post.dbsearch( user, "test" ) ).to include( post2 )

      expect( Post.dbsearch( user, "title" ).size ).to eq 1
      expect( Post.dbsearch( user, "title" ) ).to include( post1 )

      expect( Post.dbsearch( user, "body" ).size ).to eq 1
      expect( Post.dbsearch( user, "body" ) ).to include( post2 )
    end
  end

  def journal_post( attrs = {} )
    author = User.make!
    Post.make( { user: author, parent: author }.merge( attrs ) )
  end

  it "builds valid journal posts for the specs below" do
    expect( journal_post ).to be_valid
  end

  describe "blog category" do
    let( :category ) { BlogCategory.make! }

    it "is valid on a post for the category's site" do
      expect( Post.make( parent: category.site, blog_category: category ) ).to be_valid
    end

    it "is invalid on a post for another site" do
      post = Post.make( parent: Site.make!, blog_category: category )
      expect( post ).not_to be_valid
      expect( post.errors.added?( :blog_category, :must_belong_to_post_site ) ).to be true
    end

    it "is invalid on a non-Site post" do
      post = journal_post( blog_category: category )
      expect( post ).not_to be_valid
      expect( post.errors.added?( :blog_category_id, :only_allowed_on_site_posts ) ).to be true
    end
  end

  describe "featured flags" do
    it "are valid on a Site post" do
      expect( Post.make( parent: Site.make!, featured_at: Time.now, mobile_featured_at: Time.now ) ).to be_valid
    end

    it "are invalid on a non-Site post" do
      %i[featured_at mobile_featured_at].each do | attr |
        post = journal_post( attr => Time.now )
        expect( post ).not_to be_valid
        expect( post.errors.added?( attr, :only_allowed_on_site_posts ) ).to be true
      end
    end

    describe "featured=" do
      let( :post ) { Post.make( parent: Site.make! ) }

      it "sets featured_at to now when checked" do
        post.featured = "1"
        expect( post.featured_at ).to be_within( 5.seconds ).of( Time.now )
        expect( post.featured ).to be true
      end

      it "keeps an existing featured_at when checked again" do
        original = 3.days.ago.change( usec: 0 )
        post.featured_at = original
        post.featured = "1"
        expect( post.featured_at ).to eq original
      end

      it "clears featured_at when unchecked" do
        post.featured_at = Time.now
        post.featured = "0"
        expect( post.featured_at ).to be_nil
        expect( post.featured ).to be false
      end
    end

    describe "mobile_featured=" do
      let( :post ) { Post.make( parent: Site.make! ) }

      it "sets mobile_featured_at to now when checked" do
        post.mobile_featured = "1"
        expect( post.mobile_featured_at ).to be_within( 5.seconds ).of( Time.now )
        expect( post.mobile_featured ).to be true
      end

      it "keeps an existing mobile_featured_at when checked again" do
        original = 3.days.ago.change( usec: 0 )
        post.mobile_featured_at = original
        post.mobile_featured = "1"
        expect( post.mobile_featured_at ).to eq original
      end

      it "clears mobile_featured_at when unchecked" do
        post.mobile_featured_at = Time.now
        post.mobile_featured = "0"
        expect( post.mobile_featured_at ).to be_nil
        expect( post.mobile_featured ).to be false
      end
    end
  end

  describe "cover image" do
    let( :post ) { Post.make!( :draft, parent: Site.make! ) }

    it "must belong to the post" do
      post.cover_image = PostImage.make!( post: Post.make!( parent: post.parent ), alt: "A heron" )
      expect( post ).not_to be_valid
      expect( post.errors.added?( :cover_image, :must_be_one_of_the_post_images ) ).to be true
    end

    it "can be one of the post's images" do
      post.cover_image = PostImage.make!( post: post, alt: "A heron" )
      expect( post ).to be_valid
    end

    it "needs alt text to publish" do
      post.cover_image = PostImage.make!( post: post, alt: nil )
      expect( post ).to be_valid
      post.published_at = Time.now
      expect( post ).not_to be_valid
      expect( post.errors.added?( :cover_image, :needs_alt_text_to_publish ) ).to be true
    end

    it "doesn't require alt text on body images to publish" do
      PostImage.make!( post: post, alt: nil )
      post.published_at = Time.now
      expect( post ).to be_valid
    end
  end

  describe "locale" do
    it "can be blank or a supported locale" do
      expect( journal_post( locale: nil ) ).to be_valid
      expect( journal_post( locale: "es" ) ).to be_valid
    end

    it "can't be an unsupported locale" do
      expect( journal_post( locale: "xx" ) ).not_to be_valid
    end
  end

  describe "tags" do
    it "can't exceed 750 characters" do
      post = journal_post( tag_list: Array.new( 76 ) {| i | "tag#{i.to_s.rjust( 6, '0' )}" } )
      expect( post ).not_to be_valid
      expect( post.errors.added?( :tag_list, :too_long ) ).to be true
    end
  end

  describe "in_category" do
    it "returns posts in the category with that slug" do
      category = BlogCategory.make!
      in_category = Post.make!( parent: category.site, blog_category: category )
      Post.make!( parent: category.site )
      expect( Post.in_category( category.slug ) ).to eq [in_category]
    end
  end

  describe "featured scopes" do
    let( :site ) { Site.make! }

    it "returns featured Site posts, newest featured first" do
      older = Post.make!( parent: site, featured_at: 2.days.ago )
      newer = Post.make!( parent: site, featured_at: 1.day.ago )
      Post.make!( parent: site )
      expect( site.posts.featured ).to eq [newer, older]
    end

    it "returns app-featured Site posts, newest featured first" do
      older = Post.make!( parent: site, mobile_featured_at: 2.days.ago )
      newer = Post.make!( parent: site, mobile_featured_at: 1.day.ago )
      Post.make!( parent: site, featured_at: Time.now )
      expect( site.posts.mobile_featured ).to eq [newer, older]
    end

    # Notify if future scope rewrites query without the partial index
    describe "query plans" do
      before { ActiveRecord::Base.connection.execute( "SET enable_seqscan = off" ) }
      after { ActiveRecord::Base.connection.execute( "RESET enable_seqscan" ) }

      it "uses the partial index for featured" do
        expect( site.posts.featured.limit( 5 ).explain ).to include "index_posts_on_site_featured"
      end

      it "uses the partial index for mobile_featured" do
        expect( site.posts.mobile_featured.limit( 5 ).explain ).to include "index_posts_on_site_mobile_featured"
      end
    end
  end

  describe "as_indexed_json" do
    it "indexes the post's fields" do
      author = User.make!( login: "indexedauthor", name: "Indexed Author" )
      post = Post.make!( user: author, parent: author, title: "A title", locale: "es", tag_list: ["Fungi"] )
      Comment.make!( parent: post )
      json = post.as_indexed_json
      expect( json ).to include(
        id: post.id,
        uuid: post.uuid,
        parent_type: "User",
        parent_id: author.id,
        title: "A title",
        tags: ["fungi"],
        published: true,
        spam: false,
        locale: "es",
        comments_count: 1,
        published_at: post.published_at
      )
      expect( json[:user] ).to eq( id: author.id, login: "indexedauthor", name: "Indexed Author", spammer: false )
      expect( json ).not_to have_key( :blog_category_id )
    end

    describe "site_id" do
      it "is the site for a Site post" do
        site = Site.make!
        post = Post.make!( parent: site )
        expect( post.as_indexed_json[:site_id] ).to eq site.id
      end

      it "is the author's site for a User post" do
        site = Site.make!
        author = User.make!( site: site )
        post = Post.make!( user: author, parent: author )
        expect( post.as_indexed_json[:site_id] ).to eq site.id
      end

      it "is nil for a Project post" do
        project = Project.make!
        post = Post.make!( user: project.user, parent: project )
        expect( post.as_indexed_json[:site_id] ).to be_nil
      end
    end

    describe "body" do
      it "strips HTML and script content, keeping words apart" do
        html = "<p>First<br>line</p><script>alert('x')</script><p>Second <b>line</b></p>"
        post = journal_post( body: html ).tap( &:save! )
        expect( post.as_indexed_json[:body] ).to eq "First line Second line"
      end

      it "indexes a nil body as empty" do
        post = journal_post.tap( &:save! )
        post.update_column( :body, nil )
        json = post.as_indexed_json
        expect( json[:body] ).to eq ""
        expect( json[:body_excerpt] ).to eq ""
      end

      it "caps the indexed text and keeps a short excerpt" do
        post = journal_post( body: "word " * 30_000 ).tap( &:save! )
        json = post.as_indexed_json
        expect( json[:body].length ).to eq Post::INDEXED_BODY_MAX_LENGTH
        expect( json[:body_excerpt].length ).to be <= Post::BODY_EXCERPT_LENGTH
      end
    end

    it "marks drafts unpublished" do
      post = journal_post( published_at: nil ).tap( &:save! )
      expect( post.as_indexed_json[:published] ).to be false
    end

    it "marks posts flagged as spam" do
      post = journal_post.tap( &:save! )
      Flag.make!( flaggable: post, flag: Flag::SPAM )
      expect( post.as_indexed_json[:spam] ).to be true
    end

    it "marks posts by spammers" do
      post = journal_post.tap( &:save! )
      post.user.update_column( :spammer, true )
      json = post.as_indexed_json
      expect( json[:user][:spammer] ).to be true
      expect( json[:spam] ).to be false
    end

    it "counts comments for a batch in one query" do
      with_comments = journal_post.tap( &:save! )
      2.times { Comment.make!( parent: with_comments ) }
      without_comments = journal_post.tap( &:save! )
      batch = Post.where( id: [with_comments.id, without_comments.id] ).to_a
      Post.prepare_batch_for_index( batch )
      counts = batch.to_h {| post | [post.id, post.as_indexed_json[:comments_count]] }
      expect( counts ).to eq( with_comments.id => 2, without_comments.id => 0 )
    end
  end

  describe "posts index" do
    it "does not use dynamic mappings" do
      expect( Post.mappings.to_hash[:dynamic] ).to be false
    end

    it "keeps the body in _source without storing it separately" do
      mapping = Post.mappings.to_hash
      expect( mapping ).not_to have_key( :_source )
      expect( mapping[:properties][:body] ).not_to have_key( :store )
    end

    describe "documents" do
      before { enable_elastic_indexing( Post, use_transactional_fixtures: false ) }

      it "have the body in _source" do
        post = journal_post( body: "<p>A pangolin crossed the road.</p>" ).tap( &:save! )
        Post.elastic_index!( ids: [post.id] )
        expect( Post.elastic_get( post.id )["_source"]["body"] ).to eq "A pangolin crossed the road."
      end
    end
  end

  describe "prune_batch_for_index" do
    it "drops trips" do
      post = journal_post.tap( &:save! )
      trip = Trip.make!
      expect( Post.prune_batch_for_index( [post, trip] ) ).to eq [post]
    end
  end

  describe "elastic_index!" do
    it "does not index a trip" do
      trip = Trip.make!
      expect( trip.__elasticsearch__ ).not_to receive( :index_document )
      expect { trip.elastic_index! }.not_to raise_error
    end
  end

  describe "with Elasticsearch callbacks off" do
    # Run this file with E2E_EAGER_LOAD=true to check the eager load order
    it "installs no Elasticsearch commit callbacks" do
      elastic_callbacks = Post._commit_callbacks.select do | callback |
        callback.raw_filter.is_a?( Proc ) &&
          callback.raw_filter.source_location.first.end_with?( "elastic_model/acts_as_elastic_model.rb" )
      end
      expect( elastic_callbacks ).to be_empty
    end

    describe "comments" do
      before { enable_elastic_indexing( Post, use_transactional_fixtures: false ) }

      def posts_index_count
        Post.__elasticsearch__.refresh_index!
        Post.__elasticsearch__.client.count( index: Post.index_name )["count"]
      end

      it "do not index the post" do
        post = journal_post.tap( &:save! )
        expect( post ).not_to receive( :elastic_index! )
        Comment.make!( parent: post )
        expect( posts_index_count ).to eq 0
      end

      it "do not index a trip" do
        trip = Trip.make!
        expect( trip ).not_to receive( :elastic_index! )
        Comment.make!( parent: trip )
        expect( posts_index_count ).to eq 0
      end
    end
  end
end
