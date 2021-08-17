require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectList do
  subject { ProjectList.make! project: Project.make! }

  it { is_expected.to belong_to :project }
  it { is_expected.to validate_presence_of :project_id }

  describe "creation" do
    it "should set defaults" do
      p = Project.make!
      pl = p.project_list
      expect( pl ).to be_valid
      expect( pl.title ).to_not be_blank
      expect( pl.description ).to_not be_blank
    end
  end
end

