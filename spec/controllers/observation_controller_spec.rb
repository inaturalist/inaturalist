require File.dirname(__FILE__) + '/../spec_helper'

describe ObservationsController do
  describe :create do
    it "should not raise an exception if the obs was invalid and an image was submitted"
  end
  
  describe :new_batch_csv do
    it "should work under normal conditions" do
      user = User.make
      login_as user
      file = File.open(File.dirname(__FILE__) + '/../fixtures/observations.csv')
      
      user.observations.count.should be(0)
      post :new_batch_csv, :upload => {:datafile => file}
      assigns[:observations].should_not be_blank
    end
    
    it "should redirect without a file" do
      user = User.make
      login_as user
      post :new_batch_csv
      response.should be_redirect
    end
  end
  
  describe :index do
    it "should find observations by taxon_name" do
      taxon = Taxon.make
      observation = Observation.make(:taxon => taxon)
      get :index, :format => 'json', :taxon_name => taxon.name
      response.body.should match /#{observation.species_guess}/
    end
  end
  
  describe :import_photos do
    # to test this we need to mock a flickr response
    it "should import photos that are already entered as taxon photos"
  end
end
