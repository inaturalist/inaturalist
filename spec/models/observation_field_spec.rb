require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ObservationField, "creation" do
  it "should stip allowd values" do
    of = ObservationField.make!(:allowed_values => "foo |bar")
    of.allowed_values.should == "foo|bar"
  end
end

describe ObservationField, "validation" do
  it "should fail if allowd_values doesn't have pipes" do
    lambda {
      ObservationField.make!(:allowed_values => "foo")
    }.should raise_error(ActiveRecord::RecordInvalid)
  end
  
  it "should not allow tags in the name" do
    of = ObservationField.make!(:name => "hey <script>")
    of.name.should == "hey"
  end
  it "should not allow tags in the description" do
    of = ObservationField.make!(:description => "hey <script>")
    of.description.should == "hey"
  end
  it "should not allow tags in the allowed_values" do
    of = ObservationField.make!(:allowed_values => "hey|now <script>")
    of.allowed_values.should == "hey|now"
  end
end

describe ObservationField, "destruction" do
  it "should not be possible if assosiated projects exist"
  it "should not be possible if assosiated observations exist"
end

describe ObservationField, "merge" do
  let(:keeper) { ObservationField.make! }
  let(:reject) { ObservationField.make! }
  
  it "should delete the reject" do
    keeper.merge(reject)
    ObservationField.find_by_id(reject.id).should be_blank
  end

  it "should merge requested allowed values" do
    keeper.update_attributes(:allowed_values => "a|b")
    reject.update_attributes(:allowed_values => "c|d")
    keeper.merge(reject, :merge => [:allowed_values])
    keeper.reload
    keeper.allowed_values.should eq "a|b|c|d"
  end

  it "should keep requested allowed values" do
    keeper.update_attributes(:allowed_values => "a|b")
    reject.update_attributes(:allowed_values => "c|d")
    keeper.merge(reject, :keep => [:allowed_values])
    keeper.reload
    keeper.allowed_values.should eq "c|d"
  end

  it "should update observation field for the observation field values of the reject" do
    ofv = ObservationFieldValue.make!(:observation_field => reject)
    keeper.merge(reject)
    ofv.reload
    ofv.observation_field.should eq keeper
  end

  it "should create a notification for all users of the reject"
  
  it "should not be possible for a reject in use by a project" do
    pof = ProjectObservationField.make!(:observation_field => reject)
    keeper.merge(reject)
    ObservationField.find_by_id(reject.id).should_not be_blank
  end
end
