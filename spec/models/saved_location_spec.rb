# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe SavedLocation do
  describe "validation" do
    it "should fail for duplicate titles for a user" do
      sl1 = SavedLocation.make!( latitude: 1, longitude: 1 )
      sl2 = SavedLocation.make( title: sl1.title, user: sl1.user, latitude: 2, longitude: 2 )
      expect( sl2 ).not_to be_valid
    end
    it "should pass for duplicate titles for different users" do
      sl1 = SavedLocation.make!
      sl2 = SavedLocation.make( title: sl1.title )
      expect( sl2 ).to be_valid
    end
  end
end
