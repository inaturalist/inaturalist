require File.dirname(__FILE__) + '/../spec_helper'

describe WikiPagesController do
  let(:default_site) { Site.default }
  let(:other_site) { Site.make! }
  let(:staff_user) { make_admin }
  let(:site_admin_user) { SiteAdmin.make!( site: other_site ).user }
  describe "edit" do
    it "should be accessible to curators" do
      user = make_curator
      sign_in user
      wp = WikiPage.make!
      get :edit, params: { path: wp.path }
      expect( response.status ).to eq 200
    end
    describe "admin-only" do
      let(:wiki_page) { WikiPage.make!( admin_only: true ) }
      it "should be accessible to site admins if made by an admin of the site they admin" do
        site_wiki_page = WikiPage.make!( admin_only: true, creator: site_admin_user )
        sign_in site_admin_user
        get :edit, params: { path: site_wiki_page.path, inat_site_id: other_site.id }
        expect( response.status ).to eq 200
      end
      it "should not be accessible to curators" do
        sign_in make_curator
        get :edit, params: { path: wiki_page.path }
        expect( response.status ).to be_between( 300, 400 )
      end
      it "should not be accessible to site admins if the page was created by staff" do
        staff_wiki_page = WikiPage.make!( admin_only: true, creator: staff_user )
        sign_in site_admin_user
        get :edit, params: { path: staff_wiki_page.path, inat_site_id: other_site.id }
        expect( response.status ).to be_between( 300, 400 )
      end
      it "should not be accessible to site admins if the page was created by a site admin of another site" do
        yet_another_site = Site.make!
        yet_another_site_admin_user = SiteAdmin.make!( site: yet_another_site ).user
        site_wiki_page = WikiPage.make!( admin_only: true, creator: yet_another_site_admin_user )
        sign_in site_admin_user
        get :edit, params: { path: site_wiki_page.path, inat_site_id: other_site.id }
        expect( response.status ).to be_between( 300, 400 )
      end
      it "should be accessible to staff if made by a site admin of another site" do
        site_wiki_page = WikiPage.make!( admin_only: true, creator: site_admin_user )
        sign_in staff_user
        get :edit, params: { path: site_wiki_page.path }
        expect( response.status ).to eq 200
      end
    end
  end
  describe "new" do
    it "should be accessible staff on the defaults site" do
      sign_in staff_user
      get :new, params: { path: "foo", inat_site_id: default_site.id }
      expect( response.status ).to eq 200
    end
    it "should be accessible staff on the another site" do
      sign_in staff_user
      get :new, params: { path: "foo", inat_site_id: other_site.id }
      expect( response.status ).to eq 200
    end
    it "should not be accessible to site admins on a site they don't admin" do
      sign_in site_admin_user
      get :new, params: { path: "foo", inat_site_id: default_site.id }
      expect( response.status ).to be_between( 300, 400 )
    end
    it "should be accessible to site admins on a site they do admin" do
      sign_in site_admin_user
      get :new, params: { path: "foo", inat_site_id: other_site.id }
      expect( response.status ).to eq 200
    end
  end
end
