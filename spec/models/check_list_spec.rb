require File.dirname(__FILE__) + '/../spec_helper.rb'

describe CheckList do
  fixtures :places, :users, :taxa, :lists
  
  before(:each) do
    @check_list = CheckList.new(:place => places(:berkeley), 
      :taxon => taxa(:Aves))
  end
  
  it "should have one and only place" do
    @check_list.place = nil
    @check_list.should_not be_valid
  end
  
  it "should completable" do
    @check_list.respond_to?(:comprehensive).should be_true
  end
  
  it "should be editable by any user" do
    @check_list.should be_editable_by users(:ted)
    @check_list.should be_editable_by users(:aaron)
  end
  
  it "should have a unique taxon for its place" do
    @new_check_list = CheckList.new(:place => places(:berkeley), 
      :taxon => taxa(:Amphibia))
    @new_check_list.should_not be_valid
  end

  # I'm not really sure how to test model callbacks that create new db
  # records, since they tend to break RSpec transactions and leave stuff in 
  # the db
  it "should create a new is_taxon? rule if taxon_id has been set"
  # it "should create a new is_taxon? rule if taxon_id has been set" do
  #   @check_list.save
  #   puts @check_list.errors.full_messages.join(', ') unless @check_list.valid?
  #   @check_list.rules.should_not be_empty
  # end
end