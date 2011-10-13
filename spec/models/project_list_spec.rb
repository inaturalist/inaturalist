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
end

