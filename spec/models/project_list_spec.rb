# frozen_string_literal: true

require "spec_helper"

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

  describe "listed_taxa_editable_by?" do
    it "is not editable by non-users" do
      expect( subject.listed_taxa_editable_by?( nil ) ).to be false
    end

    it "is editable by project members" do
      user = User.make!
      ProjectUser.make!( project: subject.project, user: user )
      expect( subject.listed_taxa_editable_by?( user ) ).to be true
    end
  end
end
