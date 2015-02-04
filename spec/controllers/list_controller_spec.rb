require File.dirname(__FILE__) + '/../spec_helper'

describe ListsController do
  describe "create" do
    it "allow creation of multiple types" do
      taxon = Taxon.make!
      user = User.make!
      sign_in user
      
      post :create, :list => {:title => "foo", :type => "LifeList"}, :taxa => [{:taxon_id => taxon.id}]
      response.should be_redirect
      list = user.lists.last
      list.rules.first.operand_id.should be(taxon.id)
      list.should be_a(LifeList)
    end
  end

  describe "destroy" do
    it "should not allow you to delete your own life list" do
      u = User.make!
      sign_in u
      delete :destroy, :id => u.life_list_id
      List.find_by_id(u.life_list_id).should_not be_blank
    end

    it "should not allow anyone to delete a default project list" do
      p = Project.make!
      u = p.user
      sign_in u
      delete :destroy, :id => p.project_list.id
      List.find_by_project_id(p.id).should_not be_blank
    end
  end
end

describe ListsController, "compare" do
  let(:user) { User.make! }
  before do
    sign_in user
  end
  
  it "should work" do
    lt1 = ListedTaxon.make!
    lt2 = ListedTaxon.make!
    lambda {
      get :compare, :id => lt1.list_id, :with => lt2.list_id
    }.should_not raise_error
    response.should be_success
  end
end

describe ListsController, "spam" do
  let(:spammer_content) { List.make!(user: User.make!(spammer: true)) }
  let(:flagged_content) {
    l = List.make!
    Flag.make!(flaggable: l, flag: Flag::SPAM)
    l
  }

  it "should render 403 when the owner is a spammer" do
    get :show, id: spammer_content.id
    response.response_code.should == 403
  end

  it "should render 403 when content is flagged as spam" do
    get :show, id: spammer_content.id
    response.response_code.should == 403
  end
end
