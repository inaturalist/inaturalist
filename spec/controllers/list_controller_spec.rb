require File.dirname(__FILE__) + '/../spec_helper'

describe ListsController do
  elastic_models( Observation )
  describe "create" do
    it "allow creation of multiple types" do
      taxon = Taxon.make!
      user = UserPrivilege.make!( privilege: UserPrivilege::ORGANIZER ).user
      sign_in user
      place = make_place_with_geom(user: user)
      post :create, list: { title: "foo", type: "CheckList"}, taxa: [{ taxon_id: taxon.id}], place: place.id
      expect(response).to be_redirect
      list = List.where(place_id: place.id).last
      expect(list).to be_a(CheckList)
    end

    it "does not create lists for users without speech privilege" do
      taxon = Taxon.make!
      user = User.make!
      sign_in user
      expect( user.lists.count ).to eq 0
      post :create, list: { title: "foo" }, taxa: [{ taxon_id: taxon.id}]
      expect( user.lists.count ).to eq 0
    end

    it "creates lists for users with speech privilege" do
      taxon = Taxon.make!
      user = UserPrivilege.make!( privilege: UserPrivilege::SPEECH ).user
      sign_in user
      expect( user.lists.count ).to eq 0
      post :create, list: { title: "foo" }, taxa: [{ taxon_id: taxon.id}]
      expect( user.lists.count ).to eq 1
    end
  end

  describe "destroy" do
    it "should not allow anyone to delete a default project list" do
      p = Project.make!
      u = p.user
      sign_in u
      delete :destroy, :id => p.project_list.id
      expect(List.find_by_project_id(p.id)).not_to be_blank
    end
  end

  describe "compare" do
    let(:user) { User.make! }
    before do
      sign_in user
    end
  
    it "should work" do
      lt1 = ListedTaxon.make!
      lt2 = ListedTaxon.make!
      expect {
        get :compare, :id => lt1.list_id, :with => lt2.list_id
      }.not_to raise_error
      expect(response).to be_success
    end
  end

  describe "spam" do
    let(:spammer_content) {
      l = List.make!
      l.user.update_attributes(spammer: true)
      l
    }
    let(:flagged_content) {
      l = List.make!
      Flag.make!(flaggable: l, flag: Flag::SPAM)
      l
    }

    it "should render 403 when the owner is a spammer" do
      get :show, id: spammer_content.id
      expect(response.response_code).to eq 403
    end

    it "should render 403 when content is flagged as spam" do
      get :show, id: spammer_content.id
      expect(response.response_code).to eq 403
    end
  end
end