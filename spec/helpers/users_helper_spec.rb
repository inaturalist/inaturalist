require File.dirname(__FILE__) + '/../spec_helper'
include ApplicationHelper
include UsersHelper
include AuthenticatedTestHelper

describe UsersHelper do
  let(:user) { User.make! }
  describe "link_to_user" do
    it "should return an error string on a nil user" do
      expect( link_to_user( nil ) ).to eq 'deleted user'
    end
    it "should link to the given user" do
      expect( link_to_user( user ) ).to have_tag( "a[href='http://test.host/people/#{user.login}']" )
    end
    it "should use given link text if :content_text is specified" do
      expect( link_to_user( user, content_text: "Hello there!" ) ).to have_tag( "a", "Hello there!" )
    end
    it "should use the login as link text with no :content_method specified" do
      expect( link_to_user( user ) ).to have_tag( "a", user.login )
    end
    it "should use the name as link text with :content_method => :name" do
      expect( link_to_user( user, content_method: :name ) ).to have_tag( "a", user.name )
    end
    it "should use the login as title with no :title_method specified" do
      expect( link_to_user( user ) ).to have_tag( "a[title='#{user.login}']" )
    end
    it "should use the name as link title with :title_method => :name" do
      # The test matcher gets confused with the name has an apostrophe, even though the HTML is fine
      user.update( name: "Balthazar Brogdonovich" )
      expect( link_to_user( user , title_method: :name ) ).to have_tag( "a", with: { title: user.name } )
    end
    it "should have nickname as a class by default" do
      expect( link_to_user( user ) ).to have_tag( "a.nickname" )
    end
    it "should take other classes and no longer have the nickname class" do
      result = link_to_user( user , class: "foo bar" )
      expect( result ).to have_tag( "a.foo" )
      expect( result ).to have_tag( "a.bar" )
    end
  end

end
