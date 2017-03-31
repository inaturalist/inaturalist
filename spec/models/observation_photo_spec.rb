require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ObservationPhoto, "creation" do  
  it "should queue a job to update observation quality grade" do
    Delayed::Job.delete_all
    stamp = Time.now
    make_observation_photo
    jobs = Delayed::Job.where("created_at >= ?", stamp)
    jobs.select{|j| j.handler =~ /Observation.*set_quality_grade/m}.should_not be_blank
  end

  it "should increment observation_photos_count on the observation" do
    o = Observation.make!
    lambda {
      make_observation_photo(:observation => o)
      o.reload
    }.should change(o, :observation_photos_count).by(1)
  end

  it "should touch the observation" do
    o = Observation.make!
    updated_at_was = o.updated_at
    op = make_observation_photo(:observation => o)
    o.reload
    updated_at_was.should < o.updated_at
  end
end

describe ObservationPhoto, "destruction" do
  it "should queue a job to update observation quality grade" do
    op = make_observation_photo
    Delayed::Job.delete_all
    stamp = Time.now
    op.destroy
    jobs = Delayed::Job.where("created_at >= ?", stamp)
    jobs.select{|j| j.handler =~ /Observation.*set_quality_grade/m}.should_not be_blank
  end

  it "should decrement observation_photos_count on the observation" do
    op = make_observation_photo
    o = op.observation
    o.observation_photos_count.should eq(1)
    lambda {
      op.destroy
      o.reload
    }.should change(o, :observation_photos_count).by(-1)
  end
end
