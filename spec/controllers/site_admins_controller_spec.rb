require File.dirname(__FILE__) + '/../spec_helper'

describe SiteAdminsController do
  let(:site) { Site.make! }

  describe "create" do
    it "allows admins to create" do
      user = make_admin
      sign_in user
      expect {
        post :create, params: { site_admin: {
          user_id: user.id,
          site_id: site.id
        } }
      }.to change( SiteAdmin, :count ).by( 1 )
      p = SiteAdmin.last
      expect( p.user ).to eq user
      expect( p.site ).to eq site
    end

    it "does not allow non-users to create" do
      user = User.make!
      expect {
        post :create, params: { site_admin: {
          user_id: user.id,
          site_id: site.id
        } }
        expect( flash[:alert] ).to eq "You need to sign in or sign up before continuing."
      }.not_to change( SiteAdmin, :count )
    end

    it "does not allow regular users to create" do
      user = User.make!
      sign_in user
      expect {
        expect {
          post :create, params: { site_admin: {
            user_id: user.id,
            site_id: site.id
          } }
        }.to throw_symbol( :abort )
        expect( flash[:error] ).to eq "Only administrators may access that page"
      }.not_to change( SiteAdmin, :count )
    end

    it "does not allow curators to create" do
      user = make_curator
      sign_in user
      expect {
        expect {
          post :create, params: { site_admin: {
            user_id: user.id,
            site_id: site.id
          } }
        }.to throw_symbol( :abort )
        expect( flash[:error] ).to eq "Only administrators may access that page"
     }.not_to change( SiteAdmin, :count )
    end
  end

  describe "destroy" do
    let!(:site_admin) { SiteAdmin.make! }

    it "allows admins to destroy by ID" do
      user = make_admin
      sign_in user
      expect {
        post :destroy, params: { id: site_admin.id }
      }.to change( SiteAdmin, :count ).by( -1 )
    end

    it "allows admins to destroy by user_id and site_id" do
      user = make_admin
      sign_in user
      expect {
        post :destroy, params: { site_admin: {
          user_id: site_admin.user_id,
          site_id: site_admin.site_id
        } }
      }.to change( SiteAdmin, :count ).by( -1 )
    end

    it "does not allow admins to destroy with only user_id or only site_id" do
      user = make_admin
      sign_in user
      expect {
        post :destroy, params: { site_admin: {
          user_id: site_admin.user_id
        } }
        expect(response.response_code).to eq 404
      }.to_not change( SiteAdmin, :count )
      expect {
        post :destroy, params: { site_admin: {
          site_id: site_admin.site_id
        } }
        expect(response.response_code).to eq 404
      }.to_not change( SiteAdmin, :count )
    end

    it "does not allow non-users to destroy" do
      expect {
        post :destroy, params: { id: site_admin.id }
        expect( flash[:alert] ).to eq "You need to sign in or sign up before continuing."
      }.to_not change( SiteAdmin, :count )
    end

    it "does not allow regular users to destroy" do
      user = User.make!
      sign_in user
      expect {
        expect {
          post :destroy, params: { id: site_admin.id }
        }.to throw_symbol( :abort )
        expect( flash[:error] ).to eq "Only administrators may access that page"
      }.to_not change( SiteAdmin, :count )
    end

    it "does not allow curators to destroy" do
      user = make_curator
      sign_in user
      expect {
        expect {
          post :destroy, params: { id: site_admin.id }
        }.to throw_symbol( :abort )
        expect( flash[:error] ).to eq "Only administrators may access that page"
      }.to_not change( SiteAdmin, :count )
    end
  end

end
