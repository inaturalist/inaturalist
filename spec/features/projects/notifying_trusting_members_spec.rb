require "spec_helper.rb"

# Like so many of our tests, this is more of an integration test than a unit test
describe "notifying trusting members" do
  let(:old_place) { make_place_with_geom }
  let(:new_place) { make_place_with_geom( wkt: "MULTIPOLYGON(((0 0,0 -1,-1 -1,-1 0,0 0)))" ) }
  let(:project) {
    proj = Project.make!(:collection, prefers_user_trust: true )
    ProjectObservationRule.make!(
      ruler: proj,
      operator: "observed_in_place?",
      operand: old_place
    )
    proj.reload
    proj
  }
  let(:trusting_user) {
    ProjectUser.make!(
      project: project,
      prefers_curator_coordinate_access_for: ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_ANY
    )
  }

  before do
    expect( trusting_user.prefers_curator_coordinate_access_for ).to eq ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_ANY
    Delayed::Job.delete_all
  end

  describe "should email a trusting member when" do
    def expect_deliveries_to_increment_when
      expect {
        # Instead of without_delay or Delayed::Worker.new.work_off, we need to
        # do this b/c jobs to notify members are scheduled to run in an hour,
        # and when the job is invoked the project gets reloaded and checked to
        # see if it still prefers user trust. That causes problems in situations
        # where we're testing a change in user trust that might not be committed
        # when the callback fires, so here we're a) running all jobs in the
        # future, but b) ignoring the scheduling
        after_delayed_job_finishes(:ignore_run_at) { yield }
      }.to change( ActionMailer::Base.deliveries, :size ).by 1  
    end
    it "adding a place" do
      expect_deliveries_to_increment_when do
        ProjectObservationRule.make!(
          ruler: project,
          operator: "observed_in_place?",
          operand: new_place
        )
      end
    end
    it "a place boundary changes" do
      expect_deliveries_to_increment_when do
        old_place.save_geom( new_place.place_geometry.geom )
      end
    end
    it "prefers_rule_introduced changes" do
      expect( project.prefers_rule_introduced ).to be_nil
      expect_deliveries_to_increment_when do
        project.update_attributes( prefers_rule_introduced: true )
      end
    end
    it "when trust enabled" do
      project.update_attributes( prefers_user_trust: false )
      project.reload
      expect_deliveries_to_increment_when do
        project.update_attributes( prefers_user_trust: true )
      end
    end
  end
  # should it email people when taxa move around the tree? e.g. if i trust a
  # project that's about oaks, but a beech i've observed gets lumped into the
  # oaks, suddenly they have access to that obs too
  it "should not email the member about a change to members-only" do
    expect {
      project.update_attributes( preferred_rule_members_only: true )
    }.not_to change( ActionMailer::Base.deliveries, :size )
  end
  it "should not email members that don't trust the project" do
    pu = trusting_user
    pu.update_attributes( prefers_curator_coordinate_access_for: ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_NONE )
    expect( pu.prefers_curator_coordinate_access_for ).to eq ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_NONE
    expect {
      without_delay { project.update_attributes( prefers_rule_introduced: true ) }
    }.not_to change( ActionMailer::Base.deliveries, :size )
  end
  it "should not email members that trust the project if trust is disabled" do
    project.update_attributes( prefers_user_trust: false )
    expect {
      without_delay { project.update_attributes( prefers_rule_introduced: true ) }
    }.not_to change( ActionMailer::Base.deliveries, :size )
  end
  it "should queue a single job to email the trusting members after multiple changes" do
    ProjectObservationRule.make!(
      ruler: project,
      operator: "observed_in_place?",
      operand: new_place
    )
    ProjectObservationRule.make!(
      ruler: project,
      operator: "in_taxon?",
      operand: Taxon.make!
    )
    expect(
      Delayed::Job.where( unique_hash: project.notify_trusting_members_about_changes_unique_hash.to_s ).size
    ).to eq 1
  end
  it "should not email members if trust has been disabled for the project" do
    project.update_attributes( prefers_user_trust: false )
    expect {
      project.update_attributes( prefers_rule_introduced: true )
    }.not_to change( ActionMailer::Base.deliveries, :size )
  end
end
