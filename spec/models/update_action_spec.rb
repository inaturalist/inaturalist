require File.dirname(__FILE__) + '/../spec_helper.rb'

describe UpdateAction do
  before { enable_has_subscribers }
  after { disable_has_subscribers }

  describe "creation" do
    it "should set resource owner" do
      o = Observation.make!
      u = UpdateAction.make!(resource: o)
      expect( u.resource_owner_id ).to eq o.user_id
    end
  end

  describe "email_updates_to_user" do
    it "should deliver an email" do
      o = Observation.make!
      s = Subscription.make!(resource: o)
      u = s.user
      expect( UpdateAction.unviewed_by_user_from_query(u.id, { }) ).to eq false
      without_delay do
        c = Comment.make!(parent: o)
      end
      expect( UpdateAction.unviewed_by_user_from_query(u.id, { }) ).to eq true
      expect {
        UpdateAction.email_updates_to_user(u, 10.minutes.ago, Time.now)
      }.to change(ActionMailer::Base.deliveries, :size).by(1)
    end

    describe "with user preferences should filter" do
      let( :user ) { User.make! }

      def test_preference( preference, &block )
        emailer_spy = spy( Emailer )
        stub_const( "Emailer", emailer_spy )
        user.update_attributes( "prefers_#{preference}" => false )
        yield( user )
        Delayed::Worker.new.work_off
        UpdateAction.email_updates_to_user( user, 10.minutes.ago, Time.now )
        expect( emailer_spy ).not_to have_received( :updates_notification )
      end
      
      it "comment_email_notification" do
        test_preference( "comment_email_notification" ) do |u|
          Comment.make!( parent: Observation.make!( user: u ) )
        end
      end
      it "identification_email_notification " do
        test_preference( "identification_email_notification" ) do |u|
          Identification.make!( observation: Observation.make!( user: u ) )
        end
      end
      it "mention_email_notification" do
        test_preference( "mention_email_notification" ) do |u|
          Comment.make!( parent: Observation.make!, body: "hey @#{u.login}" )
        end
      end
      it "message_email_notification" do
        test_preference( "message_email_notification" ) do |u|
          sender = User.make!
          Message.make!( user: sender, from_user: sender, to_user: u )
        end
      end
      it "project_journal_post_email_notification" do
        test_preference( "project_journal_post_email_notification" ) do |u|
          pu = ProjectUser.make!( user: u )
          Post.make!( parent: pu.project )
        end
      end
      it "project_added_your_observation_email_notification" do
        test_preference( "project_added_your_observation_email_notification" ) do |u|
          ProjectObservation.make!( observation: Observation.make!( user: u ) )
        end
      end
      it "project_curator_change_email_notification" do
        test_preference( "project_curator_change_email_notification" ) do |u|
          pu = ProjectUser.make!( user: u )
          ProjectUser.make!( project: pu.project, role: ProjectUser::CURATOR )
        end
      end
      it "taxon_change_email_notification" do
        test_preference( "taxon_change_email_notification" ) do |u|
          swap = make_taxon_swap
          Observation.make!( user: u, taxon: swap.input_taxon )
          swap.committer = make_curator
          swap.commit
        end
      end
      it "user_observation_email_notification" do
        test_preference( "user_observation_email_notification" ) do |u|
          f = Friendship.make!( user: u )
          Observation.make!( user: f.friend )
        end
      end
      it "taxon_or_place_observation_email_notification" do
        test_preference( "taxon_or_place_observation_email_notification" ) do |u|
          t = Taxon.make!
          Subscription.make!( resource: t, user: u )
          Observation.make!( taxon: t )
        end
      end
    end
  end

  describe "delete_and_purge" do
    it "removes updates from ES and DB" do
      u = UpdateAction.make!
      expect(UpdateAction.count).to eq 1
      expect(UpdateAction.elastic_search.total_entries).to eq 1
      UpdateAction.delete_and_purge(id: u.id)
      expect(UpdateAction.count).to eq 0
      expect(UpdateAction.elastic_search.total_entries).to eq 0
    end
  end
end
