require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Photo, "creation" do
  it "should set the native page url" do
    p = LocalPhoto.make!
    p.native_page_url.should_not be_blank
  end
end