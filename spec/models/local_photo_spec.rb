require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Photo, "creation" do
  it "should set the native page url" do
    p = LocalPhoto.make!
    p.native_page_url.should_not be_blank
  end

  it "should set the native_realname" do
    u = User.make!(:name => "Hodor Hodor Hodor")
    lp = LocalPhoto.make!(:user => u)
    lp.native_realname.should eq(u.name)
  end
end
