require File.dirname(__FILE__) + '/../spec_helper'

describe ObservationsController do
  describe :create do
    it "should not raise an exception if the obs was invalid and an image was submitted"
    
    it "should not raise an exception if no observations passed" do
      user = User.make!
      sign_in user
      
      lambda {
        post :create
      }.should_not raise_error
    end
    
    it "should add project observations if auto join project specified" do
      project = Project.make!
      user = User.make!
      sign_in user
      
      project.users.find_by_id(user.id).should be_blank
      post :create, :observation => {:species_guess => "Foo!"}, :project_id => project.id, :accept_terms => true
      project.users.find_by_id(user.id).should_not be_blank
      project.observations.last.id.should == Observation.last.id
    end
    
    it "should add project observations if auto join project specified and format is json" do
      project = Project.make!
      user = User.make!
      sign_in user
      
      project.users.find_by_id(user.id).should be_blank
      post :create, :format => "json", :observation => {:species_guess => "Foo!"}, :project_id => project.id
      project.users.find_by_id(user.id).should_not be_blank
      project.observations.last.id.should == Observation.last.id
    end
    
    it "should set taxon from taxon_name param" do
      user = User.make!
      taxon = Taxon.make!
      sign_in user
      post :create, :observation => {:species_guess => "Foo", :taxon_name => taxon.name}
      obs = user.observations.last
      obs.should_not be_blank
      obs.species_guess.should == "Foo"
      obs.taxon_id.should == taxon.id
    end
    
  end
  
  describe :update do
    it "should not raise an exception if no observations passed" do
      user = User.make!
      sign_in user
      
      lambda {
        post :update
      }.should_not raise_error
    end
    
    it "should use latitude param even if private_latitude set" do
      taxon = Taxon.make!(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
      observation = Observation.make!(:taxon => taxon, :latitude => 38, :longitude => -122)
      observation.private_longitude.should_not be_blank
      old_latitude = observation.latitude
      old_private_latitude = observation.private_latitude
      sign_in observation.user
      post :update, :id => observation.id, :observation => {:latitude => 1}
      observation.reload
      observation.private_longitude.should_not be_blank
      observation.latitude.to_f.should_not == old_latitude.to_f
      observation.private_latitude.to_f.should_not == old_private_latitude.to_f
    end
  end
  
  describe :new_batch_csv do
    it "should work under normal conditions" do
      user = User.make!
      sign_in user
      file = File.open(File.dirname(__FILE__) + '/../fixtures/observations.csv')
      
      user.observations.count.should be(0)
      post :new_batch_csv, :upload => {:datafile => file}
      assigns[:observations].should_not be_blank
    end
    
    it "should redirect without a file" do
      user = User.make!
      sign_in user
      post :new_batch_csv
      response.should be_redirect
    end
  end
  
  describe :import_photos do
    # to test this we need to mock a flickr response
    it "should import photos that are already entered as taxon photos"
  end
  
end
