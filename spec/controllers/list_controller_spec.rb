require File.dirname(__FILE__) + '/../spec_helper'

describe ListsController do
  describe :create do
    it "allow creation of multiple types" do
      taxon = Taxon.make
      user = User.make
      login_as user
      
      post :create, :list => {:title => "foo", :type => "LifeList"}, :taxa => [{:taxon_id => taxon.id}]
      response.should be_redirect
      list = user.lists.last
      list.rules.first.operand_id.should be(taxon.id)
      list.should be_a(LifeList)
    end
  end
end
