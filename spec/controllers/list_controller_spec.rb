require File.dirname(__FILE__) + '/../spec_helper'

describe ListsController do
  describe :create do
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
end

describe ListsController, "show" do
  it "should filter by iconic taxon"
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
