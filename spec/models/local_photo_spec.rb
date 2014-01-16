require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Photo, "creation" do
  it "should set the native page url" do
    p = LocalPhoto.make!
    p.native_page_url.should_not be_blank
  end

  it "should set the native_realname" do
    u = User.make!(:name => "Hodor Hodor Hodor")
    lp = LocalPhoto.make!(:user => u)
    lp.native_realname.should eq(u.name)
  end

  it "should set absolute image urls" do
    lp = LocalPhoto.make!
    lp.small_url.should =~ /http/
  end
end

describe Photo, "to_observation" do
  it "should set a taxon from tags" do
    p = LocalPhoto.make
    p.file = File.open(File.join(Rails.root, "spec", "fixtures", "files", "cuthona_abronia-tagged.jpg"))
    t = Taxon.make!(:name => "Cuthona abronia")
    o = p.to_observation
    o.taxon.should eq(t)
  end

  it "should not set a taxon from a blank title" do
    p = LocalPhoto.make
    p.file = File.open(File.join(Rails.root, "spec", "fixtures", "files", "spider-blank_title.jpg"))
    tn = TaxonName.make!
    tn.update_attribute(:name, "")
    tn.name.should eq("")
    o = p.to_observation
    o.taxon.should be_blank
  end

  it "should set observation fields from machine tags" do
    of = ObservationField.make!(:name => "sex", :allowed_values => "unknown|male|female", :datatype => ObservationField::TEXT)
    lp = LocalPhoto.make!
    lp.metadata = {
      :dc => {
        :subject => ['sex=female']
      }
    }
    o = lp.to_observation
    o.observation_field_values.detect{|ofv| ofv.observation_field_id == of.id}.value.should eq "female"
  end

  it "should not set invalid observation fields from machine tags" do
    of = ObservationField.make!(:name => "sex", :allowed_values => "unknown|male|female", :datatype => ObservationField::TEXT)
    lp = LocalPhoto.make!
    lp.metadata = {
      :dc => {
        :subject => ['sex=whatevs']
      }
    }
    o = lp.to_observation
    o.should be_valid
    o.observation_field_values.detect{|ofv| ofv.observation_field_id == of.id}.should be_blank
  end
end
