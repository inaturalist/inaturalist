require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ObservationPhoto, "creation" do  
  it "should queue a job to update observation quality grade" do
    Delayed::Job.delete_all
    stamp = Time.now
    ObservationPhoto.make
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    jobs.select{|j| j.handler =~ /;Observation.*set_quality_grade/m}.should_not be_blank
  end
  
  it "should update user_id on photo" do
    p = Photo.make(:user => nil)
    p.user.should be_blank
    o = Observation.make
    op = ObservationPhoto.make(:photo => p, :observation => o)
    p.reload
    p.user_id.should == o.user_id
  end
end

describe ObservationPhoto, "destruction" do
  it "should queue a job to update observation quality grade" do
    op = ObservationPhoto.make
    Delayed::Job.delete_all
    stamp = Time.now
    op.destroy
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    jobs.select{|j| j.handler =~ /;Observation.*set_quality_grade/m}.should_not be_blank
  end
end
