require "spec_helper.rb"

# Like so many of our tests, this is more of an integration test than a unit test
describe "notifying trusting members" do
  let(:old_place) { make_place_with_geom }
  let(:new_place) { make_place_with_geom( wkt: "MULTIPOLYGON(((0 0,0 -1,-1 -1,-1 0,0 0)))" ) }
  let(:project) {
    proj = Project.make!(:collection)
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
        without_delay { yield }
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
    pu = ProjectUser.make!( project: project )
    expect( pu.prefers_curator_coordinate_access_for ).to eq ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_NONE
    expect {
      project.update_attributes( prefers_rule_introduced: true )
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
end
