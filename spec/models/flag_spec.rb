# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

describe Flag, "creation" do
  subject { build_stubbed :flag, flaggable: flaggable }

  let( :flaggable ) { build_stubbed :taxon }

  describe "validates uniqueness" do
    subject { build :flag }
    it do
      is_expected.to validate_uniqueness_of( :user_id ).
        scoped_to(
          :flaggable_id,
          :flaggable_type,
          :flag,
          :resolved_at
        ).
        on( :create ).
        with_message :already_flagged
    end
  end

  it { is_expected.to validate_length_of( :flag ).is_at_least( 3 ).is_at_most( 256 ) }
  it { is_expected.to validate_length_of( :comment ).is_at_most( 256 ).allow_blank }

  it "should have the right TYPES" do
    expect( Flag::TYPES ).to eq %w(
      CheckList
      Comment
      Guide
      GuideSection
      Identification
      List
      Message
      Observation
      Photo
      Place
      Post
      Project
      Sound
      Taxon
      User
    )
  end

  describe "for flaggable model" do
    stub_elastic_index! Observation

    before do
      allow( flaggable ).to receive( :save ).and_return true
      subject.run_callbacks :create
    end

    context "on observations" do
      let( :flaggable ) { build_stubbed :observation, quality_grade: Observation::NEEDS_ID }

      it "should set the flaggable content for an observation to the description" do
        expect( subject.flaggable_content ).to eq flaggable.description
      end

      it "should make flagged observations casual" do
        expect( flaggable.quality_grade ).to eq Observation::NEEDS_ID
        flaggable.run_callbacks :update
        expect( flaggable.quality_grade ).to eq Observation::CASUAL
      end
    end

    [Post, Comment, Identification].each do | model |
      context "on #{model.to_s.downcase.pluralize}" do
        let( :flaggable ) { create :"#{model.name.underscore}", body: "some bad stuff" }

        it "should set the flaggable content to the body" do
          expect( subject.flaggable_content ).to eq flaggable.body
        end
      end
    end

    context "on comments" do
      context "on observations" do
        it "should set the flaggable parent to the observation" do
          o = create( :observation )
          flaggable = create( :comment, parent: o )
          expect( create( :flag, flaggable: flaggable ).flaggable_parent ).to eq o
        end
      end
      context "on posts" do
        it "should set the flaggable parent to the post" do
          post = create( :post )
          flaggable = create( :comment, parent: post )
          expect( create( :flag, flaggable: flaggable ).flaggable_parent ).to eq post
        end
      end
    end

    context "on identifications" do
      it "should set the flaggable parent to the observation" do
        flaggable = create( :identification )
        expect( create( :flag, flaggable: flaggable ).flaggable_parent ).to eq flaggable.observation
      end
    end

    context "on posts" do
      context "belonging to users" do
        it "should set the flaggable parent to the user" do
          user = create( :user )
          flaggable = create( :post, parent: user )
          expect( create( :flag, flaggable: flaggable ).flaggable_parent ).to eq user
        end
      end
      context "belonging to projects" do
        it "should set the flaggable parent to the project" do
          project = create( :user )
          flaggable = create( :post, parent: project )
          expect( create( :flag, flaggable: flaggable ).flaggable_parent ).to eq project
        end
      end
    end

    context "on photos" do
      it "should set the flaggable parent to the observation if associated with one" do
        op = create( :observation_photo )
        expect( create( :flag, flaggable: op.photo ).flaggable_parent ).to eq op.observation
      end
      it "should set the flaggable parent to the taxon if associated with one" do
        tp = create( :taxon_photo )
        expect( create( :flag, flaggable: tp.photo ).flaggable_parent ).to eq tp.taxon
      end
      it "should set the flaggable parent to the observation if associated both obs and taxon" do
        op = create( :observation_photo )
        create( :taxon_photo, photo: op.photo )
        expect( create( :flag, flaggable: op.photo ).flaggable_parent ).to eq op.observation
      end
    end
  end
end

describe "actual creation" do
  let( :observation ) { create :observation }
  def expect_observation_to_be_updated_by
    updated_at = observation.updated_at
    yield
    observation.reload
    expect( observation.updated_at ).to be > updated_at
  end
  describe "on observations" do
    it "should touch the observation" do
      expect_observation_to_be_updated_by { create :flag, flaggable: observation }
    end
  end
  describe "on comments" do
    it "should touch the observation" do
      comment = create :comment, parent: observation
      expect_observation_to_be_updated_by do
        create :flag, flaggable: comment
      end
    end
  end
  describe "on identifications" do
    let( :identification ) { create :identification, observation: observation }
    it "should touch the observation" do
      expect_observation_to_be_updated_by do
        create :flag, flaggable: identification
      end
    end
    it "should set the flaggable content to the body" do
      flag = create :flag, flaggable: identification
      expect( flag.flaggable_content ).to eq identification.body
    end
  end
end

describe Flag, "update" do
  before { enable_has_subscribers }
  after { disable_has_subscribers }

  it "should generate an update for the user" do
    t = Taxon.make!
    f = Flag.make!( flaggable: t )
    u = make_curator
    expect( UpdateAction.unviewed_by_user_from_query( f.user_id, resource: f ) ).to eq false
    without_delay do
      f.update( resolver: u, comment: "foo", resolved: true )
    end
    expect( UpdateAction.unviewed_by_user_from_query( f.user_id, resource: f ) ).to eq true
  end

  it "should generate an update for the user even if they have blocked other users" do
    t = Taxon.make!
    f = Flag.make!( flaggable: t )
    u = make_curator
    UserBlock.make!( user: User.make!, blocked_user: f.user )
    expect( UpdateAction.unviewed_by_user_from_query( f.user_id, resource: f ) ).to eq false
    without_delay do
      f.update( resolver: u, comment: "foo", resolved: true )
    end
    expect( UpdateAction.unviewed_by_user_from_query( f.user_id, resource: f ) ).to eq true
  end

  it "should generate an update for the user even if other users have blocked them" do
    t = Taxon.make!
    f = Flag.make!( flaggable: t )
    u = make_curator
    UserBlock.make!( user: f.user, blocked_user: User.make! )
    expect( UpdateAction.unviewed_by_user_from_query( f.user_id, resource: f ) ).to eq false
    without_delay do
      f.update( resolver: u, comment: "foo", resolved: true )
    end
    expect( UpdateAction.unviewed_by_user_from_query( f.user_id, resource: f ) ).to eq true
  end

  it "should autosubscribe the resolver" do
    t = Taxon.make!
    f = Flag.make!( flaggable: t )
    u = make_curator
    without_delay { f.update( resolver: u, comment: "foo", resolved: true ) }
    expect( u.subscriptions.detect {| s | s.resource_type == "Flag" && s.resource_id == f.id } ).to_not be_blank
  end

  it "should resolve even if the flaggable owner has blocked the flagger" do
    o = Observation.make!
    f = Flag.make!( flaggable: o )
    expect( f ).to be_valid
    UserBlock.make!( user: o.user, blocked_user: f.user )
    f.update( resolved: true, resolver: User.make! )
    expect( f ).to be_valid
    expect( f ).to be_resolved
  end
end

describe Flag, "destruction" do
  before { enable_has_subscribers }
  after { disable_has_subscribers }
  it "should remove the resolver's subscription" do
    t = Taxon.make!
    f = Flag.make!( flaggable: t )
    u = make_curator
    without_delay do
      f.update( resolver: u, comment: "foo", resolved: true )
    end
    f.reload
    f.destroy
    expect( u.subscriptions.detect {| s | s.resource_type == "Flag" && s.resource_id == f.id } ).to be_blank
  end

  it "should remove update actions" do
    c = Comment.make!
    f = Flag.make!( flaggable: c )
    u = make_curator
    without_delay do
      f.update( resolver: u, comment: "foo", resolved: true )
    end
    f.reload
    expect( UpdateAction.unviewed_by_user_from_query( f.user_id, resource: f ) ).to eq true
    f.destroy
    expect( UpdateAction.unviewed_by_user_from_query( f.user_id, resource: f ) ).to eq false
  end
end
