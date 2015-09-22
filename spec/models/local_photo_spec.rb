require File.dirname(__FILE__) + '/../spec_helper.rb'

describe LocalPhoto, "creation" do
  describe "creation" do
    it "should set the native page url" do
      p = LocalPhoto.make!
      expect(p.native_page_url).not_to be_blank
    end

    it "should set the native_realname" do
      u = User.make!(:name => "Hodor Hodor Hodor")
      lp = LocalPhoto.make!(:user => u)
      expect(lp.native_realname).to eq(u.name)
    end

    it "should set absolute image urls" do
      lp = LocalPhoto.make!
      expect(lp.small_url).to be =~ /http/
    end
  end

  describe "dimensions" do
    it "should extract dimension metadata" do
      p = LocalPhoto.new(user: User.make!)
      p.file.assign(File.new(File.join(Rails.root, "app/assets/images/404mole.png")))
      expect( p.metadata ).to be nil
      p.extract_metadata
      expect( p.metadata[:dimensions][:original] ).to eq({ width: 600, height: 493 })
    end

    it "should extrapolate_dimensions_from_original from landscape photos" do
      p = LocalPhoto.new(user: User.make!)
      expect(p).to receive(:original_url).at_least(:once).and_return(
        File.join(Rails.root, "app/assets/images/404mole.png"))
      expect(p.extrapolate_dimensions_from_original).to eq({
        original: { width: 600, height: 493 },
        large: { width: 600, height: 493 },
        medium: { width: 500, height: 411 },
        small: { width: 240, height: 197 },
        thumb: { width: 100, height: 82 },
        square: { width: 75, height: 75 }
      })
    end

    it "should extrapolate_dimensions_from_original from small portrait photos" do
      p = LocalPhoto.new(user: User.make!)
      expect(p).to receive(:original_url).at_least(:once).and_return(
        File.join(Rails.root, "public/mapMarkers/mm_20_unknown.png"))
      expect(p.extrapolate_dimensions_from_original).to eq({
        original: { width: 13, height: 21 },
        large: { width: 13, height: 21 },
        medium: { width: 13, height: 21 },
        small: { width: 13, height: 21 },
        thumb: { width: 13, height: 21 },
        square: { width: 75, height: 75 }
      })
    end
  end
end

describe LocalPhoto, "to_observation" do
  it "should set a taxon from tags" do
    p = LocalPhoto.make
    p.file = File.open(File.join(Rails.root, "spec", "fixtures", "files", "cuthona_abronia-tagged.jpg"))
    t = Taxon.make!(:name => "Cuthona abronia")
    p.extract_metadata
    o = p.to_observation
    expect(o.taxon).to eq(t)
  end

  it "should not set a taxon from a blank title" do
    p = LocalPhoto.make
    p.file = File.open(File.join(Rails.root, "spec", "fixtures", "files", "spider-blank_title.jpg"))
    tn = TaxonName.make!
    tn.update_attribute(:name, "")
    expect(tn.name).to eq("")
    o = p.to_observation
    expect(o.taxon).to be_blank
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
    expect(o.observation_field_values.detect{|ofv| ofv.observation_field_id == of.id}.value).to eq "female"
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
    puts "o.errors: #{o.errors.full_messages.to_sentence}" unless o.valid?
    expect(o).to be_valid
    expect(o.observation_field_values.detect{|ofv| ofv.observation_field_id == of.id}).to be_blank
  end

  it "should add arbitrary tags from keywords" do
    lp = LocalPhoto.make!
    lp.metadata = {
      :dc => {
        :subject => ['tag1', 'tag2']
      }
    }
    o = lp.to_observation
    expect( o.tag_list ).to include 'tag1'
    expect( o.tag_list ).to include 'tag2'
  end
end

describe LocalPhoto, "flagging" do
  let(:lp) { LocalPhoto.make! }
  it "should change the URLs for copyright infringement" do
    Flag.make!(:flaggable => lp, :flag => Flag::COPYRIGHT_INFRINGEMENT)
    lp.reload
    %w(original large medium small thumb square).each do |size|
      expect(lp.send("#{size}_url")).to be =~ /copyright/
    end
  end
  it "should change the URLs back when resolved" do
    f = Flag.make!(:flaggable => lp, :flag => Flag::COPYRIGHT_INFRINGEMENT)
    lp.reload
    f.update_attributes(:resolved => true, :resolver => User.make!)
    lp.reload
    %w(original large medium small thumb square).each do |size|
      expect(lp.send("#{size}_url")).not_to be =~ /copyright/
    end
  end
  it "should not change the URLs back unless the flag was for copyright" do
    f1 = Flag.make!(:flaggable => lp, :flag => Flag::COPYRIGHT_INFRINGEMENT)
    f2 = Flag.make!(:flaggable => lp, :flag => Flag::SPAM)
    lp.reload
    f2.update_attributes(:resolved => true, :resolver => User.make!)
    lp.reload
    %w(original large medium small thumb square).each do |size|
      expect(lp.send("#{size}_url")).to be =~ /copyright/
    end
  end
  it "should change make associated observations casual grade when flagged"
  it "should change make associated observations research grade when resolved"
end
