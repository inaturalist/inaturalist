require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectList do
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

