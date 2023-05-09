require 'spec_helper'

describe ProjectUserInvitation do
  it { is_expected.to belong_to(:user).inverse_of :project_user_invitations }
  it { is_expected.to belong_to(:invited_user).class_name("User").inverse_of :project_user_invitations_received }
  it { is_expected.to belong_to(:project).inverse_of :project_user_invitations }
  it { is_expected.to validate_presence_of :user_id }
  it { is_expected.to validate_presence_of :invited_user_id }
  it { is_expected.to validate_presence_of :project_id }

  describe ProjectUserInvitation, "creation" do
    before { enable_has_subscribers }
    after { disable_has_subscribers }

    it "should email the user" do
      expect {
        ProjectUserInvitation.make!
      }.to change(ActionMailer::Base.deliveries, :size).by(1)
    end

    it "should create an update for the user" do
      expect {
        ProjectUserInvitation.make!
      }.to change(UpdateAction, :count).by(1)
    end

    it "should not be possible for members of the project" do
      pu = ProjectUser.make!
      pui = ProjectUserInvitation.make(:project => pu.project, :invited_user => pu.user)
      expect( pui ).not_to be_valid
    end
  end

  describe ProjectUserInvitation, "deletion" do
    before { enable_has_subscribers }
    after { disable_has_subscribers }
    it "should delete updates" do
      pui = without_delay { ProjectUserInvitation.make! }
      expect( UpdateAction.where(resource: pui).count ).to eq 1
      without_delay { pui.destroy }
      expect( UpdateAction.where(resource: pui).count ).to eq 0
    end
  end
end
