require File.dirname(__FILE__) + '/../spec_helper'

describe ApplicationController do
  it "should update ActiveRecord conditions using update_conditions" do
    string_conditions = "flavor IS NOT NULL"
    array_conditions = ["flavor = ?", 'glazed']
    
    string_string = controller.update_conditions(
      string_conditions, 
      "AND sprinkles = TRUE")
    string_string.should == "flavor IS NOT NULL AND sprinkles = TRUE"
    
    string_array = controller.update_conditions(
      string_conditions, 
      ["AND sprinkles = ?", true])
    string_array.should == ["flavor IS NOT NULL AND sprinkles = ?", true]
    
    array_string = controller.update_conditions(
      array_conditions,
      "AND sprinkles = TRUE")
    array_string.should == ["flavor = ? AND sprinkles = TRUE", 'glazed']
    
    array_array = controller.update_conditions(
      array_conditions,
      ["AND sprinkles = ?", true])
    array_array.should == ["flavor = ? AND sprinkles = ?", 'glazed', true]
    
    controller.update_conditions(
      nil, "flavor IS NOT NULL").should == "flavor IS NOT NULL"
    
    controller.update_conditions(
      nil, ["flavor = ?", 'glazed']).should == ["flavor = ?", 'glazed']
  end
end
