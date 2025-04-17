# frozen_string_literal: true

require "spec_helper"

describe ProjectFave do
  it { is_expected.to belong_to :project }
  it { is_expected.to belong_to :user }
  it { is_expected.to validate_presence_of :project }
  it { is_expected.to validate_presence_of :user }

  describe "validation" do
    it "fails if there are 7 other projects for this user" do
      user = create :user
      7.times { create :project_fave, user: user }
      expect( build( :project_fave, user: user ) ).not_to be_valid
    end

    it "fails if the user has already faved this project" do
      fave = create :project_fave
      expect( build( :project_fave, user: fave.user, project: fave.project ) ).not_to be_valid
    end
  end
end
