require "spec_helper"

describe "Project Index" do
  let(:project) { Project.make! }
  it "as_indexed_json should return a hash" do
    json = project.as_indexed_json
    expect( json ).to be_a Hash
    expect( json[:title] ).to eq project.title
  end

  # We don't index icon at all if there's no icon, not sure how this ever worked
  # it "indexes icons with absolute URLs" do
  #   p = Project.make!
  #   json = p.as_indexed_json
  #   expect( json[:icon] ).to include Site.default.url
  # end

  it "should index as spam if project is spam" do
    expect( project.as_indexed_json[:spam] ).to be false
    Flag.make!( flag: Flag::SPAM, flaggable: project )
    project.reload
    expect( project ).to be_known_spam
    expect( project.as_indexed_json[:spam] ).to be true
  end
  
  it "should index as spam if project owned by a spammer" do
    expect( project.as_indexed_json[:spam] ).to be false
    Flag.make!( flag: Flag::SPAM, flaggable: project.user )
    project.reload
    expect( project.user ).to be_known_spam
    expect( project ).to be_owned_by_spammer
    expect( project.as_indexed_json[:spam] ).to be true
  end

  describe "associated_place_ids" do
    let(:project) { Project.make! }
    let(:country) { make_place_with_geom( admin_level: Place::COUNTRY_LEVEL ) }
    let(:state) { make_place_with_geom( admin_level: Place::STATE_LEVEL, parent: country ) }
    it "should include the project's place_id" do
      project.update( place: country )
      expect( project.as_indexed_json[:associated_place_ids] ).to include country.id
    end
    it "should include the project place ancestors" do
      project.update( place: state )
      expect( project.as_indexed_json[:associated_place_ids] ).to include country.id
    end
    it "should include places from the project's rules" do
      project.project_observation_rules.create!( operator: "observed_in_place?", operand: country )
      expect( project.as_indexed_json[:associated_place_ids] ).to include country.id
    end
    it "should include ancestor places from the project's rules" do
      project.project_observation_rules.create!( operator: "observed_in_place?", operand: state )
      expect( project.as_indexed_json[:associated_place_ids] ).to include country.id
    end
    describe "for umbrella projects" do
      let(:umbrella) {
        u = Project.make!( project_type: "umbrella" )
        u.project_observation_rules.create!( operator: "in_project?", operand: project )
        u
      }
      it "should include a sub-project's place_id" do
        project.update( place: country )
        expect( umbrella.as_indexed_json[:associated_place_ids] ).to include country.id
      end
      it "should include a sub-project's place ancestors" do
        project.update( place: state )
        expect( umbrella.as_indexed_json[:associated_place_ids] ).to include country.id
      end
      it "should include places from a sub-project's rules" do
        project.project_observation_rules.create!( operator: "observed_in_place?", operand: country )
        expect( umbrella.as_indexed_json[:associated_place_ids] ).to include country.id
      end
      it "should include ancestor places from a sub-project's rules" do
        project.project_observation_rules.create!( operator: "observed_in_place?", operand: state )
        expect( umbrella.as_indexed_json[:associated_place_ids] ).to include country.id
      end
    end
  end
end
