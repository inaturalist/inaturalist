require File.dirname(__FILE__) + '/../spec_helper'

describe WikiPagesController do
  describe "edit" do

    it "should be accessible to curators" do
      user = make_curator
      sign_in user
      wp = WikiPage.make!
      get :edit, path: wp.path
      expect( response.status ).to eq 200
    end
    describe "admin-only" do
      let(:wiki_page) { WikiPage.make!( admin_only: true ) }
      it "should be accessible to site admins" do
        sign_in make_admin
        get :edit, path: wiki_page.path
        expect( response.status ).to eq 200
      end
      it "should not be accessible to curators" do
        sign_in make_curator
        get :edit, path: wiki_page.path
        expect( response.status ).to be_between( 300, 400 )
      end
    end
  end
end