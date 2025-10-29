# frozen_string_literal: true

require "spec_helper"

describe Post do
  it { is_expected.to belong_to :parent }
  it { is_expected.to belong_to :user }
  it { is_expected.to have_many( :comments ).dependent :destroy }

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
    let( :u ) { User.make! }
    let( :project ) { Project.make! }
    it "knows what users have been mentioned" do
      p = Post.make!( body: "hey @#{u.login}", parent: project )
      expect( p.mentioned_users ).to eq [u]
    end

    describe "mention updates" do
      it "generate for published posts" do
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
        expect( UpdateAction.unviewed_by_user_from_query( u.id, {} ) ).to eq false
        p = Post.make!( :draft, body: "hey @#{u.login}", parent: project )
        expect( p ).not_to be_published
        expect( UpdateAction.unviewed_by_user_from_query( u.id, {} ) ).to eq false
      end

      it "generate for drafts when they're published" do
        expect( UpdateAction.unviewed_by_user_from_query( u.id, {} ) ).to eq false
        p = Post.make!( :draft, body: "hey @#{u.login}", parent: project )
        expect( p ).not_to be_published
        expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: p ) ).to eq false
        p.update( published_at: Time.now )
        expect( p ).to be_published
        expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: p ) ).to eq true
      end

      it "does not generate a mention update if the body was not updated after the initial action expired out" do
        expect( UpdateAction.unviewed_by_user_from_query( u.id, {} ) ).to eq false
        p = without_delay { Post.make!( body: "hey @#{u.login}", parent: project ) }
        expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: p ) ).to eq true
        UpdateAction.user_viewed_updates( UpdateAction.where( notifier: p ), u.id )
        expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: p ) ).to eq false
        # Delete from UpdateAction to simulate expiring out after 90 days
        UpdateAction.elastic_delete_by_ids!( UpdateAction.where( notifier: p ).map( &:id ) )
        UpdateAction.where( notifier: p ).delete_all

        after_delayed_job_finishes( ignore_run_at: true ) do
          without_delay { p.update( title: "A Title" ) }
        end
        expect( UpdateAction.where( notifier: p ) ).to be_empty
        expect( UpdateAction.unviewed_by_user_from_query( u.id, {} ) ).to eq false
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
end
