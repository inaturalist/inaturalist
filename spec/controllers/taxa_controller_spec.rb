require File.dirname(__FILE__) + '/../spec_helper'

describe TaxaController do
  describe "merge" do
    it "should respond to a JS call for a taxon_id" do
      user = make_curator
      keeper = Taxon.make
      reject = Taxon.make
      login_as user
      get :merge, :id => reject.id, :taxon_id => keeper.id, :format => "js"
      response.should be_success
    end

    it "should redirect on succesfully merging" do
      user = make_curator
      keeper = Taxon.make
      reject = Taxon.make
      login_as user
      post :merge, :id => reject.id, :taxon_id => keeper.id, :commit => "Merge"
      response.should be_redirect
    end
  end
  
  describe "update" do
    it "should allow curators to supercede locking" do
      user = make_curator
      login_as user
      locked_parent = Taxon.make(:locked => true)
      taxon = Taxon.make
      put :update, :id => taxon.id, :taxon => {:parent_id => locked_parent.id}
      taxon.reload
      taxon.parent_id.should == locked_parent.id
    end
  end
end
