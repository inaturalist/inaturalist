require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ObservationFieldValue, "creation" do
  it "should touch the observation" do
    o = Observation.make!(:created_at => 1.day.ago)
    ofv = ObservationFieldValue.make!(:observation => o)
    o.reload
    expect(o.updated_at).to be > o.created_at
  end

  it "should not be valid without an observation" do
    of = ObservationField.make!
    ofv = ObservationFieldValue.new(:observation_field => of, :value => "foo")
    expect(ofv).not_to be_valid
    expect(ofv.errors[:observation]).not_to be_blank
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

describe ObservationFieldValue, "update" do
  it "should touch the observation" do
    ofv = ObservationFieldValue.make!
    o = ofv.observation
    ofv.update_attributes( value: "this is a new value" )
    o.reload
    expect( o.updated_at ).to be >= ofv.updated_at
  end
end

describe ObservationFieldValue, "updating for subscribers" do
  before do
    @ofv = ObservationFieldValue.make!(:value => "foo", :user => User.make!)
    @o = @ofv.observation
    UpdateAction.destroy_all
    enable_has_subscribers
  end
  after { disable_has_subscribers }

  it "should create an update for the observer if user is not observer" do
    expect( UpdateAction.unviewed_by_user_from_query(@o.user_id, resource: @o) ).to eq false
    without_delay { @ofv.update_attributes(:value => "bar") }
    expect( UpdateAction.unviewed_by_user_from_query(@o.user_id, resource: @o) ).to eq true
  end

  it "should create an update for the observer if user is not observer and the observer created the ofv" do
    ofv = without_delay { ObservationFieldValue.make!(:user => @o.user, :value => "foo", :observation => @o) }
    UpdateAction.destroy_all
    expect( UpdateAction.unviewed_by_user_from_query(@o.user_id, resource: @o) ).to eq false
    without_delay { ofv.update_attributes(:value => "bar", :updater => User.make!) }
    expect( UpdateAction.unviewed_by_user_from_query(@o.user_id, resource: @o) ).to eq true
  end

  it "should not create an update for the observer" do
    ofv = ObservationFieldValue.make!
    o = ofv.observation
    expect(o.user_id).to eq ofv.user_id
    UpdateAction.destroy_all
    expect( UpdateAction.unviewed_by_user_from_query(o.user_id, resource: o) ).to eq false
    without_delay { ofv.update_attributes(:value => "bar") }
    expect( UpdateAction.unviewed_by_user_from_query(o.user_id, resource: o) ).to eq false
  end

  it "should not create an update for subscribers who didn't add the value" do
    u = User.make!
    without_delay { Comment.make!(:user => u, :parent => @o)}
    UpdateAction.destroy_all
    expect( UpdateAction.unviewed_by_user_from_query(u.id, resource: @o) ).to eq false
    without_delay { @ofv.update_attributes(:value => "bar") }
    expect( UpdateAction.unviewed_by_user_from_query(u.id, resource: @o) ).to eq false
  end
end

describe ObservationFieldValue, "destruction" do
  it "should touch the observation" do
    ofv = ObservationFieldValue.make!
    o = ofv.observation
    t = o.updated_at
    ofv.destroy
    o.reload
    expect(o.updated_at).to be > t
  end
end

describe ObservationFieldValue, "validation" do

  it "should pass for allowed values" do
    of = ObservationField.make!(:datatype => "text", :allowed_values => "foo|bar")
    expect {
      ObservationFieldValue.make!(:observation_field => of, :value => "foo")
    }.not_to raise_error
    expect {
      ObservationFieldValue.make!(:observation_field => of, :value => "bar")
    }.not_to raise_error
  end
  
  it "should fail for disallowed values" do
    of = ObservationField.make!(:datatype => "text", :allowed_values => "foo|bar")
    expect {
      ObservationFieldValue.make!(:observation_field => of, :value => "baz")
    }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "allowed values validation should be case insensitive" do
    of = ObservationField.make!(:datatype => "text", :allowed_values => "foo|bar")
    expect {
      ObservationFieldValue.make!(:observation_field => of, :value => "Foo")
    }.not_to raise_error
    expect {
      ObservationFieldValue.make!(:observation_field => of, :value => "BAR")
    }.not_to raise_error
  end

  it "allowed values validation should handle nil values" do
    of = ObservationField.make!(:datatype => ObservationField::TEXT, :allowed_values => "foo|bar")
    expect {
      ObservationFieldValue.make!(:observation_field => of, :value => nil)
    }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "should be valid for numeric values in a numeric field that aren't in allowed_values" do
    of = ObservationField.make!( datatype: ObservationField::NUMERIC, allowed_values: "1|7|56-35" )
    expect( ObservationFieldValue.make!( observation_field: of, value: 5 ) ).to be_valid
  end

  describe "when observer prefers only curators" do
    let(:observer) { User.make!( prefers_observation_fields_by: User::PREFERRED_OBSERVATION_FIELDS_BY_CURATORS ) }
    let(:observation) { Observation.make!( user: observer ) }
    it "should fail if the user is not a curator" do
      ofv = ObservationFieldValue.make( observation: observation, user: User.make! )
      expect( ofv ).not_to be_valid
    end
    it "should pass if the user is a curator" do
      ofv = ObservationFieldValue.make( observation: observation, user: make_curator )
      expect( ofv ).to be_valid
    end
    it "should pass if the user is the observer" do
      ofv = ObservationFieldValue.make( observation: observation, user: observation.user )
      expect( ofv ).to be_valid
    end
    it "should pass on update if the updater is a curator" do
      ofv = ObservationFieldValue.make( observation: observation, user: observation.user )
      expect( ofv ).to be_valid
      ofv.updater = make_curator
      expect( ofv ).to be_valid
    end
    it "should fail on update if the updater is not a curator" do
      ofv = ObservationFieldValue.make!( observation: observation, user: observation.user )
      expect( ofv ).to be_valid
      ofv.updater = User.make!
      expect( ofv ).not_to be_valid
    end
  end
  describe "when observer prefers only themselves" do
    let(:observer) { User.make!( prefers_observation_fields_by: User::PREFERRED_OBSERVATION_FIELDS_BY_OBSERVER ) }
    let(:observation) { Observation.make!( user: observer ) }
    it "should fail if the user is not the observer" do
      ofv = ObservationFieldValue.make( observation: observation, user: User.make! )
      expect( ofv ).not_to be_valid
    end
    it "should pass if the user is the observer" do
      ofv = ObservationFieldValue.make( observation: observation, user: observer )
      expect( ofv ).to be_valid
    end
    it "should fail on update if the updater is not the observer" do
      ofv = ObservationFieldValue.make!( observation: observation, user: observer )
      expect( ofv ).to be_valid
      ofv.value = "something else"
      ofv.updater = User.make!
      expect( ofv ).not_to be_valid
    end
  end
end

describe ObservationFieldValue, "annotation_attribute_and_value" do
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
