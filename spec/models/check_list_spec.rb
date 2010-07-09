require File.dirname(__FILE__) + '/../spec_helper.rb'

describe CheckList do
  
  before(:each) do
    @check_list = CheckList.make(:taxon => Taxon.make)
  end
  
  it "should have one and only place" do
    @check_list.place = nil
    @check_list.should_not be_valid
  end
  
  it "should completable" do
    @check_list.respond_to?(:comprehensive).should be_true
  end
  
  it "should be editable by any user" do
    @check_list.should be_editable_by User.make
  end
  
  it "should have a unique taxon for its place" do
    @new_check_list = CheckList.new(:place => @check_list.place, 
      :taxon => @check_list.taxon)
    @new_check_list.should_not be_valid
  end
  
  it "should create a new is_taxon? rule if taxon_id has been set" do
    @check_list.rules.should_not be_empty
  end
end