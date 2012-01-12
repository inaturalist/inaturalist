require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ObservationFieldValue, "validation" do
  it "should work for numeric fields" do
    of = ObservationField.make(:datatype => "numeric")
    lambda {
      ObservationFieldValue.make(:observation_field => of, :value => "fop")
    }.should raise_error(ActiveRecord::RecordInvalid)
    lambda {
      ObservationFieldValue.make(:observation_field => of, :value => "12")
    }.should_not raise_error(ActiveRecord::RecordInvalid)
    lambda {
      ObservationFieldValue.make(:observation_field => of, :value => "12.3")
    }.should_not raise_error(ActiveRecord::RecordInvalid)
  end
end