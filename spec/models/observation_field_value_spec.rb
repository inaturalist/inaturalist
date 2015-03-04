require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ObservationFieldValue, "creation" do
  it "should touch the observation" do
    o = Observation.make!(:created_at => 1.day.ago)
    ofv = ObservationFieldValue.make!(:observation => o)
    o.reload
    o.updated_at.should be > o.created_at
  end

  it "should not be valid without an observation" do
    of = ObservationField.make!
    ofv = ObservationFieldValue.new(:observation_field => of, :value => "foo")
    ofv.should_not be_valid
    ofv.errors[:observation].should_not be_blank
  end

  describe "for subscribers" do
    before { Update.delete_all }

    it "should create an update for the observer if user is not observer" do
      o = Observation.make!
      ofv = without_delay do
        ObservationFieldValue.make!(:observation => o, :user => User.make!)
      end
      Update.where(:subscriber_id => o.user_id, :resource_id => o.id, :notifier_id => ofv.id).count.should eq 1
    end
    
    it "should not create an update for the observer if the user is the observer" do
      o = Observation.make!
      ofv = without_delay do
        ObservationFieldValue.make!(:observation => o, :user => o.user)
      end
      Update.where(:subscriber_id => o.user_id, :resource_id => o.id, :notifier_id => ofv.id).count.should eq 0
    end
  end
end

describe ObservationFieldValue, "updating for subscribers" do
  before do
    @ofv = ObservationFieldValue.make!(:value => "foo", :user => User.make!)
    @o = @ofv.observation
    Update.delete_all
  end
  
  it "should create an update for the observer if user is not observer" do
    without_delay { @ofv.update_attributes(:value => "bar") }
    Update.where(:subscriber_id => @o.user_id, :resource_id => @o.id, :notifier_id => @ofv.id).count.should eq 1
  end

  it "should create an update for the observer if user is not observer and the observer created the ofv" do
    ofv = without_delay { ObservationFieldValue.make!(:user => @o.user, :value => "foo", :observation => @o) }
    Update.delete_all
    without_delay { ofv.update_attributes(:value => "bar", :updater => User.make!) }
    Update.where(:subscriber_id => @o.user_id, :resource_id => @o.id, :notifier_id => ofv.id).count.should eq 1
  end

  it "should not create an update for the observer" do
    ofv = ObservationFieldValue.make!
    o = ofv.observation
    o.user_id.should eq ofv.user_id
    Update.delete_all
    without_delay { ofv.update_attributes(:value => "bar") }
    Update.where(:subscriber_id => o.user_id, :resource_id => o.id, :notifier_id => ofv.id).count.should eq 0
  end

  it "should not create an update for subscribers who didn't add the value" do
    u = User.make!
    without_delay { Comment.make!(:user => u, :parent => @o)}
    Update.delete_all
    without_delay { @ofv.update_attributes(:value => "bar") }
    Update.where(:subscriber_id => u.id, :resource_id => @o.id, :notifier_id => @ofv.id).count.should eq 0
  end
end

describe ObservationFieldValue, "destruction" do
  it "should touch the observation" do
    ofv = ObservationFieldValue.make!
    o = ofv.observation
    t = o.updated_at
    ofv.destroy
    o.reload
    o.updated_at.should be > t
  end
end

describe ObservationFieldValue, "validation" do
  # it "should work for numeric fields" do
  #   of = ObservationField.make!(:datatype => "numeric")
  #   lambda {
  #     ObservationFieldValue.make!(:observation_field => of, :value => "fop")
  #   }.should raise_error(ActiveRecord::RecordInvalid)
  #   lambda {
  #     ObservationFieldValue.make!(:observation_field => of, :value => "12")
  #   }.should_not raise_error(ActiveRecord::RecordInvalid)
  #   lambda {
  #     ObservationFieldValue.make!(:observation_field => of, :value => "12.3")
  #   }.should_not raise_error(ActiveRecord::RecordInvalid)
  # end

  # it "should pass for a numeric value of 0" do
  #   of = ObservationField.make!(:datatype => "numeric")
  #   lambda {
  #     ObservationFieldValue.make!(:observation_field => of, :value => "0")
  #   }.should_not raise_error(ActiveRecord::RecordInvalid)
  # end
  
  # it "should work for location" do
  #   of = ObservationField.make!(:datatype => "location")
  #   lambda {
  #     ObservationFieldValue.make!(:observation_field => of, :value => "what")
  #   }.should raise_error(ActiveRecord::RecordInvalid)
  #   lambda {
  #     ObservationFieldValue.make!(:observation_field => of, :value => "35 45")
  #   }.should raise_error(ActiveRecord::RecordInvalid)
  #   lambda {
  #     ObservationFieldValue.make!(:observation_field => of, :value => "35,45")
  #   }.should_not raise_error(ActiveRecord::RecordInvalid)
  # end
  
  # it "should work for date" do
  #   of = ObservationField.make!(:datatype => "date")
  #   lambda {
  #     ObservationFieldValue.make!(:observation_field => of, :value => "what")
  #   }.should raise_error(ActiveRecord::RecordInvalid)
  #   lambda {
  #     ObservationFieldValue.make!(:observation_field => of, :value => "2011-12-32")
  #   }.should_not raise_error(ActiveRecord::RecordInvalid)
  # end
  
  # it "should work for datetime" do
  #   of = ObservationField.make!(:datatype => "datetime")
  #   lambda {
  #     ObservationFieldValue.make!(:observation_field => of, :value => "what")
  #   }.should raise_error(ActiveRecord::RecordInvalid)
  #   lambda {
  #     ObservationFieldValue.make!(:observation_field => of, :value => Time.now.iso8601)
  #   }.should_not raise_error(ActiveRecord::RecordInvalid)
  # end

  # it "should work for time" do
  #   of = ObservationField.make!(:datatype => "time")
  #   lambda {
  #     ObservationFieldValue.make!(:observation_field => of, :value => "what")
  #   }.should raise_error(ActiveRecord::RecordInvalid)
  #   lambda {
  #     ObservationFieldValue.make!(:observation_field => of, :value => "44:23")
  #   }.should raise_error(ActiveRecord::RecordInvalid)
  #   lambda {
  #     ObservationFieldValue.make!(:observation_field => of, :value => "04:23")
  #   }.should_not raise_error(ActiveRecord::RecordInvalid)
  # end

  it "should pass for allowed values" do
    of = ObservationField.make!(:datatype => "text", :allowed_values => "foo|bar")
    lambda {
      ObservationFieldValue.make!(:observation_field => of, :value => "foo")
    }.should_not raise_error
    lambda {
      ObservationFieldValue.make!(:observation_field => of, :value => "bar")
    }.should_not raise_error
  end
  
  it "should fail for disallowed values" do
    of = ObservationField.make!(:datatype => "text", :allowed_values => "foo|bar")
    lambda {
      ObservationFieldValue.make!(:observation_field => of, :value => "baz")
    }.should raise_error(ActiveRecord::RecordInvalid)
  end

  it "allowed values validation should be case insensitive" do
    of = ObservationField.make!(:datatype => "text", :allowed_values => "foo|bar")
    lambda {
      ObservationFieldValue.make!(:observation_field => of, :value => "Foo")
    }.should_not raise_error
    lambda {
      ObservationFieldValue.make!(:observation_field => of, :value => "BAR")
    }.should_not raise_error
  end

  it "allowed values validation should handle nil values" do
    of = ObservationField.make!(:datatype => "text", :allowed_values => "foo|bar")
    lambda {
      ObservationFieldValue.make!(:observation_field => of, :value => nil)
    }.should raise_error(ActiveRecord::RecordInvalid)
  end
end
