require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ObservationPhoto, "creation" do  
  it "should queue a job to update observation quality grade" do
    Delayed::Job.delete_all
    stamp = Time.now
    ObservationPhoto.make!
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    jobs.select{|j| j.handler =~ /Observation.*set_quality_grade/m}.should_not be_blank
  end
  
  it "should update user_id on photo" do
    p = Photo.make!(:user => nil, :license => Photo::CC_BY)
    p.user.should be_blank
    o = Observation.make!
    op = ObservationPhoto.make!(:photo => p, :observation => o)
    p.reload
    p.user_id.should == o.user_id
  end

  it "should increment photos_count on the observation" do
    o = Observation.make!
    lambda {
      ObservationPhoto.make!(:observation => o)
      o.reload
    }.should change(o, :photos_count).by(1)
  end
end

describe ObservationPhoto, "destruction" do
  it "should queue a job to update observation quality grade" do
    op = ObservationPhoto.make!
    Delayed::Job.delete_all
    stamp = Time.now
    op.destroy
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    jobs.select{|j| j.handler =~ /Observation.*set_quality_grade/m}.should_not be_blank
  end

  it "should decrement photos_count on the observation" do
    op = ObservationPhoto.make!
    o = op.observation
    o.photos_count.should eq(1)
    lambda {
      op.destroy
      o.reload
    }.should change(o, :photos_count).by(-1)
  end
end
