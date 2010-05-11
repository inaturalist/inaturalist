require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ActivityStream, "batches" do
  fixtures :users, :taxa, :friendships
  
  before(:each) do
    taxon = Taxon.last
    @observations = []
    5.times do
      @observations << Observation.create(:user => users(:ted), :taxon => taxon)
    end
    @activity_stream = ActivityStream.last
  end
  
  it "should generate when a user ads a couple obs" do
    @activity_stream.batch_ids.should_not be_blank
  end
  
  it "should shift the primary acitivty object when it get destroyed" do
    @activity_stream.activity_object.destroy
    @activity_stream.reload
    @observations = Observation.all(:conditions => ["id in (?)", @activity_stream.batch_ids.split(',')])
    @observations.should include(@activity_stream.activity_object)
  end
end
