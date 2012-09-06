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