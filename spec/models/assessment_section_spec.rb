require File.expand_path("../../spec_helper", __FILE__)

describe AssessmentSection, "creation" do
  it { is_expected.to belong_to :assessment }
  it { is_expected.to belong_to :user }
  it { is_expected.to have_many(:comments).dependent :destroy }

  it { is_expected.to validate_presence_of :user }
  it { is_expected.to validate_presence_of :title }
  it { is_expected.to validate_presence_of :body }


  describe "creation" do
    it "should auto-subscribe curators" do
      a = Assessment.make!
      p = a.project
      pu = ProjectUser.make!( project: p, role: ProjectUser::CURATOR )
      as = AssessmentSection.make!( assessment: a )
      expect(
          Subscription.where(
              resource_type: "AssessmentSection",
              resource_id: as.id,
              user_id: pu.user_id
          )
      ).not_to be_blank
    end
  end

  describe "deletion" do
    it "should delete subscriptions from curators" do
      a = Assessment.make!
      p = a.project
      pu = ProjectUser.make!( project: p, role: ProjectUser::CURATOR )
      as = AssessmentSection.make!( assessment: a )
      as.destroy
      expect(
          Subscription.where(
              resource_type: "AssessmentSection",
              resource_id: as.id,
              user_id: pu.user_id
          )
      ).to be_blank
    end
  end
end
