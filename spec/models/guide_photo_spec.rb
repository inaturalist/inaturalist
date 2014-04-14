# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe GuidePhoto, "creation" do
  it "should validate the length of a description" do
    gs = GuidePhoto.make(:description => "foo")
    gs.should be_valid
    gs = GuidePhoto.make(:description => "foo"*256)
    gs.should_not be_valid
    gs.errors[:description].should_not be_blank
  end
end
