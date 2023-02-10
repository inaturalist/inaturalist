# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe GuideSection do
  describe "creation" do
    it "should set the license of the guide to CC-BY-SA if this section is CC-BY-SA"

    it "should not be modified by default" do
      gs = GuideSection.make!
      expect(gs).not_to be_modified
    end

    it "should be modified modified_on_create set" do
      gs = GuideSection.make!(:modified_on_create => true)
      expect(gs).to be_modified
    end

    it { is_expected.to validate_length_of(:title).is_at_least(1) }
    it { is_expected.to validate_length_of(:title).is_at_most(256) }
  end

  describe "acts_as_spammable" do
    it "does not check for spam if there is a source_url" do
      gs = GuideSection.make(title: "t", description: "d")
      expect(gs).to receive(:check_for_spam)
      gs.save
      gs = GuideSection.make(title: "t", description: "d", source_url: "something")
      expect(gs).not_to receive(:check_for_spam?)
      gs.save
    end
  end
end

describe GuideSection, "updating" do
  let(:guide_section) { GuideSection.make! }
  it "should result in a modified record" do
    guide_section.update(:description => "#{guide_section.description} foo")
    expect(guide_section).to be_modified
  end
end

describe GuideSection, "new_from_eol_data_object" do
  before(:all) do
    @eol = EolService.new(:timeout => 30)
    response = @eol.data_objects( 12618489 )
    response.remove_namespaces!
    @data_object = response.at( "dataObject" )
    @guide_section = GuideSection.new_from_eol_data_object(@data_object)
  end

  it "should work" do
    expect(@guide_section).to be_new_record
  end

  it "should set license" do
    expect(@guide_section.license.to_s.downcase).to be =~ /by-sa/
  end

  it "should set rights_holder" do
    expect(@guide_section.rights_holder).to be =~ /Wikipedia/
  end

  it "should set rights_holder to compiler if no rightsHolder" do
    r = @eol.data_objects( 12618489 )
    r.remove_namespaces!
    data_object = r.at('dataObject')
    guide_section = GuideSection.new_from_eol_data_object(data_object)
    expect(guide_section.rights_holder).not_to be_blank
  end

  it "should set source_url" do
    expect(@guide_section.source_url).to be =~ /eol.org/
  end

end
