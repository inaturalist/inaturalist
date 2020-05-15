require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ObservationField do
  elastic_models( Observation, Project )

  describe "creation" do
    it "should stip allowd values" do
      of = ObservationField.make!(:allowed_values => "foo |bar")
      expect( of.allowed_values).to eq "foo|bar"
    end
  end

  describe "validation" do
    it "should fail if allowd_values doesn't have pipes" do
      expect {
        ObservationField.make!(:allowed_values => "foo")
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "should not allow tags in the name" do
      of = ObservationField.make!(:name => "hey <script>")
      expect(of.name).to eq"hey"
    end
    it "should not allow tags in the description" do
      of = ObservationField.make!(:description => "hey <script>")
      expect(of.description).to eq "hey"
    end
    it "should not allow tags in the allowed_values" do
      of = ObservationField.make!(:allowed_values => "hey|now <script>")
      expect(of.allowed_values).to eq "hey|now"
    end
  end

  describe "editing" do
    it "should reindex observations if the name is changed" do
      o = Observation.make!
      of = ObservationField.make!(name: "oldname")
      ofv = ObservationFieldValue.make!(observation: o, observation_field: of)
      expect( Observation.page_of_results({ "field:oldname": nil }).total_entries ).to eq 1
      without_delay{ of.update_attributes(name: "newname") }
      new_of_with_oldname = ObservationField.make!(name: "oldname")
      expect( Observation.page_of_results({ "field:oldname": nil }).total_entries ).to eq 0
      expect( Observation.page_of_results({ "field:newname": nil }).total_entries ).to eq 1
    end

    it "should reindex projects" do
      of = ObservationField.make!( datatype: "numeric" )
      proj = Project.make!
      pof = ProjectObservationField.make!( project: proj, observation_field: of )
      Project.elastic_index!( ids: [proj.id] )
      expect( Project.elastic_search( id: proj.id ).results.results.first.
        project_observation_fields.first.observation_field.datatype ).to eq "numeric"
      without_delay{ of.update_attributes( datatype: "text" ) }
      expect( Project.elastic_search( id: proj.id ).results.results.first.
        project_observation_fields.first.observation_field.datatype ).to eq "text"
    end
  end

  describe "destruction" do
    it "should not be possible if assosiated projects exist"
    it "should not be possible if assosiated observations exist"
  end

  describe "merge" do
    let(:keeper) { ObservationField.make! }
    let(:reject) { ObservationField.make! }

    it "should delete the reject" do
      keeper.merge(reject)
      expect(ObservationField.find_by_id(reject.id)).to be_blank
    end

    it "should merge requested allowed values" do
      keeper.update_attributes(:allowed_values => "a|b")
      reject.update_attributes(:allowed_values => "c|d")
      keeper.merge(reject, :merge => [:allowed_values])
      keeper.reload
      expect(keeper.allowed_values).to eq "a|b|c|d"
    end

    it "should keep requested allowed values" do
      keeper.update_attributes(:allowed_values => "a|b")
      reject.update_attributes(:allowed_values => "c|d")
      keeper.merge(reject, :keep => [:allowed_values])
      keeper.reload
      expect(keeper.allowed_values).to eq "c|d"
    end

    it "should update observation field for the observation field values of the reject" do
      ofv = ObservationFieldValue.make!(:observation_field => reject)
      keeper.merge(reject)
      ofv.reload
      expect(ofv.observation_field).to eq keeper
    end

    it "should create a notification for all users of the reject"

    it "should not be possible for a reject in use by a project" do
      pof = ProjectObservationField.make!(:observation_field => reject)
      keeper.merge(reject)
      expect(ObservationField.find_by_id(reject.id)).not_to be_blank
    end
  end

end
