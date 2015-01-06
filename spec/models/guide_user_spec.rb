# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe GuideUser, "creation" do
  it "should not allow duplicate users" do
    gu1 = GuideUser.make!
    gu2 = GuideUser.make(:guide => gu1.guide, :user => gu1.user)
    gu2.should_not be_valid
    gu2.errors[:user_id].should_not be_blank
  end

  it "should not allow blank user" do
    gu = GuideUser.new(:guide => Guide.make!)
    gu.should_not be_valid
    gu.errors[:user].should_not be_blank
  end

  it "should not allow blank guide" do
    gu = GuideUser.new(:user => User.make!)
    gu.should_not be_valid
    gu.errors[:guide].should_not be_blank
  end
end