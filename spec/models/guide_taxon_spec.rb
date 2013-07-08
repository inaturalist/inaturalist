# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe GuideTaxon, "creation" do
  it "should add the taxon's wikipedia description as a GuideSection" do
    t = Taxon.make!(:wikipedia_summary => "foo bar")
    gt = GuideTaxon.make!(:taxon => t)
    gt.reload
    gt.guide_sections.should_not be_blank
    gt.guide_sections.first.description.should eq(t.wikipedia_summary)
  end

  it "should set the license for the default GuideSection to CC-BY-SA" do
    t = Taxon.make!(:wikipedia_summary => "foo bar")
    gt = GuideTaxon.make!(:taxon => t)
    gt.reload
    gt.guide_sections.first.license.should eq(Observation::CC_BY_SA)
  end
end