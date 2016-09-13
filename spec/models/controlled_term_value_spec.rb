require "spec_helper.rb"

describe ControlledTermValue do

  it "validates presence of controlled_value_id" do
    expect{ ControlledTermValue.make!(controlled_value: nil) }.to raise_error(
      ActiveRecord::RecordInvalid, /Controlled value can't be blank/)
  end

  it "validates presence of controlled_attribute_id" do
    expect{ ControlledTermValue.make!(controlled_attribute: nil) }.to raise_error(
      ActiveRecord::RecordInvalid, /Controlled attribute can't be blank/)
  end

  it "validates uniqueness of value in attribute" do
    ctv = ControlledTermValue.make!
    expect{
      ControlledTermValue.make!(
        controlled_attribute: ctv.controlled_attribute,
        controlled_value: ctv.controlled_value
      )
    }.to raise_error(ActiveRecord::RecordInvalid, /Controlled value has already been taken/)
  end

end
