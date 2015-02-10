# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe GuideSection, "creation" do
  it "should set the license of the guide to CC-BY-SA if this section is CC-BY-SA"
  
  it "should not be modified by default" do
    gs = GuideSection.make!
    expect(gs).not_to be_modified
  end

  it "should be modified modified_on_create set" do
    gs = GuideSection.make!(:modified_on_create => true)
    expect(gs).to be_modified
  end

  it "should validate the length of a title" do
    gs = GuideSection.make(:title => "foo")
    expect(gs).to be_valid
    gs = GuideSection.make(:title => "foo"*256)
    expect(gs).not_to be_valid
    expect(gs.errors[:title]).not_to be_blank
  end
end

describe GuideSection, "updating" do
  let(:guide_section) { GuideSection.make! }
  it "should result in a modified record" do
    guide_section.update_attributes(:description => "#{guide_section.description} foo")
    expect(guide_section).to be_modified
  end
end

describe GuideSection, "new_from_eol_data_object" do
  before(:all) do
    @eol = EolService.new(:timeout => 30)
    response = @eol.data_objects('dd57f96ecfd345de4dc59c358bb1de49')
    response.remove_namespaces!
    @data_object = response.at('dataObject')
    @guide_section = GuideSection.new_from_eol_data_object(@data_object)
  end

  it "should work" do
    expect(@guide_section).to be_new_record
  end

  it "should set license" do
    expect(@guide_section.license.to_s.downcase).to be =~ /by-nc/
  end

  it "should set rights_holder" do
    expect(@guide_section.rights_holder).to be =~ /NatureServe/
  end

  it "should set rights_holder to compiler if no rightsHolder" do
    r = @eol.data_objects('ecea27fefc7a2961d4af0361b90d3f69')
    r.remove_namespaces!
    data_object = r.at('dataObject')
    guide_section = GuideSection.new_from_eol_data_object(data_object)
    expect(guide_section.rights_holder).not_to be_blank
  end

  it "should set source_url" do
    expect(@guide_section.source_url).to be =~ /eol.org/
  end

end