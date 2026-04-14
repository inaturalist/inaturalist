# frozen_string_literal: true

require "spec_helper"

describe ModeratorAction do
  it { is_expected.to belong_to( :user ).inverse_of :moderator_actions }
  it { is_expected.to belong_to( :resource ).inverse_of :moderator_actions }

  it { is_expected.to validate_inclusion_of( :action ).in_array ModeratorAction::ACTIONS }
  it { is_expected.to validate_length_of( :reason ).is_at_least 10 }

  let( :generic_reason ) { Faker::Lorem.sentence }

  let( :admin ) { make_admin }
  let( :curator ) { make_curator }

  describe "create" do
    describe "HIDE" do
      it "should be possible for a comment" do
        expect(
          create( :moderator_action, action: ModeratorAction::HIDE,
            resource: create( :comment ), user: admin )
        ).to be_persisted
      end

      it "should not be possible for a user" do
        expect(
          build( :moderator_action, action: ModeratorAction::HIDE,
            resource: create( :user ), user: admin )
        ).not_to be_valid
      end

      it "should delete update actions for a comment" do
        enable_has_subscribers
        comment = after_delayed_job_finishes( ignore_run_at: true ) do
          create( :comment )
        end
        ua = UpdateAction.where( notifier: comment ).first
        expect( ua ).not_to be_blank
        after_delayed_job_finishes( ignore_run_at: true ) do
          create( :moderator_action, action: ModeratorAction::HIDE, resource: comment, user: admin )
        end
        ua = UpdateAction.where( notifier: comment ).first
        expect( ua ).to be_blank
        disable_has_subscribers
      end

      shared_examples_for "hiding media" do
        it "regular users cannot hide media" do
          action = ModeratorAction.create(
            action: ModeratorAction::HIDE,
            resource: resource,
            user: User.make!,
            reason: generic_reason
          )
          expect( action ).not_to be_valid
          expect( action.errors.any? do | e |
            e.type == :only_staff_and_curators_can_hide
          end ).to be true
        end

        it "curators and admins can hide media" do
          action = ModeratorAction.create(
            action: ModeratorAction::HIDE,
            resource: resource,
            user: curator,
            reason: generic_reason
          )
          expect( action ).to be_valid
          expect( resource.hidden? ).to eq true

          action = ModeratorAction.create(
            action: ModeratorAction::HIDE,
            resource: resource,
            user: admin,
            reason: generic_reason
          )
          expect( action ).to be_valid
          expect( resource.hidden? ).to eq true
        end

        it "admins can set media as private" do
          action = ModeratorAction.create(
            action: ModeratorAction::HIDE,
            resource: resource,
            user: admin,
            reason: generic_reason,
            private: true
          )
          expect( action ).to be_valid
          expect( resource.moderated_as_private? ).to eq true
        end

        it "curators cannot set media as private" do
          action = ModeratorAction.create(
            action: ModeratorAction::HIDE,
            resource: resource,
            user: curator,
            reason: generic_reason,
            private: true
          )
          expect( action ).not_to be_valid
          expect( action.errors.any? do | e |
            e.type == :only_staff_can_make_private
          end ).to be true
        end

        it "only hidden content can be set to private" do
          action = ModeratorAction.create(
            action: ModeratorAction::UNHIDE,
            resource: resource,
            user: admin,
            reason: generic_reason,
            private: true
          )
          expect( action ).not_to be_valid
          expect( action.errors.any? do | e |
            e.type == :only_hidden_content_can_be_private
          end ).to be true
        end
      end

      describe "Photos" do
        let( :resource ) { Photo.make! }
        it_behaves_like "hiding media"
      end
      describe "Sounds" do
        let( :resource ) { Sound.make! }
        it_behaves_like "hiding media"
      end
    end

    describe "UNHIDE" do
      it "admins can unhide" do
        comment = Comment.make!
        ModeratorAction.create( action: ModeratorAction::HIDE, resource: comment, user: admin,
          reason: generic_reason )
        comment.reload
        expect( comment.hidden? ).to be true
        unhide_action = ModeratorAction.create( action: ModeratorAction::UNHIDE, resource: comment,
          user: admin, reason: generic_reason )
        comment.reload
        expect( comment.hidden? ).to be false
        expect( unhide_action.errors.any? do | e |
          e.message == "Only staff and curators who hide content can unhide it"
        end ).to be false
      end

      it "normal users cannot unhide" do
        comment = Comment.make!
        ModeratorAction.create( action: ModeratorAction::HIDE, resource: comment, user: admin,
          reason: generic_reason )
        comment.reload
        expect( comment.hidden? ).to be true
        unhide_action = ModeratorAction.create( action: ModeratorAction::UNHIDE, resource: comment,
          user: User.make!, reason: generic_reason )
        comment.reload
        expect( comment.hidden? ).to be true
        expect( unhide_action.errors.any? do | e |
          e.message == "Only staff and curators who hide content can unhide it"
        end ).to be true
      end

      it "curators who hid the content can unhide" do
        comment = Comment.make!
        ModeratorAction.create( action: ModeratorAction::HIDE, resource: comment, user: curator,
          reason: generic_reason )
        comment.reload
        expect( comment.hidden? ).to be true
        unhide_action = ModeratorAction.create( action: ModeratorAction::UNHIDE, resource: comment,
          user: curator, reason: generic_reason )
        comment.reload
        expect( comment.hidden? ).to be false
        expect( unhide_action.errors.any? do | e |
          e.message == "Only staff and curators who hide content can unhide it"
        end ).to be false
      end

      it "curators who didnt hide the content cannot unhide" do
        comment = Comment.make!
        ModeratorAction.create( action: ModeratorAction::HIDE, resource: comment, user: curator,
          reason: generic_reason )
        comment.reload
        expect( comment.hidden? ).to be true
        unhide_action = ModeratorAction.create( action: ModeratorAction::UNHIDE, resource: comment,
          user: make_curator, reason: generic_reason )
        comment.reload
        expect( comment.hidden? ).to be true
        expect( unhide_action.errors.any? do | e |
          e.message == "Only staff and curators who hide content can unhide it"
        end ).to be true
      end
    end

    describe "SUSPEND" do
      it "should not be possible for a comment" do
        expect(
          build( :moderator_action, action: ModeratorAction::SUSPEND, resource: create( :comment ) )
        ).not_to be_valid
      end
      it "should be possible for a user" do
        expect(
          create( :moderator_action, action: ModeratorAction::SUSPEND, resource: create( :user ) )
        ).to be_persisted
      end
      it "should suspend a user" do
        u = create :user
        expect( u ).not_to be_suspended
        create( :moderator_action, action: ModeratorAction::SUSPEND, resource: u )
        u.reload
        expect( u ).to be_suspended
      end
      it "should not suspend staff" do
        u = create :user, :as_admin
        expect( u ).not_to be_suspended
        expect( build( :moderator_action, action: ModeratorAction::SUSPEND, resource: u ) ).not_to be_valid
        u.reload
        expect( u ).not_to be_suspended
      end
      it "should not allow a suspend reason longer than #{ModeratorAction::MAXIMUM_SUSPEND_REASON_LENGTH} characters" do
        u = create :user
        long_reason = "a" * ( ModeratorAction::MAXIMUM_SUSPEND_REASON_LENGTH + 1 )
        ma = build( :moderator_action, action: ModeratorAction::SUSPEND, resource: u, reason: long_reason )
        expect( ma ).not_to be_valid
        expect( ma.errors[:reason] ).to be_present
      end
      it "should allow a suspend reason up to #{ModeratorAction::MAXIMUM_SUSPEND_REASON_LENGTH} characters" do
        u = create :user
        reason = "a" * ModeratorAction::MAXIMUM_SUSPEND_REASON_LENGTH
        ma = create( :moderator_action, action: ModeratorAction::SUSPEND, resource: u, reason: reason )
        expect( ma ).to be_persisted
      end
      it "should not allow suspended_until in the past" do
        u = create :user
        ma = build( :moderator_action, action: ModeratorAction::SUSPEND, resource: u,
          suspended_until: 1.day.ago )
        expect( ma ).not_to be_valid
        expect( ma.errors[:suspended_until] ).to be_present
      end
      it "should allow suspended_until in the future" do
        u = create :user
        ma = create( :moderator_action, action: ModeratorAction::SUSPEND, resource: u,
          suspended_until: 7.days.from_now )
        expect( ma ).to be_persisted
      end
      it "sets suspended_by_user" do
        u = create :user
        expect( u ).not_to be_suspended
        ma = create( :moderator_action, action: ModeratorAction::SUSPEND, resource: u )
        u.reload
        expect( u.suspended_by_user ).to eq ma.user
      end
      it "copies suspended_until to user when set" do
        u = create :user
        future = 7.days.from_now
        create( :moderator_action, action: ModeratorAction::SUSPEND, resource: u, suspended_until: future )
        u.reload
        expect( u.suspended_until ).to be_within( 1.second ).of( future )
      end
      it "leaves suspended_until nil on user when not set" do
        u = create :user
        create( :moderator_action, action: ModeratorAction::SUSPEND, resource: u )
        u.reload
        expect( u.suspended_until ).to be_nil
      end
      it "copies a predefined reason key to the user's suspension_reason" do
        u = create :user
        create( :moderator_action, action: ModeratorAction::SUSPEND, resource: u,
          reason: "hate_speech", suspended_until: 1.day.from_now )
        u.reload
        expect( u.suspension_reason ).to eq "hate_speech"
      end
    end

    describe "UNSUSPEND" do
      it "should unsuspend a user" do
        u = create :user
        u.suspend!
        expect( u ).to be_suspended
        create( :moderator_action, action: ModeratorAction::UNSUSPEND, resource: u )
        u.reload
        expect( u ).not_to be_suspended
      end
      it "clears suspended_until on unsuspend" do
        u = create :user
        u.update_columns( suspended_at: Time.zone.now, suspended_until: 7.days.from_now )
        expect( u ).to be_suspended
        create( :moderator_action, action: ModeratorAction::UNSUSPEND, resource: u )
        u.reload
        expect( u ).not_to be_suspended
        expect( u.suspended_until ).to be_nil
      end

      it "marks spam users as non-spammers" do
        u = User.make!( spammer: true )
        u.suspend!
        expect( u.spammer ).to be true
        expect( u.spammer? ).to be true
        expect( u ).to be_suspended
        create( :moderator_action, action: ModeratorAction::UNSUSPEND, resource: u )
        u.reload
        expect( u.spammer ).to be false
        expect( u.spammer? ).to be false
        expect( u ).not_to be_suspended
      end

      it "marks users with unknown spammer status as non-spammers" do
        u = User.make!
        u.suspend!
        expect( u.spammer ).to be_nil
        expect( u.spammer? ).to be false
        expect( u ).to be_suspended
        create( :moderator_action, action: ModeratorAction::UNSUSPEND, resource: u )
        u.reload
        expect( u.spammer ).to be false
        expect( u.spammer? ).to be false
        expect( u ).not_to be_suspended
      end
    end
    describe "RENAME" do
      
      it "should not allow a non-admin user to rename" do
        u = create( :user, login: "old_login" )
        action = build( :moderator_action, action: ModeratorAction::RENAME, resource: u, user: User.make!,
          reason: generic_reason )
        expect( action ).not_to be_valid
        expect( action.errors[:base] ).to include( "Only staff can rename" )
      end
    end
    describe "set_resource_user_id" do
      it "is set properly for Comments" do
        comment = Comment.make!
        action = ModeratorAction.make!(
          action: ModeratorAction::HIDE,
          resource: comment,
          user: admin,
          reason: generic_reason
        )
        expect( action.resource_user ).to eq comment.user
      end

      it "is set properly for Identifications" do
        identification = Identification.make!
        action = ModeratorAction.make!(
          action: ModeratorAction::HIDE,
          resource: identification,
          user: admin,
          reason: generic_reason
        )
        expect( action.resource_user ).to eq identification.user
      end

      it "is set properly for Photos" do
        photo = LocalPhoto.make!
        action = ModeratorAction.make!(
          action: ModeratorAction::HIDE,
          resource: photo,
          user: admin,
          reason: generic_reason
        )
        expect( action.resource_user ).to eq photo.user
      end

      it "is set properly for Sounds" do
        sound = LocalSound.make!
        action = ModeratorAction.make!(
          action: ModeratorAction::HIDE,
          resource: sound,
          user: admin,
          reason: generic_reason
        )
        expect( action.resource_user ).to eq sound.user
      end

      it "is set properly for Users" do
        user = User.make!
        action = ModeratorAction.make!(
          action: ModeratorAction::SUSPEND,
          resource: user,
          user: admin,
          reason: generic_reason
        )
        expect( action.resource_user ).to eq user
      end
    end

    describe "set_resource_content" do
      it "is set properly for Comments" do
        comment = Comment.make!( body: Faker::Lorem.paragraph )
        action = ModeratorAction.make!(
          action: ModeratorAction::HIDE,
          resource: comment,
          user: admin,
          reason: generic_reason
        )
        expect( action.resource_content ).to eq comment.body
      end

      it "is set properly for Identifications" do
        identification = Identification.make!( body: Faker::Lorem.paragraph )
        action = ModeratorAction.make!(
          action: ModeratorAction::HIDE,
          resource: identification,
          user: admin,
          reason: generic_reason
        )
        expect( action.resource_content ).to eq identification.body
      end

      it "is set properly for Photos" do
        photo = LocalPhoto.make!
        action = ModeratorAction.make!(
          action: ModeratorAction::HIDE,
          resource: photo,
          user: admin,
          reason: generic_reason
        )
        expect( action.resource_content ).to be_nil
      end

      it "is set properly for Sounds" do
        sound = LocalSound.make!
        action = ModeratorAction.make!(
          action: ModeratorAction::HIDE,
          resource: sound,
          user: admin,
          reason: generic_reason
        )
        expect( action.resource_content ).to be_nil
      end

      it "is set properly for Users" do
        user = User.make!( description: Faker::Lorem.paragraph )
        action = ModeratorAction.make!(
          action: ModeratorAction::SUSPEND,
          resource: user,
          user: admin,
          reason: generic_reason
        )
        expect( action.resource_content ).to eq user.description
      end
    end

    describe "set_resource_parent" do
      it "is set properly for Comments" do
        observation = Observation.make!
        comment = Comment.make!( parent: observation )
        action = ModeratorAction.make!(
          action: ModeratorAction::HIDE,
          resource: comment,
          user: admin,
          reason: generic_reason
        )
        expect( action.resource_parent ).to eq comment.parent
      end

      it "is set properly for Identifications" do
        observation = Observation.make!
        identification = Identification.make!( observation: observation )
        action = ModeratorAction.make!(
          action: ModeratorAction::HIDE,
          resource: identification,
          user: admin,
          reason: generic_reason
        )
        expect( action.resource_parent ).to eq identification.observation
      end

      it "is set properly for observation Photos" do
        observation = Observation.make!
        photo = LocalPhoto.make!( user: observation.user )
        observation_photo = ObservationPhoto.make!( observation: observation, photo: photo )
        action = ModeratorAction.make!(
          action: ModeratorAction::HIDE,
          resource: observation_photo.photo,
          user: admin,
          reason: generic_reason
        )
        expect( action.resource_parent ).to eq observation_photo.observation
      end

      it "is set properly for taxon Photos" do
        taxon_photo = TaxonPhoto.make!
        action = ModeratorAction.make!(
          action: ModeratorAction::HIDE,
          resource: taxon_photo.photo,
          user: admin,
          reason: generic_reason
        )
        expect( action.resource_parent ).to eq taxon_photo.taxon
      end

      it "is set properly for guide Photos" do
        guide_photo = GuidePhoto.make!
        action = ModeratorAction.make!(
          action: ModeratorAction::HIDE,
          resource: guide_photo.photo,
          user: admin,
          reason: generic_reason
        )
        expect( action.resource_parent ).to eq guide_photo.guide_taxon
      end

      it "is set properly for observation Sounds" do
        observation = Observation.make!
        sound = LocalSound.make!( user: observation.user )
        observation_sound = ObservationSound.make!( observation: observation, sound: sound )
        action = ModeratorAction.make!(
          action: ModeratorAction::HIDE,
          resource: observation_sound.sound,
          user: admin,
          reason: generic_reason
        )
        expect( action.resource_parent ).to eq observation_sound.observation
      end

      it "is set properly for Users" do
        user = User.make!( description: Faker::Lorem.paragraph )
        action = ModeratorAction.make!(
          action: ModeratorAction::SUSPEND,
          resource: user,
          user: admin,
          reason: generic_reason
        )
        expect( action.resource_parent ).to be_nil
      end
    end
  end

  describe "editable_by?" do
    let( :suspension_action ) do
      create( :moderator_action, action: ModeratorAction::SUSPEND, resource: create( :user ), user: curator )
    end
    let( :hide_action ) do
      create( :moderator_action, action: ModeratorAction::HIDE, resource: create( :comment ), user: curator )
    end

    it "returns false for a blank editor" do
      expect( suspension_action.editable_by?( nil ) ).to be false
    end

    it "returns false for non-SUSPEND actions" do
      expect( hide_action.editable_by?( admin ) ).to be false
    end

    it "returns true for admin on a SUSPEND action" do
      expect( suspension_action.editable_by?( admin ) ).to be true
    end

    it "returns true for the curator who created the action" do
      expect( suspension_action.editable_by?( curator ) ).to be true
    end

    it "returns false for a different curator" do
      expect( suspension_action.editable_by?( make_curator ) ).to be false
    end

    it "returns false for a regular user" do
      expect( suspension_action.editable_by?( User.make! ) ).to be false
    end
  end

  describe "update" do
    describe "SUSPEND" do
      it "syncs updated suspended_until to the user" do
        u = create :user
        ma = create( :moderator_action, action: ModeratorAction::SUSPEND, resource: u )
        u.reload
        original_suspended_at = u.suspended_at

        expect( u.suspended_until ).to be_nil
        new_time = 14.days.from_now
        audit_comment = "Adjusting suspension duration"
        ma.audit_comment = audit_comment
        ma.update!( suspended_until: new_time )
        u.reload

        expect( u.suspended_at ).to eq original_suspended_at
        expect( u.suspended_until ).to be_within( 1.second ).of( new_time )
        expect( ma.audits.last.comment ).to eq( audit_comment )
      end

      it "requires audit_comment on update" do
        u = create :user
        ma = create( :moderator_action, action: ModeratorAction::SUSPEND, resource: u )
        expect( ma.update( suspended_until: 7.days.from_now ) ).to be false
        expect( ma.errors[:audit_comment] ).not_to be_empty
      end

      it "validates audit_comment minimum length" do
        u = create :user
        ma = create( :moderator_action, action: ModeratorAction::SUSPEND, resource: u )
        ma.audit_comment = "short"
        expect( ma.update( suspended_until: 7.days.from_now ) ).to be false
        expect( ma.errors[:audit_comment] ).not_to be_empty
      end
    end
  end

  describe "persistence" do
    shared_examples_for "media" do
      let( :curator ) { make_curator }
      let!( :action ) do
        ModeratorAction.make!(
          action: ModeratorAction::HIDE,
          resource: resource,
          user: curator,
          reason: generic_reason
        )
      end
      it "records persist after resources are destroyed" do
        expect( resource.class.where( id: resource.id ).exists? ).to eq true
        expect( ModeratorAction.where( resource: resource ).exists? ).to eq true
        resource.destroy
        expect( resource.class.where( id: resource.id ).exists? ).to eq false
        expect( ModeratorAction.where( resource: resource ).exists? ).to eq true
      end

      it "records persist after moderating user is destroyed" do
        expect( resource.class.where( id: resource.id ).exists? ).to eq true
        expect( User.where( id: action.user_id ).exists? ).to eq true
        expect( ModeratorAction.where( resource: resource ).exists? ).to eq true
        action.user.destroy
        expect( resource.class.where( id: resource.id ).exists? ).to eq true
        expect( User.where( id: action.user_id ).exists? ).to eq false
        expect( ModeratorAction.where( resource: resource ).exists? ).to eq true
        expect( ModeratorAction.where( resource: resource ).first.user_id ).to eq action.user_id
      end
    end

    describe "Photos" do
      let( :resource ) { Photo.make! }
      it_behaves_like "media"
    end
    describe "Sounds" do
      let( :resource ) { Sound.make! }
      it_behaves_like "media"
    end
  end

  describe "translated_reason" do
    it "translates a predefined suspension reason key" do
      ma = build( :moderator_action, action: ModeratorAction::SUSPEND, reason: "hate_speech" )
      expect( ma.translated_reason ).to eq I18n.t( "suspension_reasons.hate_speech" )
    end

    it "returns custom reason text unchanged" do
      ma = build( :moderator_action, action: ModeratorAction::SUSPEND, reason: "posting spam links" )
      expect( ma.translated_reason ).to eq "posting spam links"
    end

    it "returns nil for blank reason" do
      ma = build( :moderator_action, action: ModeratorAction::SUSPEND, reason: nil )
      expect( ma.translated_reason ).to be_nil
    end
  end
end
