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
    of = ObservationField.make!(:datatype => "text", :allowed_values => "foo|bar")
    expect {
      ObservationFieldValue.make!(:observation_field => of, :value => nil)
    }.to raise_error(ActiveRecord::RecordInvalid)
  end

  describe "when observer prefers only curators" do
    let(:observer) { User.make!( prefers_observation_fields_by: User::PREFERRED_OBSERVATION_FIELDS_BY_CURATORS ) }
    let(:observation) { Observation.make!( user: observer ) }
    it "should fail if the user is not a curator" do
      ofv = ObservationFieldValue.make( observation: observation )
      expect( ofv ).not_to be_valid
    end
    it "should pass if the user is a curator" do
      ofv = ObservationFieldValue.make( observation: observation, user: make_curator )
      expect( ofv ).to be_valid
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
  end
end
