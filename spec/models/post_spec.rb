require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Post do
  before { enable_has_subscribers }
  after { disable_has_subscribers }

  describe "creation" do
    it "should not generate jobs if it's a draft" do
      friendship = Friendship.make
      user, friend = [friendship.user, friendship.friend]
      expect {
        Post.make(:draft, :user => friend)
      }.to_not change(Delayed::Job, :count)
    end

    it "should not generate an update for the owner" do
      u = User.make!
      post = without_delay {Post.make!(:user => u, :parent => u)}
      expect(UpdateAction.where(:notifier_type => "Post", :notifier_id => post.id).first).to be_blank
    end

    it "should not be published if user created in the last 24 hours" do
      u = User.make!(:created_at => Time.now)
      p = Post.make(:published_at => Time.now, :user => u)
      expect(p).not_to be_valid
      expect(p.errors[:user]).not_to be_blank
    end
  end

  describe "update" do
    it "should generate an update if the post was just published" do
      f = Friendship.make!
      post = without_delay { Post.make!( :draft, parent: f.friend ) }
      expect( post ).not_to be_published
      UpdateAction.destroy_all
      expect( UpdateAction.unviewed_by_user_from_query(f.user_id, notifier: post) ).to eq false
      without_delay { post.update_attributes( body: "#{post.body} something else", published_at: Time.now ) }
      expect( UpdateAction.unviewed_by_user_from_query(f.user_id, notifier: post) ).to eq true
    end
    it "should not generate updates if body changed by published_at didn't" do
      f = Friendship.make!
      post = without_delay { Post.make!( parent: f.friend, published_at: Time.now ) }
      UpdateAction.destroy_all
      expect( UpdateAction.unviewed_by_user_from_query(f.user_id, notifier: post) ).to eq false
      without_delay { post.update_attributes( body: "#{post.body} something else" ) }
      expect( UpdateAction.unviewed_by_user_from_query(f.user_id, notifier: post) ).to eq false
    end
  end

  describe "publish" do
    describe "for a project" do
      let(:project) { Project.make! }
      let(:post) { Post.make!( :draft, parent: project, user: project.user) }

      it "should generate an update for a project user" do
        pu = ProjectUser.make!(project: project)
        expect( UpdateAction.unviewed_by_user_from_query(pu.user_id, notifier: post) ).to eq false
        without_delay do
          post.update_attributes(published_at: Time.now)
        end
        expect( UpdateAction.unviewed_by_user_from_query(pu.user_id, notifier: post) ).to eq true
      end

      it "should not generate an update for a project user if they don't prefer it" do
        pu = ProjectUser.make!(project: project, prefers_updates: false)
        expect( UpdateAction.unviewed_by_user_from_query(pu.user_id, notifier: post) ).to eq false
        without_delay do
          post.update_attributes(published_at: Time.now)
        end
        expect( UpdateAction.unviewed_by_user_from_query(pu.user_id, notifier: post) ).to eq false
      end

      it "should notify subscribers of collection projects" do
        u = User.make!
        Subscription.make!( user: u, resource: project )
        without_delay do
          post.update_attributes( published_at: Time.now )
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
        p.update_attributes( published_at: Time.now )
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
        p.update_attributes( published_at: nil )
        u.reload
        expect( u.journal_posts_count ).to eq 0
      end
    end
  end

  describe "creation for project" do
    it "should generate an update for the owner" do
      p = Project.make!
      u = p.user
      expect( UpdateAction.unviewed_by_user_from_query(u.id, { }) ).to eq false
      post = without_delay {Post.make!(:user => u, :parent => p)}
      expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: post) ).to eq true
    end
  end

  describe "creation for user" do
    it "should generate updates for followers" do
      f = Friendship.make!
      expect( UpdateAction.unviewed_by_user_from_query(f.user_id, { }) ).to eq false
      post = without_delay { Post.make!(:parent => f.friend) }
      expect( UpdateAction.unviewed_by_user_from_query(f.user_id, notifier: post) ).to eq true
    end
  end

  describe "mentions" do
    it "knows what users have been mentioned" do
      u = User.make!
      project = Project.make!
      p = Post.make!(body: "hey @#{ u.login }", parent: project)
      expect( p.mentioned_users ).to eq [ u ]
    end

    describe "mention updates" do
      it "generate for published posts" do
        u = User.make!
        project = Project.make!
        expect( UpdateAction.unviewed_by_user_from_query(u.id, { }) ).to eq false
        p = Post.make!( body: "hey @#{ u.login }", parent: project )
        expect( p ).to be_published
        expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: p) ).to eq true
      end
      it "do not generate for drafts" do
        u = User.make!
        project = Project.make!
        expect( UpdateAction.unviewed_by_user_from_query(u.id, { }) ).to eq false
        p = Post.make!( :draft, body: "hey @#{ u.login }", parent: project )
        expect( p ).not_to be_published
        expect( UpdateAction.unviewed_by_user_from_query(u.id, { }) ).to eq false
      end

      it "generate for drafts when they're published" do
        u = User.make!
        project = Project.make!
        expect( UpdateAction.unviewed_by_user_from_query(u.id, { }) ).to eq false
        p = Post.make!( :draft, body: "hey @#{ u.login }", parent: project )
        expect( p ).not_to be_published
        expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: p) ).to eq false
        p.update_attributes( published_at: Time.now )
        expect( p ).to be_published
        expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: p) ).to eq true
      end

    end
  end
end
