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
      expect( Post.make( parent: Site.make!, blog_category: category ) ).not_to be_valid
    end

    it "is invalid on a non-Site post" do
      expect( journal_post( blog_category: category ) ).not_to be_valid
    end
  end

  describe "featured flags" do
    it "are valid on a Site post" do
      expect( Post.make( parent: Site.make!, featured_at: Time.now, mobile_featured_at: Time.now ) ).to be_valid
    end

    it "are invalid on a non-Site post" do
      expect( journal_post( featured_at: Time.now ) ).not_to be_valid
      expect( journal_post( mobile_featured_at: Time.now ) ).not_to be_valid
    end
  end

  describe "cover image" do
    let( :post ) { Post.make!( :draft, parent: Site.make! ) }

    it "must belong to the post" do
      post.cover_image = PostImage.make!( post: Post.make!( parent: post.parent ), alt: "A heron" )
      expect( post ).not_to be_valid
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
      expect( journal_post( tag_list: Array.new( 76 ) {| i | "tag#{i.to_s.rjust( 6, '0' )}" } ) ).not_to be_valid
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
end
