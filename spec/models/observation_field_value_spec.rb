require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ObservationFieldValue do
  xit { is_expected.to belong_to(:observation).inverse_of :observation_field_values }
  xit { is_expected.to belong_to :observation_field }
  xit { is_expected.to belong_to :user }
  it { is_expected.to have_one :annotation }

  context "with user and observation field" do
    subject { ObservationFieldValue.make  }
    it { is_expected.to validate_uniqueness_of(:observation_field_id).scoped_to :observation_id }
    it { is_expected.to validate_presence_of :observation }
    it { is_expected.to validate_length_of(:value).is_at_most 2048 }
  end

  describe "creation" do
    it "should touch the observation" do
      o = Observation.make!(:created_at => 1.day.ago)
      ofv = ObservationFieldValue.make!(:observation => o)
      o.reload
      expect(o.updated_at).to be > o.created_at
    end

    describe "for subscribers" do
      before do
        UpdateAction.delete_all
        enable_has_subscribers
      end
      after { disable_has_subscribers }

      it "should create an update for the observer if user is not observer" do
        o = Observation.make!
        expect( UpdateAction.unviewed_by_user_from_query(o.user_id, resource: o) ).to eq false
        ofv = without_delay do
          ObservationFieldValue.make!(:observation => o, :user => User.make!)
        end
        expect( UpdateAction.unviewed_by_user_from_query(o.user_id, resource: o) ).to eq true
      end

      it "should not create an update for the observer if the user is the observer" do
        o = Observation.make!
        expect( UpdateAction.unviewed_by_user_from_query(o.user_id, resource: o) ).to eq false
        ofv = without_delay do
          ObservationFieldValue.make!(:observation => o, :user => o.user)
        end
        expect( UpdateAction.unviewed_by_user_from_query(o.user_id, resource: o) ).to eq false
      end
    end
  end

  describe "update" do
    it "should touch the observation" do
      ofv = ObservationFieldValue.make!
      o = ofv.observation
      ofv.update( value: "this is a new value" )
      o.reload
      expect( o.updated_at ).to be >= ofv.updated_at
    end
  end

  describe "updating for subscribers" do
    before do
      @ofv = ObservationFieldValue.make!(:value => "foo", :user => User.make!)
      @o = @ofv.observation
      UpdateAction.destroy_all
      enable_has_subscribers
    end
    after { disable_has_subscribers }

    it "should create an update for the observer if user is not observer" do
      expect( UpdateAction.unviewed_by_user_from_query(@o.user_id, resource: @o) ).to eq false
      without_delay { @ofv.update(:value => "bar") }
      expect( UpdateAction.unviewed_by_user_from_query(@o.user_id, resource: @o) ).to eq true
    end

    it "should create an update for the observer if user is not observer and the observer created the ofv" do
      ofv = without_delay { ObservationFieldValue.make!(:user => @o.user, :value => "foo", :observation => @o) }
      UpdateAction.destroy_all
      expect( UpdateAction.unviewed_by_user_from_query(@o.user_id, resource: @o) ).to eq false
      without_delay { ofv.update(:value => "bar", :updater => User.make!) }
      expect( UpdateAction.unviewed_by_user_from_query(@o.user_id, resource: @o) ).to eq true
    end

    it "should not create an update for the observer" do
      ofv = ObservationFieldValue.make!
      o = ofv.observation
      expect(o.user_id).to eq ofv.user_id
      UpdateAction.destroy_all
      expect( UpdateAction.unviewed_by_user_from_query(o.user_id, resource: o) ).to eq false
      without_delay { ofv.update(:value => "bar") }
      expect( UpdateAction.unviewed_by_user_from_query(o.user_id, resource: o) ).to eq false
    end

    it "should not create an update for subscribers who didn't add the value" do
      u = User.make!
      without_delay { Comment.make!(:user => u, :parent => @o)}
      UpdateAction.destroy_all
      expect( UpdateAction.unviewed_by_user_from_query(u.id, resource: @o) ).to eq false
      without_delay { @ofv.update(:value => "bar") }
      expect( UpdateAction.unviewed_by_user_from_query(u.id, resource: @o) ).to eq false
    end
  end

  describe "destruction" do
    it "should touch the observation" do
      ofv = ObservationFieldValue.make!
      o = ofv.observation
      t = o.updated_at
      ofv.destroy
      o.reload
      expect(o.updated_at).to be > t
    end
  end

  describe "validation" do
    describe "#set_user" do
      context "with updater" do
        let(:updater) { build_stubbed :user }
        context "with no user" do

          subject { build_stubbed :observation_field_value, user: nil, updater: updater }

          it "sets user to updater" do
            expect(subject).to be_valid
            expect(subject.user).to eq updater
          end
        end

        context "with existing user" do
          let(:user) { build_stubbed :user }
          subject { build_stubbed :observation_field_value, user: user, updater: updater }

          it "maintains user" do
            expect(subject).to be_valid
            expect(subject.user).to_not eq updater
          end
        end
      end

      context "with observation but no updater" do
        context "with no user" do
          subject { build_stubbed :observation_field_value, user: nil }

          it "sets user and updater to observation user" do
            expect(subject).to be_valid
            expect(subject.user).to eq subject.observation.user
            expect(subject.updater).to eq subject.observation.user
          end
        end

        context "with existing user and updater" do
          let(:user) { build_stubbed :user }
          let(:updater) { build_stubbed :user }

          subject { build_stubbed :observation_field_value, user: user, updater: updater }

          it "maintains user and updater" do
            expect(subject).to be_valid
            expect(subject.user).to_not eq subject.observation.user
            expect(subject.updater).to_not eq subject.observation.user
          end
        end
      end
    end

    context "with text type observation field" do
      let(:of) { build_stubbed :observation_field, datatype: ObservationField::TEXT, allowed_values: "foo|bar" }

      it "should pass for allowed values" do
        expect(build_stubbed :observation_field_value, observation_field: of, value: "foo").to be_valid
        expect(build_stubbed :observation_field_value, observation_field: of, value: "bar").to be_valid
      end

      it "should fail for disallowed values" do
        expect(build_stubbed :observation_field_value, observation_field: of, value: "baz").to_not be_valid
      end

      it "allowed values validation should be case insensitive" do
        expect(build_stubbed :observation_field_value, observation_field: of, value: "Foo").to be_valid
        expect(build_stubbed :observation_field_value, observation_field: of, value: "BAR").to be_valid
      end

      it "allowed values validation should handle nil values" do
        expect(build_stubbed :observation_field_value, observation_field: of, value: nil).to_not be_valid
      end
    end

    context "with numeric type observation field" do
      let(:of) { build_stubbed :observation_field, datatype: ObservationField::NUMERIC, allowed_values: "1|7|56-35" }

      it "should be valid for numeric values in a numeric field that aren't in allowed_values" do
        expect(build_stubbed :observation_field_value,  observation_field: of, value: 5).to be_valid
      end
    end

    context "with user preference" do
      let(:observer) { build_stubbed :user, prefers_observation_fields_by: preference }
      let(:observation) { build_stubbed :observation, user: observer }
      let(:other_user) { build_stubbed :user }
      let(:curator) { build_stubbed :curator }

      subject { build_stubbed :observation_field_value, observation: observation, user: user }

      context "when observer prefers only curators" do
        let(:preference) { User::PREFERRED_OBSERVATION_FIELDS_BY_CURATORS }

        context "and the user is not a curator" do
          let(:user) { other_user }

          it { is_expected.to_not be_valid }
        end
        context "and the user is a curator" do
          let(:user) { curator }

          it { is_expected.to be_valid }
        end
        context "and the user is the observer" do
          let(:user) { observer }

          it { is_expected.to be_valid }
        end
        context "and the updater is a curator" do
          let(:user) { observer }

          it "is valid on update" do
            expect(subject).to be_valid
            subject.updater = curator
            expect(subject).to be_valid
          end
        end
        context "and the updater is not a curator" do
          let(:user) { observer }

          it "is valid on update" do
            expect(subject).to be_valid
            subject.updater = other_user
            expect(subject).not_to be_valid
          end
        end
      end
      context "when observer prefers only themselves" do
        let(:preference) { User::PREFERRED_OBSERVATION_FIELDS_BY_OBSERVER }

        context "and if the user is not the observer" do
          let(:user) { other_user }

          it { is_expected.to_not be_valid }
        end
        context "and the user is the observer" do
          let(:user) { observer }

          it { is_expected.to be_valid }
        end
        context "and the updater is not the observer" do
          let(:user) { observer }

          it "is valid on update" do
            expect(subject).to be_valid
            subject.value = "something else"
            subject.updater = other_user
            expect(subject).not_to be_valid
          end
        end
      end
    end
  end

  describe "annotation_attribute_and_value" do
    before( :all ) do
      @alive_or_dead = ControlledTerm.make!( active: true )
      ControlledTermLabel.make!( controlled_term: @alive_or_dead, label: "Alive or Dead" )
      @alive = ControlledTerm.make!( is_value: true, active: true )
      ControlledTermLabel.make!( controlled_term: @alive, label: "Alive")
      @dead = ControlledTerm.make!( is_value: true, active: true )
      ControlledTermLabel.make!( controlled_term: @dead, label: "Dead" )
      @cannot_be_determined = ControlledTerm.make!( is_value: true, active: true )
      ControlledTermLabel.make!( controlled_term: @cannot_be_determined, label: "Cannot Be Determined" )
      @alive_or_dead.controlled_term_values.create( controlled_value: @alive )
      @alive_or_dead.controlled_term_values.create( controlled_value: @dead )
      @alive_or_dead.controlled_term_values.create( controlled_value: @cannot_be_determined )
      @dead_or_alive_field = ObservationField.make!( name: "Dead or alive", allowed_values: "dead|alive|moribund|not sure" )
      @evidence = ControlledTerm.make!( active: true )
      ControlledTermLabel.make!( controlled_term: @evidence, label: "Evidence of Presence" )
      # @dead = ControlledTerm.make!( is_value: true, active: true )
      # ControlledTermLabel.make!( controlled_term: @dead, label: "Dead" )
      @track = ControlledTerm.make!( is_value: true, active: true )
      ControlledTermLabel.make!( controlled_term: @track, label: "Track" )
      @scat = ControlledTerm.make!( is_value: true, active: true )
      ControlledTermLabel.make!( controlled_term: @scat, label: "Scat" )
      @feather = ControlledTerm.make!( is_value: true, active: true )
      ControlledTermLabel.make!( controlled_term: @feather, label: "Feather" )
      @molt = ControlledTerm.make!( is_value: true, active: true )
      ControlledTermLabel.make!( controlled_term: @molt, label: "Molt" )
      @evidence_field = ObservationField.make!(
          name: "Animal Sign and Song",
          allowed_values: "None Recorded|Tracks|Scat|Remains|Call/Song|Evidence of Feeding|Evidence of Egg Laying|Smell|Scratching/Scent Post|Nest|Burrow/Den|Web|Fur/Feathers|Shell/Exoskeleton|Shed skin|Window print"
      )
    end

    it "associates alive ofvs" do
      ofv = ObservationFieldValue.make( observation_field: @dead_or_alive_field, value: "alive" )
      attr_val = ofv.annotation_attribute_and_value
      expect( attr_val ).not_to be_blank
      expect( attr_val[:controlled_attribute] ).to eq @alive_or_dead
      expect( attr_val[:controlled_value] ).to eq @alive
    end

    it "associates dead ofvs" do
      ofv = ObservationFieldValue.make( observation_field: @dead_or_alive_field, value: "dead" )
      attr_val = ofv.annotation_attribute_and_value
      expect( attr_val ).not_to be_blank
      expect( attr_val[:controlled_attribute] ).to eq @alive_or_dead
      expect( attr_val[:controlled_value] ).to eq @dead
    end

    it "associates not sure ofvs" do
      ofv = ObservationFieldValue.make( observation_field: @dead_or_alive_field, value: "not sure" )
      attr_val = ofv.annotation_attribute_and_value
      expect( attr_val ).not_to be_blank
      expect( attr_val[:controlled_attribute] ).to eq @alive_or_dead
      expect( attr_val[:controlled_value] ).to eq @cannot_be_determined
    end

    it "does not associate moribund ofvs" do
      ofv = ObservationFieldValue.make( observation_field: @dead_or_alive_field, value: "moribund" )
      attr_val = ofv.annotation_attribute_and_value
      expect( attr_val ).to be_blank
    end

    it "associates tracks ofvs" do
      ofv = ObservationFieldValue.make( observation_field: @evidence_field, value: "Tracks" )
      attr_val = ofv.annotation_attribute_and_value
      expect( attr_val ).not_to be_blank
      expect( attr_val[:controlled_attribute] ).to eq @evidence
      expect( attr_val[:controlled_value] ).to eq @track
    end

    it "associates scat ofvs" do
      ofv = ObservationFieldValue.make( observation_field: @evidence_field, value: "Scat" )
      attr_val = ofv.annotation_attribute_and_value
      expect( attr_val ).not_to be_blank
      expect( attr_val[:controlled_attribute] ).to eq @evidence
      expect( attr_val[:controlled_value] ).to eq @scat
    end
    it "associates Fur/Feathers ofvs" do
      ofv = ObservationFieldValue.make( observation_field: @evidence_field, value: "Fur/Feathers" )
      attr_val = ofv.annotation_attribute_and_value
      expect( attr_val ).not_to be_blank
      expect( attr_val[:controlled_attribute] ).to eq @evidence
      expect( attr_val[:controlled_value] ).to eq @feather
    end
    it "associates shed ofvs" do
      ofv = ObservationFieldValue.make( observation_field: @evidence_field, value: "Shed skin" )
      attr_val = ofv.annotation_attribute_and_value
      expect( attr_val ).not_to be_blank
      expect( attr_val[:controlled_attribute] ).to eq @evidence
      expect( attr_val[:controlled_value] ).to eq @molt
    end
    it "shoud map an OFV like Tracks?=yes" do
      of = ObservationField.make!( name: "Tracks", allowed_values: "yes|no" )
      ofv = ObservationFieldValue.make!( observation_field: of, value: "yes" )
      attr_val = ofv.annotation_attribute_and_value
      expect( attr_val ).not_to be_blank
      expect( attr_val[:controlled_attribute] ).to eq @evidence
      expect( attr_val[:controlled_value] ).to eq @track
    end
  end
end
