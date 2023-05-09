require "spec_helper"

describe Assessment do
  it { is_expected.to belong_to :project }
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :taxon }
  it do
    is_expected.to have_many(:sections).order("display_order DESC").with_foreign_key(:assessment_id)
                                       .class_name("AssessmentSection").dependent :delete_all
  end

  it { is_expected.to validate_presence_of :project }
  it { is_expected.to validate_presence_of :user }
  it { is_expected.to validate_presence_of :taxon }
end
