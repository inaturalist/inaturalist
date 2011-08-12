require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectList do
  describe "creation" do
    it "should set defaults" do
      p = Project.make
      pl = p.project_list
      pl.should be_valid
      pl.title.should_not be_blank
      pl.description.should_not be_blank
    end
  end
  describe "refresh" do
    it "should destroy unobserved taxa" do
      list = ProjectList.make
      list.taxa << Taxon.make
      list.taxa.count.should be(1)
      list.refresh
      list.taxa.count.should be(0)
    end
  end
end

