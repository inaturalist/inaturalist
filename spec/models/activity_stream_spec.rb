require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ActivityStream, "batches" do
  before(:each) do
    @friendship = Friendship.make
    @user, @friend = [@friendship.user, @friendship.friend]
    @friend.followers.should_not be_blank
    @observations = []
    5.times do
      o = Observation.make(:user => @friend, :taxon => Taxon.make)
      @observations << o
      Observation.create_activity_update(o) # skip the DJ stuff
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
