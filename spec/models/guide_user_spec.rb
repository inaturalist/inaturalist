# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe GuideUser, "creation" do
  it "should not allow duplicate users" do
    gu1 = GuideUser.make!
    gu2 = GuideUser.make(:guide => gu1.guide, :user => gu1.user)
    expect( gu2 ).not_to be_valid
    expect( gu2.errors[:user_id] ).not_to be_blank
  end

  it "should not allow blank user" do
    gu = GuideUser.new(:guide => Guide.make!)
    expect( gu).not_to be_valid
    expect( gu.errors[:user] ).not_to be_blank
  end

  it "should not allow blank guide" do
    gu = GuideUser.new(:user => User.make!)
    expect( gu).not_to be_valid
    expect( gu.errors[:guide] ).not_to be_blank
  end
end
